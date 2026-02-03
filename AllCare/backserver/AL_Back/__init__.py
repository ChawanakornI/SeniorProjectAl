"""
AL_Back - Active Learning Backend Module

This package contains the Active Learning infrastructure for the AllCare
skin lesion classification system.

Structure:
- al_model_loader.py: Dedicated model loading for AL (separate from production)
- models/: Model file storage (production, candidates, archive)
- db/: Registry, labels pool, event log
- config/: Training configuration
"""

from .al_model_loader import (
    ALModelLoader,
    compare_models,
    evaluate_model_on_image,
    detect_architecture,
    create_model_architecture,
)

__all__ = [
    "ALModelLoader",
    "compare_models",
    "evaluate_model_on_image",
    "detect_architecture",
    "create_model_architecture",
]
