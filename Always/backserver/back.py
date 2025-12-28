import csv
import json
import threading
import uuid
from datetime import datetime
from io import BytesIO
from pathlib import Path
from typing import Optional, Dict, Any, List

import cv2
import numpy as np
from fastapi import FastAPI, File, UploadFile, HTTPException, Header, Depends
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image

from . import auth
from . import config
from . import crypto_utils
from .model import model_service
from .schemas import (
    CheckImageResponse,
    CaseLog,
    CaseUpdate,
    RejectCase,
    CaseIdRelease,
    LoginRequest,
    TokenResponse,
    UserInfo,
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
    # Try JWT token first
    if authorization and authorization.lower().startswith("bearer "):
        return auth.get_current_user(authorization)

    # Fall back to legacy headers
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


def _load_mock_user_ids() -> List[str]:
    credentials_path = config.PROJECT_ROOT / "assets" / "mock_credentials.csv"
    if not credentials_path.exists():
        return []
    user_ids: List[str] = []
    try:
        with open(credentials_path, "r", encoding="utf-8") as file:
            reader = csv.reader(file)
            for row in reader:
                if not row:
                    continue
                if row[0].strip().lower() in ("username", "#username"):
                    continue
                user_id = _normalize_user_id(row[0])
                if user_id:
                    user_ids.append(user_id)
    except OSError:
        return []
    return user_ids


def _ensure_mock_user_dirs() -> None:
    for user_id in _load_mock_user_ids():
        _ensure_user_storage(user_id)


_ensure_mock_user_dirs()


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


if __name__ == "__main__":
    import uvicorn

    ssl_kwargs = {}
    if config.TLS_CERT_FILE and config.TLS_KEY_FILE:
        ssl_kwargs["ssl_certfile"] = config.TLS_CERT_FILE
        ssl_kwargs["ssl_keyfile"] = config.TLS_KEY_FILE

    uvicorn.run(app, host=config.BACKSERVER_HOST, port=config.BACKSERVER_PORT, **ssl_kwargs)
