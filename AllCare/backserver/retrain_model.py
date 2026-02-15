"""
Model Retraining Module for Active Learning System.

Supports multiple architectures (EfficientNetV2-M, ResNet50) with transfer learning
from the current production model or base checkpoints.
"""

import os
import csv
import json
import time
import random
import shutil
from datetime import datetime
from pathlib import Path
from collections import defaultdict
from typing import Dict, Any, Optional, Tuple, List

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader, Dataset
from torchvision import models, transforms
from PIL import Image

from . import config
from . import model_registry
from . import training_config as tc
from . import labels_pool
from . import event_log


def _get_ultralytics_yolo():
    """Lazy import ultralytics YOLO to keep module import resilient."""
    try:
        from ultralytics import YOLO  # type: ignore
        return YOLO
    except Exception:
        return None


def _is_yolo_available() -> Tuple[bool, Optional[str]]:
    if not config.AL_YOLO_ENABLED:
        return False, "YOLO retraining disabled by AL_YOLO_ENABLED"
    if config.AL_YOLO_TASK != "classify":
        return False, f"Unsupported AL_YOLO_TASK: {config.AL_YOLO_TASK}"
    if _get_ultralytics_yolo() is None:
        return False, "Missing 'ultralytics' package"
    return True, None


# Normalized aliases for user-provided architecture values.
_ARCH_ALIASES = {
    "efficientnet": config.ModelArchitecture.EFFICIENTNET_V2_M,
    "efficientnet_v2_m": config.ModelArchitecture.EFFICIENTNET_V2_M,
    "resnet": config.ModelArchitecture.RESNET50,
    "resnet50": config.ModelArchitecture.RESNET50,
    "mobilenet": config.ModelArchitecture.MOBILENET_V3_LARGE,
    "mobilenet_v3": config.ModelArchitecture.MOBILENET_V3_LARGE,
    "mobilenet_v3_large": config.ModelArchitecture.MOBILENET_V3_LARGE,
    "yolo": config.ModelArchitecture.YOLO,
    "yolov8": config.ModelArchitecture.YOLO,
}


def normalize_architecture_name(architecture: Optional[str]) -> str:
    """Normalize user-provided architecture names."""
    if architecture is None or not str(architecture).strip():
        architecture = config.AL_DEFAULT_ARCHITECTURE
    cleaned = str(architecture).strip().lower()
    return _ARCH_ALIASES.get(cleaned, cleaned)


def get_available_retrain_architectures() -> List[Dict[str, Any]]:
    """Describe architectures and whether they are currently trainable."""
    yolo_available, yolo_reason = _is_yolo_available()
    return [
        {
            "id": config.ModelArchitecture.EFFICIENTNET_V2_M,
            "label": "EfficientNetV2-M",
            "available": True,
            "reason": None,
        },
        {
            "id": config.ModelArchitecture.RESNET50,
            "label": "ResNet50",
            "available": True,
            "reason": None,
        },
        {
            "id": config.ModelArchitecture.MOBILENET_V3_LARGE,
            "label": "MobileNetV3 Large",
            "available": True,
            "reason": None,
        },
        {
            "id": config.ModelArchitecture.YOLO,
            "label": "YOLO",
            "available": yolo_available,
            "reason": yolo_reason,
        },
    ]


def validate_retrain_architecture(architecture: Optional[str]) -> Tuple[bool, str, Optional[str]]:
    """
    Validate requested architecture and return (is_valid, normalized_id, reason_if_invalid).
    """
    normalized = normalize_architecture_name(architecture)
    options = {o["id"]: o for o in get_available_retrain_architectures()}
    opt = options.get(normalized)
    if not opt:
        return False, normalized, f"Unsupported architecture: {normalized}"
    if not opt.get("available", False):
        return False, normalized, opt.get("reason") or f"Architecture not available: {normalized}"
    return True, normalized, None


# =============================================================================
# Model Factory - Supports Multiple Architectures
# =============================================================================

def detect_architecture_from_state_dict(state_dict: Dict[str, Any]) -> Optional[str]:
    """
    Detect model architecture by analyzing state_dict keys.

    Returns:
        Architecture string or None if unknown
    """
    keys = list(state_dict.keys())

    # EfficientNetV2 has 'features.0.0.block' pattern
    if any("features.0.0" in k for k in keys):
        return config.ModelArchitecture.EFFICIENTNET_V2_M

    # ResNet has 'layer1', 'layer2', etc.
    if any("layer1" in k for k in keys):
        return config.ModelArchitecture.RESNET50

    # MobileNetV3 classifier commonly ends with classifier.3.*
    if any("classifier.3" in k for k in keys):
        return config.ModelArchitecture.MOBILENET_V3_LARGE

    return None


def create_model(architecture: str, num_classes: int = 7, dropout: float = 0.3) -> nn.Module:
    """
    Factory function to create a model by architecture name.

    Args:
        architecture: One of ModelArchitecture constants
        num_classes: Number of output classes
        dropout: Dropout rate for classifier head

    Returns:
        PyTorch model with appropriate classifier head
    """
    if architecture == config.ModelArchitecture.EFFICIENTNET_V2_M:
        model = models.efficientnet_v2_m(weights=None)
        in_features = model.classifier[1].in_features
        model.classifier = nn.Sequential(
            nn.Dropout(p=dropout, inplace=True),
            nn.Linear(in_features, num_classes)
        )
        return model

    elif architecture == config.ModelArchitecture.RESNET50:
        model = models.resnet50(weights=None)
        in_features = model.fc.in_features
        model.fc = nn.Sequential(
            nn.Dropout(p=dropout),
            nn.Linear(in_features, num_classes)
        )
        return model

    elif architecture == config.ModelArchitecture.MOBILENET_V3_LARGE:
        model = models.mobilenet_v3_large(weights=None)
        in_features = model.classifier[3].in_features
        model.classifier = nn.Sequential(
            nn.Linear(model.classifier[0].in_features, model.classifier[0].out_features),
            nn.Hardswish(),
            nn.Dropout(p=dropout, inplace=True),
            nn.Linear(in_features, num_classes),
        )
        return model

    elif architecture == config.ModelArchitecture.YOLO:
        raise ValueError("YOLO retraining is not supported in this transfer-learning pipeline yet")

    else:
        raise ValueError(f"Unknown architecture: {architecture}")


