"""
Event Log Module for Active Learning System.

Provides admin notifications and audit trail for AL operations.
Uses JSONL format for efficient append operations.
"""

import json
import os
from datetime import datetime
from typing import Dict, List, Optional, Any

from . import config


class EventType:
    """Event type constants for the AL system."""
    RETRAIN_TRIGGERED = "retrain_triggered"
    TRAINING_STARTED = "training_started"
    TRAINING_COMPLETED = "training_completed"
    TRAINING_FAILED = "training_failed"
    MODEL_PROMOTED = "model_promoted"
    MODEL_ROLLBACK = "model_rollback"
    CONFIG_UPDATED = "config_updated"
    LABEL_ADDED = "label_added"
    THRESHOLD_REACHED = "threshold_reached"


def log_event(
    event_type: str,
    message: str,
    metadata: Optional[Dict[str, Any]] = None
) -> Dict[str, Any]:
    """
    Log an event to the event log.

    Args:
        event_type: Type of event (use EventType constants)
        message: Human-readable message
        metadata: Optional additional data

    Returns:
        The logged event entry
    """
    os.makedirs(os.path.dirname(config.AL_EVENT_LOG_FILE), exist_ok=True)

    event = {
        "timestamp": datetime.now().isoformat(),
        "type": event_type,
        "message": message,
        "metadata": metadata or {}
    }

    with open(config.AL_EVENT_LOG_FILE, "a") as f:
        f.write(json.dumps(event) + "\n")

    return event


def get_recent_events(limit: int = 50) -> List[Dict[str, Any]]:
    """
    Get the most recent events.

    Args:
        limit: Maximum number of events to return

    Returns:
        List of events, newest first
    """
    if not os.path.exists(config.AL_EVENT_LOG_FILE):
        return []

    events = []
    with open(config.AL_EVENT_LOG_FILE, "r") as f:
        for line in f:
            line = line.strip()
            if line:
                events.append(json.loads(line))

    # Return newest first
    events.reverse()
    return events[:limit]


def get_events_by_type(event_type: str, limit: int = 50) -> List[Dict[str, Any]]:
    """
    Get events filtered by type.

    Args:
        event_type: Type to filter by
        limit: Maximum number of events to return

    Returns:
        List of matching events, newest first
    """
    if not os.path.exists(config.AL_EVENT_LOG_FILE):
        return []

    events = []
    with open(config.AL_EVENT_LOG_FILE, "r") as f:
        for line in f:
            line = line.strip()
            if line:
                event = json.loads(line)
                if event.get("type") == event_type:
                    events.append(event)

    events.reverse()
    return events[:limit]


def get_events_since(timestamp: str, limit: int = 100) -> List[Dict[str, Any]]:
    """
    Get events after a given timestamp.

    Args:
        timestamp: ISO format timestamp string
        limit: Maximum number of events to return

    Returns:
        List of events newer than timestamp, newest first
    """
    if not os.path.exists(config.AL_EVENT_LOG_FILE):
        return []

    events = []
    with open(config.AL_EVENT_LOG_FILE, "r") as f:
        for line in f:
            line = line.strip()
            if line:
                event = json.loads(line)
                if event.get("timestamp", "") > timestamp:
                    events.append(event)

    events.reverse()
    return events[:limit]


def get_all_events() -> List[Dict[str, Any]]:
    """
    Get all events in the log.

    Returns:
        List of all events, newest first
    """
    if not os.path.exists(config.AL_EVENT_LOG_FILE):
        return []

    events = []
    with open(config.AL_EVENT_LOG_FILE, "r") as f:
        for line in f:
            line = line.strip()
            if line:
                events.append(json.loads(line))

    events.reverse()
    return events


def clear_events() -> int:
    """
    Clear all events from the log.
    USE WITH CAUTION - for testing/maintenance only.

    Returns:
        Number of events cleared
    """
    if not os.path.exists(config.AL_EVENT_LOG_FILE):
        return 0

    count = len(get_all_events())

    with open(config.AL_EVENT_LOG_FILE, "w") as f:
        pass  # Truncate file

    return count


# Convenience functions for common events

def log_retrain_triggered(samples_count: int, threshold: int) -> Dict[str, Any]:
    """Log when retraining is triggered."""
    return log_event(
        EventType.RETRAIN_TRIGGERED,
        f"Retrain triggered: {samples_count} samples (threshold: {threshold})",
        {"samples_count": samples_count, "threshold": threshold}
    )


def log_training_started(version_id: str, config_used: Dict[str, Any]) -> Dict[str, Any]:
    """Log when training starts."""
    return log_event(
        EventType.TRAINING_STARTED,
        f"Training started for model {version_id}",
        {"version_id": version_id, "config": config_used}
    )


def log_training_completed(
    version_id: str,
    accuracy: float,
    samples_used: int
) -> Dict[str, Any]:
    """Log when training completes successfully."""
    return log_event(
        EventType.TRAINING_COMPLETED,
        f"Training completed: {version_id} (accuracy: {accuracy:.1%}, samples: {samples_used})",
        {"version_id": version_id, "accuracy": accuracy, "samples_used": samples_used}
    )


def log_training_failed(version_id: str, error: str) -> Dict[str, Any]:
    """Log when training fails."""
    return log_event(
        EventType.TRAINING_FAILED,
        f"Training failed for {version_id}: {error}",
        {"version_id": version_id, "error": error}
    )


def log_model_promoted(version_id: str, accuracy: float) -> Dict[str, Any]:
    """Log when a model is promoted to production."""
    return log_event(
        EventType.MODEL_PROMOTED,
        f"Model {version_id} promoted to production (accuracy: {accuracy:.1%})",
        {"version_id": version_id, "accuracy": accuracy}
    )


def log_model_rollback(
    from_version: str,
    to_version: str,
    reason: str
) -> Dict[str, Any]:
    """Log when a rollback occurs."""
    return log_event(
        EventType.MODEL_ROLLBACK,
        f"Rollback from {from_version} to {to_version}: {reason}",
        {"from_version": from_version, "to_version": to_version, "reason": reason}
    )


def log_config_updated(changes: Dict[str, Any]) -> Dict[str, Any]:
    """Log when training config is updated."""
    return log_event(
        EventType.CONFIG_UPDATED,
        "Training configuration updated",
        {"changes": changes}
    )
