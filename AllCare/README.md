# AllCare - AI-Powered Skin Cancer Detection with Active Learning

Flutter mobile app + FastAPI backend for AI-assisted skin lesion diagnosis. The system combines deep learning inference with an **Active Learning (AL) pipeline** that enables continuous model improvement through expert feedback.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Flutter Mobile App                            │
│  Role-based UI (GP/Doctor) • Multi-image capture • Dashboard     │
└──────────────────────────────┬──────────────────────────────────┘
                               │ REST API (HTTP)
┌──────────────────────────────▼──────────────────────────────────┐
│                    FastAPI Backend                               │
├─────────────────────────────────────────────────────────────────┤
│  Authentication │ Case Management │ ML Inference │ Active Learning│
└──────────────────────────────┬──────────────────────────────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        ▼                      ▼                      ▼
   ┌─────────┐          ┌───────────┐          ┌───────────┐
   │ Images  │          │ Metadata  │          │AL_Back/   │
   │ Storage │          │ (JSONL)   │          │ Models    │
   └─────────┘          └───────────┘          └───────────┘
```

## Feature Highlights

### Core Features
- **AI-powered diagnosis** with blur detection before inference
- **Multi-image capture** with swipeable preview; per-image decisions tracked
- **Case management** with editable demographics and symptoms
- **Role-aware UX**: GP view hides labeling; doctor view shows full workflow
- **Glassmorphism UI** theme with light/dark support

### Active Learning Pipeline
- **Model Registry**: Version control for ML models with status tracking (training → evaluating → production → archived)
- **Labels Pool**: Collects expert-corrected labels for retraining
- **Auto-Promote**: Automatically promotes better-performing models to production
- **Event Log**: Full audit trail of model lifecycle events
- **Configurable Training**: Admin-adjustable hyperparameters (epochs, batch size, learning rate)

## Tech Stack

| Layer | Technologies |
|-------|-------------|
| **Frontend** | Flutter 3.7+, Dart, Material 3, Glassmorphism theme |
| **Backend** | FastAPI, Uvicorn, Pydantic 2.x |
| **ML/AI** | PyTorch 2.0+, torchvision, EfficientNetV2-M/ResNet50 |
| **Image Processing** | OpenCV (blur detection), Pillow |
| **Authentication** | JWT (PyJWT), bcrypt password hashing |
| **Storage** | File system (JSONL metadata, JSON config) |

## Requirements

- Flutter SDK 3.7.0+
- Dart 3.7.0+
- Python 3.10+
- Android emulator/device or iOS simulator/device

## Quick Start

### Backend Setup
```bash
cd backserver
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Start server
PYTHONPATH=. uvicorn back:app --host 0.0.0.0 --port 8000

# Verify
curl http://localhost:8000/health
```

### Frontend Setup
```bash
flutter pub get

# Run with backend URL (adjust for your environment)
# Android emulator: http://10.0.2.2:8000
# iOS simulator: http://127.0.0.1:8000
# Real device: http://<your-LAN-IP>:8000

flutter run --dart-define=BACKSERVER_BASE=http://10.0.2.2:8000
```

## Roles & Credentials

| Role | Examples | Capabilities |
|------|----------|-------------|
| **GP** | user001/Mock01, user003/Mock03 | Create cases, view own cases, make decisions |
| **Doctor** | user002/Mock02, user004/Mock04 | All GP + view all cases, label rejected cases |
| **Admin** | (via users.json) | Full access + model management, training config |

Credentials stored in `assets/mock_credentials.csv` (frontend) and `backserver/users.json` (backend JWT auth).

## Active Learning Workflow

```
1. Doctor captures lesion image → AI prediction
                    ↓
2. Doctor reviews prediction
   ├── Confident → CONFIRM (no label needed)
   └── Uncertain → REJECT (candidate for labeling)
                    ↓
3. Rejected cases accumulate in metadata
                    ↓
4. Doctor labels rejected cases via Annotate screen
   └── Labels saved to AL_Back/db/labels_pool.jsonl
                    ↓
5. Admin triggers retraining (or auto-trigger at threshold)
   └── Transfer learning on new labels
                    ↓
6. Candidate model evaluated
   └── If better than production → Auto-promote
                    ↓
7. New model deployed, cycle repeats
```

## Project Structure

```
lib/                              # Flutter frontend
├── main.dart                     # Entry point
├── app_state.dart               # Global state (ChangeNotifier)
├── pages/                       # UI pages
│   ├── home_page.dart          # Doctor home
│   ├── gp_home_page.dart       # GP home (limited)
│   ├── dashboard_page.dart     # Analytics
│   ├── result_screen.dart      # ML predictions
│   └── admin.dart              # Admin panel
├── features/
│   ├── case/                   # Case management
│   │   ├── case_service.dart   # HTTP client
│   │   ├── prediction_service.dart
│   │   ├── create_case.dart
│   │   └── annotate_screen.dart
│   └── login/                  # Authentication
└── theme/glass.dart            # UI theme

