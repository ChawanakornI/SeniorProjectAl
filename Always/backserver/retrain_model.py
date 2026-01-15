import os
import json
import argparse
from pathlib import Path
import torch
import torch.nn as nn
from torch.utils.data import DataLoader, Dataset
from torchvision import models, transforms
from PIL import Image
from datetime import datetime

from . import config


class LabeledDataset(Dataset):
    def __init__(self, samples):
        self.samples = samples
        self.transform = transforms.Compose([
            transforms.Resize((224, 224)),
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


def collect_labeled_cases():
    results = []
    root = Path(config.STORAGE_ROOT)

    for user_dir in root.iterdir():
        meta = user_dir / config.METADATA_FILENAME
        if not meta.exists():
            continue

        with open(meta, "r") as f:
            for line in f:
                data = json.loads(line)
                if data.get("entry_type") == "reject" and "correct_label" in data and "image_paths" in data:
                    for p in data["image_paths"]:
                        img_path = user_dir / p
                        if img_path.exists():
                            results.append((str(img_path), data["correct_label"]))
    return results


def retrain_model(model_path, output_path, epochs=5, batch_size=16):
    samples = collect_labeled_cases()
    if len(samples) < 5:
        print("Not enough labeled samples")
        return False

    label_map = {"akiec":0,"bcc":1,"bkl":2,"df":3,"mel":4,"nv":5,"vasc":6}
    samples = [(p, label_map[l]) for p, l in samples]

    dataset = LabeledDataset(samples)
    loader = DataLoader(dataset, batch_size=batch_size, shuffle=True)

    device = "cuda" if torch.cuda.is_available() else "cpu"

    model = models.resnet50(weights=models.ResNet50_Weights.IMAGENET1K_V2)
    model.fc = nn.Sequential(
        nn.Dropout(0.3),
        nn.Linear(model.fc.in_features, 7)
    )
    model.to(device)

    optimizer = torch.optim.Adam(model.parameters(), lr=1e-4)
    loss_fn = nn.CrossEntropyLoss()

    for epoch in range(epochs):
        total, correct, loss_sum = 0, 0, 0.0
        for x, y in loader:
            x, y = x.to(device), y.to(device)
            optimizer.zero_grad()
            out = model(x)
            loss = loss_fn(out, y)
            loss.backward()
            optimizer.step()

            loss_sum += loss.item()
            correct += (out.argmax(1) == y).sum().item()
            total += y.size(0)

        print(f"Epoch {epoch+1}: loss={loss_sum:.4f} acc={correct/total:.2%}")

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    torch.save({"model_state_dict": model.state_dict()}, output_path)
    print("Model saved to", output_path)




def get_retrain_status():
    status_file = Path("model_retrain_status.json")
    if not status_file.exists():
        return {
            "status": "not_started",
            "last_retrain": None
        }

    try:
        with open(status_file, "r") as f:
            return json.load(f)
    except Exception:
        return {
            "status": "error",
            "message": "Failed to read retrain status"
        }
