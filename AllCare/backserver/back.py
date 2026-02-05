
import json
import threading
import uuid
from datetime import datetime
from io import BytesIO
from pathlib import Path
from typing import Optional, Dict, Any, List
import subprocess
from fastapi.staticfiles import StaticFiles
import cv2
import numpy as np
from fastapi import FastAPI, File, UploadFile, HTTPException, Header, Depends
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image

from . import auth
from . import config
from . import crypto_utils
from .model import ModelService

from .AL import get_active_learning_candidates
from .retrain_model import get_retrain_status, retrain_model, check_retrain_threshold
from . import model_registry
from . import training_config
from . import labels_pool
from . import event_log
from . import auto_promote
from .schemas import (
    CheckImageResponse,
    CaseLog,
    CaseUpdate,
    RejectCase,
    CaseIdRelease,
    LabelSubmission,
    LoginRequest,
    TokenResponse,
    UserInfo,
    AnnotationSubmission,
    TrainingConfigRequest,
    ModelPromoteRequest,
    ModelRollbackRequest,
    RetrainTriggerRequest,
)
app = FastAPI()

# Case ID sequencing
_CASE_ID_LOCK = threading.Lock()
_CASE_ID_MAX_DIGITS = 6  # Ignore legacy date-based IDs when scanning metadata.

# Ensure storage paths exist
Path(config.STORAGE_ROOT).mkdir(parents=True, exist_ok=True)
Path(config.CASE_COUNTER_FILE).parent.mkdir(parents=True, exist_ok=True)

origins = ["*"] if not config.ALLOWED_ORIGINS or "*" in config.ALLOWED_ORIGINS else config.ALLOWED_ORIGINS
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def require_api_key(x_api_key: Optional[str] = Header(default=None)):
    if config.API_KEY and x_api_key != config.API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")
    return True


def _normalize_user_id(user_id: Optional[str]) -> Optional[str]:
    if not user_id:
        return None
    cleaned = user_id.strip()
    if not cleaned:
        return None
    safe = "".join(ch for ch in cleaned if ch.isalnum() or ch in ("-", "_"))
    return safe or None


def _role_allows_global_access(user_role: str) -> bool:
    return user_role in {"admin"}


def get_user_context(
    authorization: Optional[str] = Header(default=None),
    x_user_id: Optional[str] = Header(default=None, alias="X-User-Id"),
    x_user_role: Optional[str] = Header(default=None, alias="X-User-Role"),
) -> Dict[str, str]:
    """
    Extract user context from JWT token or legacy headers.
    Prefers JWT token if Authorization header is present.
    Falls back to X-User-Id/X-User-Role headers for backward compatibility.
    """
    if authorization and authorization.lower().startswith("bearer "):
        return auth.get_current_user(authorization)

    user_id = _normalize_user_id(x_user_id)
    if not user_id:
        raise HTTPException(status_code=400, detail="Missing Authorization header or X-User-Id header")
    user_role = (x_user_role or "").strip().lower()
    return {"user_id": user_id, "user_role": user_role}


def _user_storage_dir(user_id: str) -> Path:
    return Path(config.STORAGE_ROOT) / user_id


def _user_metadata_path(user_id: str) -> Path:
    return _user_storage_dir(user_id) / config.METADATA_FILENAME


def _ensure_user_storage(user_id: str) -> Path:
    user_dir = _user_storage_dir(user_id)
    user_dir.mkdir(parents=True, exist_ok=True)
    return user_dir


def get_blur_score(image):
    """
    ฟังก์ชันคำนวณค่าความชัด (Laplacian Variance)
    ค่ายิ่งเยอะ ยิ่งชัด
    """
    cvt_color = getattr(cv2, "cvtColor")
    laplacian = getattr(cv2, "Laplacian")
    color_bgr2gray = getattr(cv2, "COLOR_BGR2GRAY")
    cv_64f = getattr(cv2, "CV_64F")

    gray = cvt_color(image, color_bgr2gray)
    score = laplacian(gray, cv_64f).var()
    return score


def _save_image(bytes_data: bytes, image_id: str, user_id: str) -> str:
    image = Image.open(BytesIO(bytes_data)).convert("RGB")
    user_dir = _ensure_user_storage(user_id)
    dest = user_dir / f"{image_id}.jpg"
    if crypto_utils.is_encryption_enabled():
        buffer = BytesIO()
        image.save(buffer, format="JPEG", quality=90)
        encrypted = crypto_utils.encrypt_bytes(buffer.getvalue())
        dest = dest.with_suffix(".bin")
        with open(dest, "wb") as f:
            f.write(encrypted)
        return str(dest)

    image.save(dest, format="JPEG", quality=90)
    return str(dest)


def _append_metadata(entry: Dict[str, Any], metadata_path: Path) -> None:
    entry_line = _serialize_metadata_entry(entry)
    metadata_path.parent.mkdir(parents=True, exist_ok=True)
    with open(metadata_path, "a", encoding="utf-8") as f:
        f.write(entry_line + "\n")


