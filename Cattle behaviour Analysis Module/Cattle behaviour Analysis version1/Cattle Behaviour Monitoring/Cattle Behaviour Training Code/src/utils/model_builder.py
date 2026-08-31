"""
model_builder.py
Factory for creating and loading EfficientNetV2 behaviour classification models.
Replaces the repeated model-loading boilerplate found across all inference scripts.
"""

from __future__ import annotations

from pathlib import Path

import timm
import torch
import torch.nn as nn


def build_efficientnetv2(
    num_classes: int,
    pretrained: bool = True,
    drop_rate: float = 0.2,
    drop_path_rate: float = 0.1,
    backbone: str = "efficientnetv2_rw_s",
) -> nn.Module:
    """Create an EfficientNetV2 model with a custom classification head.

    Args:
        num_classes:      Number of output behaviour classes.
        pretrained:       Load ImageNet pretrained weights from timm.
        drop_rate:        Dropout rate to reduce overfitting.
        drop_path_rate:   Stochastic depth drop-path rate.
        backbone:         timm model name (default: efficientnetv2_rw_s).

    Returns:
        Initialised model (not yet moved to device).
    """
    model = timm.create_model(
        backbone,
        pretrained=pretrained,
        num_classes=num_classes,
        drop_rate=drop_rate,
        drop_path_rate=drop_path_rate,
    )
    return model


def load_behaviour_model(
    weights_path: str | Path,
    num_classes: int,
    device: torch.device,
    backbone: str = "efficientnetv2_rw_s",
) -> nn.Module:
    """Load a trained behaviour model from a weights file.

    Args:
        weights_path: Absolute or relative path to the ``.pt`` weights file.
        num_classes:  Number of output classes the model was trained on.
        device:       Target device (CPU or CUDA).
        backbone:     timm model name used during training.

    Returns:
        Model loaded with trained weights, set to eval mode, on ``device``.

    Raises:
        FileNotFoundError: If the weights file does not exist.
    """
    weights_path = Path(weights_path)
    if not weights_path.exists():
        raise FileNotFoundError(
            f"Weights file not found: {weights_path}\n"
            "Run training first or check the path in config.yaml."
        )

    model = build_efficientnetv2(num_classes=num_classes, pretrained=False, backbone=backbone)

    state = torch.load(weights_path, map_location=device, weights_only=False)

    # Support both raw state_dicts and checkpoint dicts (with 'state_dict' key)
    if isinstance(state, dict) and "state_dict" in state:
        state = state["state_dict"]
        # Strip DataParallel 'module.' prefix if present
        state = {k.replace("module.", ""): v for k, v in state.items()}

    model.load_state_dict(state, strict=True)
    model.to(device)
    model.eval()
    return model
