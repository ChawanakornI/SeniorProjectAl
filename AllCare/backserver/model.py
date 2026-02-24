import os
import zipfile
from typing import List, Dict, Any

import numpy as np
from PIL import Image

from . import config

try:
    # Encourage deterministic CUDA behavior when possible.
    if "CUBLAS_WORKSPACE_CONFIG" not in os.environ:
        os.environ["CUBLAS_WORKSPACE_CONFIG"] = ":4096:8"

    import torch  # type: ignore
    import torch.nn as nn  # type: ignore
    from torchvision import models  # type: ignore

    # # Make inference deterministic/reproducible
    # torch.manual_seed(0)
    # np.random.seed(0)
    # torch.set_num_threads(1)
    # # cuDNN/cuda knobs for determinism
    # try:
    #     torch.backends.cudnn.deterministic = True  # type: ignore[attr-defined]
    #     torch.backends.cudnn.benchmark = False  # type: ignore[attr-defined]
    # except Exception:
    #     pass
#     try:
#         torch.backends.cuda.matmul.allow_tf32 = False  # type: ignore[attr-defined]
#         torch.backends.cudnn.allow_tf32 = False  # type: ignore[attr-defined]
#     except Exception:
#         pass
#     try:
#         torch.set_num_interop_threads(1)
#     except Exception:
#         pass
#     # Full determinism can be opt-in; avoid hard failure on unsupported ops.
#     try:
#         torch.use_deterministic_algorithms(False)
#         # print("[model] Deterministic algorithms enabled successfully")
#         print("disable deterministic algo successfully")
#     except Exception as e:
#         print(f"[model] Warning: Could not enable deterministic algorithms: {e}")
#         print("[model] Falling back to standard algorithms - some operations may be non-deterministic")
except ImportError:
    torch = None
    nn = None
    models = None