def create_model_with_pretrained_weights(
    architecture: str,
    num_classes: int = 7,
    dropout: float = 0.3
) -> nn.Module:
    """
    Create a model with ImageNet-pretrained weights (for fresh start).
    """
    if architecture == config.ModelArchitecture.EFFICIENTNET_V2_M:
        model = models.efficientnet_v2_m(weights=models.EfficientNet_V2_M_Weights.IMAGENET1K_V1)
        in_features = model.classifier[1].in_features
        model.classifier = nn.Sequential(
            nn.Dropout(p=dropout, inplace=True),
            nn.Linear(in_features, num_classes)
        )
        return model

    elif architecture == config.ModelArchitecture.RESNET50:
        model = models.resnet50(weights=models.ResNet50_Weights.IMAGENET1K_V2)
        in_features = model.fc.in_features
        model.fc = nn.Sequential(
            nn.Dropout(p=dropout),
            nn.Linear(in_features, num_classes)
        )
        return model

    elif architecture == config.ModelArchitecture.MOBILENET_V3_LARGE:
        model = models.mobilenet_v3_large(weights=models.MobileNet_V3_Large_Weights.IMAGENET1K_V2)
        in_features = model.classifier[3].in_features
        model.classifier = nn.Sequential(
            nn.Linear(model.classifier[0].in_features, model.classifier[0].out_features),
            nn.Hardswish(),
            nn.Dropout(p=dropout, inplace=True),
            nn.Linear(in_features, num_classes),
        )
        return model

    elif architecture == config.ModelArchitecture.YOLO:
        raise ValueError("YOLO retraining is not supported in this transfer-learning pipeline yet")

    else:
        raise ValueError(f"Unknown architecture: {architecture}")


def load_checkpoint(
    path: str,
    device: str,
    architecture: Optional[str] = None
) -> Tuple[nn.Module, str]:
    """
    Load a model from checkpoint file.

    Args:
        path: Path to checkpoint file
        device: Device to load onto
        architecture: Optional architecture hint (auto-detected if None)

    Returns:
        Tuple of (model, detected_architecture)
    """
    checkpoint = torch.load(path, map_location=device, weights_only=False)

    # Handle different checkpoint formats
    if isinstance(checkpoint, dict):
        state_dict = checkpoint.get("model_state_dict") or checkpoint.get("state_dict") or checkpoint
        arch_hint = checkpoint.get("architecture")
    else:
        # Might be a raw state_dict or a model object
        if hasattr(checkpoint, "state_dict"):
            state_dict = checkpoint.state_dict()
        else:
            state_dict = checkpoint
        arch_hint = None

    # Determine architecture
    if architecture:
        arch = architecture
    elif arch_hint:
        arch = arch_hint
    else:
        arch = detect_architecture_from_state_dict(state_dict)
        if not arch:
            raise ValueError(f"Could not detect architecture from checkpoint: {path}")

    # Create model and load weights
    num_classes = len(config.LABEL_MAP)
    model = create_model(arch, num_classes)
    model.load_state_dict(state_dict)

    return model, arch


# =============================================================================
# Dataset
# =============================================================================

class LabeledDataset(Dataset):
    """Dataset for labeled skin lesion images."""

    def __init__(self, samples: List[Tuple[str, int]], augment: bool = False, image_size: int = 224):
        self.samples = samples

        # EfficientNetV2-M uses 480x480, but we use 224 for consistency and speed
        # You can adjust this based on your needs
        resize_size = image_size + 32  # 256 for 224 input

        if augment:
            self.transform = transforms.Compose([
                transforms.Resize((resize_size, resize_size)),
                transforms.RandomHorizontalFlip(),
                transforms.RandomVerticalFlip(),
                transforms.RandomRotation(20),
                transforms.ColorJitter(brightness=0.2, contrast=0.2),
                transforms.CenterCrop(image_size),
                transforms.ToTensor(),
                transforms.Normalize(
                    mean=[0.485, 0.456, 0.406],
                    std=[0.229, 0.224, 0.225]
                )
            ])
        else:
            self.transform = transforms.Compose([
                transforms.Resize((resize_size, resize_size)),
                transforms.CenterCrop(image_size),
                transforms.ToTensor(),
                transforms.Normalize(
                    mean=[0.485, 0.456, 0.406],
                    std=[0.229, 0.224, 0.225]
                )
            ])

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        path, label = self.samples[idx]
        img = Image.open(path).convert("RGB")
        return self.transform(img), label


# =============================================================================
# Data Collection
# =============================================================================

def collect_labeled_samples() -> List[Tuple[str, int]]:
    """Collect labeled samples from the AL labels pool."""
    label_map = config.LABEL_MAP
    training_data = labels_pool.get_labels_for_training()

    samples = []
    for item in training_data:
        img_path = item["image_path"]
        label_str = item["label"]

        if label_str not in label_map:
            continue

        if not os.path.isabs(img_path):
            img_path = os.path.join(config.STORAGE_ROOT, img_path)

        if os.path.exists(img_path):
            samples.append((img_path, label_map[label_str]))

    return samples


def collect_legacy_labeled_cases() -> List[Tuple[str, int]]:
    """Collect labeled cases from legacy metadata files (backwards compatibility)."""
    label_map = config.LABEL_MAP
    results = []
    root = Path(config.STORAGE_ROOT)

    if not root.exists():
        return results

    for user_dir in root.iterdir():
        if not user_dir.is_dir():
            continue

        meta = user_dir / config.METADATA_FILENAME
        if not meta.exists():
            continue

        with open(meta, "r") as f:
            for line in f:
                try:
                    data = json.loads(line)
                except json.JSONDecodeError:
                    continue

                if data.get("entry_type") == "reject" and "correct_label" in data:
                    label = data["correct_label"]
                    if label not in label_map:
                        continue

                    for p in data.get("image_paths", []):
                        img_path = user_dir / p
                        if img_path.exists():
                            results.append((str(img_path), label_map[label]))

    return results


def _normalize_old_label(raw_label: str) -> Optional[str]:
    """Map old dataset labels to current training labels."""
    if not isinstance(raw_label, str):
        return None
    cleaned = raw_label.strip()
    if not cleaned:
        return None

    old_map = config.AL_OLD_DATA_LABEL_MAP or {}
    mapped = old_map.get(cleaned) or old_map.get(cleaned.upper()) or old_map.get(cleaned.lower())
    if not mapped:
        return None
    mapped_label = str(mapped).strip().lower()
    if mapped_label not in config.LABEL_MAP:
        return None
    return mapped_label