def _serialize_metadata_entry(entry: Dict[str, Any]) -> str:
    if crypto_utils.is_encryption_enabled():
        entry = crypto_utils.encrypt_json(entry)
    return json.dumps(entry, ensure_ascii=False)


def _load_metadata_entry(line: str) -> Optional[Dict[str, Any]]:
    try:
        entry = json.loads(line.strip())
    except json.JSONDecodeError:
        return None
    if isinstance(entry, dict) and "enc" in entry:
        try:
            return crypto_utils.decrypt_json(entry)
        except (ValueError, RuntimeError, json.JSONDecodeError):
            return None
    if isinstance(entry, dict):
        return entry
    return None


def _read_metadata_entries(metadata_path: Path) -> List[Dict[str, Any]]:
    entries: List[Dict[str, Any]] = []
    if metadata_path.exists():
        with open(metadata_path, "r", encoding="utf-8") as f:
            for line in f:
                entry = _load_metadata_entry(line)
                if entry:
                    entries.append(entry)
    return entries


def _write_metadata_entries(metadata_path: Path, entries: List[Dict[str, Any]]) -> None:
    metadata_path.parent.mkdir(parents=True, exist_ok=True)
    with open(metadata_path, "w", encoding="utf-8") as f:
        for entry in entries:
            f.write(_serialize_metadata_entry(entry) + "\n")


def _iter_user_metadata_paths() -> List[tuple[str, Path]]:
    root = Path(config.STORAGE_ROOT)
    paths: List[tuple[str, Path]] = []
    if not root.exists():
        return paths
    for child in root.iterdir():
        if child.is_dir():
            paths.append((child.name, child / config.METADATA_FILENAME))
    return paths


def _read_user_metadata_entries(user_id: str) -> List[Dict[str, Any]]:
    return _read_metadata_entries(_user_metadata_path(user_id))


def _read_all_metadata_entries() -> List[Dict[str, Any]]:
    entries: List[Dict[str, Any]] = []
    for _, metadata_path in _iter_user_metadata_paths():
        entries.extend(_read_metadata_entries(metadata_path))
    legacy_metadata_path = Path(config.LEGACY_METADATA_FILE)
    if legacy_metadata_path.exists():
        entries.extend(_read_metadata_entries(legacy_metadata_path))
    return entries


def _count_rejected_labeled_images(entries: List[Dict[str, Any]]) -> int:
    count = 0
    for entry in entries:
        if entry.get("entry_type") != "reject":
            continue
        if not entry.get("correct_label"):
            continue
        image_paths = entry.get("image_paths") or []
        count += len(image_paths)
    return count


def _user_counter_path(user_id: str) -> Path:
    """Get the path to the user-specific case counter file."""
    user_dir = _user_storage_dir(user_id)
    return user_dir / "case_counter.json"


def _read_user_case_counter(user_id: str) -> Optional[int]:
    """Read the case counter for a specific user."""
    counter_path = _user_counter_path(user_id)
    if not counter_path.exists():
        return None
    try:
        data = json.loads(counter_path.read_text(encoding="utf-8"))
        last_id = data.get("last_case_id")
        return int(last_id)
    except (ValueError, TypeError, json.JSONDecodeError):
        return None


def _write_user_case_counter(user_id: str, last_id: int) -> None:
    """Write the case counter for a specific user."""
    counter_path = _user_counter_path(user_id)
    counter_path.parent.mkdir(parents=True, exist_ok=True)
    counter_path.write_text(json.dumps({"last_case_id": last_id}), encoding="utf-8")


def _max_case_id_from_user_metadata(user_id: str) -> Optional[int]:
    """Find the maximum case ID from a user's metadata entries."""
    metadata_path = _user_metadata_path(user_id)
    entries = _read_metadata_entries(metadata_path)
    max_id = None
    for entry in entries:
        case_id = entry.get("case_id")
        if isinstance(case_id, str) and case_id.isdigit():
            if len(case_id) > _CASE_ID_MAX_DIGITS:
                continue
            value = int(case_id)
            if value < config.CASE_ID_START:
                continue
            if max_id is None or value > max_id:
                max_id = value
    return max_id


def _next_case_id_for_user(user_id: str) -> str:
    """Generate the next case ID for a specific user. Starts from 10001."""
    with _CASE_ID_LOCK:
        last_id = _read_user_case_counter(user_id)
        if last_id is None:
            # Check existing metadata for this user to find max case_id
            last_id = _max_case_id_from_user_metadata(user_id) or (config.CASE_ID_START - 1)
        next_id = max(last_id + 1, config.CASE_ID_START)
        _write_user_case_counter(user_id, next_id)
        return str(next_id)


# Legacy global counter functions (kept for backwards compatibility)
def _read_case_counter() -> Optional[int]:
    counter_path = Path(config.CASE_COUNTER_FILE)
    if not counter_path.exists():
        return None
    try:
        data = json.loads(counter_path.read_text(encoding="utf-8"))
        last_id = data.get("last_case_id")
        return int(last_id)
    except (ValueError, TypeError, json.JSONDecodeError):
        return None


