import json
import uuid
from io import BytesIO
from pathlib import Path
from typing import Optional, Dict, Any

import cv2
import numpy as np
from fastapi import FastAPI, File, UploadFile, HTTPException, Header, Depends
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image

from . import config
from .model import model_service
from .schemas import CheckImageResponse, CaseLog, RejectCase

app = FastAPI()

# Ensure storage paths exist
Path(config.STORAGE_DIR).mkdir(parents=True, exist_ok=True)
Path(config.METADATA_FILE).parent.mkdir(parents=True, exist_ok=True)

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


def _save_image(bytes_data: bytes, image_id: str) -> str:
    image = Image.open(BytesIO(bytes_data)).convert("RGB")
    dest = Path(config.STORAGE_DIR) / f"{image_id}.jpg"
    image.save(dest, format="JPEG", quality=90)
    return str(dest)


def _append_metadata(entry: Dict[str, Any]) -> None:
    with open(config.METADATA_FILE, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/check-image", response_model=CheckImageResponse, dependencies=[Depends(require_api_key)])
async def check_image(file: UploadFile = File(...), case_id: Optional[str] = None):
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
    case_id = case_id or str(uuid.uuid4())
    _save_image(contents, image_id)

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
        }
    )

    return CheckImageResponse(
        status=status,
        message=message,
        blur_score=blur_score,
        predictions=predictions,
        image_id=image_id,
        case_id=case_id,
    )


@app.post("/cases", dependencies=[Depends(require_api_key)])
async def log_case(payload: CaseLog):
    entry = payload.model_dump()
    entry["entry_type"] = "case"
    _append_metadata(entry)
    return {"status": "ok", "message": "logged"}


@app.post("/cases/reject", dependencies=[Depends(require_api_key)])
async def reject_case(payload: RejectCase):
    entry = payload.model_dump()
    entry["entry_type"] = "reject"
    _append_metadata(entry)
    return {"status": "ok", "message": "rejected_logged"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=config.BACKSERVER_HOST, port=config.BACKSERVER_PORT)