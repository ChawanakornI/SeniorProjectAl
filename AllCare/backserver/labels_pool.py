"""
Labels Pool Module for Active Learning System.

Manages corrected labels for model retraining.
Uses JSONL format for efficient append operations.
"""

import json
import os
from datetime import datetime
from typing import Dict, List, Optional, Any

from . import config


def _normalize_image_retrain_history(label: Dict[str, Any]) -> Dict[str, List[str]]:
    """Ensure image retrain history has a stable dict[str, list[str]] shape."""
    history = label.get(config.AL_IMAGE_RETRAIN_HISTORY_FIELD)
    if not isinstance(history, dict):
        history = {}

    normalized: Dict[str, List[str]] = {}
    for image_path, versions in history.items():
        if not isinstance(image_path, str):
            continue
        if isinstance(versions, list):
            normalized[image_path] = [str(v) for v in versions if isinstance(v, str)]
        else:
            normalized[image_path] = []

    for image_path in label.get("image_paths", []):
        if isinstance(image_path, str):
            normalized.setdefault(image_path, [])

    return normalized


def _load_all_labels() -> List[Dict[str, Any]]:
    """Load all labels from the pool file."""
    if not os.path.exists(config.AL_LABELS_POOL_FILE):
        return []

    labels = []
    with open(config.AL_LABELS_POOL_FILE, "r") as f:
        for line in f:
            line = line.strip()
            if line:
                labels.append(json.loads(line))

    return labels


def _save_all_labels(labels: List[Dict[str, Any]]) -> None:
    """Rewrite all labels to the pool file."""
    os.makedirs(os.path.dirname(config.AL_LABELS_POOL_FILE), exist_ok=True)

    with open(config.AL_LABELS_POOL_FILE, "w") as f:
        for label in labels:
            f.write(json.dumps(label) + "\n")


def _append_label(label: Dict[str, Any]) -> None:
    """Append a single label to the pool file."""
    os.makedirs(os.path.dirname(config.AL_LABELS_POOL_FILE), exist_ok=True)

    with open(config.AL_LABELS_POOL_FILE, "a") as f:
        f.write(json.dumps(label) + "\n")


def add_label(
    case_id: str,
    image_paths: List[str],
    correct_label: str,
    user_id: str
) -> Dict[str, Any]:
    """
    Add or update a label in the pool.

    Implements "latest wins" conflict resolution:
    - If case_id already exists, update with new label and timestamp
    - Otherwise, create new entry

    Args:
        case_id: Unique case identifier
        image_paths: List of image file paths for this case
        correct_label: The corrected label (e.g., "mel", "nv")
        user_id: ID of the user who provided the correction

    Returns:
        The created/updated label entry
    """
    now = datetime.now().isoformat()
    labels = _load_all_labels()

    # Check for existing entry with same case_id
    existing_idx = None
    for i, label in enumerate(labels):
        if label.get("case_id") == case_id:
            existing_idx = i
            break

    label_entry = {
        "case_id": case_id,
        "image_paths": image_paths,
        "correct_label": correct_label,
        "user_id": user_id,
        "created_at": now if existing_idx is None else labels[existing_idx].get("created_at", now),
        "updated_at": now,
        config.AL_LABELS_USED_MODELS_FIELD: (
            [] if existing_idx is None else labels[existing_idx].get(config.AL_LABELS_USED_MODELS_FIELD, [])
        ),
        # Tracks per-image retrain rounds (version IDs) for this labeled case.
        config.AL_IMAGE_RETRAIN_HISTORY_FIELD: (
            {p: [] for p in image_paths}
            if existing_idx is None
            else _normalize_image_retrain_history(labels[existing_idx])
        )
    }

    if existing_idx is not None:
        # Update existing (latest wins)
        labels[existing_idx] = label_entry
        _save_all_labels(labels)
    else:
        # Append new
        _append_label(label_entry)

    return label_entry


def get_all_labels() -> List[Dict[str, Any]]:
    """
    Get all labels in the pool.

    Returns:
        List of all label entries
    """
    return _load_all_labels()


def get_unused_labels() -> List[Dict[str, Any]]:
    """
    Get labels that haven't been used in any model training yet.

    Returns:
        List of unused label entries
    """
    labels = _load_all_labels()
    return [l for l in labels if not l.get(config.AL_LABELS_USED_MODELS_FIELD)]


def get_labels_since(timestamp: str) -> List[Dict[str, Any]]:
    """
    Get labels created or updated after a given timestamp.

    Args:
        timestamp: ISO format timestamp string

    Returns:
        List of labels newer than timestamp
    """
    labels = _load_all_labels()
    return [l for l in labels if l.get("updated_at", "") > timestamp]


def get_label_count() -> int:
    """
    Get total count of labels in the pool.

    Returns:
        Number of labels
    """
    return len(_load_all_labels())


def get_unused_label_count() -> int:
    """
    Get count of labels not yet used in training.

    Returns:
        Number of unused labels
    """
    return len(get_unused_labels())


def mark_labels_used(version_id: str, case_ids: Optional[List[str]] = None) -> int:
    """
    Mark labels as used in a model training.

    Args:
        version_id: Model version that used these labels
        case_ids: Specific case IDs to mark, or None for all

    Returns:
        Number of labels marked
    """
    labels = _load_all_labels()
    marked = 0

    for label in labels:
        if case_ids is None or label.get("case_id") in case_ids:
            if version_id not in label.get(config.AL_LABELS_USED_MODELS_FIELD, []):
                label.setdefault(config.AL_LABELS_USED_MODELS_FIELD, []).append(version_id)
                marked += 1

            image_history = _normalize_image_retrain_history(label)
            for image_path in label.get("image_paths", []):
                if not isinstance(image_path, str):
                    continue
                history = image_history.setdefault(image_path, [])
                if version_id not in history:
                    history.append(version_id)
            label[config.AL_IMAGE_RETRAIN_HISTORY_FIELD] = image_history

    _save_all_labels(labels)
    return marked


def get_label_by_case(case_id: str) -> Optional[Dict[str, Any]]:
    """
    Get a specific label by case ID.

    Args:
        case_id: Case identifier to look up

    Returns:
        Label entry or None if not found
    """
    labels = _load_all_labels()
    for label in labels:
        if label.get("case_id") == case_id:
            return label
    return None


def delete_label(case_id: str) -> bool:
    """
    Delete a label from the pool.

    Args:
        case_id: Case identifier to delete

    Returns:
        True if deleted, False if not found
    """
    labels = _load_all_labels()
    original_len = len(labels)
    labels = [l for l in labels if l.get("case_id") != case_id]

    if len(labels) < original_len:
        _save_all_labels(labels)
        return True

    return False


def get_labels_for_training() -> List[Dict[str, Any]]:
    """
    Get all labels formatted for training.

    Returns:
        List of dicts with 'image_paths' and 'label' keys
    """
    labels = _load_all_labels()
    training_data = []

    for label in labels:
        for img_path in label.get("image_paths", []):
            training_data.append({
                "image_path": img_path,
                "label": label.get("correct_label"),
                "case_id": label.get("case_id")
            })

    return training_data
