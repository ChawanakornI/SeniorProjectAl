"""
Model Registry Module for Active Learning System.

Manages model versions, statuses, and the production/candidate lifecycle.
"""

import json
import os
import shutil
from datetime import datetime
from typing import Dict, List, Optional, Any

from . import config


class ModelStatus:
    TRAINING = "training"
    EVALUATING = "evaluating"
    PRODUCTION = "production"
    ARCHIVED = "archived"
    FAILED = "failed"


def _load_registry() -> Dict[str, Any]:
    """Load the model registry from disk."""
    if not os.path.exists(config.AL_MODEL_REGISTRY_FILE):
        return {"models": {}, "current_production": None, "pending_promotion": None, "active_inference": None}

    with open(config.AL_MODEL_REGISTRY_FILE, "r") as f:
        registry = json.load(f)
    if "active_inference" not in registry:
        registry["active_inference"] = None
    if "models" not in registry:
        registry["models"] = {}
    return registry


def _save_registry(registry: Dict[str, Any]) -> None:
    """Save the model registry to disk."""
    os.makedirs(os.path.dirname(config.AL_MODEL_REGISTRY_FILE), exist_ok=True)
    with open(config.AL_MODEL_REGISTRY_FILE, "w") as f:
        json.dump(registry, f, indent=2)


def generate_version_id() -> str:
    """
    Generate a unique version ID in format v{YYYYMMDD}_{seq}.
    Sequence number increments for same-day versions.
    """
    registry = _load_registry()
    today = datetime.now().strftime("%Y%m%d")
    prefix = f"v{today}_"

    existing = [k for k in registry["models"].keys() if k.startswith(prefix)]
    if not existing:
        return f"{prefix}001"

    max_seq = max(int(v.split("_")[1]) for v in existing)
    return f"{prefix}{max_seq + 1:03d}"


def register_model(
    version_id: str,
    base_model: Optional[str],
    training_config: Dict[str, Any],
    path: str,
    status: str = ModelStatus.TRAINING
) -> Dict[str, Any]:
    """
    Register a new model in the registry.

    Args:
        version_id: Unique version identifier
        base_model: Version ID of the base model (for transfer learning)
        training_config: Training configuration used
        path: Path to the model file
        status: Initial status (default: training)

    Returns:
        The created model entry
    """
    registry = _load_registry()

    model_entry = {
        "status": status,
        "created_at": datetime.now().isoformat(),
        "base_model": base_model,
        "training_config": training_config,
        "metrics": {},
        "path": path
    }

    registry["models"][version_id] = model_entry
    _save_registry(registry)

    return model_entry


def update_model_status(version_id: str, status: str) -> bool:
    """Update the status of a model."""
    registry = _load_registry()

    if version_id not in registry["models"]:
        return False

    registry["models"][version_id]["status"] = status
    _save_registry(registry)
    return True


def update_model_metrics(version_id: str, metrics: Dict[str, Any]) -> bool:
    """Update the metrics of a model after training/evaluation."""
    registry = _load_registry()

    if version_id not in registry["models"]:
        return False

    registry["models"][version_id]["metrics"] = metrics
    _save_registry(registry)
    return True


def get_production_model() -> Optional[Dict[str, Any]]:
    """
    Get the current production model info.

    Returns:
        Model entry dict with version_id added, or None if no production model
    """
    registry = _load_registry()
    prod_id = registry.get("current_production")

    if not prod_id or prod_id not in registry["models"]:
        return None

    model = registry["models"][prod_id].copy()
    model["version_id"] = prod_id
    return model


def get_production_model_path() -> Optional[str]:
    """Get the file path of the current production model."""
    model = get_production_model()
    return model["path"] if model else None