def collect_old_dataset_samples() -> List[Tuple[str, int]]:
    """
    Collect old replay samples from CSV + image folder.
    """
    csv_path = config.AL_OLD_DATA_CSV
    dataset_dir = config.AL_OLD_DATASET_DIR
    image_col = config.AL_OLD_DATA_CSV_IMAGE_COLUMN
    label_col = config.AL_OLD_DATA_CSV_LABEL_COLUMN

    if not csv_path or not os.path.exists(csv_path):
        return []
    if not dataset_dir or not os.path.isdir(dataset_dir):
        return []

    samples: List[Tuple[str, int]] = []
    with open(csv_path, "r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            img_name = (row.get(image_col) or "").strip()
            raw_label = (row.get(label_col) or "").strip()
            if not img_name or not raw_label:
                continue

            mapped_label = _normalize_old_label(raw_label)
            if not mapped_label:
                continue

            img_path = os.path.join(dataset_dir, img_name)
            if not os.path.exists(img_path):
                continue

            samples.append((img_path, config.LABEL_MAP[mapped_label]))

    return samples


def _build_eval_transform(image_size: int = 224):
    resize_size = image_size + 32
    return transforms.Compose([
        transforms.Resize((resize_size, resize_size)),
        transforms.CenterCrop(image_size),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=[0.485, 0.456, 0.406],
            std=[0.229, 0.224, 0.225]
        )
    ])


def _extract_features(model: nn.Module, x: torch.Tensor, arch: str) -> torch.Tensor:
    """Extract embeddings before classifier head."""
    if arch == config.ModelArchitecture.EFFICIENTNET_V2_M:
        feat = model.features(x)
        feat = model.avgpool(feat)
        return torch.flatten(feat, 1)

    if arch == config.ModelArchitecture.RESNET50:
        x = model.conv1(x)
        x = model.bn1(x)
        x = model.relu(x)
        x = model.maxpool(x)
        x = model.layer1(x)
        x = model.layer2(x)
        x = model.layer3(x)
        x = model.layer4(x)
        x = model.avgpool(x)
        return torch.flatten(x, 1)

    if arch == config.ModelArchitecture.MOBILENET_V3_LARGE:
        feat = model.features(x)
        feat = F.adaptive_avg_pool2d(feat, 1)
        return torch.flatten(feat, 1)

    # Fallback for unknown architectures
    out = model(x)
    if out.ndim == 1:
        out = out.unsqueeze(0)
    return out


def _compute_sample_embeddings(
    samples: List[Tuple[str, int]],
    model: nn.Module,
    arch: str,
    device: str,
    image_size: int,
    batch_size: int,
) -> Tuple[List[int], torch.Tensor]:
    """Compute embeddings for samples; returns kept sample indices and features."""
    transform = _build_eval_transform(image_size=image_size)
    kept_indices: List[int] = []
    tensor_batch: List[torch.Tensor] = []
    feature_chunks: List[torch.Tensor] = []

    def _flush_batch():
        nonlocal tensor_batch
        if not tensor_batch:
            return
        x = torch.stack(tensor_batch).to(device)
        with torch.no_grad():
            feat = _extract_features(model, x, arch)
            feat = F.normalize(feat, p=2, dim=1)
        feature_chunks.append(feat.detach().cpu())
        tensor_batch = []

    model.eval()
    for idx, (img_path, _) in enumerate(samples):
        try:
            img = Image.open(img_path).convert("RGB")
            tensor = transform(img)
        except Exception:
            continue
        kept_indices.append(idx)
        tensor_batch.append(tensor)
        if len(tensor_batch) >= batch_size:
            _flush_batch()

    _flush_batch()

    if not feature_chunks:
        return [], torch.empty((0, 0))

    return kept_indices, torch.cat(feature_chunks, dim=0)


def _allocate_quota_per_class(class_sizes: Dict[int, int], total_quota: int) -> Dict[int, int]:
    """Allocate quota proportionally by class with floor + largest remainder."""
    if total_quota <= 0:
        return {k: 0 for k in class_sizes}

    total_count = sum(class_sizes.values())
    if total_count <= 0:
        return {k: 0 for k in class_sizes}

    raw = {k: (class_sizes[k] / total_count) * total_quota for k in class_sizes}
    alloc = {k: min(class_sizes[k], int(raw[k])) for k in class_sizes}
    assigned = sum(alloc.values())

    # Largest remainder method
    remainders = sorted(
        class_sizes.keys(),
        key=lambda k: (raw[k] - int(raw[k])),
        reverse=True,
    )
    i = 0
    while assigned < total_quota and remainders:
        k = remainders[i % len(remainders)]
        if alloc[k] < class_sizes[k]:
            alloc[k] += 1
            assigned += 1
        i += 1
        if i > total_quota * 4:
            break

    return alloc


