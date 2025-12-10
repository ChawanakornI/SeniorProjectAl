---
name: Backend-ML-Integration
overview: Add a cloud-hosted FastAPI backend that ingests camera images, runs local ML (skin cancer/acne), supports blur/quality checks, and stores rejected cases for active learning.
todos:
  - id: backend-config
    content: Add backend config/env + requirements
    status: completed
  - id: model-serve
    content: Implement model load/inference module
    status: completed
  - id: api-endpoints
    content: "Implement FastAPI endpoints: health, check-image, cases, reject"
    status: completed
  - id: storage
    content: Persist images/metadata for active learning
    status: completed
  - id: frontend-wire
    content: Point app to cloud BACKSERVER_BASE & show predictions
    status: in_progress
  - id: testing
    content: Test curl/device flows and thresholds
    status: pending
---

# Backend + ML integration plan

## Scope

- Run FastAPI on a cloud VM; expose HTTPS endpoint.
- Serve local ML model (skin cancer + acne) via FastAPI.
- Keep existing blur check; add inference; return predictions + confidence.
- Add active-learning flow: store rejected/uncertain cases for later labeling.
- Wire mobile app to configurable base URL.

## Steps

1) **Backend service (cloud)**

- Create `backserver/requirements.txt` with FastAPI, uvicorn, pillow/opencv, numpy, torch/onnxruntime (per model), pydantic.
- Add `backserver/config.py` for envs: HOST, PORT, MODEL_PATH, THRESHOLD, STORAGE_DIR, S3/GCS (optional), CORS origins.
- Add CORS in `backserver/back.py` (or `app.py`).

2) **Model loading & inference**

- Add `backserver/model.py`: load model once (ONNX or Torch), preprocess (resize/normalize), run inference, postprocess to classes/confidence.
- Add `backserver/schemas.py`: request/response models (prediction, confidence, blur_score, timestamp, case_id).

3) **API endpoints**

- `/health` (keep).
- `/check-image` → now: blur check + model inference; returns {status, message, blur_score, predictions[]}.
- `/cases` POST to log a prediction result (image meta, prediction, confidence, blur_score, device info).
- `/cases/reject` POST to flag a case for active learning (stores reference + reason).
- (Optional) `/upload` to store original image to disk/S3 and return an ID.

4) **Storage & active learning**

- Save images to `backserver/storage/` (or S3) with UUID filenames; persist metadata to lightweight store (JSONL/SQLite) keyed by case_id.
- Mark rejected/low-confidence cases for later labeling; provide export endpoint (future) to download those samples.

5) **Mobile integration**

- Update app config to use `BACKSERVER_BASE` (already in camera_screen) pointing to the cloud URL.
- Add handling of model response: show prediction/confidence; if rejected by user, call `/cases/reject` with image_id/case_id.

6) **Deployment**

- On VM: install deps, run `uvicorn back:app --host 0.0.0.0 --port 8000` behind reverse proxy (nginx/Caddy) with HTTPS.
- Open firewall for 80/443; lock down if needed with API key/header (lightweight) or token.

7) **Quality/thresholds**

- Keep blur variance threshold env-driven (BLUR_THRESHOLD).
- Add confidence threshold env (e.g., CONF_THRESHOLD); if below, flag as `uncertain` so frontend can propose retake or manual review.

8) **Testing**

- Local curl tests for /health, /check-image.
- On device: set BACKSERVER_BASE to public HTTPS and retest capture → inference → preview → save/reject.

## Files to touch (backend)

- `backserver/back.py` (or new `app.py`)
- `backserver/model.py` (new)
- `backserver/schemas.py` (new)
- `backserver/config.py` (new)
- `backserver/requirements.txt` (new)
- `backserver/storage/` (new folder for saved images/metadata)

## Files to touch (frontend)

- `lib/features/case/camera_screen.dart` (ensure BACKSERVER_BASE uses cloud URL)
- (If needed) `lib/features/case/photo_preview_screen.dart` to handle prediction display and reject flow
- (Optional) add a small service file for API calls to new endpoints