def promote_model(version_id: str) -> bool:
    """
    Promote a model to production.

    - Archives the current production model
    - Sets the new model as production

    Returns:
        True if successful, False if version_id not found
    """
    registry = _load_registry()

    if version_id not in registry["models"]:
        return False

    # Archive current production model
    old_prod = registry.get("current_production")
    if old_prod and old_prod in registry["models"]:
        registry["models"][old_prod]["status"] = ModelStatus.ARCHIVED
        # Move model file to archive
        old_path = registry["models"][old_prod]["path"]
        if os.path.exists(old_path):
            archive_path = os.path.join(
                config.AL_ARCHIVE_DIR,
                old_prod,
                os.path.basename(old_path)
            )
            os.makedirs(os.path.dirname(archive_path), exist_ok=True)
            shutil.move(old_path, archive_path)
            registry["models"][old_prod]["path"] = archive_path

    # Promote new model
    registry["models"][version_id]["status"] = ModelStatus.PRODUCTION
    registry["current_production"] = version_id

    # Move model to production directory
    current_path = registry["models"][version_id]["path"]
    if os.path.exists(current_path) and config.AL_PRODUCTION_DIR not in current_path:
        prod_path = os.path.join(config.AL_PRODUCTION_DIR, "model.pt")
        os.makedirs(config.AL_PRODUCTION_DIR, exist_ok=True)
        shutil.copy(current_path, prod_path)
        # Keep original in candidates for reference, update path to production copy
        registry["models"][version_id]["production_path"] = prod_path

    _save_registry(registry)
    return True


def get_active_inference_model() -> Optional[Dict[str, Any]]:
    """Get the active inference model info."""
    registry = _load_registry()
    active = registry.get("active_inference")
    if not active:
        return None
    version_id = active.get("version_id")
    if not version_id:
        return None
    model = get_model(version_id)
    if not model:
        return None
    model["active_path"] = active.get("path")
    return model


def set_active_inference_model(version_id: str, path: str) -> bool:
    """Set the active inference model by version id and path."""
    registry = _load_registry()
    if version_id not in registry.get("models", {}):
        return False
    registry["active_inference"] = {"version_id": version_id, "path": path}
    _save_registry(registry)
    return True


def rollback_to(version_id: str) -> bool:
    """
    Rollback to a previous model version.

    - Demotes current production to archived
    - Promotes the specified version to production

    Returns:
        True if successful, False if version_id not found or not archived
    """
    registry = _load_registry()

    if version_id not in registry["models"]:
        return False

    model = registry["models"][version_id]
    if model["status"] not in [ModelStatus.ARCHIVED, ModelStatus.PRODUCTION]:
        return False

    # Use promote_model logic for consistency
    return promote_model(version_id)


def list_models(status: Optional[str] = None) -> List[Dict[str, Any]]:
    """
    List all models, optionally filtered by status.

    Returns:
        List of model entries with version_id included
    """
    registry = _load_registry()
    models = []

    for version_id, model in registry["models"].items():
        if status is None or model["status"] == status:
            entry = model.copy()
            entry["version_id"] = version_id
            models.append(entry)

    # Sort by creation date, newest first
    models.sort(key=lambda m: m.get("created_at", ""), reverse=True)
    return models


def get_model(version_id: str) -> Optional[Dict[str, Any]]:
    """Get a specific model by version ID."""
    registry = _load_registry()

    if version_id not in registry["models"]:
        return None

    model = registry["models"][version_id].copy()
    model["version_id"] = version_id
    return model


def get_model_metrics(version_id: str) -> Optional[Dict[str, Any]]:
    """Get metrics for a specific model."""
    model = get_model(version_id)
    return model["metrics"] if model else None


def delete_model(version_id: str) -> bool:
    """
    Delete a model from the registry.
    Cannot delete the current production model.
    """
    registry = _load_registry()

    if version_id not in registry["models"]:
        return False

    if registry.get("current_production") == version_id:
        return False

    # Remove model file if exists
    model_path = registry["models"][version_id].get("path")
    if model_path and os.path.exists(model_path):
        os.remove(model_path)

    del registry["models"][version_id]
    _save_registry(registry)
    return True