def _write_case_counter(last_id: int) -> None:
    counter_path = Path(config.CASE_COUNTER_FILE)
    counter_path.write_text(json.dumps({"last_case_id": last_id}), encoding="utf-8")


def _max_case_id_from_metadata(entries: List[Dict[str, Any]]) -> Optional[int]:
    max_id = None
    for entry in entries:
        case_id = entry.get("case_id")
        if isinstance(case_id, str) and case_id.isdigit():
            if len(case_id) > _CASE_ID_MAX_DIGITS:
                continue
            value = int(case_id)
            if value < config.CASE_ID_START:
                continue
            if max_id is None or value > max_id:
                max_id = value
    return max_id


def _next_case_id() -> str:
    with _CASE_ID_LOCK:
        last_id = _read_case_counter()
        if last_id is None:
            entries = _read_all_metadata_entries()
            last_id = _max_case_id_from_metadata(entries) or (config.CASE_ID_START - 1)
        next_id = max(last_id + 1, config.CASE_ID_START)
        _write_case_counter(next_id)
        return str(next_id)


def _case_id_has_entries(case_id: str) -> bool:
    entries = _read_all_metadata_entries()
    for entry in entries:
        if entry.get("case_id") == case_id:
            return True
    return False


def _case_metadata_keys(entry: Dict[str, Any]) -> Dict[str, Any]:
    payload_keys = ("gender", "age", "location", "symptoms", "notes")
    return {key: entry.get(key) for key in payload_keys if entry.get(key) not in (None, [], "")}


def _apply_case_summary_to_image(entry: Dict[str, Any], case_entry: Dict[str, Any]) -> Dict[str, Any]:
    updated = dict(entry)
    updated["case_status"] = case_entry.get("status")
    updated["case_entry_type"] = case_entry.get("entry_type")
    updated["case_updated_at"] = case_entry.get("created_at")
    if case_entry.get("user_id"):
        updated["user_id"] = case_entry.get("user_id")
    if case_entry.get("user_role"):
        updated["user_role"] = case_entry.get("user_role")
    updated.update(_case_metadata_keys(case_entry))
    return updated


def _collect_image_ids(entries: List[Dict[str, Any]], case_id: str) -> List[str]:
    image_ids = {
        entry.get("image_id")
        for entry in entries
        if entry.get("case_id") == case_id and isinstance(entry.get("image_id"), str)
    }
    return sorted(image_ids)


def _log_case_entry(
    payload: Any,
    *,
    entry_type: str,
    default_status: str,
    user_id: str,
    user_role: str,
) -> Dict[str, Any]:
    """Persist a case-like entry and return the stored dict."""
    entry = payload.model_dump()
    case_id = entry.get("case_id")
    if case_id is None or str(case_id).strip() == "":
        entry["case_id"] = _next_case_id_for_user(user_id)
    else:
        entry["case_id"] = str(case_id)
    entry["entry_type"] = entry_type
    entry["status"] = entry.get("status") or default_status
    entry["user_id"] = user_id
    if user_role:
        entry["user_role"] = user_role
    if not entry.get("created_at"):
        entry["created_at"] = datetime.now().isoformat()

    case_id = entry["case_id"]
    metadata_path = _user_metadata_path(user_id)
    entries = _read_metadata_entries(metadata_path)
    updated_entries: List[Dict[str, Any]] = []
    for existing in entries:
        if existing.get("case_id") == case_id:
            if existing.get("entry_type") in {"case", "uncertain", "reject"}:
                continue
            if existing.get("image_id"):
                updated_entries.append(_apply_case_summary_to_image(existing, entry))
                continue
        updated_entries.append(existing)

    image_ids = _collect_image_ids(updated_entries, case_id)
    if image_ids:
        entry["image_ids"] = image_ids
        entry["image_paths"] = [f"{user_id}/{img_id}.jpg" for img_id in image_ids]

    updated_entries.append(entry)
    _write_metadata_entries(metadata_path, updated_entries)
    return entry


def _update_case_in_entries(
    entries: List[Dict[str, Any]],
    case_id: str,
    update_fields: Dict[str, Any],
) -> Optional[Dict[str, Any]]:
    allowed_entry_types = {"case", "uncertain"}
    for idx in range(len(entries) - 1, -1, -1):
        entry = entries[idx]
        if entry.get("case_id") != case_id:
            continue
        if entry.get("entry_type") not in allowed_entry_types:
            continue
        entry.update(update_fields)
        entry["updated_at"] = datetime.now().isoformat()
        entries[idx] = entry
        return entry
    return None


def _update_case_in_user_storage(
    user_id: str,
    case_id: str,
    update_fields: Dict[str, Any],
) -> Optional[Dict[str, Any]]:
    metadata_path = _user_metadata_path(user_id)
    entries = _read_metadata_entries(metadata_path)
    if not entries:
        return None
    updated_entry = _update_case_in_entries(entries, case_id, update_fields)
    if updated_entry is None:
        return None
    _write_metadata_entries(metadata_path, entries)
    return updated_entry


