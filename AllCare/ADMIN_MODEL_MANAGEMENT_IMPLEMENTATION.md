# Backend Implementation Plan: Admin Model Management System

## 📋 Overview

This document outlines the complete implementation plan for an admin model management system in the FastAPI backend. The system allows administrators to upload model metadata (JSON only), maintain a versioned model registry, activate models at runtime, and track model history using JSON file-based storage.

---

## 🎯 User Requirements Summary

- ✅ Admin uploads JSON metadata only (not .pt files - they're already on server)
- ✅ Model registry with history in JSON file format
- ✅ Models are distinct, no auto-replace, support rollback
- ✅ Specific endpoints: upload, list, get, activate, delete, get-active
- ✅ No backend validation (frontend validates JSON)
- ✅ JWT authentication with admin role check
- ✅ Logging correlated with model version
- ✅ Backend must load .pt model from uploaded metadata path
- ✅ Detect if model trained with Active Learning data

---

## 🏗️ Architecture Design

### Model Registry File Structure

**Location:** `/backserver/storage/models_registry.json`

```json
{
  "active_model_id": "model_abc123",
  "models": {
    "model_abc123": {
      "model_id": "model_abc123",
      "model_version": 1,
      "model_name": "ham10000_resnet50_tuned_best",
      "model_type": "RESNET50",
      "model_file_path": "assets/models/ham10000_resnet50_tuned_best.pt",
      "uploaded_at": "2026-01-18T...",
      "uploaded_by": "user006",
      "uploader_name": "Jake Peralta",
      "is_active": true,
      "performance_metrics": {
        "accuracy": 0.95,
        "auc": 0.98,
        "f1_score": 0.94,
        "precision": 0.93,
        "recall": 0.96
      },
      "active_learning_metadata": {
        "is_al_model": false,
        "parent_model_version": null,
        "num_al_samples_added": 0
      },
      "class_mappings": {},
      "training_details": {},
      "timestamp": "2026-01-18T...",
      "training_dataset": "HAM10000",
      "status": "production"
    }
  },
  "activation_history": [
    {
      "model_id": "model_abc123",
      "activated_at": "2026-01-18T...",
      "activated_by": "user006",
      "activator_name": "Jake Peralta",
      "previous_model_id": "model_xyz789",
      "success": true,
      "error_message": null
    }
  ]
}
```

### Runtime Model Switching Strategy

1. **Thread-safe activation** with global lock (`_MODEL_SWITCH_LOCK`)
2. **Verify .pt file exists** before activation
3. **Reload ModelService** with new model path
4. **Rollback to previous model** if loading fails
5. **Log all activation attempts** (success/failure)

---

## 📝 Implementation Steps

### Phase 1: Core Infrastructure

#### 1.1 Update `schemas.py`

**File:** `/backserver/schemas.py`

**Action:** Add model management Pydantic models (~120 lines)

<details>
<summary>Click to view code</summary>

```python
# Model Management Schemas

class PerformanceMetrics(BaseModel):
    accuracy: float
    auc: float
    f1_score: float
    precision: float
    recall: float

class TrainingDetails(BaseModel):
    epochs: int
    batch_size: int
    learning_rate: float
    optimizer: str
    augmentation_applied: bool
    total_parameters: Optional[int] = None

class ActiveLearningMetadata(BaseModel):
    is_al_model: bool
    parent_model_version: Optional[int] = None
    num_al_samples_added: int = 0

class ModelMetadataUpload(BaseModel):
    """Model metadata uploaded by admin (JSON only)."""
    model_version: int
    model_name: str
    model_type: str
    training_dataset: str
    model_file_path: str
    timestamp: str
    performance_metrics: PerformanceMetrics
    class_mappings: Dict[str, str]
    training_details: TrainingDetails
    active_learning_metadata: ActiveLearningMetadata
    status: str = "production"

class ModelMetadataResponse(BaseModel):
    """Model metadata returned by API."""
    model_id: str
    model_version: int
    model_name: str
    model_type: str
    training_dataset: str
    model_file_path: str
    timestamp: str
    uploaded_at: str
    uploaded_by: str
    uploader_name: str
    is_active: bool
    performance_metrics: PerformanceMetrics
    class_mappings: Dict[str, str]
    training_details: TrainingDetails
    active_learning_metadata: ActiveLearningMetadata
    status: str

class ModelActivationResponse(BaseModel):
    """Response from model activation."""
    status: str
    message: str
    model_id: str
    previous_model_id: Optional[str] = None
    activated_at: str

class ModelListResponse(BaseModel):
    """List of all models."""
    models: List[ModelMetadataResponse]
    total: int
    active_model_id: Optional[str] = None
```

</details>

---

#### 1.2 Create `model_manager.py`

**File:** `/backserver/model_manager.py` (NEW)

**Action:** Create model registry management functions (~250 lines)

<details>
<summary>Click to view code</summary>

```python
"""Model registry management for admin model uploads and activation."""

import json
import threading
import uuid
from pathlib import Path
from typing import Optional, Dict, Any, List
from datetime import datetime

from . import config

# Global lock for thread-safe registry access
_REGISTRY_LOCK = threading.Lock()


def _get_registry_path() -> Path:
    """Get path to models registry file."""
    return Path(config.STORAGE_ROOT) / "models_registry.json"


def _load_registry() -> Dict[str, Any]:
    """Load model registry from JSON file. Thread-safe."""
    registry_path = _get_registry_path()
    if not registry_path.exists():
        return {
            "active_model_id": None,
            "models": {},
            "activation_history": []
        }

    with open(registry_path, "r", encoding="utf-8") as f:
        return json.load(f)


def _save_registry(registry: Dict[str, Any]) -> None:
    """Save model registry to JSON file. Thread-safe."""
    registry_path = _get_registry_path()
    registry_path.parent.mkdir(parents=True, exist_ok=True)

    with open(registry_path, "w", encoding="utf-8") as f:
        json.dump(registry, f, indent=2, ensure_ascii=False)


def add_model(metadata: Dict[str, Any], user_id: str, user_name: str) -> str:
    """
    Add new model to registry.

    Args:
        metadata: Model metadata dict from upload payload
        user_id: ID of user uploading
        user_name: Full name of uploader

    Returns:
        model_id: Unique ID for this model
    """
    with _REGISTRY_LOCK:
        registry = _load_registry()

        # Generate unique model ID
        model_id = f"model_{uuid.uuid4().hex[:8]}"

        # Create model entry
        model_entry = {
            "model_id": model_id,
            **metadata,
            "uploaded_at": datetime.now().isoformat(),
            "uploaded_by": user_id,
            "uploader_name": user_name,
            "is_active": False
        }

        registry["models"][model_id] = model_entry
        _save_registry(registry)

        return model_id


def get_model(model_id: str) -> Optional[Dict[str, Any]]:
    """Get model metadata by ID."""
    with _REGISTRY_LOCK:
        registry = _load_registry()
        return registry["models"].get(model_id)


def list_models() -> List[Dict[str, Any]]:
    """List all models, sorted by upload time (newest first)."""
    with _REGISTRY_LOCK:
        registry = _load_registry()
        models = list(registry["models"].values())
        models.sort(key=lambda x: x.get("uploaded_at", ""), reverse=True)
        return models


def get_active_model() -> Optional[Dict[str, Any]]:
    """Get currently active model metadata."""
    with _REGISTRY_LOCK:
        registry = _load_registry()
        active_id = registry.get("active_model_id")
        if not active_id:
            return None
        return registry["models"].get(active_id)


def delete_model(model_id: str) -> bool:
    """
    Delete model from registry.
    Cannot delete active model.

    Returns:
        True if deleted, False if not found or is active
    """
    with _REGISTRY_LOCK:
        registry = _load_registry()

        if model_id not in registry["models"]:
            return False

        if registry.get("active_model_id") == model_id:
            return False  # Cannot delete active model

        del registry["models"][model_id]
        _save_registry(registry)
        return True


def activate_model(model_id: str, user_id: str, user_name: str) -> Dict[str, Any]:
    """
    Mark model as active and update registry.
    Verifies model file exists.

    Returns:
        Dict with: success (bool), error (str), model_path (str), previous_model_id (str)
    """
    with _REGISTRY_LOCK:
        registry = _load_registry()

        if model_id not in registry["models"]:
            return {"success": False, "error": "Model not found"}

        # Verify model file exists
        model_file_path = registry["models"][model_id]["model_file_path"]
        model_path = Path(model_file_path)

        # Try absolute path first, then relative to PROJECT_ROOT
        if not model_path.is_absolute():
            model_path = config.PROJECT_ROOT / model_file_path

        if not model_path.exists():
            return {
                "success": False,
                "error": f"Model file not found: {model_file_path}"
            }

        # Deactivate previous model
        previous_model_id = registry.get("active_model_id")
        if previous_model_id and previous_model_id in registry["models"]:
            registry["models"][previous_model_id]["is_active"] = False

        # Activate new model
        registry["models"][model_id]["is_active"] = True
        registry["active_model_id"] = model_id

        # Log activation
        activation_event = {
            "model_id": model_id,
            "activated_at": datetime.now().isoformat(),
            "activated_by": user_id,
            "activator_name": user_name,
            "previous_model_id": previous_model_id,
            "success": True,
            "error_message": None
        }
        registry["activation_history"].append(activation_event)

        _save_registry(registry)

        return {
            "success": True,
            "model_id": model_id,
            "previous_model_id": previous_model_id,
            "model_path": str(model_path)
        }


def log_activation_failure(model_id: str, user_id: str, user_name: str, error: str) -> None:
    """Log failed activation attempt."""
    with _REGISTRY_LOCK:
        registry = _load_registry()

        activation_event = {
            "model_id": model_id,
            "activated_at": datetime.now().isoformat(),
            "activated_by": user_id,
            "activator_name": user_name,
            "previous_model_id": registry.get("active_model_id"),
            "success": False,
            "error_message": error
        }
        registry["activation_history"].append(activation_event)

        _save_registry(registry)
```

</details>

---

#### 1.3 Update `model.py`

**File:** `/backserver/model.py`

**Action:** Add `reload_model()` method to `ModelService` class (~30 lines)

**Location:** After `predict()` method (around line 240)

<details>
<summary>Click to view code</summary>

```python
def reload_model(self, model_path: str) -> bool:
    """
    Reload model from new path.
    Thread-safe. Restores previous model on failure.

    Args:
        model_path: Path to new .pt model file

    Returns:
        True if successful, False if failed (previous model restored)
    """
    previous_model = self.model
    previous_path = self.model_path

    try:
        self.model_path = model_path
        self.model = None  # Clear current model
        self._load()  # Use existing _load method

        if self.model is None:
            # Reload failed, restore previous
            self.model = previous_model
            self.model_path = previous_path
            return False

        print(f"[model] Successfully reloaded model from: {model_path}")
        return True

    except Exception as e:
        # Restore previous model on error
        self.model = previous_model
        self.model_path = previous_path
        print(f"[model] Reload failed, restored previous model: {e}")
        return False
```

</details>

---

### Phase 2: API Endpoints

#### 2.1 Create `admin_models.py`

**File:** `/backserver/admin_models.py` (NEW)

**Action:** Create admin API endpoints (~200 lines)

<details>
<summary>Click to view code</summary>

```python
"""Admin endpoints for model management."""

import threading
from datetime import datetime
from typing import Dict
from fastapi import APIRouter, HTTPException, Depends

from . import auth, model_manager
from .schemas import (
    ModelMetadataUpload,
    ModelMetadataResponse,
    ModelActivationResponse,
    ModelListResponse,
)

router = APIRouter(prefix="/api/admin/models", tags=["admin-models"])

# Global lock for model switching (prevents concurrent activations)
_MODEL_SWITCH_LOCK = threading.Lock()


def require_admin(user_context: Dict[str, str] = Depends(auth.get_current_user)) -> Dict[str, str]:
    """Dependency to ensure user is admin."""
    if user_context.get("user_role", "").lower() != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return user_context


@router.post("/upload", response_model=ModelMetadataResponse)
async def upload_model_metadata(
    payload: ModelMetadataUpload,
    user_context: Dict[str, str] = Depends(require_admin)
):
    """
    Upload model metadata (JSON only, not .pt file).
    Admin only.
    """
    user_id = user_context["user_id"]
    user_name = f"{user_context.get('first_name', '')} {user_context.get('last_name', '')}".strip()

    # Add model to registry
    model_id = model_manager.add_model(
        payload.model_dump(),
        user_id,
        user_name
    )

    # Return created model
    model = model_manager.get_model(model_id)
    return model


@router.get("", response_model=ModelListResponse)
async def list_models(
    user_context: Dict[str, str] = Depends(require_admin)
):
    """
    List all models in registry.
    Admin only.
    """
    models = model_manager.list_models()
    registry = model_manager._load_registry()

    return {
        "models": models,
        "total": len(models),
        "active_model_id": registry.get("active_model_id")
    }


@router.get("/active", response_model=ModelMetadataResponse)
async def get_active_model(
    user_context: Dict[str, str] = Depends(require_admin)
):
    """
    Get currently active model.
    Admin only.
    """
    model = model_manager.get_active_model()
    if not model:
        raise HTTPException(status_code=404, detail="No active model")
    return model


@router.get("/{model_id}", response_model=ModelMetadataResponse)
async def get_model(
    model_id: str,
    user_context: Dict[str, str] = Depends(require_admin)
):
    """
    Get specific model by ID.
    Admin only.
    """
    model = model_manager.get_model(model_id)
    if not model:
        raise HTTPException(status_code=404, detail="Model not found")
    return model


@router.post("/{model_id}/activate", response_model=ModelActivationResponse)
async def activate_model(
    model_id: str,
    user_context: Dict[str, str] = Depends(require_admin)
):
    """
    Activate a model (load it into runtime).
    Admin only. Thread-safe with rollback on failure.
    """
    user_id = user_context["user_id"]
    user_name = f"{user_context.get('first_name', '')} {user_context.get('last_name', '')}".strip()

    # Thread-safe activation
    with _MODEL_SWITCH_LOCK:
        # Step 1: Update registry and verify file exists
        result = model_manager.activate_model(model_id, user_id, user_name)

        if not result["success"]:
            raise HTTPException(status_code=400, detail=result["error"])

        # Step 2: Reload model service
        from . import back  # Import to access global model_service

        success = back.model_service.reload_model(result["model_path"])

        if not success:
            # Rollback registry change
            if result["previous_model_id"]:
                model_manager.activate_model(
                    result["previous_model_id"],
                    "system",
                    "System (rollback)"
                )

            # Log failure
            model_manager.log_activation_failure(
                model_id,
                user_id,
                user_name,
                "Model loading failed"
            )

            raise HTTPException(
                status_code=500,
                detail="Failed to load model. Previous model restored."
            )

    return {
        "status": "success",
        "message": f"Model {model_id} activated successfully",
        "model_id": model_id,
        "previous_model_id": result.get("previous_model_id"),
        "activated_at": datetime.now().isoformat()
    }


@router.delete("/{model_id}")
async def delete_model(
    model_id: str,
    user_context: Dict[str, str] = Depends(require_admin)
):
    """
    Delete model from registry.
    Cannot delete active model.
    Admin only.
    """
    success = model_manager.delete_model(model_id)

    if not success:
        model = model_manager.get_model(model_id)
        if not model:
            raise HTTPException(status_code=404, detail="Model not found")
        if model.get("is_active"):
            raise HTTPException(
                status_code=400,
                detail="Cannot delete active model. Activate another model first."
            )

    return {"status": "ok", "message": "Model deleted"}
```

</details>

---

### Phase 3: Integration

#### 3.1 Update `back.py`

**File:** `/backserver/back.py`

**Changes:**

1. **Import admin router** (add near top with other imports):
```python
from .admin_models import router as admin_models_router
from . import model_manager
```

2. **Mount admin router** (add after CORS middleware setup, around line 54):
```python
# Mount admin models router
app.include_router(admin_models_router)
```

3. **Update `/check-image` endpoint** to log model version (around line 605):
```python
# Get active model for logging
active_model = model_manager.get_active_model()
model_version_id = active_model.get("model_id") if active_model else None
model_name = active_model.get("model_name") if active_model else None

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
        "model_version_id": model_version_id,  # NEW
        "model_name": model_name,  # NEW
    },
    _user_metadata_path(user_id),
)
```

**Total lines to modify:** ~15 lines

---

#### 3.2 Update `config.py`

**File:** `/backserver/config.py`

**Action:** Add model registry settings (around line 51)

```python
# Model registry settings
MODELS_REGISTRY_FILE: str = os.getenv(
    "MODELS_REGISTRY_FILE",
    os.path.join(STORAGE_ROOT, "models_registry.json")
)
```

**Lines to add:** ~5 lines

---

### Phase 4: Initialization & Migration

#### 4.1 Create Migration Script

**File:** `/backserver/initialize_model_registry.py` (NEW)

**Action:** Create initialization script (~70 lines)

<details>
<summary>Click to view code</summary>

```python
"""Initialize models_registry.json with current model."""

import json
from pathlib import Path
from datetime import datetime

def initialize_registry():
    """Initialize models_registry.json with current model."""

    # Load existing model metadata
    model_json_path = Path(__file__).parent.parent / "assets/models/ham10000_resnet50_tuned_best.json"

    if not model_json_path.exists():
        print(f"Error: Model metadata not found at {model_json_path}")
        print("Please ensure the JSON file exists.")
        return

    with open(model_json_path, "r") as f:
        model_metadata = json.load(f)

    # Create initial registry
    registry = {
        "active_model_id": "model_initial",
        "models": {
            "model_initial": {
                "model_id": "model_initial",
                **model_metadata,
                "uploaded_at": datetime.now().isoformat(),
                "uploaded_by": "system",
                "uploader_name": "System Migration",
                "is_active": True
            }
        },
        "activation_history": [
            {
                "model_id": "model_initial",
                "activated_at": datetime.now().isoformat(),
                "activated_by": "system",
                "activator_name": "System Migration",
                "previous_model_id": None,
                "success": True,
                "error_message": None
            }
        ]
    }

    # Save registry
    registry_path = Path(__file__).parent / "storage/models_registry.json"
    registry_path.parent.mkdir(parents=True, exist_ok=True)

    with open(registry_path, "w") as f:
        json.dump(registry, f, indent=2, ensure_ascii=False)

    print(f"✓ Registry initialized: {registry_path}")
    print(f"✓ Initial model: {model_metadata['model_name']}")

if __name__ == "__main__":
    initialize_registry()
```

</details>

**Run after implementation:**
```bash
cd backserver
python initialize_model_registry.py
```

---

## 📊 Implementation Summary

### Files to Create (NEW)

| File | Lines | Description |
|------|-------|-------------|
| `backserver/model_manager.py` | ~250 | Model registry management functions |
| `backserver/admin_models.py` | ~200 | Admin API endpoints |
| `backserver/initialize_model_registry.py` | ~70 | Migration script |

### Files to Modify

| File | Lines Added | Description |
|------|-------------|-------------|
| `backserver/schemas.py` | ~120 | Pydantic models for API |
| `backserver/model.py` | ~30 | Model reload method |
| `backserver/back.py` | ~15 | Router mounting + logging |
| `backserver/config.py` | ~5 | Registry settings |

**Total Lines of Code:** ~690 lines

---

## 🔒 Security Considerations

### 1. Authentication & Authorization
- ✅ All endpoints require JWT authentication via `Depends(require_admin)`
- ✅ Admin role verified before any operation
- ✅ User context includes user_id, role, name from JWT

### 2. Thread Safety
- ✅ `_REGISTRY_LOCK` prevents concurrent registry modifications
- ✅ `_MODEL_SWITCH_LOCK` prevents concurrent model activations
- ✅ Atomic operations for registry updates

### 3. Rollback Safety
- ✅ Previous model kept in memory during activation
- ✅ Registry rollback if model loading fails
- ✅ All failures logged in activation_history

### 4. File Path Validation
- ✅ Model file existence verified before activation
- ✅ Paths resolved relative to PROJECT_ROOT
- ✅ Returns error if file not found

### 5. Audit Trail
- ✅ All uploads logged with user_id and timestamp
- ✅ All activations logged (success and failure)
- ✅ Cannot delete active model (safety check)

---

## 🧪 Testing Strategy

### Manual Testing Checklist

#### 1. Upload Model
```bash
# Login as admin
curl -X POST http://localhost:8000/api/admin/models/upload \
  -H "Authorization: Bearer <admin_jwt>" \
  -H "Content-Type: application/json" \
  -d @assets/models/ham10000_resnet50_best.json
```
✅ Verify model added to registry

#### 2. List Models
```bash
curl http://localhost:8000/api/admin/models \
  -H "Authorization: Bearer <admin_jwt>"
```
✅ Verify all models listed with active marked

#### 3. Activate Model
```bash
curl -X POST http://localhost:8000/api/admin/models/{id}/activate \
  -H "Authorization: Bearer <admin_jwt>"
```
✅ Verify model switched
✅ Make prediction to confirm new model in use

#### 4. Rollback Test
- Upload model with invalid path
- Try to activate
- ✅ Verify activation fails and previous model still active

#### 5. Delete Model
- Try to delete active model (should fail)
- Delete inactive model (should succeed)

#### 6. Non-Admin Access
- Login as doctor/GP
- Try to access endpoints
- ✅ Should get 403 Forbidden

#### 7. Model Version Logging
```bash
cat backserver/storage/user001/metadata.jsonl | tail -1 | jq .
```
✅ Should include `model_version_id` and `model_name` fields

---

## ✅ Post-Implementation Verification

### 1. Registry File Created
```bash
cat backserver/storage/models_registry.json
```
Should show initial model with `is_active: true`

### 2. API Endpoints Accessible
Test all endpoints:
- `POST /api/admin/models/upload`
- `GET /api/admin/models`
- `GET /api/admin/models/active`
- `GET /api/admin/models/{model_id}`
- `POST /api/admin/models/{model_id}/activate`
- `DELETE /api/admin/models/{model_id}`

### 3. Model Switching Works
- Activate different model
- Make prediction via `/check-image`
- Verify prediction uses new model

### 4. Predictions Log Model Version
```bash
cat backserver/storage/user001/metadata.jsonl | tail -1 | jq .
```
Should include `model_version_id` and `model_name` fields

### 5. Rollback Works
- Activate model with non-existent .pt file
- ✅ Verify error returned
- ✅ Verify previous model still active
- ✅ Check activation_history has failed entry

---

## 🔮 Future Enhancements (Out of Scope)

- [ ] Model performance tracking (accuracy per version)
- [ ] Auto-rollback if performance degrades
- [ ] Model comparison dashboard
- [ ] Scheduled model updates
- [ ] Canary deployments (partial rollout)
- [ ] Model backup/archive system

---

## 📝 Notes

- ✅ This implementation follows the existing JSONL/JSON file-based storage pattern
- ✅ No database required - consistent with current architecture
- ✅ Thread-safe design allows concurrent API requests
- ✅ Rollback mechanism ensures system stability
- ✅ Audit trail provides full model lifecycle tracking

---

## 🚀 Quick Start

1. **Implement all files** according to phases 1-4
2. **Run migration script:**
   ```bash
   cd backserver
   python initialize_model_registry.py
   ```
3. **Restart backend server:**
   ```bash
   uvicorn backserver.back:app --reload
   ```
4. **Test endpoints** using the testing checklist above

---

## 📚 API Documentation

Once implemented, visit:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

Look for the **admin-models** tag to see all model management endpoints.

---

**Document Version:** 1.0
**Last Updated:** 2026-01-18
**Status:** Ready for Implementation