def select_replay_samples(
    old_samples: List[Tuple[str, int]],
    model: nn.Module,
    arch: str,
    device: str,
) -> Tuple[List[Tuple[str, int]], Dict[str, Any]]:
    """
    Select old samples with Experience Replay strategy:
    - Herding majority
    - Random minority
    """
    if not old_samples:
        return [], {
            "enabled": config.AL_EXPERIENCE_REPLAY_ENABLED,
            "old_samples_total": 0,
            "old_samples_selected": 0,
            "quota": 0,
            "herding_selected": 0,
            "random_selected": 0,
        }

    quota = max(0, int(config.AL_REPLAY_OLD_QUOTA))
    if quota <= 0:
        return [], {
            "enabled": config.AL_EXPERIENCE_REPLAY_ENABLED,
            "old_samples_total": len(old_samples),
            "old_samples_selected": 0,
            "quota": 0,
            "herding_selected": 0,
            "random_selected": 0,
        }

    total_available = len(old_samples)
    quota = min(quota, total_available)

    herding_ratio = max(0.0, min(1.0, float(config.AL_REPLAY_HERDING_RATIO)))
    random_ratio = max(0.0, min(1.0, float(config.AL_REPLAY_RANDOM_RATIO)))
    ratio_sum = herding_ratio + random_ratio
    if ratio_sum <= 0:
        herding_ratio = 0.8
        random_ratio = 0.2
        ratio_sum = 1.0
    herding_ratio /= ratio_sum
    random_ratio /= ratio_sum

    herding_target = int(round(quota * herding_ratio))
    random_target = quota - herding_target

    image_size = max(64, int(config.AL_REPLAY_IMAGE_SIZE))
    batch_size = max(1, int(config.AL_REPLAY_BATCH_SIZE))
    kept_indices, features = _compute_sample_embeddings(
        old_samples,
        model=model,
        arch=arch,
        device=device,
        image_size=image_size,
        batch_size=batch_size,
    )

    if not kept_indices or features.shape[0] == 0:
        rng = random.Random(config.AL_REPLAY_RANDOM_SEED)
        picked = rng.sample(old_samples, quota) if quota < len(old_samples) else list(old_samples)
        return picked, {
            "enabled": config.AL_EXPERIENCE_REPLAY_ENABLED,
            "old_samples_total": len(old_samples),
            "old_samples_selected": len(picked),
            "quota": quota,
            "herding_selected": 0,
            "random_selected": len(picked),
            "fallback": "random_only_no_embeddings",
        }

    # Reduced sample space with valid embeddings
    valid_samples = [old_samples[i] for i in kept_indices]
    quota = min(quota, len(valid_samples))
    herding_target = min(herding_target, quota)
    random_target = quota - herding_target

    class_indices: Dict[int, List[int]] = defaultdict(list)
    for i, (_, label_idx) in enumerate(valid_samples):
        class_indices[label_idx].append(i)

    class_sizes = {k: len(v) for k, v in class_indices.items()}
    per_class_quota = _allocate_quota_per_class(class_sizes, herding_target)

    selected_indices = set()
    for label_idx, idxs in class_indices.items():
        target_k = per_class_quota.get(label_idx, 0)
        if target_k <= 0:
            continue

        class_feats = features[idxs]
        centroid = class_feats.mean(dim=0, keepdim=True)
        distances = torch.norm(class_feats - centroid, dim=1)
        order = torch.argsort(distances).tolist()
        for rank in order[:target_k]:
            selected_indices.add(idxs[rank])

    # If herding under-fills due to edge cases, top up with random
    rng = random.Random(config.AL_REPLAY_RANDOM_SEED)
    remaining = [i for i in range(len(valid_samples)) if i not in selected_indices]
    missing_for_herding = herding_target - len(selected_indices)
    if missing_for_herding > 0 and remaining:
        top_up = rng.sample(remaining, min(missing_for_herding, len(remaining)))
        selected_indices.update(top_up)
        remaining = [i for i in remaining if i not in set(top_up)]

    # Random part
    random_pick = rng.sample(remaining, min(random_target, len(remaining))) if remaining and random_target > 0 else []
    selected_indices.update(random_pick)

    # Ensure exact quota when possible
    if len(selected_indices) < quota:
        remaining = [i for i in range(len(valid_samples)) if i not in selected_indices]
        extra = rng.sample(remaining, min(quota - len(selected_indices), len(remaining)))
        selected_indices.update(extra)
    elif len(selected_indices) > quota:
        selected_indices = set(rng.sample(list(selected_indices), quota))

    picked_list = sorted(selected_indices)
    selected_samples = [valid_samples[i] for i in picked_list]

    herding_selected = min(len(selected_samples), herding_target)
    random_selected = len(selected_samples) - herding_selected
    return selected_samples, {
        "enabled": config.AL_EXPERIENCE_REPLAY_ENABLED,
        "old_samples_total": len(old_samples),
        "old_samples_with_embeddings": len(valid_samples),
        "old_samples_selected": len(selected_samples),
        "quota": quota,
        "herding_target": herding_target,
        "random_target": random_target,
        "herding_selected": herding_selected,
        "random_selected": random_selected,
        "herding_ratio": herding_ratio,
        "random_ratio": random_ratio,
        "seed": config.AL_REPLAY_RANDOM_SEED,
        "image_size": image_size,
        "batch_size": batch_size,
    }


def get_available_training_sample_count() -> int:
    """
    Count how many samples are available for retraining.
    Prefers labels_pool data; falls back to legacy metadata if empty.
    """
    samples = collect_labeled_samples()
    if not samples:
        samples = collect_legacy_labeled_cases()
    return len(samples)


def get_training_log_path(version_id: str) -> Optional[str]:
    """Resolve the training log path for a model version."""
    model = model_registry.get_model(version_id)
    if not model:
        return None

    model_path = model.get("path")
    if not model_path:
        return None

    return os.path.join(os.path.dirname(model_path), config.AL_TRAINING_LOG_FILENAME)


def load_training_log(version_id: str) -> List[Dict[str, Any]]:
    """Load per-epoch training log for a model version."""
    log_path = get_training_log_path(version_id)
    if not log_path or not os.path.exists(log_path):
        return []

    try:
        with open(log_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, list):
                return data
    except (json.JSONDecodeError, OSError, ValueError):
        return []

    return []


