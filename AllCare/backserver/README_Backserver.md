# AllCare Backend Server Documentation

## Table of Contents
1. [System Overview](#system-overview)
2. [Architecture & Data Flow](#architecture--data-flow)
3. [Active Learning Pipeline](#active-learning-pipeline)
4. [Project Structure](#project-structure)
5. [Setup & Installation](#setup--installation)
6. [Authentication & Security](#authentication--security)
7. [API Reference](#api-reference)
8. [Configuration](#configuration)
9. [AI Model Details](#ai-model-details)
10. [Troubleshooting](#troubleshooting)

---

## System Overview

The **AllCare Backend** is a high-performance REST API built with **FastAPI**. It serves as the bridge between the Flutter mobile app and the AI diagnosis model, providing intelligent skin lesion analysis with **continuous learning capabilities**.

### Key Responsibilities

| Component | Purpose |
|-----------|---------|
| **Authentication** | JWT-based auth with role-based access control (GP, Doctor, Admin) |
| **Image Validation** | Blur detection using Laplacian variance (OpenCV) |
| **AI Inference** | PyTorch model classification (7 skin lesion categories) |
| **Case Management** | Create, update, query cases with per-user isolation |
| **Active Learning** | Model versioning, retraining, auto-promotion |
| **Audit Trail** | Event logging for all model lifecycle operations |

### Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Framework** | FastAPI 0.115+ | Async REST API with auto-validation |
| **ML/AI** | PyTorch 2.0+ | Neural network inference |
| **Vision** | torchvision | Pre-trained models & transforms |
| **Image** | OpenCV, Pillow | Blur detection, image I/O |
| **Auth** | PyJWT, bcrypt | Token auth, password hashing |
| **Validation** | Pydantic 2.x | Request/response schemas |

---

## Architecture & Data Flow

### Layered Architecture

```
┌────────────────────────────────────────────────────┐
│          API Layer (FastAPI Endpoints)              │
├────────────────────────────────────────────────────┤
│  /health, /auth/login, /check-image, /cases, ...   │
│  /admin/models, /admin/retrain, /admin/events      │
├────────────────────────────────────────────────────┤
│          Business Logic Layer                       │
├────────────────────────────────────────────────────┤
│  ModelService    │ Case Logic   │ Active Learning   │
│  (inference)     │ (CRUD)       │ (retrain/promote) │
├────────────────────────────────────────────────────┤
│          Data Access Layer                          │
├────────────────────────────────────────────────────┤
│  model_registry │ labels_pool │ event_log │ storage │
├────────────────────────────────────────────────────┤
│          Persistence Layer                          │
├────────────────────────────────────────────────────┤
│  JSON/JSONL Files │ PyTorch Models │ Image Files    │
└────────────────────────────────────────────────────┘
```

### Image Classification Flow

```
┌──────────┐     POST /check-image      ┌──────────────┐
│  Mobile  │ ─────────────────────────→ │   FastAPI    │
│   App    │                            │   Server     │
└──────────┘                            └──────┬───────┘
                                               │
                                     ┌─────────▼─────────┐
                                     │ 1. Blur Detection │
                                     │    (OpenCV)       │
                                     └─────────┬─────────┘
                                               │
                              ┌────────────────┴────────────────┐
                              │                                 │
                    Score < Threshold                 Score >= Threshold
                              │                                 │
                              ▼                                 ▼
                    ┌─────────────────┐            ┌────────────────────┐
                    │ 400 Error       │            │ 2. PyTorch Model   │
                    │ "Too Blurry"    │            │    Inference       │
                    └─────────────────┘            └─────────┬──────────┘
                                                             │
                                                   ┌─────────▼──────────┐
                                                   │ 3. Save Image &    │
                                                   │    Log Metadata    │
                                                   └─────────┬──────────┘
                                                             │
                                                   ┌─────────▼──────────┐
                                                   │ 4. JSON Response   │
                                                   │    (predictions)   │
                                                   └────────────────────┘
```

---

## Active Learning Pipeline

The AL pipeline enables continuous model improvement through expert feedback. This is the core differentiator of the AllCare system.

### Pipeline Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    ACTIVE LEARNING CYCLE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. INFERENCE          2. FEEDBACK           3. ACCUMULATE       │
│  ┌─────────┐           ┌─────────┐           ┌─────────┐        │
│  │ Patient │  ──────→  │ Doctor  │  ──────→  │ Labels  │        │
│  │ Image   │           │ Reviews │           │ Pool    │        │
│  └─────────┘           └────┬────┘           └────┬────┘        │
│       │                     │                     │              │
│       │              Reject/Correct          Threshold           │
│       │                     │                 Reached            │
│       │                     ▼                     │              │
│       │              ┌─────────┐                  │              │
│       │              │ Submit  │                  │              │
│       │              │ Label   │                  │              │
│       │              └─────────┘                  │              │
│       │                                          │              │
│  4. RETRAIN            5. EVALUATE          6. PROMOTE          │
│  ┌─────────┐           ┌─────────┐           ┌─────────┐        │
│  │Transfer │  ──────→  │Compare  │  ──────→  │ Deploy  │        │
│  │Learning │           │Accuracy │           │   New   │        │
│  └─────────┘           └─────────┘           │  Model  │        │
│       ▲                                      └────┬────┘        │
│       │                                           │              │
│       └───────────────────────────────────────────┘              │
│                        CYCLE REPEATS                             │
└─────────────────────────────────────────────────────────────────┘
```

### AL Components

#### 1. Model Registry (`model_registry.py`)

Manages model versions and lifecycle status.

**Model Status Flow:**
```
training → evaluating → production → archived
                    ↘ failed
```

**Version ID Format:** `v{YYYYMMDD}_{seq}` (e.g., `v20260129_001`)

**Storage:** `AL_Back/db/model_registry.json`
```json
{
  "models": {
    "v20260129_001": {
      "status": "production",
      "created_at": "2026-01-29T10:00:00Z",
      "base_model": "v20260128_prod",
      "training_config": { "epochs": 10, "batch_size": 16 },
      "metrics": { "train_accuracy": 0.95, "val_accuracy": 0.92 },
      "path": "AL_Back/models/candidates/v20260129_001/model.pt"
    }
  },
  "current_production": "v20260129_001",
  "pending_promotion": null
}
```

**Key Functions:**
- `register_model()` - Register new model with metadata
- `promote_model()` - Move to production, archive old
- `rollback_to()` - Revert to previous version
- `get_production_model()` - Get current production info
- `list_models()` - List all or filter by status

---

#### 2. Labels Pool (`labels_pool.py`)

Collects and manages expert-corrected labels for retraining.

**Conflict Resolution:** "Latest wins" - newer corrections override older ones

**Storage:** `AL_Back/db/labels_pool.jsonl` (append-only)
```json
{"case_id": "12345", "image_paths": ["..."], "correct_label": "mel", "user_id": "doctor_001", "created_at": "...", "updated_at": "...", "used_in_models": ["v20260129_001"]}
```

**Key Functions:**
- `add_label()` - Add/update label for a case
- `get_all_labels()` - Get all corrected labels
- `get_unused_labels()` - Labels not yet used in training
- `mark_labels_used()` - Track which model used which labels
- `get_labels_for_training()` - Format for dataset creation

---

#### 3. Training Configuration (`training_config.py`)

Manages retraining hyperparameters.

**Default Config:**
```json
{
  "epochs": 10,
  "batch_size": 16,
  "learning_rate": 1e-4,
  "optimizer": "Adam",
  "dropout": 0.3,
  "augmentation_applied": true
}
```

**Storage:** `AL_Back/config/active_config.json`

**Key Functions:**
- `load_config()` - Load from file with fallback to defaults
- `save_config()` - Persist admin-provided config
- `validate_config()` - Validate ranges and types
- `get_optimizer_class()` - Return torch.optim class

---

#### 4. Event Log (`event_log.py`)

Audit trail for all AL operations.

**Event Types:**
| Event | Description |
|-------|-------------|
| `retrain_triggered` | Threshold reached, training started |
| `training_completed` | Training finished successfully |
| `training_failed` | Training error occurred |
| `model_promoted` | Auto or manual promotion |
| `model_rollback` | Reverted to previous model |
| `config_updated` | Training config changed |
| `label_added` | New label submitted |
| `threshold_reached` | Label count hit threshold |

**Storage:** `AL_Back/db/event_log.jsonl` (append-only)
```json
{"timestamp": "2026-01-29T10:30:00Z", "type": "model_promoted", "message": "Model v20260129 promoted (94.2% accuracy)", "metadata": {"version_id": "v20260129", "accuracy": 0.942}}
```

**Key Functions:**
- `log_event()` - Append event to log
- `get_recent_events()` - Get last N events
- `get_events_by_type()` - Filter by event type
- `get_events_since()` - Events after timestamp

---

#### 5. Retraining Module (`retrain_model.py`)

Implements transfer learning for model improvement.

**Supported Architectures:**
- EfficientNetV2-M (default)
- ResNet50

**Workflow:**
1. Load production model as base
2. Detect architecture from state_dict
3. Create dataset from labeled cases
4. 80/20 train-val split
5. Fine-tune with configured hyperparameters
6. Evaluate and save to candidates directory
7. Update registry with metrics

**Key Functions:**
- `create_model()` - Factory for architecture creation
- `detect_architecture_from_state_dict()` - Auto-detect arch
- `check_retrain_threshold()` - Check if minimum labels reached
- `retrain_model()` - Execute full retraining workflow
- `get_retrain_status()` - Current retraining state

---

#### 6. Auto-Promotion (`auto_promote.py`)

Evaluates candidate models and promotes better performers.

**Promotion Logic:**
```python
if candidate_accuracy > production_accuracy:
    promote(candidate)
    archive(old_production)
    log_event("model_promoted")
```

**Key Functions:**
- `compare_models()` - Compare candidate vs production metrics
- `evaluate_and_promote()` - Full evaluation and promotion
- `manual_promote()` - Admin override promotion
- `trigger_rollback()` - Revert to previous model
- `check_production_health()` - Monitor production status

---

### AL Directory Structure

```
AL_Back/
├── models/
│   ├── production/           # Current deployed model
│   │   └── model.pt
│   ├── candidates/           # Models under evaluation
│   │   └── v20260129_001/
│   │       └── model.pt
│   └── archive/              # Previous production models
│       └── v20260128_001/
│           └── model.pt
├── db/
│   ├── model_registry.json   # Model inventory & status
│   ├── labels_pool.jsonl     # Corrected labels (append-only)
│   └── event_log.jsonl       # Audit trail (append-only)
└── config/
    └── active_config.json    # Current training config
```

---

## Project Structure

```
backserver/
├── back.py                     # Main FastAPI app & all endpoints
├── config.py                   # Environment configuration & constants
├── model.py                    # ModelService: PyTorch inference engine
├── schemas.py                  # Pydantic request/response models
│
├── auth.py                     # JWT authentication & user validation
├── admin_user_manager.py       # Admin CLI for user management
│
├── # Active Learning Modules
├── model_registry.py           # Model versioning & lifecycle
├── training_config.py          # Hyperparameter management
├── labels_pool.py              # Corrected labels storage
├── event_log.py                # Audit trail
├── retrain_model.py            # Transfer learning logic
├── auto_promote.py             # Model comparison & promotion
├── AL.py                       # Uncertainty sampling
│
├── AL_Back/                    # AL infrastructure (see above)
│
├── storage/                    # User case data
│   ├── user_<id>/
│   │   ├── metadata.jsonl      # User's case metadata
│   │   ├── images/             # User's case images
│   │   └── case_counter.json   # User's case ID counter
│   └── case_counter.json       # Global counter (legacy)
│
├── users.json                  # User credentials database
├── requirements.txt            # Python dependencies
└── export_torchscript.py       # Model export utility
```

### Key Components

| File | Responsibility |
|------|----------------|
| `back.py` | API endpoints, CORS, middleware |
| `model.py` | Load PyTorch model, run inference |
| `auth.py` | JWT creation/validation, bcrypt |
| `config.py` | Environment variables, defaults |
| `schemas.py` | Pydantic validation models |
| `model_registry.py` | Model CRUD & status tracking |
| `labels_pool.py` | Label collection & retrieval |
| `retrain_model.py` | Transfer learning execution |
| `auto_promote.py` | Model evaluation & promotion |
| `event_log.py` | Audit logging |

---

## Setup & Installation

### 1. Environment Setup

```bash
cd backserver
python -m venv .venv

# Activate
source .venv/bin/activate  # macOS/Linux
# .venv\Scripts\activate   # Windows
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Verify Model Assets

Default model path: `../assets/models/ham10000_efficientnetV2m_7class_torchscript.pt`

If missing, server starts in "Dummy Mode" with mock predictions.

### 4. Run the Server

```bash
# From backserver directory
PYTHONPATH=. uvicorn back:app --host 0.0.0.0 --port 8000

# Or from project root
python -m uvicorn backserver.back:app --host 0.0.0.0 --port 8000
```

### 5. Verify

```bash
curl http://localhost:8000/health
# {"status": "ok"}
```

### 6. User Management (Optional)

```bash
python -m backserver.admin_user_manager
```

Interactive CLI for:
- Create/delete users
- Update roles (gp, doctor, admin)
- Reset passwords
- List all users

---

## Authentication & Security

### JWT Overview

- **Stateless** authentication using JSON Web Tokens
- **Claims**: user_id, role, first_name, last_name, exp, iat
- **Signing**: HS256 algorithm with configurable secret

### User Roles

| Role | Permissions |
|------|-------------|
| `gp` | Create cases, view own cases, make decisions |
| `doctor` | All GP + view all cases, label cases, annotation |
| `admin` | Full access + model management, training config |

### Authentication Flow

```
1. POST /auth/login (username, password)
        ↓
2. Server validates credentials (bcrypt)
        ↓
3. JWT token returned
        ↓
4. Client stores token
        ↓
5. All requests include: Authorization: Bearer <token>
        ↓
6. Server validates token on each request
```

### Login Example

**Request:**
```bash
curl -X POST "http://localhost:8000/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username": "user002", "password": "Mock02"}'
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "bearer",
  "user": {
    "user_id": "user002",
    "first_name": "Jane",
    "last_name": "Doctor",
    "role": "doctor"
  }
}
```

### Using Tokens

```bash
TOKEN="eyJhbGciOiJIUzI1NiIs..."

curl -X POST "http://localhost:8000/check-image" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@lesion.jpg"
```

### Security Features

| Feature | Description |
|---------|-------------|
| Password Hashing | bcrypt with auto salt |
| Token Expiration | Configurable (default 24h) |
| CORS Protection | Configurable allowed origins |
| API Key | Optional additional layer |
| HTTPS | Optional TLS/SSL support |

### Legacy Auth (Backward Compatible)

Headers: `X-User-Id`, `X-User-Role`

JWT takes precedence if `Authorization` header present.

---

## API Reference

### Authentication

#### `POST /auth/login`
Authenticate and receive JWT token.

**Request:**
```json
{"username": "user001", "password": "yourpassword"}
```

**Response:**
```json
{
  "access_token": "...",
  "token_type": "bearer",
  "user": {"user_id": "...", "first_name": "...", "last_name": "...", "role": "..."}
}
```

---

### Health Check

#### `GET /health`
Server health check.

**Response:** `{"status": "ok"}`

---

### Image Analysis

#### `POST /check-image`
Analyze skin lesion image.

**Input:** `multipart/form-data` with `file`, optional `case_id` query param

**Response:**
```json
{
  "status": "success",
  "message": "Image processed",
  "blur_score": 125.5,
  "predictions": [
    {"label": "mel", "confidence": 0.85},
    {"label": "nv", "confidence": 0.12}
  ],
  "image_id": "uuid",
  "case_id": "12345"
}
```

---

### Case Management

#### `POST /cases/next-id`
Get next available case ID.

#### `POST /cases/release-id`
Release unused case ID.

#### `GET /cases`
List cases with filters.

**Params:** `limit`, `status`, `include_uncertain`, `include_rejected`

**Access:** GPs see own cases; Doctors/Admins see all

#### `POST /cases`
Create/log new case.

**Input:** `CaseLog` schema

#### `PUT /cases/{case_id}`
Update existing case.

#### `POST /cases/uncertain`
Mark case as uncertain.

#### `POST /cases/reject`
Reject prediction with reason.

---

### Labeling & Annotations

#### `POST /cases/{case_id}/label`
Submit correct label for retraining.

**Input:**
```json
{
  "correct_label": "mel",
  "notes": "Clear melanoma signs"
}
```

#### `POST /cases/{case_id}/annotations`
Submit detailed annotations (strokes, boxes).

---

### Active Learning

#### `POST /active-learning/candidates`
Get uncertain cases needing expert review.

**Input:**
```json
{"top_k": 5}
```

**Response:**
```json
{
  "candidates": [...],
  "total_candidates": 5,
  "selection_method": "minimum_margin_case_sampling",
  "description": "..."
}
```

---

### Admin Endpoints

All admin endpoints require admin role.

#### `GET /admin/training-config`
Get current training configuration.

#### `POST /admin/training-config`
Update training configuration.

**Input:**
```json
{
  "epochs": 15,
  "batch_size": 32,
  "learning_rate": 5e-5,
  "optimizer": "AdamW",
  "dropout": 0.4,
  "augmentation_applied": true
}
```

#### `GET /admin/models`
List all models with status.

**Response:**
```json
{
  "models": [...],
  "current_production": "v20260129_001"
}
```

#### `GET /admin/models/production`
Get current production model info.

#### `POST /admin/models/{version_id}/promote`
Manually promote a model to production.

#### `POST /admin/models/{version_id}/rollback`
Rollback to previous model version.

#### `POST /admin/retrain/trigger`
Trigger model retraining.

**Requirements:** Minimum labels reached (default 10)

#### `GET /admin/retrain/status`
Get current retraining status.

**Response:**
```json
{
  "status": "in_progress",
  "progress": 0.45,
  "current_epoch": 5,
  "total_epochs": 10
}
```

#### `GET /admin/events`
Get recent AL events (audit log).

**Params:** `limit` (default 50), `type` (filter)

#### `GET /admin/labels/count`
Get current label count.

#### `GET /admin/labels`
Get all labels in the pool.

---

## Configuration

### Environment Variables

#### Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKSERVER_HOST` | `0.0.0.0` | Server bind address |
| `BACKSERVER_PORT` | `8000` | Server port |
| `MODEL_PATH` | `assets/models/...pt` | Path to AI model |
| `MODEL_DEVICE` | auto | Force: cpu, cuda, mps |
| `BLUR_THRESHOLD` | `50.0` | Image clarity threshold |
| `CONF_THRESHOLD` | `0.5` | Prediction confidence threshold |

#### Active Learning

| Variable | Default | Description |
|----------|---------|-------------|
| `RETRAIN_MIN_NEW_LABELS` | `10` | Labels needed to trigger retraining |
| `AL_BACK_PATH` | `AL_Back` | AL infrastructure directory |

#### Authentication

| Variable | Default | Description |
|----------|---------|-------------|
| `JWT_SECRET_KEY` | `your-secret-key...` | **CHANGE IN PRODUCTION** |
| `JWT_ALGORITHM` | `HS256` | Signing algorithm |
| `JWT_EXPIRATION_HOURS` | `24` | Token lifetime |
| `API_KEY` | (empty) | Optional API key |
| `USERS_FILE` | `backserver/users.json` | User database |

#### Storage

| Variable | Default | Description |
|----------|---------|-------------|
| `STORAGE_ROOT` | `backserver/storage` | User data directory |
| `ENCRYPT_STORAGE` | (empty) | Enable encryption |
| `DATA_ENCRYPTION_KEY` | (empty) | Fernet key |
| `CASE_ID_START` | `10000` | Starting case ID |

#### Security

| Variable | Default | Description |
|----------|---------|-------------|
| `ALLOWED_ORIGINS` | `*` | CORS origins |
| `TLS_CERT_FILE` | (empty) | HTTPS certificate |
| `TLS_KEY_FILE` | (empty) | HTTPS key |

### Generate Secure Keys

```bash
# JWT Secret
python -c "import secrets; print(secrets.token_urlsafe(32))"

# Fernet Key (for encryption)
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

---

## AI Model Details

### Architecture

Primary: **EfficientNetV2-M** (also supports ResNet50)

Fine-tuned on **HAM10000** dataset.

### Classes (7 categories)

| Code | Condition | Risk |
|------|-----------|------|
| akiec | Actinic keratoses | Pre-cancerous |
| bcc | Basal cell carcinoma | Cancer |
| bkl | Benign keratosis | Benign |
| df | Dermatofibroma | Benign |
| mel | Melanoma | **Dangerous** |
| nv | Melanocytic nevi | Benign |
| vasc | Vascular lesions | Benign |

### Preprocessing Pipeline

```python
transforms.Compose([
    transforms.Resize(256),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize(
        mean=[0.485, 0.456, 0.406],  # ImageNet
        std=[0.229, 0.224, 0.225]
    )
])
```

### Available Models

| Model | Architecture | Notes |
|-------|--------------|-------|
| `ham10000_efficientnetV2m_7class_torchscript.pt` | EfficientNetV2-M | Production (TorchScript) |
| `ham10000_efficientnetV2m_7Class.pt` | EfficientNetV2-M | Base for transfer learning |
| `ham10000_resnet50_7Class.pt` | ResNet50 | Alternative architecture |

---

## Troubleshooting

### General Issues

**ModuleNotFoundError**
```bash
pip install -r requirements.txt
```

**Model not found**
- Check `MODEL_PATH` points to existing file
- Use absolute path if running from different directory

**Cannot connect from Android emulator**
- Use `10.0.2.2` instead of `localhost`

### Authentication Issues

**Invalid credentials**
- Check `users.json` exists and is valid JSON
- Verify password was hashed with bcrypt
- Regenerate hash if needed

**Token expired**
- Re-login to get new token
- Increase `JWT_EXPIRATION_HOURS` if needed

**Invalid token**
- Check `Authorization: Bearer <token>` format
- Verify `JWT_SECRET_KEY` hasn't changed

### Active Learning Issues

**Retraining won't start**
- Check label count with `GET /admin/labels/count`
- Verify `RETRAIN_MIN_NEW_LABELS` threshold
- Check `event_log.jsonl` for errors

**Model not promoted**
- Check metrics in `model_registry.json`
- Candidate must exceed production accuracy
- Review `event_log.jsonl` for promotion events

**Labels not saving**
- Verify write permissions on `AL_Back/db/`
- Check `labels_pool.jsonl` for entries
- Confirm case_id exists in metadata

### Storage Issues

**Cases not appearing**
- Check user authentication (user_id match)
- GPs only see own cases
- Verify `storage/<user_id>/metadata.jsonl` exists

**Encryption errors**
- Same `DATA_ENCRYPTION_KEY` required for reading
- Don't toggle `ENCRYPT_STORAGE` without migration

### Create User Script

```python
import bcrypt
import json

password = "yourpassword"
hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()

user = {
    "username": {
        "password_hash": hashed,
        "first_name": "John",
        "last_name": "Doe",
        "role": "doctor"
    }
}
print(json.dumps(user, indent=2))
```

---

## Changelog

See `CHANGELOG_README.md` for implementation history.