backserver/                      # FastAPI backend
├── back.py                     # Main API endpoints
├── config.py                   # Configuration
├── model.py                    # PyTorch inference
├── schemas.py                  # Pydantic models
├── auth.py                     # JWT authentication
│
├── # Active Learning Modules
├── model_registry.py           # Model version control
├── training_config.py          # Hyperparameter management
├── labels_pool.py              # Corrected labels storage
├── event_log.py                # Audit trail
├── retrain_model.py            # Transfer learning
├── auto_promote.py             # Model promotion logic
└── AL.py                       # Uncertainty sampling
│
├── AL_Back/                    # AL infrastructure
│   ├── models/
│   │   ├── production/         # Current deployed model
│   │   ├── candidates/         # Models under evaluation
│   │   └── archive/            # Previous versions
│   ├── db/
│   │   ├── model_registry.json
│   │   ├── labels_pool.jsonl
│   │   └── event_log.jsonl
│   └── config/
│       └── active_config.json  # Training hyperparameters
│
└── storage/                    # Per-user case data
    └── user_<id>/
        ├── metadata.jsonl
        ├── images/
        └── case_counter.json
```

## API Quick Reference

### Core Endpoints
| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/health` | Health check |
| POST | `/auth/login` | JWT authentication |
| POST | `/check-image` | Image classification |
| GET | `/cases` | List cases |
| POST | `/cases` | Create case |
| POST | `/cases/{id}/label` | Submit label |

### Active Learning Endpoints
| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/active-learning/candidates` | Get uncertain cases |
| GET | `/admin/models` | List all models |
| GET | `/admin/models/production` | Current production model |
| POST | `/admin/models/{id}/promote` | Manual promote |
| POST | `/admin/retrain/trigger` | Trigger retraining |
| GET | `/admin/retrain/status` | Retraining status |
| GET | `/admin/events` | Event audit log |
| GET/POST | `/admin/training-config` | Training hyperparameters |

## Configuration

### Backend Environment Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `BACKSERVER_HOST` | `0.0.0.0` | Server bind address |
| `BACKSERVER_PORT` | `8000` | Server port |
| `MODEL_PATH` | `assets/models/...pt` | Model file path |
| `MODEL_DEVICE` | auto | Force: cpu, cuda, mps |
| `BLUR_THRESHOLD` | `50.0` | Image clarity threshold |
| `CONF_THRESHOLD` | `0.5` | Prediction confidence threshold |
| `RETRAIN_MIN_NEW_LABELS` | `10` | Labels needed for retraining |
| `JWT_SECRET_KEY` | (change in prod) | JWT signing key |
| `JWT_EXPIRATION_HOURS` | `24` | Token lifetime |

### Frontend Configuration
Pass via `--dart-define`:
```bash
flutter run \
  --dart-define=BACKSERVER_BASE=http://10.0.2.2:8000 \
  --dart-define=API_KEY=optional-key
```

## HAM10000 Classes

The model classifies lesions into 7 categories:

| Code | Condition | Risk Level |
|------|-----------|------------|
| akiec | Actinic keratoses | Pre-cancerous |
| bcc | Basal cell carcinoma | Cancer |
| bkl | Benign keratosis | Benign |
| df | Dermatofibroma | Benign |
| mel | Melanoma | **Dangerous** |
| nv | Melanocytic nevi (moles) | Benign |
| vasc | Vascular lesions | Benign |

## Design Patterns

- **Singleton**: AppState (global state), ModelService (ML inference)
- **Service Layer**: CaseService, PredictionService abstract HTTP calls
- **Repository**: model_registry, labels_pool, event_log for data access
- **Factory**: create_model() for multi-architecture support
- **Observer**: ChangeNotifier for Flutter state management
- **Event-Driven**: Decoupled audit logging for model lifecycle

## Testing

```bash
flutter analyze
flutter test
```

## Additional Documentation

- `backserver/README_Backserver.md` - Detailed backend documentation
- `AL_architecture.md` - Comprehensive architecture deep-dive
- `INTEGRATION_WALKTHROUGH.md` - Frontend/backend data flow
- `UI_UX_IMPROVEMENTS.md` - UI change history
- `GOOGLE_SIGN_IN_SETUP.md` - OAuth configuration guide

## Known Limitations

- Single-model inference (no ensemble)
- Sequential retraining (no concurrent training)
- Local storage only (no cloud integration)
- No A/B testing framework

## License

Senior Project - All Rights Reserved
