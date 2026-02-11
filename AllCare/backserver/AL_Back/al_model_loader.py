"""
AL Model Loader - Dedicated model loading for Active Learning system.

This module handles loading models from the AL registry, separate from
the main production inference in model.py. This isolation ensures:
1. AL experiments don't affect production inference
2. Easy testing of AL models independently
3. Clear separation between stable production and experimental AL
"""

import os
from typing import Dict, Any, Optional, List, Tuple

import numpy as np
from PIL import Image

# Import from parent package
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backserver import config
from backserver import model_registry

try:
    import torch
    import torch.nn as nn
    from torchvision import models, transforms
except ImportError:
    torch = None
    nn = None
    models = None
    transforms = None


def detect_architecture(state_dict: Dict[str, Any]) -> Optional[str]:
    """Detect model architecture from state_dict keys."""
    keys = list(state_dict.keys())

    if any("features.0.0" in k for k in keys):
        return config.ModelArchitecture.EFFICIENTNET_V2_M

    if any("layer1" in k for k in keys):
        return config.ModelArchitecture.RESNET50

    return None


def create_model_architecture(
    architecture: str,
    num_classes: int = 7,
    dropout: float = 0.3
) -> "nn.Module":
    """Create a model instance by architecture name."""
    if models is None:
        raise RuntimeError("PyTorch/torchvision not installed")

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


class ALModelLoader:
    """
    Model loader for Active Learning system.

    Loads models from the AL registry, supporting multiple architectures
    and providing inference capabilities for AL evaluation.
    """

    def __init__(self):
        self.model = None
        self.model_path = None
        self.version_id = None
        self.architecture = None
        self.device = self._select_device()
        self.class_names = list(config.LABEL_MAP.keys())

        # Preprocessing transform
        self._transform = None
        if transforms is not None:
            self._transform = transforms.Compose([
                transforms.Resize(256),
                transforms.CenterCrop(224),
                transforms.ToTensor(),
                transforms.Normalize(
                    mean=[0.485, 0.456, 0.406],
                    std=[0.229, 0.224, 0.225]
                )
            ])

    def _select_device(self) -> str:
        """Select the best available device."""
        if torch is None:
            return "cpu"

        if torch.cuda.is_available():
            return "cuda"
        if hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
            return "mps"
        return "cpu"

    def load_production_model(self) -> bool:
        """
        Load the current production model from the AL registry.

        Returns:
            True if loaded successfully, False otherwise
        """
        prod = model_registry.get_production_model()
        if not prod:
            print("[AL] No production model in registry")
            return False

        path = prod.get("production_path") or prod.get("path")
        arch = prod.get("architecture")

        return self.load_model(path, architecture=arch, version_id=prod.get("version_id"))

    def load_candidate_model(self, version_id: str) -> bool:
        """
        Load a candidate model by version ID.

        Args:
            version_id: The version ID of the candidate model

        Returns:
            True if loaded successfully, False otherwise
        """
        model_info = model_registry.get_model(version_id)
        if not model_info:
            print(f"[AL] Model {version_id} not found in registry")
            return False

        path = model_info.get("path")
        arch = model_info.get("architecture")

        return self.load_model(path, architecture=arch, version_id=version_id)

    def load_model(
        self,
        path: str,
        architecture: Optional[str] = None,
        version_id: Optional[str] = None
    ) -> bool:
        """
        Load a model from a checkpoint file.

        Args:
            path: Path to the model checkpoint
            architecture: Optional architecture hint
            version_id: Optional version ID for logging

        Returns:
            True if loaded successfully, False otherwise
        """
        if torch is None:
            print("[AL] PyTorch not installed")
            return False

        if not path or not os.path.isfile(path):
            print(f"[AL] Model file not found: {path}")
            return False

        try:
            checkpoint = torch.load(path, map_location=self.device, weights_only=False)

            # Extract state_dict and architecture hint
            if isinstance(checkpoint, dict):
                state_dict = checkpoint.get("model_state_dict") or checkpoint.get("state_dict") or checkpoint
                arch_from_file = checkpoint.get("architecture")
            else:
                state_dict = checkpoint
                arch_from_file = None

            # Determine architecture
            arch = architecture or arch_from_file or detect_architecture(state_dict)
            if not arch:
                print(f"[AL] Could not detect architecture for {path}")
                return False

            # Create and load model
            num_classes = len(self.class_names)
            model = create_model_architecture(arch, num_classes)
            model.load_state_dict(state_dict)
            model.to(self.device)
            model.train(False)  # Set to inference mode

            self.model = model
            self.model_path = path
            self.architecture = arch
            self.version_id = version_id

            print(f"[AL] Loaded {arch} model from {path}" +
                  (f" (version: {version_id})" if version_id else ""))
            return True

        except Exception as e:
            print(f"[AL] Failed to load model from {path}: {e}")
            return False

    def predict(self, image: Image.Image) -> List[Dict[str, Any]]:
        """
        Run prediction on an image.

        Args:
            image: PIL Image to classify

        Returns:
            List of predictions sorted by confidence
        """
        if self.model is None:
            return [{"label": "unavailable", "confidence": 0.0}]

        # Preprocess
        img = image.convert("RGB")
        if self._transform:
            tensor = self._transform(img).unsqueeze(0).to(self.device)
        else:
            # Fallback preprocessing
            tensor = self._manual_preprocess(img)

        # Inference
        with torch.no_grad():
            outputs = self.model(tensor)

        if isinstance(outputs, (list, tuple)):
            outputs = outputs[0]

        logits = outputs.squeeze()
        probs = torch.softmax(logits, dim=0).cpu().numpy()

        # Build predictions
        preds = []
        for i, p in enumerate(probs):
            label = self.class_names[i] if i < len(self.class_names) else f"class_{i}"
            preds.append({"label": label, "confidence": float(p)})

        return sorted(preds, key=lambda x: x["confidence"], reverse=True)

    def _manual_preprocess(self, img: Image.Image) -> "torch.Tensor":
        """Fallback preprocessing without torchvision transforms."""
        img = img.resize((256, 256))
        left = (256 - 224) // 2
        top = (256 - 224) // 2
        img = img.crop((left, top, left + 224, top + 224))

        arr = np.array(img).astype("float32") / 255.0
        mean = np.array([0.485, 0.456, 0.406], dtype="float32")
        std = np.array([0.229, 0.224, 0.225], dtype="float32")
        arr = (arr - mean) / std
        arr = np.transpose(arr, (2, 0, 1))

        return torch.from_numpy(arr).unsqueeze(0).to(self.device)

    def get_info(self) -> Dict[str, Any]:
        """Get information about the currently loaded model."""
        return {
            "loaded": self.model is not None,
            "model_path": self.model_path,
            "version_id": self.version_id,
            "architecture": self.architecture,
            "device": self.device,
            "class_names": self.class_names,
        }

    def unload(self) -> None:
        """Unload the current model to free memory."""
        self.model = None
        self.model_path = None
        self.version_id = None
        self.architecture = None
        if torch is not None:
            torch.cuda.empty_cache() if torch.cuda.is_available() else None