def _should_include_entry(
    entry: Dict[str, Any],
    allowed_entry_types: set,
    status_filter: Optional[str],
) -> bool:
    entry_type = entry.get("entry_type")
    if entry_type not in allowed_entry_types:
        return False

    if status_filter is None:
        return True

    entry_status = entry.get("status")
    return isinstance(entry_status, str) and entry_status.lower() == status_filter.lower()


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/auth/login", response_model=TokenResponse)
async def login(payload: LoginRequest):
    """
    Authenticate user and return JWT access token.
    """
    user = auth.authenticate_user(payload.username, payload.password)
    if not user:
        raise HTTPException(
            status_code=401,
            detail="Invalid username or password",
        )

    access_token = auth.create_access_token(
        user_id=payload.username,
        user_role=user.get("role", ""),
        first_name=user.get("first_name", ""),
        last_name=user.get("last_name", ""),
    )

    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        user=UserInfo(
            user_id=payload.username,
            first_name=user.get("first_name", ""),
            last_name=user.get("last_name", ""),
            role=user.get("role", ""),
        ),
    )


@app.post("/cases/next-id", dependencies=[Depends(require_api_key)])
async def next_case_id(user_context: Dict[str, str] = Depends(get_user_context)):
    user_id = user_context["user_id"]
    return {"case_id": _next_case_id_for_user(user_id)}


@app.post("/cases/release-id", dependencies=[Depends(require_api_key)])
async def release_case_id(
    payload: CaseIdRelease,
    user_context: Dict[str, str] = Depends(get_user_context),
):
    case_id = payload.case_id.strip()
    if not case_id or not case_id.isdigit():
        raise HTTPException(status_code=400, detail="Invalid case_id")

    user_id = user_context["user_id"]

    with _CASE_ID_LOCK:
        last_id = _read_user_case_counter(user_id)
        if last_id is None:
            return {"status": "skipped", "reason": "missing_counter"}
        if str(last_id) != case_id:
            return {
                "status": "skipped",
                "reason": "counter_mismatch",
                "last_case_id": str(last_id),
            }
        # Check if case_id has entries in user's metadata
        metadata_path = _user_metadata_path(user_id)
        entries = _read_metadata_entries(metadata_path)
        case_in_use = any(entry.get("case_id") == case_id for entry in entries)
        if case_in_use:
            return {"status": "skipped", "reason": "case_in_use"}
        next_last_id = max(last_id - 1, config.CASE_ID_START - 1)
        _write_user_case_counter(user_id, next_last_id)

    return {"status": "ok", "case_id": case_id}


@app.post("/check-image", response_model=CheckImageResponse, dependencies=[Depends(require_api_key)])
async def check_image(
    file: UploadFile = File(...),
    case_id: Optional[str] = None,
    user_context: Dict[str, str] = Depends(get_user_context),
):
    contents = await file.read()
    nparr = np.frombuffer(contents, np.uint8)
    imdecode = getattr(cv2, "imdecode")
    imread_color = getattr(cv2, "IMREAD_COLOR")
    img = imdecode(nparr, imread_color)

    if img is None:
        raise HTTPException(status_code=400, detail="Invalid image file")

    blur_score = get_blur_score(img)
    pil_image = Image.open(BytesIO(contents)).convert("RGB")
    predictions = model_service.predict(pil_image)

    image_id = str(uuid.uuid4())
    user_id = user_context["user_id"]
    user_role = user_context.get("user_role", "")
    case_id = case_id or _next_case_id_for_user(user_id)
    _save_image(contents, image_id, user_id)

    status = "success" if blur_score >= config.BLUR_THRESHOLD else "fail"
    message = (
        f"Image is too blurry (score={blur_score:.2f}, threshold={config.BLUR_THRESHOLD})"
        if status == "fail"
        else "Image processed"
    )

    _append_metadata(
        {
            "case_id": case_id,
            "image_id": image_id,
            "blur_score": blur_score,
            "predictions": predictions,
            "status": status,
            "created_at": datetime.now().isoformat(),
            "user_id": user_id,
            "user_role": user_role or None,
        },
        _user_metadata_path(user_id),
    )

    return CheckImageResponse(
        status=status,
        message=message,
        blur_score=blur_score,
        predictions=predictions,
        image_id=image_id,
        case_id=case_id,
        user_id=user_id,
        user_role=user_role or None,
    )


@app.get("/cases", dependencies=[Depends(require_api_key)])
async def get_cases(
    status: Optional[str] = None,
    limit: int = 100,
    include_uncertain: bool = True,
    include_rejected: bool = True,
    user_context: Dict[str, str] = Depends(get_user_context),
):
    """Return all cases, optionally filtered by status. Most recent first."""
    allowed_entry_types = {"case"}
    if include_uncertain:
        allowed_entry_types.add("uncertain")
    if include_rejected:
        allowed_entry_types.add("reject")

    cases = []
    user_role = user_context.get("user_role", "")
    if _role_allows_global_access(user_role):
        entries = _read_all_metadata_entries()
    else:
        entries = _read_user_metadata_entries(user_context["user_id"])
    for entry in entries:
        if entry and _should_include_entry(entry, allowed_entry_types, status):
            cases.append(entry)
    # Return most recent first, limited
    return {"cases": cases[-limit:][::-1]}