def build_training_plot_data(training_log: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Convert raw epoch logs into chart-friendly series.

    Returns:
        {
          "epochs": [1,2,...],
          "series": {"metric_name": [values...]},
          "available_metrics": ["..."]
        }
    """
    epochs: List[int] = []
    series: Dict[str, List[Any]] = {}

    for row in training_log:
        if not isinstance(row, dict):
            continue
        epoch = row.get("epoch")
        if not isinstance(epoch, int):
            continue
        epochs.append(epoch)

        for key, value in row.items():
            if key == "epoch":
                continue
            series.setdefault(key, []).append(value)

    return {
        "epochs": epochs,
        "series": series,
        "available_metrics": sorted(series.keys()),
    }


def _trim_xy(epochs: List[int], values: List[Any]) -> Tuple[List[int], List[Any]]:
    point_count = min(len(epochs), len(values))
    return epochs[:point_count], values[:point_count]


def _pick_accuracy_keys(series: Dict[str, List[Any]]) -> Tuple[Optional[str], Optional[str]]:
    train_key = "train_accuracy" if "train_accuracy" in series else None
    val_key = "val_accuracy" if "val_accuracy" in series else None
    if train_key is None and "accuracy" in series:
        train_key = "accuracy"
    return train_key, val_key


def _generate_training_graph(version_id: str) -> Optional[str]:
    """Generate epoch loss/accuracy graph for a trained model version."""
    training_log = load_training_log(version_id)
    if not training_log:
        return None

    plot_data = build_training_plot_data(training_log)
    epochs = plot_data.get("epochs", [])
    series = plot_data.get("series", {})
    if not epochs or not isinstance(series, dict):
        return None
    if "train_loss" not in series or "val_loss" not in series:
        return None

    train_acc_key, val_acc_key = _pick_accuracy_keys(series)
    if train_acc_key is None and val_acc_key is None:
        return None

    try:
        import matplotlib.pyplot as plt
    except Exception as err:
        print(f"[retrain] Graph generation skipped (matplotlib unavailable): {err}")
        return None

    graph_dir = Path(__file__).resolve().parent / "graph"
    graph_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_path = graph_dir / f"epoch_loss_accuracy_{version_id}_{timestamp}.png"

    fig, ax_loss = plt.subplots(figsize=(11, 6.5))
    x_train_loss, y_train_loss = _trim_xy(epochs, series.get("train_loss", []))
    x_val_loss, y_val_loss = _trim_xy(epochs, series.get("val_loss", []))
    ax_loss.plot(x_train_loss, y_train_loss, color="#1f77b4", label="Train Loss", linewidth=2)
    ax_loss.plot(x_val_loss, y_val_loss, color="#ff7f0e", label="Val Loss", linewidth=2)
    ax_loss.set_xlabel("Epoch")
    ax_loss.set_ylabel("Loss")
    ax_loss.grid(True, alpha=0.3)

    ax_acc = ax_loss.twinx()
    if train_acc_key is not None:
        x_train_acc, y_train_acc = _trim_xy(epochs, series.get(train_acc_key, []))
        ax_acc.plot(
            x_train_acc,
            y_train_acc,
            color="#2ca02c",
            label="Train Accuracy",
            linestyle="--",
            linewidth=2,
        )
    if val_acc_key is not None:
        x_val_acc, y_val_acc = _trim_xy(epochs, series.get(val_acc_key, []))
        ax_acc.plot(
            x_val_acc,
            y_val_acc,
            color="#d62728",
            label="Val Accuracy",
            linestyle="--",
            linewidth=2,
        )
    ax_acc.set_ylabel("Accuracy")
    ax_acc.set_ylim(0.0, 1.05)

    lines_1, labels_1 = ax_loss.get_legend_handles_labels()
    lines_2, labels_2 = ax_acc.get_legend_handles_labels()
    ax_loss.legend(lines_1 + lines_2, labels_1 + labels_2, loc="best")
    plt.title(f"Epoch vs Train/Val Loss and Accuracy ({version_id})")
    plt.tight_layout()
    plt.savefig(output_path, dpi=160)
    plt.close(fig)
    return str(output_path)


# =============================================================================
# Base Model Loading (Transfer Learning)
# =============================================================================

def load_base_model(
    device: str,
    architecture: Optional[str] = None
) -> Tuple[nn.Module, Optional[str], str]:
    """
    Load the base model for transfer learning.

    Priority:
    1. Base checkpoint from AL_BASE_MODELS config (when AL_FORCE_BASE_MODEL_ONLY=true)
    2. Current production model from registry (when base-only mode disabled)
    3. Fresh ImageNet-pretrained model (fallback)

    Args:
        device: Device to load model onto
        architecture: Optional architecture override (uses default if None)

    Returns:
        Tuple of (model, base_version_id, architecture)
    """
    target_arch = normalize_architecture_name(architecture)
    num_classes = len(config.LABEL_MAP)

    # Try base checkpoint for the target architecture
    base_path = config.AL_BASE_MODELS.get(target_arch)
    if base_path and os.path.exists(base_path):
        try:
            model, detected_arch = load_checkpoint(base_path, device, target_arch)
            print(f"[retrain] Loaded base checkpoint: {base_path} ({detected_arch})")
            return model, "base", detected_arch
        except Exception as e:
            print(f"[retrain] Failed to load base checkpoint: {e}")

    # Try to load production model from registry when base-only mode is disabled.
    if not config.AL_FORCE_BASE_MODEL_ONLY:
        prod_model = model_registry.get_production_model()
        if prod_model:
            prod_path = prod_model.get("production_path") or prod_model.get("path")
            prod_arch = prod_model.get("architecture", target_arch)

            if prod_path and os.path.exists(prod_path):
                try:
                    model, detected_arch = load_checkpoint(prod_path, device, prod_arch)
                    print(f"[retrain] Loaded production model: {prod_model['version_id']} ({detected_arch})")
                    return model, prod_model["version_id"], detected_arch
                except Exception as e:
                    print(f"[retrain] Failed to load production model: {e}")

    # Fallback: fresh ImageNet-pretrained model
    print(f"[retrain] Using fresh ImageNet-pretrained {target_arch}")
    model = create_model_with_pretrained_weights(target_arch, num_classes)
    return model, None, target_arch


def _split_samples_for_training(samples: List[Tuple[str, int]]) -> Tuple[List[Tuple[str, int]], List[Tuple[str, int]]]:
    """Deterministic stratified train/val split controlled by config."""
    if not samples:
        return [], []
    ratio = max(0.1, min(0.95, float(config.AL_SPLIT_TRAIN_RATIO)))
    rng = random.Random(config.AL_SPLIT_SEED)
    by_label: Dict[int, List[Tuple[str, int]]] = defaultdict(list)
    for sample in samples:
        by_label[sample[1]].append(sample)

    train_samples: List[Tuple[str, int]] = []
    val_samples: List[Tuple[str, int]] = []

    for label in sorted(by_label.keys()):
        class_samples = list(by_label[label])
        rng.shuffle(class_samples)
        class_count = len(class_samples)

        if class_count <= 1:
            # Single-sample classes cannot be represented in both splits.
            train_samples.extend(class_samples)
            continue

        class_train_size = int(class_count * ratio)
        class_train_size = max(1, min(class_train_size, class_count - 1))
        train_samples.extend(class_samples[:class_train_size])
        val_samples.extend(class_samples[class_train_size:])

    # Keep at least one sample in validation when possible.
    if not val_samples and len(train_samples) > 1:
        moved = train_samples.pop()
        val_samples.append(moved)

    rng.shuffle(train_samples)
    rng.shuffle(val_samples)
    return train_samples, val_samples


def _build_replay_summary_placeholder() -> Dict[str, Any]:
    return {
        "enabled": config.AL_EXPERIENCE_REPLAY_ENABLED,
        "old_samples_total": 0,
        "old_samples_selected": 0,
        "quota": 0,
        "herding_selected": 0,
        "random_selected": 0,
    }


def _build_yolo_classify_dataset(
    samples: List[Tuple[str, int]],
    dataset_root: str,
) -> Tuple[List[Tuple[str, int]], List[Tuple[str, int]], Dict[str, int]]:
    """
    Build YOLO classification dataset structure:
    dataset_root/train/<class_name>/*.jpg
    dataset_root/val/<class_name>/*.jpg
    """
    train_samples, val_samples = _split_samples_for_training(samples)
    class_counts: Dict[str, int] = defaultdict(int)

    for split_name, split_samples in (("train", train_samples), ("val", val_samples)):
        for idx, (src_path, label_idx) in enumerate(split_samples):
            class_name = config.REVERSE_LABEL_MAP.get(label_idx)
            if not class_name:
                continue
            class_dir = os.path.join(dataset_root, split_name, class_name)
            os.makedirs(class_dir, exist_ok=True)

            src_name = os.path.basename(src_path)
            dst_name = f"{idx:08d}_{src_name}"
            dst_path = os.path.join(class_dir, dst_name)
            shutil.copy2(src_path, dst_path)
            class_counts[class_name] += 1

    return train_samples, val_samples, dict(class_counts)


def _parse_yolo_results_csv(results_csv_path: str) -> List[Dict[str, Any]]:
    """Parse ultralytics results.csv into epoch logs."""
    if not os.path.exists(results_csv_path):
        return []

    parsed: List[Dict[str, Any]] = []
    with open(results_csv_path, "r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            epoch_raw = row.get("epoch")
            try:
                epoch = int(float(epoch_raw)) + 1
            except (TypeError, ValueError):
                epoch = len(parsed) + 1

            clean_row: Dict[str, Any] = {"epoch": epoch}
            for key, value in row.items():
                if key is None or key == "epoch":
                    continue
                if value is None or value == "":
                    clean_row[key] = None
                    continue
                try:
                    clean_row[key] = float(value)
                except (TypeError, ValueError):
                    clean_row[key] = value
            parsed.append(clean_row)

    return parsed


def _extract_yolo_accuracy(training_log: List[Dict[str, Any]]) -> Tuple[float, float]:
    """Return (last_acc, best_acc) from parsed YOLO logs."""
    if not training_log:
        return 0.0, 0.0
    keys_priority = (
        "metrics/accuracy_top1",
        "metrics/top1",
        "metrics/acc_top1",
    )
    values: List[float] = []
    for row in training_log:
        for key in keys_priority:
            val = row.get(key)
            if isinstance(val, (int, float)):
                values.append(float(val))
                break
    if not values:
        return 0.0, 0.0
    return values[-1], max(values)


def _train_yolo_classifier(
    version_dir: str,
    samples: List[Tuple[str, int]],
    training_cfg: Dict[str, Any],
) -> Dict[str, Any]:
    """Run YOLO classify training and return unified retrain payload fields."""
    YOLO = _get_ultralytics_yolo()
    if YOLO is None:
        raise RuntimeError("Missing 'ultralytics' package")

    dataset_root = os.path.join(version_dir, config.AL_YOLO_DATASET_DIRNAME)
    train_samples, val_samples, class_counts = _build_yolo_classify_dataset(samples, dataset_root)
    if not train_samples or not val_samples:
        raise RuntimeError("YOLO dataset split failed (need at least 1 train and 1 val sample)")

    base_path = config.AL_BASE_MODELS.get(config.ModelArchitecture.YOLO)
    if base_path and os.path.exists(base_path):
        yolo_weights = base_path
        base_model_id = "base"
    else:
        yolo_weights = config.AL_YOLO_PRETRAINED_WEIGHTS
        base_model_id = None

    epochs = int(training_cfg.get("epochs", 10))
    batch_size = int(training_cfg.get("batch_size", 16))
    learning_rate = float(training_cfg.get("learning_rate", 1e-3))
    imgsz = int(config.AL_YOLO_IMG_SIZE)

    model = YOLO(yolo_weights)
    run_results = model.train(
        data=dataset_root,
        task=config.AL_YOLO_TASK,
        epochs=epochs,
        batch=batch_size,
        lr0=learning_rate,
        imgsz=imgsz,
        workers=max(0, int(config.AL_YOLO_WORKERS)),
        patience=max(0, int(config.AL_YOLO_PATIENCE)),
        save_period=int(config.AL_YOLO_SAVE_PERIOD),
        project=version_dir,
        name=config.AL_YOLO_RUN_NAME,
        exist_ok=True,
        seed=int(config.AL_SPLIT_SEED),
    )

    run_dir = os.path.join(version_dir, config.AL_YOLO_RUN_NAME)
    best_ckpt = os.path.join(run_dir, "weights", "best.pt")
    if not os.path.exists(best_ckpt):
        raise RuntimeError(f"YOLO training finished without best checkpoint: {best_ckpt}")

    date_str = datetime.now().strftime("%Y-%m-%d")
    output_path = os.path.join(version_dir, f"[{date_str}] - {config.ModelArchitecture.YOLO}.pt")
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    shutil.copy2(best_ckpt, output_path)

    training_log = _parse_yolo_results_csv(os.path.join(run_dir, "results.csv"))
    log_path = os.path.join(os.path.dirname(output_path), config.AL_TRAINING_LOG_FILENAME)
    with open(log_path, "w", encoding="utf-8") as f:
        json.dump(training_log, f, indent=2)

    last_acc, best_acc = _extract_yolo_accuracy(training_log)
    metrics = {
        "train_accuracy": last_acc,
        "val_accuracy": best_acc,
        "samples_used": len(samples),
        "epochs_completed": len(training_log) if training_log else epochs,
        "training_log_file": config.AL_TRAINING_LOG_FILENAME,
        "yolo_task": config.AL_YOLO_TASK,
        "yolo_run_dir": run_dir,
        "yolo_dataset_dir": dataset_root,
        "yolo_class_counts": class_counts,
        "train_samples": len(train_samples),
        "val_samples": len(val_samples),
        "base_weights": yolo_weights,
    }

    return {
        "path": output_path,
        "metrics": metrics,
        "training_log": training_log,
        "base_model": base_model_id,
        "architecture": config.ModelArchitecture.YOLO,
    }


# =============================================================================
# Main Retraining Function
# =============================================================================

def retrain_model(
    output_path: Optional[str] = None,
    training_cfg: Optional[Dict[str, Any]] = None,
    architecture: Optional[str] = None
) -> Dict[str, Any]:
    """
    Retrain the model using transfer learning.

    Args:
        output_path: Optional override for output model path
        training_cfg: Optional override for training config
        architecture: Optional architecture override

    Returns:
        Dict with keys: version_id, metrics, samples_used, path, success, architecture
    """
    is_arch_valid, normalized_arch, arch_error = validate_retrain_architecture(architecture)
    if not is_arch_valid:
        return {
            "version_id": None,
            "success": False,
            "error": arch_error,
            "architecture": normalized_arch,
        }

    architecture = normalized_arch

    # Generate version ID
    version_id = model_registry.generate_version_id()

    # Load training configuration
    if training_cfg is None:
        training_cfg = tc.load_config()

    # Allow config.py to override training defaults (no hardcode)
    if config.RETRAIN_DEFAULT_EPOCHS > 0:
        training_cfg["epochs"] = config.RETRAIN_DEFAULT_EPOCHS
    if config.RETRAIN_DEFAULT_BATCH_SIZE > 0:
        training_cfg["batch_size"] = config.RETRAIN_DEFAULT_BATCH_SIZE

    epochs = training_cfg.get("epochs", 10)
    batch_size = training_cfg.get("batch_size", 16)
    learning_rate = training_cfg.get("learning_rate", 1e-4)
    optimizer_name = training_cfg.get("optimizer", "Adam")
    dropout = training_cfg.get("dropout", 0.3)
    augment = training_cfg.get("augmentation_applied", True)

    # Collect new labeled samples (replay data is added later)
    new_samples = collect_labeled_samples()
    if not new_samples:
        new_samples = collect_legacy_labeled_cases()

    if len(new_samples) < config.RETRAIN_MIN_NEW_LABELS:
        return {
            "version_id": version_id,
            "success": False,
            "error": f"Not enough new samples: {len(new_samples)} < {config.RETRAIN_MIN_NEW_LABELS}",
            "samples_used": len(new_samples),
            "new_samples": len(new_samples),
        }

    # Determine output directory early so registry can track this training run
    version_dir = os.path.join(config.AL_CANDIDATES_DIR, version_id)
    if output_path is None:
        output_path = os.path.join(version_dir, "pending.pt")

    # Register model as training and log training start
    model_registry.register_model(
        version_id=version_id,
        base_model=None,
        training_config=training_cfg,
        path=output_path,
        status=model_registry.ModelStatus.TRAINING
    )
    event_log.log_training_started(version_id, training_cfg)

    # Set up device
    # Select device based on config preference
    if config.RETRAIN_DEVICE == "cuda":
        device = "cuda" if torch.cuda.is_available() else "cpu"
    elif config.RETRAIN_DEVICE == "cpu":
        device = "cpu"
    else:
        device = "cuda" if torch.cuda.is_available() else "cpu"

    try:
        replay_samples: List[Tuple[str, int]] = []
        replay_summary: Dict[str, Any] = _build_replay_summary_placeholder()
        completion_acc = 0.0
        graph_path: Optional[str] = None

        if architecture == config.ModelArchitecture.YOLO:
            # Use a lightweight torch backbone for replay herding features.
            feature_model, _, feature_arch = load_base_model(device, config.ModelArchitecture.MOBILENET_V3_LARGE)
            feature_model.to(device)
            if config.AL_EXPERIENCE_REPLAY_ENABLED:
                old_samples = collect_old_dataset_samples()
                replay_samples, replay_summary = select_replay_samples(
                    old_samples=old_samples,
                    model=feature_model,
                    arch=feature_arch,
                    device=device,
                )

            samples = list(new_samples) + replay_samples
            rng = random.Random(config.AL_REPLAY_RANDOM_SEED)
            rng.shuffle(samples)

            yolo_result = _train_yolo_classifier(
                version_dir=version_dir,
                samples=samples,
                training_cfg=training_cfg,
            )
            output_path = yolo_result["path"]
            base_model_id = yolo_result.get("base_model")
            arch = yolo_result["architecture"]
            metrics = yolo_result["metrics"]
            metrics["new_samples_used"] = len(new_samples)
            metrics["replay_samples_used"] = len(replay_samples)
            metrics["experience_replay"] = replay_summary
            completion_acc = float(metrics.get("val_accuracy", 0.0) or 0.0)

        else:
            # Load base model for transfer learning
            model, base_model_id, arch = load_base_model(device, architecture)
            model.to(device)

            if config.AL_EXPERIENCE_REPLAY_ENABLED:
                old_samples = collect_old_dataset_samples()
                replay_samples, replay_summary = select_replay_samples(
                    old_samples=old_samples,
                    model=model,
                    arch=arch,
                    device=device,
                )

            samples = list(new_samples) + replay_samples
            rng = random.Random(config.AL_REPLAY_RANDOM_SEED)
            rng.shuffle(samples)
            train_samples, val_samples = _split_samples_for_training(samples)

            train_dataset = LabeledDataset(train_samples, augment=augment)
            val_dataset = LabeledDataset(val_samples, augment=False)

            train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
            val_loader = DataLoader(val_dataset, batch_size=batch_size, shuffle=False)

            # Set up optimizer
            optimizer_cls = tc.get_optimizer_class(optimizer_name)
            optimizer = optimizer_cls(model.parameters(), lr=learning_rate)
            loss_fn = nn.CrossEntropyLoss()

            # Training loop
            best_val_acc = 0.0
            best_val_loss = float("inf")
            training_log = []

            for epoch in range(epochs):
                epoch_started_at = datetime.now().isoformat()
                epoch_start_time = time.perf_counter()
                # Training phase
                model.train()
                train_loss, train_correct, train_total, train_batches = 0.0, 0, 0, 0

                for x, y in train_loader:
                    x, y = x.to(device), y.to(device)
                    optimizer.zero_grad()
                    out = model(x)
                    loss = loss_fn(out, y)
                    loss.backward()
                    optimizer.step()

                    train_loss += loss.item()
                    train_correct += (out.argmax(1) == y).sum().item()
                    train_total += y.size(0)
                    train_batches += 1

                train_acc = train_correct / train_total if train_total > 0 else 0
                train_loss_avg = train_loss / train_batches if train_batches > 0 else 0

                # Validation phase
                model.train(False)  # Set to inference mode
                val_correct, val_total, val_loss, val_batches = 0, 0, 0.0, 0

                with torch.no_grad():
                    for x, y in val_loader:
                        x, y = x.to(device), y.to(device)
                        out = model(x)
                        loss = loss_fn(out, y)
                        val_loss += loss.item()
                        val_correct += (out.argmax(1) == y).sum().item()
                        val_total += y.size(0)
                        val_batches += 1

                val_acc = val_correct / val_total if val_total > 0 else 0
                val_loss_avg = val_loss / val_batches if val_batches > 0 else 0
                best_val_acc = max(best_val_acc, val_acc)
                best_val_loss = min(best_val_loss, val_loss_avg)
                epoch_seconds = time.perf_counter() - epoch_start_time
                current_lr = optimizer.param_groups[0]["lr"] if optimizer.param_groups else learning_rate

                epoch_log = {
                    "epoch": epoch + 1,
                    "epoch_started_at": epoch_started_at,
                    "epoch_finished_at": datetime.now().isoformat(),
                    "epoch_seconds": epoch_seconds,
                    "train_loss": train_loss_avg,
                    "train_accuracy": train_acc,
                    "val_loss": val_loss_avg,
                    "val_accuracy": val_acc,
                    "learning_rate": current_lr,
                    "train_samples": train_total,
                    "val_samples": val_total,
                }
                training_log.append(epoch_log)
                print(
                    f"Epoch {epoch + 1}: train_loss={train_loss_avg:.4f} "
                    f"train_acc={train_acc:.2%} val_loss={val_loss_avg:.4f} val_acc={val_acc:.2%}"
                )

            # Determine output file name based on date and model architecture
            date_str = datetime.now().strftime("%Y-%m-%d")
            model_name = arch or "model"
            output_path = os.path.join(version_dir, f"[{date_str}] - {model_name}.pt")

            # Ensure output directory exists
            os.makedirs(os.path.dirname(output_path), exist_ok=True)

            # Save model with architecture metadata
            torch.save({
                "model_state_dict": model.state_dict(),
                "architecture": arch
            }, output_path)

            # Save training log
            log_path = os.path.join(os.path.dirname(output_path), config.AL_TRAINING_LOG_FILENAME)
            with open(log_path, "w") as f:
                json.dump(training_log, f, indent=2)

            # Calculate metrics
            metrics = {
                "train_accuracy": training_log[-1]["train_accuracy"] if training_log else 0,
                "val_accuracy": best_val_acc,
                "train_loss": training_log[-1]["train_loss"] if training_log else 0,
                "val_loss": training_log[-1]["val_loss"] if training_log else 0,
                "best_val_loss": best_val_loss if best_val_loss != float("inf") else 0,
                "samples_used": len(samples),
                "new_samples_used": len(new_samples),
                "replay_samples_used": len(replay_samples),
                "epochs_completed": epochs,
                "training_log_file": config.AL_TRAINING_LOG_FILENAME,
                "experience_replay": replay_summary,
            }
            completion_acc = best_val_acc

        # Update registry with final details and metrics
        registry = model_registry._load_registry()
        if version_id in registry["models"]:
            registry["models"][version_id]["base_model"] = base_model_id
            registry["models"][version_id]["training_config"] = training_cfg
            registry["models"][version_id]["path"] = output_path
            registry["models"][version_id]["architecture"] = arch
            registry["models"][version_id]["metrics"] = metrics
            registry["models"][version_id]["status"] = model_registry.ModelStatus.EVALUATING
            model_registry._save_registry(registry)
        else:
            model_registry.register_model(
                version_id=version_id,
                base_model=base_model_id,
                training_config=training_cfg,
                path=output_path,
                status=model_registry.ModelStatus.EVALUATING
            )
            model_registry.update_model_metrics(version_id, metrics)

        # Ensure status is not left as training
        model_registry.update_model_status(version_id, model_registry.ModelStatus.EVALUATING)

        # Mark labels as used
        case_ids = [item["case_id"] for item in labels_pool.get_labels_for_training()]
        if case_ids:
            labels_pool.mark_labels_used(version_id, case_ids)

        # Log completion
        event_log.log_training_completed(version_id, completion_acc, len(samples))
        try:
            graph_path = _generate_training_graph(version_id)
            if graph_path:
                print(f"[retrain] Training graph saved: {graph_path}")
        except Exception as graph_err:
            print(f"[retrain] Training graph generation failed: {graph_err}")

        print(f"Model saved to {output_path} (architecture: {arch})")

        return {
            "version_id": version_id,
            "success": True,
            "metrics": metrics,
            "samples_used": len(samples),
            "new_samples": len(new_samples),
            "replay_samples": len(replay_samples),
            "experience_replay": replay_summary,
            "path": output_path,
            "base_model": base_model_id,
            "architecture": arch,
            "graph_path": graph_path,
        }

    except Exception as e:
        event_log.log_training_failed(version_id, str(e))
        model_registry.update_model_status(version_id, model_registry.ModelStatus.FAILED)

        return {
            "version_id": version_id,
            "success": False,
            "error": str(e),
            "samples_used": len(new_samples),
            "new_samples": len(new_samples),
        }


# =============================================================================
# Status Functions
# =============================================================================

def get_retrain_status() -> Dict[str, Any]:
    """Get the current retraining status."""
    training_models = model_registry.list_models(status=model_registry.ModelStatus.TRAINING)
    if training_models:
        return {
            "status": "training",
            "version_id": training_models[0]["version_id"],
            "started_at": training_models[0].get("created_at")
        }

    recent_events = event_log.get_events_by_type(event_log.EventType.TRAINING_COMPLETED, limit=1)
    if recent_events:
        event = recent_events[0]
        return {
            "status": "idle",
            "last_retrain": event["timestamp"],
            "last_version": event["metadata"].get("version_id"),
            "last_accuracy": event["metadata"].get("accuracy")
        }

    return {"status": "not_started", "last_retrain": None}


def check_retrain_threshold() -> Tuple[bool, int, int]:
    """Check if enough new labels exist to trigger retraining."""
    current = labels_pool.get_unused_label_count()
    threshold = config.RETRAIN_MIN_NEW_LABELS
    return current >= threshold, current, threshold