def compare_models(
    image: Image.Image,
    production_loader: ALModelLoader,
    candidate_loader: ALModelLoader
) -> Dict[str, Any]:
    """
    Compare predictions between production and candidate models.

    Args:
        image: Image to classify
        production_loader: Loader with production model
        candidate_loader: Loader with candidate model

    Returns:
        Comparison results
    """
    prod_preds = production_loader.predict(image)
    cand_preds = candidate_loader.predict(image)

    prod_top = prod_preds[0] if prod_preds else {"label": "none", "confidence": 0}
    cand_top = cand_preds[0] if cand_preds else {"label": "none", "confidence": 0}

    return {
        "production": {
            "version": production_loader.version_id,
            "top_prediction": prod_top,
            "all_predictions": prod_preds
        },
        "candidate": {
            "version": candidate_loader.version_id,
            "top_prediction": cand_top,
            "all_predictions": cand_preds
        },
        "agreement": prod_top["label"] == cand_top["label"],
        "confidence_diff": cand_top["confidence"] - prod_top["confidence"]
    }


# Convenience function for quick evaluation
def evaluate_model_on_image(version_id: str, image: Image.Image) -> Dict[str, Any]:
    """
    Quick evaluation of a specific model on an image.

    Args:
        version_id: Model version to evaluate
        image: Image to classify

    Returns:
        Prediction results with model info
    """
    loader = ALModelLoader()

    if version_id == "production":
        success = loader.load_production_model()
    else:
        success = loader.load_candidate_model(version_id)

    if not success:
        return {"error": f"Failed to load model {version_id}"}

    predictions = loader.predict(image)
    info = loader.get_info()

    loader.unload()

    return {
        "model_info": info,
        "predictions": predictions
    }