@app.post("/cases", dependencies=[Depends(require_api_key)])
async def log_case(payload: CaseLog, user_context: Dict[str, str] = Depends(get_user_context)):
    entry = _log_case_entry(
        payload,
        entry_type="case",
        default_status="pending",
        user_id=user_context["user_id"],
        user_role=user_context.get("user_role", ""),
    )
    return {
        "status": "ok",
        "message": "logged",
        "case_id": entry.get("case_id"),
        "case_status": entry.get("status"),
    }


@app.put("/cases/{case_id}", dependencies=[Depends(require_api_key)])
async def update_case(
    case_id: str,
    payload: CaseUpdate,
    user_context: Dict[str, str] = Depends(get_user_context),
):
    update_fields = payload.model_dump(exclude_unset=True)
    target_user_id = _normalize_user_id(update_fields.pop("user_id", None))
    update_fields.pop("user_role", None)
    if not update_fields:
        raise HTTPException(status_code=400, detail="No fields to update")

    user_role = user_context.get("user_role", "")
    if _role_allows_global_access(user_role):
        if target_user_id:
            updated_entry = _update_case_in_user_storage(target_user_id, case_id, update_fields)
        else:
            updated_entry = None
            for user_id, metadata_path in _iter_user_metadata_paths():
                entries = _read_metadata_entries(metadata_path)
                updated_entry = _update_case_in_entries(entries, case_id, update_fields)
                if updated_entry:
                    _write_metadata_entries(metadata_path, entries)
                    break
            if updated_entry is None:
                legacy_metadata_path = Path(config.LEGACY_METADATA_FILE)
                if legacy_metadata_path.exists():
                    entries = _read_metadata_entries(legacy_metadata_path)
                    updated_entry = _update_case_in_entries(entries, case_id, update_fields)
                    if updated_entry:
                        _write_metadata_entries(legacy_metadata_path, entries)
    else:
        updated_entry = _update_case_in_user_storage(user_context["user_id"], case_id, update_fields)

    if updated_entry is None:
        raise HTTPException(status_code=404, detail="Case not found")

    return {"status": "ok", "case_id": case_id}




@app.get("/model/retrain-status", dependencies=[Depends(require_api_key)])
async def get_retrain_status_endpoint(user_context: Dict[str, str] = Depends(get_user_context)):
    """
    Get current retraining status and statistics.
    """
    try:
        status = get_retrain_status()
        return status
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get retrain status: {str(e)}")


