#!/usr/bin/env python3
"""
Export a PyTorch checkpoint to TorchScript for use by the backserver.

Why: `backserver/model.py` can load a TorchScript archive via `torch.jit.load(...)`
without re-constructing a hard-coded architecture (e.g., ResNet50).

Typical usage (CPU-only):
  python backserver/export_torchscript.py \
    --checkpoint path/to/checkpoint.pt \
    --output assets/models/my_model_torchscript.pt \
    --factory my_training_pkg.models:build_model \
    --example-shape 1,3,224,224
"""

from __future__ import annotations

import argparse
import importlib
import inspect
import os
import shutil
import sys
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Mapping


def _is_torchscript_archive(path: Path) -> bool:
    try:
        if not zipfile.is_zipfile(path):
            return False
        with zipfile.ZipFile(path, "r") as zf:
            return "constants.pkl" in zf.namelist()
    except Exception:
        return False


def _import_callable(spec: str) -> Callable[..., Any]:
    if ":" not in spec:
        raise ValueError(f"Invalid --factory '{spec}'. Expected 'module.submodule:function_name'.")
    module_name, func_name = spec.split(":", 1)
    module = importlib.import_module(module_name)
    func = getattr(module, func_name, None)
    if func is None or not callable(func):
        raise ValueError(f"Factory '{spec}' not found or not callable.")
    return func


def _parse_shape(value: str) -> tuple[int, ...]:
    parts = [p.strip() for p in value.split(",") if p.strip()]
    if not parts:
        raise ValueError("Empty --example-shape.")
    shape = tuple(int(p) for p in parts)
    if any(d <= 0 for d in shape):
        raise ValueError(f"Invalid --example-shape '{value}'. All dims must be > 0.")
    return shape


def _extract_state_dict(ckpt: Any) -> Mapping[str, Any] | None:
    if isinstance(ckpt, Mapping):
        for key in ("model_state_dict", "state_dict"):
            value = ckpt.get(key)
            if isinstance(value, Mapping):
                return value
        # If it already looks like a state_dict (common case)
        if ckpt and all(isinstance(k, str) for k in ckpt.keys()):
            return ckpt  # type: ignore[return-value]
    return None


def _call_factory(factory: Callable[..., Any], num_classes: int | None) -> Any:
    sig = inspect.signature(factory)
    kwargs: dict[str, Any] = {}
    if num_classes is not None:
        for name in ("num_classes", "n_classes", "classes", "class_count"):
            if name in sig.parameters:
                kwargs[name] = num_classes
                break
    return factory(**kwargs) if kwargs else factory()


@dataclass(frozen=True)
class ExportArgs:
    checkpoint: Path
    output: Path
    factory: str | None
    num_classes: int | None
    example_shape: tuple[int, ...]
    device: str
    mode: str
    strict: bool


def _parse_args(argv: list[str]) -> ExportArgs:
    parser = argparse.ArgumentParser(description="Export a PyTorch model checkpoint to TorchScript.")
    parser.add_argument("--checkpoint", required=True, help="Input checkpoint (.pt/.pth).")
    parser.add_argument("--output", required=True, help="Output TorchScript archive path (.pt recommended).")
    parser.add_argument(
        "--factory",
        help="Python callable that constructs the model, e.g. 'my_pkg.models:build_model'.",
    )
    parser.add_argument("--num-classes", type=int, help="Optional; passed to factory if it accepts it.")
    parser.add_argument(
        "--example-shape",
        default="1,3,224,224",
        help="Example input shape for tracing (comma-separated), default: 1,3,224,224",
    )
    parser.add_argument(
        "--device",
        default="cpu",
        choices=("cpu", "cuda", "mps"),
        help="Device to run export on (usually CPU).",
    )
    parser.add_argument(
        "--mode",
        default="trace",
        choices=("trace", "script"),
        help="TorchScript export mode. Use 'script' if tracing fails.",
    )
    parser.add_argument(
        "--strict",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Load state_dict with strict=True (recommended). Use --no-strict if keys mismatch.",
    )
    ns = parser.parse_args(argv)
    return ExportArgs(
        checkpoint=Path(ns.checkpoint),
        output=Path(ns.output),
        factory=ns.factory,
        num_classes=ns.num_classes,
        example_shape=_parse_shape(ns.example_shape),
        device=ns.device,
        mode=ns.mode,
        strict=bool(ns.strict),
    )


