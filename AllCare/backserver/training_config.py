"""
Training Configuration Module for Active Learning System.

Manages training hyperparameters uploaded by admin.
"""

import json
import os
from typing import Dict, Any, List, Tuple

from . import config


DEFAULT_TRAINING_CONFIG: Dict[str, Any] = {
    "epochs": 10,
    "batch_size": 16,
    "learning_rate": 1e-4,
    "optimizer": "Adam",
    "dropout": 0.3,
    "augmentation_applied": True
}

# Validation rules: (min, max, type)
CONFIG_VALIDATION_RULES: Dict[str, Dict[str, Any]] = {
    "epochs": {"min": 1, "max": 100, "type": int},
    "batch_size": {"min": 1, "max": 128, "type": int},
    "learning_rate": {"min": 1e-6, "max": 1.0, "type": float},
    "optimizer": {"allowed": ["Adam", "SGD", "AdamW", "RMSprop"], "type": str},
    "dropout": {"min": 0.0, "max": 0.9, "type": float},
    "augmentation_applied": {"type": bool}
}


def load_config() -> Dict[str, Any]:
    """
    Load the active training configuration.
    Falls back to defaults if file doesn't exist or is invalid.

    Returns:
        Training configuration dictionary
    """
    if not os.path.exists(config.AL_ACTIVE_CONFIG_FILE):
        return DEFAULT_TRAINING_CONFIG.copy()

    try:
        with open(config.AL_ACTIVE_CONFIG_FILE, "r") as f:
            loaded = json.load(f)

        # Merge with defaults to ensure all keys exist
        merged = DEFAULT_TRAINING_CONFIG.copy()
        merged.update(loaded)
        return merged

    except (json.JSONDecodeError, IOError):
        return DEFAULT_TRAINING_CONFIG.copy()


def save_config(config_dict: Dict[str, Any]) -> bool:
    """
    Save a new training configuration.

    Args:
        config_dict: Configuration dictionary to save

    Returns:
        True if saved successfully
    """
    os.makedirs(os.path.dirname(config.AL_ACTIVE_CONFIG_FILE), exist_ok=True)

    # Merge with defaults to ensure completeness
    to_save = DEFAULT_TRAINING_CONFIG.copy()
    to_save.update(config_dict)

    with open(config.AL_ACTIVE_CONFIG_FILE, "w") as f:
        json.dump(to_save, f, indent=2)

    return True


def validate_config(config_dict: Dict[str, Any]) -> Tuple[bool, List[str]]:
    """
    Validate a training configuration dictionary.

    Args:
        config_dict: Configuration to validate

    Returns:
        Tuple of (is_valid, list of error messages)
    """
    errors = []

    for key, rules in CONFIG_VALIDATION_RULES.items():
        if key not in config_dict:
            continue

        value = config_dict[key]
        expected_type = rules.get("type")

        # Type check
        if expected_type and not isinstance(value, expected_type):
            # Allow int for float fields
            if expected_type == float and isinstance(value, int):
                value = float(value)
                config_dict[key] = value
            else:
                errors.append(f"{key}: expected {expected_type.__name__}, got {type(value).__name__}")
                continue

        # Range check
        if "min" in rules and value < rules["min"]:
            errors.append(f"{key}: value {value} is below minimum {rules['min']}")

        if "max" in rules and value > rules["max"]:
            errors.append(f"{key}: value {value} is above maximum {rules['max']}")

        # Allowed values check
        if "allowed" in rules and value not in rules["allowed"]:
            errors.append(f"{key}: value '{value}' not in allowed values {rules['allowed']}")

    return len(errors) == 0, errors


def get_optimizer_class(optimizer_name: str):
    """
    Get the PyTorch optimizer class by name.

    Args:
        optimizer_name: Name of the optimizer

    Returns:
        Optimizer class from torch.optim
    """
    import torch.optim as optim

    optimizers = {
        "Adam": optim.Adam,
        "SGD": optim.SGD,
        "AdamW": optim.AdamW,
        "RMSprop": optim.RMSprop
    }

    return optimizers.get(optimizer_name, optim.Adam)


def get_default_config() -> Dict[str, Any]:
    """Return a copy of the default configuration."""
    return DEFAULT_TRAINING_CONFIG.copy()
