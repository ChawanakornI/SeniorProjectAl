# Alskin - Skin Cancer Detection (Senior Project)

Flutter app plus FastAPI backend for AI-assisted skin lesion triage. The app supports role-based logins (doctor vs GP), captures lesion photos, runs local ML inference through the backend, and surfaces the results across Home, Dashboard, and Notifications.

## Feature Highlights
- AI-powered diagnosis with blur detection before inference.
- Multi-image capture and swipeable preview; per-image decisions tracked on the result screen.
- Case management with editable demographics and symptoms; decisions log back to the server.
- Live case feeds on Home, Notifications, and Dashboard (counts, trends, diagnosis distribution).
- Role-aware UX: GP view hides labeling entry points; doctor view shows full workflow.
- Glassmorphism UI theme with light/dark support.

## Current Snapshot
- Role-based login with mock credentials stored in `assets/mock_credentials.csv`; Google Sign-In is present in code but disabled until OAuth is configured (see `GOOGLE_SIGN_IN_SETUP.md`).
- Backend uses FastAPI + PyTorch with models under `assets/models/`; predictions and metadata persist to `backserver/storage/metadata.jsonl`.
- Case data is loaded from the backend everywhere (Home, Dashboard, Notifications, Case Summary, Result) via `CaseService`.
- GP accounts are routed to `gp_home_page.dart`, which hides labeling actions; doctors land on the full `home_page.dart`.

## Tech Stack
- Frontend: Flutter (Dart), Material 3 + custom glassmorphism theme, `camera`, `image_picker`, `shared_preferences`, `http`, `google_fonts`.
- Authentication: CSV-backed mock login with role routing (Google Sign-In present in code, currently disabled).
- Backend: FastAPI, pydantic, uvicorn, PyTorch/torchvision, OpenCV blur check, Pillow image IO.
- Storage: Local filesystem for uploaded images; metadata appended to `metadata.jsonl` (JSONL format).

## Requirements
- Flutter SDK 3.7.0+
- Dart 3.7.0+
- Python 3.10+ (for the backend)
- Android emulator/device or iOS simulator/device

## Roles and Credentials
- GP examples: `user001 / Mock01`, `user003 / Mock03`, `user005 / Mock05`
- Doctor examples: `user002 / Mock02`, `user004 / Mock04`
- File of record: `assets/mock_credentials.csv`
- Login flow: `LoadingScreen` -> `LoginScreen` -> routed to GP or Doctor home based on role; optional "Remember me" persists username in `shared_preferences`.

## Configuration Knobs
- Frontend (passed via `--dart-define`): `BACKSERVER_BASE` (e.g., `http://10.0.2.2:8000`), `API_KEY` (if backend enforces one).
- Backend environment variables: `BACKSERVER_HOST`, `BACKSERVER_PORT`, `MODEL_DEVICE` (cpu|cuda|mps), `MODEL_PATH`, `BLUR_THRESHOLD`, `CONF_THRESHOLD`, `RETRAIN_MIN_NEW_LABELS`, `STORAGE_DIR`, `METADATA_FILE`, `ALLOWED_ORIGINS`, `API_KEY`.

## Backend Setup (FastAPI)
```bash
cd backserver
python -m venv .venv && source .venv/bin/activate  # optional, but recommended
pip install -r requirements.txt

# Optional env vars:
# BACKSERVER_HOST=0.0.0.0 | BACKSERVER_PORT=8000
# MODEL_DEVICE=cpu|cuda|mps | MODEL_PATH=<path/to/model.pt>
# BLUR_THRESHOLD=100.0 | CONF_THRESHOLD=0.5
# RETRAIN_MIN_NEW_LABELS=10
# STORAGE_DIR=... | METADATA_FILE=... | API_KEY=<secret>

PYTHONPATH=. uvicorn back:app --host "${BACKSERVER_HOST:-0.0.0.0}" --port "${BACKSERVER_PORT:-8000}"
```
Quick start (no venv):
```bash
cd backserver
pip install -r requirements.txt
python -m uvicorn backserver.back:app --host 0.0.0.0 --port 8000
```
Check it:
```bash
curl http://localhost:8000/health
```
Defaults load `assets/models/ham10000_resnet50_tuned_best.pt` on CPU and allow all origins. Set `API_KEY` to require `X-API-Key` on requests.

## Frontend Setup (Flutter)
```bash
flutter pub get

# Use emulator-friendly host when needed:
# - Android emulator: http://10.0.2.2:8000
# - iOS simulator: http://127.0.0.1:8000
# - Real device: http://<your-LAN-IP>:8000

flutter run \
  --dart-define=BACKSERVER_BASE=http://10.0.2.2:8000 \
  --dart-define=API_KEY=<optional-api-key>
```
The app starts at `LoadingScreen` -> `LoginScreen`. Use credentials from `assets/mock_credentials.csv`, e.g. `user001 / Mock01` (GP) or `user002 / Mock02` (Doctor). "Remember me" uses `shared_preferences`.
Note: The `camera` plugin is not supported on macOS; the app falls back to an empty camera list there.

