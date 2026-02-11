"""
Auto-Promotion Module for Active Learning System.

Handles automatic model promotion based on performance comparison,
and provides rollback capabilities.
"""

from typing import Dict, Any, Optional, Tuple

from . import config
from . import model_registry
from . import event_log


def get_production_metrics() -> Optional[Dict[str, Any]]:
    """
    Get metrics for the current production model.

    Returns:
        Metrics dict or None if no production model
    """
    prod = model_registry.get_production_model()
    if not prod:
        return None
    return prod.get("metrics", {})


def get_candidate_metrics(version_id: str) -> Optional[Dict[str, Any]]:
    """
    Get metrics for a candidate model.

    Returns:
        Metrics dict or None if model not found
    """
    return model_registry.get_model_metrics(version_id)


def compare_models(
    candidate_id: str,
    metric_key: str = "val_accuracy",
    threshold: float = 0.0
) -> Tuple[bool, float, float]:
    """
    Compare a candidate model against production.

    Args:
        candidate_id: Version ID of candidate model
        metric_key: Metric to compare (default: val_accuracy)
        threshold: Minimum improvement required to promote (default: 0)

    Returns:
        Tuple of (should_promote, candidate_value, production_value)
    """
    candidate_metrics = get_candidate_metrics(candidate_id)
    production_metrics = get_production_metrics()

    if not candidate_metrics:
        return False, 0.0, 0.0

    candidate_value = candidate_metrics.get(metric_key, 0.0)

    # If no production model, any candidate is better
    if not production_metrics:
        return True, candidate_value, 0.0

    production_value = production_metrics.get(metric_key, 0.0)

    # Candidate must be at least threshold better
    should_promote = candidate_value > (production_value + threshold)

    return should_promote, candidate_value, production_value


def evaluate_and_promote(
    version_id: str,
    metric_key: str = "val_accuracy",
    min_improvement: float = 0.0,
    auto_promote: bool = True
) -> Dict[str, Any]:
    """
    Evaluate a candidate model and optionally promote it.

    Args:
        version_id: Candidate model version ID
        metric_key: Metric to compare
        min_improvement: Minimum improvement required
        auto_promote: If True, automatically promote better models

    Returns:
        Result dict with decision and metrics
    """
    # Get candidate model
    candidate = model_registry.get_model(version_id)
    if not candidate:
        return {
            "success": False,
            "error": f"Model {version_id} not found",
            "promoted": False
        }

    # Compare against production
    should_promote, candidate_val, production_val = compare_models(
        version_id, metric_key, min_improvement
    )

    result = {
        "success": True,
        "version_id": version_id,
        "candidate_value": candidate_val,
        "production_value": production_val,
        "metric": metric_key,
        "improvement": candidate_val - production_val,
        "meets_threshold": should_promote,
        "promoted": False
    }

    if should_promote and auto_promote:
        # Get current production for logging
        current_prod = model_registry.get_production_model()
        old_version = current_prod["version_id"] if current_prod else None

        # Promote the model
        if model_registry.promote_model(version_id):
            result["promoted"] = True
            result["previous_production"] = old_version

            # Log the promotion event
            event_log.log_model_promoted(version_id, candidate_val)
        else:
            result["error"] = "Promotion failed"
            result["success"] = False

    elif not should_promote:
        # Update status to archived (not good enough)
        model_registry.update_model_status(version_id, model_registry.ModelStatus.ARCHIVED)
        result["reason"] = f"Candidate ({candidate_val:.4f}) did not improve over production ({production_val:.4f}) by required threshold ({min_improvement})"

    return result


def manual_promote(version_id: str, reason: str = "Manual promotion") -> Dict[str, Any]:
    """
    Manually promote a model to production.

    Args:
        version_id: Model to promote
        reason: Reason for manual promotion

    Returns:
        Result dict
    """
    model = model_registry.get_model(version_id)
    if not model:
        return {"success": False, "error": f"Model {version_id} not found"}

    current_prod = model_registry.get_production_model()
    old_version = current_prod["version_id"] if current_prod else None

    if model_registry.promote_model(version_id):
        metrics = model.get("metrics", {})
        accuracy = metrics.get("val_accuracy", 0.0)

        event_log.log_event(
            event_log.EventType.MODEL_PROMOTED,
            f"Model {version_id} manually promoted: {reason}",
            {"version_id": version_id, "accuracy": accuracy, "reason": reason}
        )

        return {
            "success": True,
            "version_id": version_id,
            "previous_production": old_version,
            "reason": reason
        }

    return {"success": False, "error": "Promotion failed"}


def trigger_rollback(
    to_version: Optional[str] = None,
    reason: str = "Manual rollback"
) -> Dict[str, Any]:
    """
    Rollback to a previous model version.

    Args:
        to_version: Specific version to rollback to, or None for most recent archived
        reason: Reason for rollback

    Returns:
        Result dict
    """
    current_prod = model_registry.get_production_model()
    if not current_prod:
        return {"success": False, "error": "No production model to rollback from"}

    from_version = current_prod["version_id"]

    # Find target version
    if to_version:
        target = model_registry.get_model(to_version)
        if not target:
            return {"success": False, "error": f"Target model {to_version} not found"}
    else:
        # Find most recent archived model
        archived = model_registry.list_models(status=model_registry.ModelStatus.ARCHIVED)
        if not archived:
            return {"success": False, "error": "No archived models available for rollback"}
        target = archived[0]  # Most recent (list is sorted by date)
        to_version = target["version_id"]

    # Perform rollback
    if model_registry.rollback_to(to_version):
        event_log.log_model_rollback(from_version, to_version, reason)

        return {
            "success": True,
            "from_version": from_version,
            "to_version": to_version,
            "reason": reason
        }

    return {"success": False, "error": "Rollback failed"}


def check_production_health() -> Dict[str, Any]:
    """
    Check if the production model is healthy.

    This is a placeholder for more sophisticated health checks.
    Could be extended to monitor:
    - Prediction confidence distribution
    - Error rates
    - Latency metrics

    Returns:
        Health status dict
    """
    prod = model_registry.get_production_model()

    if not prod:
        return {
            "healthy": False,
            "reason": "No production model deployed",
            "production_model": None
        }

    metrics = prod.get("metrics", {})

    return {
        "healthy": True,
        "production_model": prod["version_id"],
        "architecture": prod.get("architecture", "unknown"),
        "metrics": metrics,
        "deployed_at": prod.get("created_at")
    }


def get_promotion_candidates() -> list:
    """
    Get models that are ready for promotion evaluation.

    Returns:
        List of models with 'evaluating' status
    """
    return model_registry.list_models(status=model_registry.ModelStatus.EVALUATING)


def auto_evaluate_candidates(
    metric_key: str = "val_accuracy",
    min_improvement: float = 0.0
) -> list:
    """
    Automatically evaluate and promote all candidate models.

    Args:
        metric_key: Metric to use for comparison
        min_improvement: Minimum improvement required

    Returns:
        List of evaluation results
    """
    candidates = get_promotion_candidates()
    results = []

    for candidate in candidates:
        result = evaluate_and_promote(
            candidate["version_id"],
            metric_key=metric_key,
            min_improvement=min_improvement,
            auto_promote=True
        )
        results.append(result)

    return results