class ModelService:
    def __init__(self, model_path: str | None = None, conf_threshold: float = 0.5, source: str = "model"):
        self.model_path = model_path or getattr(config, "MODEL_PATH", "")
        self.conf_threshold = conf_threshold
        self.model = None
        self.device = self._select_device()
        # HAM10000 label order
        self.class_names = [
            "akiec",
            "bcc",
            "bkl",
            "df",
            "mel",
            "nv",
            "vasc",
        ]
        self._load(source=source)

    def _is_torchscript_archive(self, path: str) -> bool:
        """Check if the file is a TorchScript archive (zip with constants.pkl)."""
        try:
            if not zipfile.is_zipfile(path):
                return False
            with zipfile.ZipFile(path, "r") as zf:
                # TorchScript archives can store constants under a prefixed folder
                # (e.g. "archive/constants.pkl"), not only at zip root.
                return any(name.endswith("constants.pkl") for name in zf.namelist())
        except Exception:
            return False

    def _load(self, source: str = "model"):
        if torch is None or nn is None or models is None:
            print(f"[{source}] torch/torchvision not installed; running in dummy mode.")
            return
        if not self.model_path or not os.path.isfile(self.model_path):
            print(f"[{source}] MODEL_PATH missing or not a file; running in dummy mode.")
            return

        # 1) Try torchscript only if file looks like a TorchScript archive
        if self._is_torchscript_archive(self.model_path):
            try:
                self.model = torch.jit.load(self.model_path, map_location=self.device)
                self.model.to(self.device).eval()
                print(f"[{source}] loaded torchscript model from {self.model_path}")
                return
            except Exception as exc:
                print(f"[{source}] torchscript load failed: {exc}")

        # 2) Try checkpoint with state_dict (ResNet50 or EfficientNetV2-M)
        try:
            checkpoint = torch.load(self.model_path, map_location=self.device, weights_only=False)
            state_dict = None
            architecture = None
            if isinstance(checkpoint, dict):
                state_dict = checkpoint.get("model_state_dict") or checkpoint.get("state_dict")
                architecture = checkpoint.get("architecture")
            if state_dict:
                if architecture is None:
                    architecture = self._detect_architecture_from_state_dict(state_dict)
                model = self._create_model(architecture)
                model.load_state_dict(state_dict)
                model.to(self.device).eval()
                
                # # Ensure deterministic behavior
                # if hasattr(model, 'apply'):
                #     model.apply(self._set_deterministic_flags)
                
                self.model = model
                arch_label = architecture or "unknown"
                print(f"[{source}] loaded {arch_label} checkpoint from {self.model_path}")
                return
            # If the loaded object is already a module, use it directly
            if hasattr(checkpoint, "eval") and callable(getattr(checkpoint, "eval")):
                checkpoint.to(self.device).eval()
                # if hasattr(checkpoint, 'apply'):
                #     checkpoint.apply(self._set_deterministic_flags)
                self.model = checkpoint
                print(f"[{source}] loaded torch model object from {self.model_path}")
                return
        except Exception as exc:
            print(f"[{source}] checkpoint load failed: {exc}")

        print(f"[{source}] unable to load model; running in dummy mode.")

    def _detect_architecture_from_state_dict(self, state_dict) -> str | None:
        keys = list(state_dict.keys())
        if any("features.0.0" in k for k in keys):
            return "efficientnet_v2_m"
        if any("layer1" in k for k in keys):
            return "resnet50"
        return None

    def _create_model(self, architecture: str | None):
        num_classes = len(self.class_names)
        arch = (architecture or "resnet50").lower()
        if arch == "efficientnet_v2_m":
            model = models.efficientnet_v2_m(weights=None)
            in_features = model.classifier[1].in_features
            model.classifier = nn.Sequential(
                nn.Dropout(p=0.3, inplace=True),
                nn.Linear(in_features, num_classes),
            )
            return model
        # Default to ResNet50
        model = models.resnet50(weights=None)
        in_features = model.fc.in_features
        model.fc = nn.Sequential(nn.Dropout(p=0.3), nn.Linear(in_features, num_classes))
        return model

    def set_model_path(self, model_path: str, source: str = "model") -> None:
        prev_model = self.model
        prev_path = self.model_path
        self.model_path = model_path
        self.model = None
        self._load(source=source)
        if self.model is None and prev_model is not None:
            print(f"[{source}] load failed; reverting to previous model.")
            self.model = prev_model
            self.model_path = prev_path

    # def _set_deterministic_flags(self, module):
    #     """
    #     Set flags to ensure deterministic behavior for all modules.
    #     This is especially important for dropout layers and other stochastic operations.
    #     """
    #     if isinstance(module, (nn.Dropout, nn.Dropout2d, nn.Dropout3d)):
    #         # Ensure dropout is disabled during inference
    #         module.train(False)
        
    #     # For other modules, ensure they're in eval mode
    #     if hasattr(module, 'train'):
    #         module.train(False)

    def _select_device(self) -> str:
        """
        Choose device with an optional override for determinism.
        Set MODEL_DEVICE=cpu for most consistent results.
        """
        # If torch is unavailable, stay on CPU (dummy mode)
        if torch is None:
            return "cpu"

        preferred = getattr(config, "MODEL_DEVICE", "").strip().lower()

        # Honor explicit override when possible
        if preferred in ("cpu", "cuda", "mps"):
            if preferred == "cuda" and torch.cuda.is_available():
                return "cuda"
            if preferred == "mps" and hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
                return "mps"
            if preferred == "cpu":
                return "cpu"
            # If the preferred device is unavailable, fall back to auto selection below.

        # Auto-select: prefer CUDA, then MPS, otherwise CPU
        if torch.cuda.is_available():
            return "cuda"
        if hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
            return "mps"
        return "cpu"

    def _preprocess(self, image: Image.Image) -> np.ndarray:
        """
        Match exact training preprocessing: resize to 256, center-crop 224,
        convert to tensor, normalize with ImageNet stats.
        Based on training code: build_eval_transform(image_size=224)
        """
        img = image.convert("RGB")

        # Match exact training transform: image_size=224, resize=224+32=256
        if models is not None and hasattr(models, "ResNet50_Weights"):
            # Use torchvision transforms but override to match training exactly
            try:
                # Manually build the exact transform from training code
                import torchvision.transforms as T
                preprocess = T.Compose([
                    T.Resize(256),  # image_size + 32 = 224 + 32 = 256
                    T.CenterCrop(224),  # image_size = 224
                    T.ToTensor(),
                    T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
                ])
                tensor = preprocess(img)  # shape: C,H,W float32
                return tensor.unsqueeze(0).cpu().numpy()
            except ImportError:
                pass

        # Fallback: manual pipeline matching training code exactly
        img = img.resize((256, 256))  # Resize to 256
        # Center crop 224x224
        left = (256 - 224) // 2
        top = (256 - 224) // 2
        right = left + 224
        bottom = top + 224
        img = img.crop((left, top, right, bottom))
        arr = np.array(img).astype("float32") / 255.0
        mean = np.array([0.485, 0.456, 0.406], dtype="float32")
        std = np.array([0.229, 0.224, 0.225], dtype="float32")
        arr = (arr - mean) / std
        arr = np.transpose(arr, (2, 0, 1))  # CHW
        return np.expand_dims(arr, axis=0)

    def predict(self, image: Image.Image) -> List[Dict[str, Any]]:
        # Dummy predictions when no model is loaded
        if torch is None or self.model is None:
            return [{"label": "unavailable", "confidence": 0.0}]

        input_tensor = self._preprocess(image)
        tensor = torch.from_numpy(input_tensor).to(self.device)
        with torch.no_grad():
            outputs = self.model(tensor)

        # Support tuple outputs
        if isinstance(outputs, (list, tuple)):
            outputs = outputs[0]

        logits = outputs.squeeze()
        if logits.ndim == 0:
            logits = torch.stack((1 - logits, logits))
        probs = torch.softmax(logits, dim=0).cpu().numpy()

        preds = []
        for i, p in enumerate(probs):
            preds.append({"label": self.class_names[i] if i < len(self.class_names) else f"class_{i}", "confidence": float(p)})
        preds = sorted(preds, key=lambda x: x["confidence"], reverse=True)
        return preds


# Singleton instance
model_service = ModelService(conf_threshold=config.CONF_THRESHOLD, source="normalClassifier")
