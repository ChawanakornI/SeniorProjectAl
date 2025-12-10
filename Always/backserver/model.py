import os
import uuid
from typing import List, Dict, Any

import numpy as np
from PIL import Image
import onnxruntime as ort

from . import config


class ModelService:
    def __init__(self, model_path: str | None = None, conf_threshold: float = 0.5):
        self.model_path = model_path or config.MODEL_PATH
        self.conf_threshold = conf_threshold
        self.session = None
        self.input_name = None
        self.class_names = ["benign", "malignant"]  # placeholder; replace with real labels
        self._load()

    def _load(self):
        if not self.model_path or not os.path.isfile(self.model_path):
            # Run in dummy mode if model is missing
            return
        self.session = ort.InferenceSession(self.model_path, providers=["CPUExecutionProvider"])
        self.input_name = self.session.get_inputs()[0].name

    def _preprocess(self, image: Image.Image) -> np.ndarray:
        # Simple preprocessing: resize to 224x224 and normalize 0-1
        img = image.convert("RGB").resize((224, 224))
        arr = np.array(img).astype("float32") / 255.0
        arr = np.transpose(arr, (2, 0, 1))  # CHW
        return np.expand_dims(arr, axis=0)

    def predict(self, image: Image.Image) -> List[Dict[str, Any]]:
        # Dummy predictions when no model is loaded
        if self.session is None:
            return [
                {"label": "benign", "confidence": 0.55},
                {"label": "malignant", "confidence": 0.45},
            ]

        input_tensor = self._preprocess(image)
        outputs = self.session.run(None, {self.input_name: input_tensor})
        logits = outputs[0].squeeze()
        if logits.ndim == 0:
            logits = np.array([1 - float(logits), float(logits)])
        probs = self._softmax(logits)

        preds = []
        for i, p in enumerate(probs):
            preds.append({"label": self.class_names[i] if i < len(self.class_names) else f"class_{i}", "confidence": float(p)})
        preds = sorted(preds, key=lambda x: x["confidence"], reverse=True)
        preds = [p for p in preds if p["confidence"] >= self.conf_threshold] or preds[:1]
        return preds

    @staticmethod
    def _softmax(x: np.ndarray) -> np.ndarray:
        e_x = np.exp(x - np.max(x))
        return e_x / e_x.sum()


# Singleton instance
model_service = ModelService(conf_threshold=config.CONF_THRESHOLD)