def main(argv: list[str]) -> int:
    args = _parse_args(argv)

    if not args.checkpoint.exists():
        print(f"[export] ERROR: checkpoint not found: {args.checkpoint}", file=sys.stderr)
        return 2

    args.output.parent.mkdir(parents=True, exist_ok=True)

    # If already TorchScript, just copy it to the requested output.
    if _is_torchscript_archive(args.checkpoint):
        shutil.copyfile(args.checkpoint, args.output)
        print(f"[export] checkpoint is already TorchScript; copied to: {args.output}")
        return 0

    try:
        import torch  # type: ignore
        import torch.nn as nn  # noqa: F401
    except Exception as e:
        print(f"[export] ERROR: torch not available: {e}", file=sys.stderr)
        return 2

    if args.device == "cuda" and not torch.cuda.is_available():
        print("[export] ERROR: --device=cuda requested but CUDA is not available.", file=sys.stderr)
        return 2
    if args.device == "mps":
        if not hasattr(torch.backends, "mps") or not torch.backends.mps.is_available():  # type: ignore[attr-defined]
            print("[export] ERROR: --device=mps requested but MPS is not available.", file=sys.stderr)
            return 2

    print(f"[export] loading checkpoint: {args.checkpoint}")
    ckpt = torch.load(args.checkpoint, map_location="cpu")
    state_dict = _extract_state_dict(ckpt)
    if state_dict is None:
        print(
            "[export] ERROR: checkpoint does not look like a state_dict.\n"
            "        Provide a state_dict checkpoint or export TorchScript from your training code.",
            file=sys.stderr,
        )
        return 2

    if not args.factory:
        print(
            "[export] ERROR: --factory is required for non-TorchScript checkpoints.\n"
            "        Example: --factory my_training_pkg.models:build_model",
            file=sys.stderr,
        )
        return 2

    print(f"[export] importing factory: {args.factory}")
    factory = _import_callable(args.factory)

    try:
        model = _call_factory(factory, args.num_classes)
    except Exception as e:
        print(f"[export] ERROR: failed to construct model from factory: {e}", file=sys.stderr)
        return 2

    if not hasattr(model, "load_state_dict"):
        print("[export] ERROR: factory did not return a torch.nn.Module-like object.", file=sys.stderr)
        return 2

    missing_unexpected = model.load_state_dict(state_dict, strict=args.strict)
    if not args.strict:
        print(f"[export] load_state_dict non-strict result: {missing_unexpected}")

    model.eval()
    model.to(args.device)

    example = torch.randn(*args.example_shape, device=args.device)
    with torch.no_grad():
        if args.mode == "script":
            ts = torch.jit.script(model)
        else:
            ts = torch.jit.trace(model, example)

    torch.jit.save(ts, args.output)
    print(f"[export] saved TorchScript to: {args.output}")

    # Quick validation: load and run once.
    ts2 = torch.jit.load(str(args.output), map_location=args.device)
    with torch.no_grad():
        out = ts2(example)
    try:
        shape = tuple(out.shape)  # type: ignore[attr-defined]
    except Exception:
        shape = None
    print(f"[export] validate forward ok; output shape: {shape}")

    # Help users keep the backend loader happy.
    print(
        "[export] note: backserver/model.py applies softmax on the model output.\n"
        "        Export a model that returns logits shaped like [1, num_classes] or [num_classes]."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

