"""
Active Learning module for margin-based uncertainty sampling.
"""

from typing import List, Dict, Any, Tuple
import heapq


def calculate_margin(predictions: List[Dict[str, Any]]) -> float:
    """
    Calculate the margin (difference between top two predictions) for uncertainty sampling.

    Args:
        predictions: List of prediction dictionaries with 'label' and 'confidence' keys

    Returns:
        Margin value (lower = more uncertain)
    """
    if len(predictions) < 2:
        return 1.0  # Maximum certainty if only one prediction

    # Sort predictions by confidence in descending order
    sorted_predictions = sorted(predictions, key=lambda x: x['confidence'], reverse=True)

    # Margin = confidence of top prediction - confidence of second top prediction
    top_confidence = sorted_predictions[0]['confidence']
    second_confidence = sorted_predictions[1]['confidence']

    return top_confidence - second_confidence


def calculate_case_margin(case: Dict[str, Any]) -> float:
    """
    Calculate the case-level uncertainty using minimum margin across all images.

    Args:
        case: Case dictionary containing images with predictions

    Returns:
        Minimum margin across all images in the case (lower = more uncertain)
    """
    images = case.get('images', [])
    if not images:
        # Fallback to case-level predictions if no images
        predictions = case.get('predictions', [])
        if predictions:
            return calculate_margin(predictions)
        return 1.0  # Maximum certainty if no predictions

    margins = []
    for image in images:
        predictions = image.get('predictions', [])
        if predictions:
            margin = calculate_margin(predictions)
            margins.append(margin)

    if not margins:
        return 1.0  # Maximum certainty if no valid predictions

    # Return minimum margin (most uncertain image determines case uncertainty)
    return min(margins)


def select_uncertain_samples(cases: List[Dict[str, Any]], top_k: int = 5) -> List[Dict[str, Any]]:
    """
    Select top-k most uncertain cases based on minimum margin sampling.

    Args:
        cases: List of case dictionaries containing images with predictions
        top_k: Number of uncertain samples to select

    Returns:
        List of top-k uncertain cases with margin scores
    """
    uncertain_samples = []

    for idx, case in enumerate(cases):
        margin = calculate_case_margin(case)
        case_with_margin = {
            **case,
            'margin': margin,
            'uncertainty_score': 1.0 - margin  
        }

        # Use heap to keep top-k uncertain samples (smallest margins)
        if len(uncertain_samples) < top_k:
            heapq.heappush(uncertain_samples, (margin, idx, case_with_margin))
        elif margin < uncertain_samples[0][0]:
            heapq.heapreplace(uncertain_samples, (margin, idx, case_with_margin))

    # Return cases sorted by uncertainty (most uncertain first)
    result = [case for _, __, case in sorted(uncertain_samples, key=lambda x: x[0])]
    return result


def get_active_learning_candidates(cases: List[Dict[str, Any]], top_k: int = 5) -> Dict[str, Any]:
    """
    Get active learning candidates for labeling based on case-level uncertainty.

    Case uncertainty is determined by the minimum margin across all images in the case.
    Cases with lower minimum margins are considered more uncertain.

    Args:
        cases: List of cases with images containing predictions
        top_k: Number of candidates to return

    Returns:
        Dictionary containing candidates and metadata
    """
    candidates = select_uncertain_samples(cases, top_k)

    return {
        'candidates': candidates,
        'total_candidates': len(candidates),
        'selection_method': 'minimum_margin_case_sampling',
        'description': f'Top {len(candidates)} most uncertain cases based on minimum prediction margins across all images'
    }
