"""
Model Retraining Module for Active Learning System.

Supports multiple architectures (EfficientNetV2-M, ResNet50) with transfer learning
from the current production model or base checkpoints.
"""

import os
import json
from pathlib import Path
from typing import Dict, Any, Optional, Tuple, List

import torch
import torch.nn as nn
from torch.utils.data import DataLoader, Dataset
from torchvision import models, transforms
from PIL import Image

from . import config
from . import model_registry
from . import training_config as tc
from . import labels_pool
from . import event_log


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
    key_str = " ".join(keys[:20])  # Check first 20 keys

    # EfficientNetV2 has 'features.0.0.block' pattern
    if any("features.0.0" in k for k in keys):
        return config.ModelArchitecture.EFFICIENTNET_V2_M

    # ResNet has 'layer1', 'layer2', etc.
    if any("layer1" in k for k in keys):
        return config.ModelArchitecture.RESNET50

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
    1. Current production model from registry
    2. Base checkpoint from AL_BASE_MODELS config
    3. Fresh ImageNet-pretrained model (fallback)

    Args:
        device: Device to load model onto
        architecture: Optional architecture override (uses default if None)

    Returns:
        Tuple of (model, base_version_id, architecture)
    """
    target_arch = architecture or config.AL_DEFAULT_ARCHITECTURE
    num_classes = len(config.LABEL_MAP)

    # Try to load production model from registry
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

    # Try base checkpoint for the target architecture
    base_path = config.AL_BASE_MODELS.get(target_arch)
    if base_path and os.path.exists(base_path):
        try:
            model, detected_arch = load_checkpoint(base_path, device, target_arch)
            print(f"[retrain] Loaded base checkpoint: {base_path} ({detected_arch})")
            return model, "base", detected_arch
        except Exception as e:
            print(f"[retrain] Failed to load base checkpoint: {e}")

    # Fallback: fresh ImageNet-pretrained model
    print(f"[retrain] Using fresh ImageNet-pretrained {target_arch}")
    model = create_model_with_pretrained_weights(target_arch, num_classes)
    return model, None, target_arch


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
    # Generate version ID
    version_id = model_registry.generate_version_id()

    # Load training configuration
    if training_cfg is None:
        training_cfg = tc.load_config()

    epochs = training_cfg.get("epochs", 10)
    batch_size = training_cfg.get("batch_size", 16)
    learning_rate = training_cfg.get("learning_rate", 1e-4)
    optimizer_name = training_cfg.get("optimizer", "Adam")
    dropout = training_cfg.get("dropout", 0.3)
    augment = training_cfg.get("augmentation_applied", True)

    # Collect samples
    samples = collect_labeled_samples()
    if not samples:
        samples = collect_legacy_labeled_cases()

    if len(samples) < config.RETRAIN_MIN_NEW_LABELS:
        return {
            "version_id": version_id,
            "success": False,
            "error": f"Not enough samples: {len(samples)} < {config.RETRAIN_MIN_NEW_LABELS}",
            "samples_used": len(samples)
        }

    # Log training start
    event_log.log_training_started(version_id, training_cfg)

    # Set up device
    device = "cuda" if torch.cuda.is_available() else "cpu"

    try:
        # Load base model for transfer learning
        model, base_model_id, arch = load_base_model(device, architecture)
        model.to(device)

        # Split data: 80% train, 20% validation
        train_size = int(0.8 * len(samples))
        train_dataset = LabeledDataset(samples[:train_size], augment=augment)
        val_dataset = LabeledDataset(samples[train_size:], augment=False)

        train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
        val_loader = DataLoader(val_dataset, batch_size=batch_size, shuffle=False)

        # Set up optimizer
        optimizer_cls = tc.get_optimizer_class(optimizer_name)
        optimizer = optimizer_cls(model.parameters(), lr=learning_rate)
        loss_fn = nn.CrossEntropyLoss()

        # Training loop
        best_val_acc = 0.0
        training_log = []

        for epoch in range(epochs):
            # Training phase
            model.train()
            train_loss, train_correct, train_total = 0.0, 0, 0

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

            train_acc = train_correct / train_total if train_total > 0 else 0

            # Validation phase
            model.train(False)  # Set to inference mode
            val_correct, val_total = 0, 0

            with torch.no_grad():
                for x, y in val_loader:
                    x, y = x.to(device), y.to(device)
                    out = model(x)
                    val_correct += (out.argmax(1) == y).sum().item()
                    val_total += y.size(0)

            val_acc = val_correct / val_total if val_total > 0 else 0
            best_val_acc = max(best_val_acc, val_acc)

            epoch_log = {
                "epoch": epoch + 1,
                "train_loss": train_loss,
                "train_accuracy": train_acc,
                "val_accuracy": val_acc
            }
            training_log.append(epoch_log)
            print(f"Epoch {epoch + 1}: loss={train_loss:.4f} train_acc={train_acc:.2%} val_acc={val_acc:.2%}")

        # Determine output path
        if output_path is None:
            version_dir = os.path.join(config.AL_CANDIDATES_DIR, version_id)
            os.makedirs(version_dir, exist_ok=True)
            output_path = os.path.join(version_dir, "model.pt")

        # Save model with architecture metadata
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        torch.save({
            "model_state_dict": model.state_dict(),
            "architecture": arch
        }, output_path)

        # Save training log
        log_path = os.path.join(os.path.dirname(output_path), "training_log.json")
        with open(log_path, "w") as f:
            json.dump(training_log, f, indent=2)

        # Calculate metrics
        metrics = {
            "train_accuracy": training_log[-1]["train_accuracy"] if training_log else 0,
            "val_accuracy": best_val_acc,
            "samples_used": len(samples),
            "epochs_completed": epochs
        }

        # Register model in registry (include architecture)
        model_entry = model_registry.register_model(
            version_id=version_id,
            base_model=base_model_id,
            training_config=training_cfg,
            path=output_path,
            status=model_registry.ModelStatus.EVALUATING
        )
        model_registry.update_model_metrics(version_id, metrics)

        # Update registry with architecture info
        registry = model_registry._load_registry()
        if version_id in registry["models"]:
            registry["models"][version_id]["architecture"] = arch
            model_registry._save_registry(registry)

        # Mark labels as used
        case_ids = [item["case_id"] for item in labels_pool.get_labels_for_training()]
        if case_ids:
            labels_pool.mark_labels_used(version_id, case_ids)

        # Log completion
        event_log.log_training_completed(version_id, best_val_acc, len(samples))

        print(f"Model saved to {output_path} (architecture: {arch})")

        return {
            "version_id": version_id,
            "success": True,
            "metrics": metrics,
            "samples_used": len(samples),
            "path": output_path,
            "base_model": base_model_id,
            "architecture": arch
        }

    except Exception as e:
        event_log.log_training_failed(version_id, str(e))
        model_registry.update_model_status(version_id, model_registry.ModelStatus.FAILED)

        return {
            "version_id": version_id,
            "success": False,
            "error": str(e),
            "samples_used": len(samples)
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