## Case Flow (App <-> Backend)
1) Create case (`create_case.dart`) -> add photos (camera/gallery) -> preview (`photo_preview_screen.dart`).
2) Case summary (`case_summary_screen.dart`) -> run prediction -> backend `POST /check-image` -> loading dialog -> result (`result_screen.dart`).
3) Decisions (Confirm/Pending/Reject) log via `CaseService` to `/cases` or `/cases/reject`; records surface on Home, Dashboard, and Notifications via `GET /cases`.
4) Active learning uses rejected cases only: doctors label them in the app, then retraining can be triggered once `RETRAIN_MIN_NEW_LABELS` rejected+Labeled images are available.

## Backend API Quick Reference
- `GET /health` - liveness check.
- `POST /auth/login` - JWT login (username/password).
- `POST /check-image` - file upload; returns blur score, predictions, `image_id`, `case_id`. Optional `case_id` lets you keep multiple images in one case.
- `GET /cases` - list case-like entries; supports `status`, `limit`, `include_uncertain`, `include_rejected`.
- `POST /cases` - log or update a case with predictions and metadata.
- `POST /cases/uncertain` - mark a case as uncertain.
- `POST /cases/reject` - log a rejection with notes and predictions.
- `POST /active-learning/candidates` - return rejected cases needing labels.
- `POST /cases/{case_id}/label` - submit doctor label for a rejected case.
- `GET /model/retrain-status` - return current retrain status.
- `POST /model/retrain` - trigger retraining if the rejected-labeled threshold is met.
- All endpoints honor `X-API-Key` when `API_KEY` is set in the backend environment.
- Auth supports JWT (`Authorization: Bearer <token>`) or legacy headers (`X-User-Id`, `X-User-Role`).

## Project Layout
```
lib/
|-- main.dart, app_state.dart, routes.dart, custom_shape.dart
|-- pages/
|   |-- home_page.dart (doctor)    |-- gp_home_page.dart (GP view)
|   |-- dashboard_page.dart        |-- notification_page.dart
|   |-- profile_settings_page.dart |-- settings_page.dart
|   |-- result_screen.dart (ML prediction results with SevenLayerGradientBox)
|   `-- admin.dart
|-- features/
|   |-- case/
|   |   |-- api_config.dart (BACKSERVER_BASE, API_KEY)
|   |   |-- case_service.dart (GET/POST cases, reject, saveAnnotations)
|   |   |-- prediction_service.dart (check-image upload)
|   |   |-- create_case.dart, case_summary_screen.dart
|   |   |-- photo_preview_screen.dart, camera_screen.dart, add_photo.dart
|   |   |-- annotate_screen.dart (doctor annotation for rejected predictions)
|   |   `-- camera_globals.dart
|   `-- login/
|       |-- loading_screen.dart, login_screen.dart, forgot_password_screen.dart
|       `-- widgets/login_form.dart
`-- theme/glass.dart

backserver/
|-- back.py (endpoints), config.py (env), model.py (PyTorch loader)
|-- schemas.py (pydantic models), requirements.txt
`-- storage/metadata.jsonl (created at runtime)

Note: `backserver/back.py` is the merged backend entrypoint (AL + JWT login). Older split variants have been removed.
```

## Configuration Notes
- Frontend base URL and API key are passed via `--dart-define` and read in `lib/features/case/api_config.dart`.
- Backend image paths are relative (e.g., `user001/uuid.jpg`); the app resolves them to `${BACKSERVER_BASE}/images/<path>` when showing Case Summary, Result, Add Photo, Create Case, and Annotate screens. Make sure `BACKSERVER_BASE` is reachable from your emulator/device.
- Backend CORS defaults to `*` unless `ALLOWED_ORIGINS` is set.
- Image and case metadata append to `backserver/storage/metadata.jsonl`; remove the file to clear history.
- Available models (bundled): `ham10000_resnet50_tuned_best.pt` (default), `ham10000_resnet50_best.pt`, `ham10000_convnext_base_best.pt`, `ham10000_efficientnet_b4_best.pt`, `ham10000_unet_best.pt`. Point `MODEL_PATH` to swap.

## Known Issues / TODO (from `tofix.txt`)
- Make the image decision section fully responsive and ensure decisions are tracked per image.
- Improve the AI prediction loading dialog visuals (glassmorphism polish is underway).
- Fix case summary image count mismatches and enable deletion via the "x" control in `create_case.dart`.
- Add a labeling page and link it to Notifications and Home case records; split GP vs Doctor result flows.
- Split result experience: GP should only decide per image and auto-confirm when all decisions are made; doctors keep full controls.
- Dashboard trend graph should respect the selected period (today/week/month/all time) and filter by decision status (accept/uncertain/reject).

## Testing
```bash
flutter analyze
flutter test
```

## Additional Docs
- `INTEGRATION_WALKTHROUGH.md` - frontend/backend data flow
- `UI_UX_IMPROVEMENTS.md` - recent UI changes
- `GOOGLE_SIGN_IN_SETUP.md` - how to re-enable Google OAuth when credentials are available
- `tofix.txt` - live bug/feature list pulled into Known Issues above