@app.post("/model/retrain", dependencies=[Depends(require_api_key)])
async def retrain_model_endpoint(user_context: Dict[str, str] = Depends(get_user_context)):
    """
    Trigger model retraining using labeled data from active learning.
    Only admins can trigger retraining.
    """
    user_role = user_context.get("user_role", "").lower()

    if user_role != "admin":
        raise HTTPException(status_code=403, detail="Only admins can trigger model retraining")

    try:
        total_rejected_labeled = _count_rejected_labeled_images(_read_all_metadata_entries())
        if total_rejected_labeled < config.RETRAIN_MIN_NEW_LABELS:
            return {
                "status": "skipped",
                "reason": "insufficient_rejected_labels",
                "required": config.RETRAIN_MIN_NEW_LABELS,
                "current": total_rejected_labeled,
            }

        # Run retraining script asynchronously
        script_path = Path(__file__).parent / "retrain_model.py"

        # Start retraining in background
        process = subprocess.Popen([
            "python", str(script_path),
            "--epochs", "5",
            "--batch-size", "16",
            "--learning-rate", "0.0001",
            "--min-samples", "10"
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        # Return immediately with process info
        return {
            "status": "retraining_started",
            "message": "Model retraining has been started in the background",
            "process_id": process.pid
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to start retraining: {str(e)}")

@app.post("/cases/{case_id}/label", dependencies=[Depends(require_api_key)])
async def submit_case_label(
    case_id: str,
    payload: LabelSubmission,
    user_context: Dict[str, str] = Depends(get_user_context)
):
    """
    Submit a label for a case in active learning.
    """
    
    # Find and update the case
    user_id = user_context["user_id"]
    user_role = user_context.get("user_role", "")
    if user_role == "gp":
        raise HTTPException(status_code=403, detail="GP role is not allowed to label rejected cases")

    # Load user metadata using JSONL format
    metadata_path = _user_metadata_path(user_id)
    if not metadata_path.exists():
        raise HTTPException(status_code=404, detail="User metadata not found")

    # Read metadata entries using JSONL format
    metadata = _read_metadata_entries(metadata_path)

    # Find the case (prefer rejected entry, then fall back to case/uncertain)
    case_index = None
    fallback_index = None
    for i in range(len(metadata) - 1, -1, -1):
        entry = metadata[i]
        if entry.get("case_id") != case_id:
            continue
        entry_type = entry.get("entry_type")
        if entry_type == "reject":
            case_index = i
            break
        if fallback_index is None and entry_type in {"case", "uncertain"}:
            fallback_index = i

    if case_index is None:
        case_index = fallback_index

    if case_index is None:
        raise HTTPException(status_code=404, detail="Case not found")

    # Update the case with the label
    entry = metadata[case_index]
    entry["correct_label"] = payload.correct_label
    entry["labeled_by"] = user_id
    entry["labeled_at"] = datetime.now().isoformat()
    entry["label_notes"] = payload.notes
    entry["updated_at"] = datetime.now().isoformat()
    metadata[case_index] = entry

    # Save updated metadata using JSONL format
    _write_metadata_entries(metadata_path, metadata)

    return {
        "status": "ok",
        "message": "Label submitted successfully",
        "case_id": case_id,
        "correct_label": payload.correct_label
    }


@app.post("/cases/uncertain", dependencies=[Depends(require_api_key)])
async def log_uncertain_case(payload: CaseLog, user_context: Dict[str, str] = Depends(get_user_context)):
    entry = _log_case_entry(
        payload,
        entry_type="uncertain",
        default_status="pending",
        user_id=user_context["user_id"],
        user_role=user_context.get("user_role", ""),
    )
    return {
        "status": "ok",
        "message": "uncertain_logged",
        "case_id": entry.get("case_id"),
        "case_status": entry.get("status"),
    }


@app.post("/cases/reject", dependencies=[Depends(require_api_key)])
async def reject_case(payload: RejectCase, user_context: Dict[str, str] = Depends(get_user_context)):
    _log_case_entry(
        payload,
        entry_type="reject",
        default_status="rejected",
        user_id=user_context["user_id"],
        user_role=user_context.get("user_role", ""),
    )
    return {"status": "ok", "message": "rejected_logged"}


#(bridge-frontend-backend): Add annotations endpoint
# This endpoint receives annotation data from the AnnotateScreen (strokes, boxes, correct label)
# and updates the rejected case entry for active learning model retraining.

@app.post("/cases/{case_id}/annotations", dependencies=[Depends(require_api_key)])
async def save_annotations(
    case_id: str,
    payload: AnnotationSubmission,
    user_context: Dict[str, str] = Depends(get_user_context),
):
    """
    Save manual annotations (strokes, boxes, correct_label) for a case.
    Updates the case's correct_label for active learning retraining.
    """
    user_id = user_context["user_id"]
    user_role = user_context.get("user_role", "")
    case_user_id = (payload.case_user_id or "").strip()
    target_user_id = case_user_id or user_id

    def _find_rejected_case_index(case_entries: List[Dict[str, Any]]) -> Optional[int]:
        for i in range(len(case_entries) - 1, -1, -1):
            entry = case_entries[i]
            if entry.get("case_id") == case_id and entry.get("entry_type") == "reject":
                return i
        return None

    metadata_path = _user_metadata_path(target_user_id)
    entries = _read_metadata_entries(metadata_path)

    # Find the rejected case entry for the target user
    case_index = _find_rejected_case_index(entries)

    # Allow doctors/admins to annotate rejected cases across users when needed
    if case_index is None and not case_user_id and user_role.lower() in {"doctor", "admin"}:
        matched = None
        for _, candidate_path in _iter_user_metadata_paths():
            candidate_entries = _read_metadata_entries(candidate_path)
            candidate_index = _find_rejected_case_index(candidate_entries)
            if candidate_index is None:
                continue
            if matched is not None:
                raise HTTPException(
                    status_code=409,
                    detail="Multiple rejected cases found for case_id; provide case_user_id",
                )
            matched = (candidate_path, candidate_entries, candidate_index)
        if matched is not None:
            metadata_path, entries, case_index = matched

    if case_index is None:
        if case_user_id and not metadata_path.exists():
            raise HTTPException(status_code=404, detail="User metadata not found")
        raise HTTPException(status_code=404, detail="Rejected case not found")
    
    # Block GP role from annotating rejected cases
    if user_role.lower() == "gp":
        raise HTTPException(status_code=403, detail="GP role is not allowed to annotate rejected cases")

    # Update with annotation data
    entry = entries[case_index]
    entry["correct_label"] = payload.correct_label
    entry["annotations"] = payload.annotations
    entry["annotated_by"] = user_id
    entry["annotated_at"] = payload.annotated_at or datetime.now().isoformat()
    entry["annotation_image_index"] = payload.image_index
    if payload.notes:
        entry["annotation_notes"] = payload.notes
    entry["updated_at"] = datetime.now().isoformat()

    entries[case_index] = entry
    _write_metadata_entries(metadata_path, entries)

    return {
        "status": "ok",
        "message": "Annotations saved successfully",
        "case_id": case_id,
        "correct_label": payload.correct_label,
    }


app.mount("/images", StaticFiles(directory=config.STORAGE_ROOT), name="images")

# แทนที่ฟังก์ชัน get_active_learning_candidates_endpoint ด้วย:
@app.post("/active-learning/candidates", dependencies=[Depends(require_api_key)])
async def get_active_learning_candidates_endpoint(payload: Dict[str, Any], user_context: Dict[str, str] = Depends(get_user_context)):
    """
    Get active learning candidates based on uncertainty sampling.
    For doctors and admins, considers all cases in the system.
    For GPs, considers only their own cases.
    """
    user_role = user_context.get("user_role", "").lower()
    top_k = payload.get('top_k', config.AL_CANDIDATES_TOP_K)
    entry_type_filter = (payload.get('entry_type') or config.AL_CANDIDATES_ENTRY_TYPE or '').strip().lower()
    status_filter = (payload.get('status') or config.AL_CANDIDATES_STATUS or '').strip().lower()
    include_labeled = bool(payload.get('include_labeled', config.AL_CANDIDATES_INCLUDE_LABELED))

    # Get entries based on user role
    if user_role in {"doctor", "admin"}:
        # Doctors and admins can see all cases for active learning
        all_entries = _read_all_metadata_entries()
        entries = [entry for entry in all_entries if entry]
    else:
        # GPs can only see their own cases
        entries = _read_user_metadata_entries(user_context["user_id"])

    if not entries:
        return {"candidates": [], "total_candidates": 0, "message": "No cases available"}

    # Compute margin for all cases (only case-level entries)
    case_entry_types = {"case", "uncertain", "reject"}
    if include_labeled:
        candidates_entries = [
            e for e in entries
            if (e.get('entry_type') or '').strip().lower() in case_entry_types
        ]
    else:
        candidates_entries = [
            e for e in entries
            if (e.get('entry_type') or '').strip().lower() in case_entry_types
            and not e.get('correct_label')
        ]
    if entry_type_filter:
        candidates_entries = [
            e for e in candidates_entries
            if (e.get('entry_type') or '').strip().lower() == entry_type_filter
        ]
    if status_filter:
        candidates_entries = [
            e for e in candidates_entries
            if (e.get('status') or '').strip().lower() == status_filter
        ]
    image_entries = {e['image_id']: e for e in entries if 'image_id' in e}

    # Build cases with images
    cases = []
    for case_entry in candidates_entries:
        images = []
        for image_path in case_entry.get('image_paths', []) or []:
            image_id = Path(str(image_path)).stem if image_path else None
            img_entry = image_entries.get(image_id) if image_id else None
            image_payload = {
                'path': image_path,
                'image_id': image_id,
            }
            if img_entry:
                image_payload.update({
                    'predictions': img_entry.get('predictions', []),
                    'blur_score': img_entry.get('blur_score'),
                    'status': img_entry.get('status'),
                })
            images.append(image_payload)
        if images:
            case_entry['images'] = images
        cases.append(case_entry)

    if not cases:
        return {"candidates": [], "total_candidates": 0, "message": "No cases with images available"}

    effective_top_k = top_k
    if effective_top_k is None or int(effective_top_k) <= 0:
        effective_top_k = len(cases)
    result = get_active_learning_candidates(cases, int(effective_top_k))
    return result


# =============================================================================
# Admin Endpoints - Active Learning Model Management
# =============================================================================

def require_admin_role(user_context: Dict[str, str] = Depends(get_user_context)):
    """Dependency to ensure user has admin role."""
    if user_context.get("user_role", "").lower() != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    return user_context


@app.get("/admin/training-config", dependencies=[Depends(require_api_key)])
async def get_training_config(user_context: Dict[str, str] = Depends(require_admin_role)):
    """Get current training configuration."""
    current_config = training_config.load_config()
    return {
        "status": "ok",
        "config": current_config,
        "defaults": training_config.get_default_config()
    }


@app.post("/admin/training-config", dependencies=[Depends(require_api_key)])
async def update_training_config(
    payload: TrainingConfigRequest,
    user_context: Dict[str, str] = Depends(require_admin_role)
):
    """Update training configuration."""
    # Build config dict from non-None fields
    new_config = {k: v for k, v in payload.model_dump().items() if v is not None}

    if not new_config:
        raise HTTPException(status_code=400, detail="No configuration values provided")

    # Validate
    is_valid, errors = training_config.validate_config(new_config)
    if not is_valid:
        raise HTTPException(status_code=400, detail={"validation_errors": errors})

    # Save
    training_config.save_config(new_config)
    event_log.log_config_updated(new_config)

    return {
        "status": "ok",
        "message": "Training configuration updated",
        "config": training_config.load_config()
    }


@app.get("/admin/models", dependencies=[Depends(require_api_key)])
async def list_models(
    status: Optional[str] = None,
    user_context: Dict[str, str] = Depends(require_admin_role)
):
    """List all models, optionally filtered by status."""
    models = model_registry.list_models(status=status)
    production = model_registry.get_production_model()

    return {
        "status": "ok",
        "models": models,
        "current_production": production["version_id"] if production else None,
        "total": len(models)
    }


@app.get("/admin/models/production", dependencies=[Depends(require_api_key)])
async def get_production_model(user_context: Dict[str, str] = Depends(require_admin_role)):
    """Get current production model info."""
    production = model_registry.get_production_model()

    if not production:
        return {
            "status": "ok",
            "production_model": None,
            "message": "No production model deployed"
        }

    return {
        "status": "ok",
        "production_model": production
    }


@app.post("/admin/models/{version_id}/promote", dependencies=[Depends(require_api_key)])
async def promote_model(
    version_id: str,
    payload: ModelPromoteRequest,
    user_context: Dict[str, str] = Depends(require_admin_role)
):
    """Manually promote a model to production."""
    result = auto_promote.manual_promote(version_id, payload.reason)

    if not result.get("success"):
        raise HTTPException(status_code=400, detail=result.get("error", "Promotion failed"))

    return {
        "status": "ok",
        "message": f"Model {version_id} promoted to production",
        **result
    }


@app.post("/admin/models/{version_id}/rollback", dependencies=[Depends(require_api_key)])
async def rollback_model(
    version_id: str,
    payload: ModelRollbackRequest,
    user_context: Dict[str, str] = Depends(require_admin_role)
):
    """Rollback to a specific model version."""
    result = auto_promote.trigger_rollback(to_version=version_id, reason=payload.reason)

    if not result.get("success"):
        raise HTTPException(status_code=400, detail=result.get("error", "Rollback failed"))

    return {
        "status": "ok",
        "message": f"Rolled back to model {version_id}",
        **result
    }


@app.post("/admin/retrain/trigger", dependencies=[Depends(require_api_key)])
async def trigger_retrain(
    payload: RetrainTriggerRequest,
    user_context: Dict[str, str] = Depends(require_admin_role)
):
    """Manually trigger model retraining."""
    # Check threshold unless forced
    if not payload.force:
        should_retrain, current, threshold = check_retrain_threshold()
        if not should_retrain:
            return {
                "status": "skipped",
                "reason": "Below threshold",
                "current_labels": current,
                "threshold": threshold,
                "message": "Use force=true to override"
            }

    # Start retraining (this is synchronous for now - consider background task for production)
    result = retrain_model(architecture=payload.architecture)

    if not result.get("success"):
        raise HTTPException(status_code=500, detail=result.get("error", "Retraining failed"))

    # Auto-evaluate and promote if successful
    if result.get("success"):
        eval_result = auto_promote.evaluate_and_promote(
            result["version_id"],
            auto_promote=True
        )
        result["promotion_result"] = eval_result

    return {
        "status": "ok",
        "message": "Retraining completed",
        **result
    }


@app.get("/admin/retrain/status", dependencies=[Depends(require_api_key)])
async def get_retrain_status_endpoint(user_context: Dict[str, str] = Depends(require_admin_role)):
    """Get current retraining status."""
    status = get_retrain_status()
    threshold_info = check_retrain_threshold()

    return {
        "status": "ok",
        "retrain_status": status,
        "threshold": {
            "should_retrain": threshold_info[0],
            "current_labels": threshold_info[1],
            "required": threshold_info[2]
        }
    }


@app.get("/admin/events", dependencies=[Depends(require_api_key)])
async def get_events(
    limit: int = 50,
    event_type: Optional[str] = None,
    user_context: Dict[str, str] = Depends(require_admin_role)
):
    """Get recent AL events."""
    if event_type:
        events = event_log.get_events_by_type(event_type, limit=limit)
    else:
        events = event_log.get_recent_events(limit=limit)

    return {
        "status": "ok",
        "events": events,
        "total": len(events)
    }


@app.get("/admin/labels/count", dependencies=[Depends(require_api_key)])
async def get_label_count(user_context: Dict[str, str] = Depends(require_admin_role)):
    """Get current label counts."""
    total = labels_pool.get_label_count()
    unused = labels_pool.get_unused_label_count()
    threshold = config.RETRAIN_MIN_NEW_LABELS

    return {
        "status": "ok",
        "total_labels": total,
        "unused_labels": unused,
        "used_labels": total - unused,
        "retrain_threshold": threshold,
        "ready_for_retrain": unused >= threshold
    }


@app.get("/admin/labels", dependencies=[Depends(require_api_key)])
async def get_labels(
    limit: int = 100,
    unused_only: bool = False,
    user_context: Dict[str, str] = Depends(require_admin_role)
):
    """Get labels from the pool."""
    if unused_only:
        labels = labels_pool.get_unused_labels()
    else:
        labels = labels_pool.get_all_labels()

    return {
        "status": "ok",
        "labels": labels[:limit],
        "total": len(labels)
    }


model_service = ModelService(conf_threshold=config.CONF_THRESHOLD)

if __name__ == "__main__":
    import uvicorn

    ssl_kwargs = {}
    if config.TLS_CERT_FILE and config.TLS_KEY_FILE:
        ssl_kwargs["ssl_certfile"] = config.TLS_CERT_FILE
        ssl_kwargs["ssl_keyfile"] = config.TLS_KEY_FILE

    uvicorn.run(app, host=config.BACKSERVER_HOST, port=config.BACKSERVER_PORT, **ssl_kwargs)
