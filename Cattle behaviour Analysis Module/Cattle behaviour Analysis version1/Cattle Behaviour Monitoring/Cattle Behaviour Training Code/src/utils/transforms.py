"""
transforms.py
Standard torchvision image transforms used across training, evaluation,
and inference. All parameters are read from config.yaml.
"""

from __future__ import annotations

from torchvision import transforms


def get_train_transform(image_size: int = 224,
                        mean: list[float] | None = None,
                        std: list[float] | None = None) -> transforms.Compose:
    """Return the augmented transform pipeline used during training.

    Applies:
        - Resize to ``image_size - image_size``
        - Random horizontal flip
        - Random rotation (-15-)
        - Colour jitter (brightness + contrast)
        - ToTensor + ImageNet normalisation

    Args:
        image_size: Target spatial dimension (square).
        mean: Per-channel normalisation mean. Defaults to ImageNet values.
        std:  Per-channel normalisation std.  Defaults to ImageNet values.

    Returns:
        Composed transform object.
    """
    mean = mean or [0.485, 0.456, 0.406]
    std  = std  or [0.229, 0.224, 0.225]

    return transforms.Compose([
        transforms.Resize((image_size, image_size)),
        transforms.RandomHorizontalFlip(),
        transforms.RandomRotation(15),
        transforms.ColorJitter(brightness=0.2, contrast=0.2),
        transforms.ToTensor(),
        transforms.Normalize(mean=mean, std=std),
    ])


def get_val_transform(image_size: int = 224,
                      mean: list[float] | None = None,
                      std: list[float] | None = None) -> transforms.Compose:
    """Return the deterministic transform pipeline used for validation / test.

    Applies:
        - Resize to ``image_size - image_size``
        - ToTensor + ImageNet normalisation

    Args:
        image_size: Target spatial dimension (square).
        mean: Per-channel normalisation mean. Defaults to ImageNet values.
        std:  Per-channel normalisation std.  Defaults to ImageNet values.

    Returns:
        Composed transform object.
    """
    mean = mean or [0.485, 0.456, 0.406]
    std  = std  or [0.229, 0.224, 0.225]

    return transforms.Compose([
        transforms.Resize((image_size, image_size)),
        transforms.ToTensor(),
        transforms.Normalize(mean=mean, std=std),
    ])


def get_inference_transform(image_size: int = 224,
                            mean: list[float] | None = None,
                            std: list[float] | None = None) -> transforms.Compose:
    """Return the transform pipeline for real-time frame inference.

    Same as val_transform but accepts raw numpy arrays (BGR) via ToPILImage.

    Args:
        image_size: Target spatial dimension (square).
        mean: Per-channel normalisation mean. Defaults to ImageNet values.
        std:  Per-channel normalisation std.  Defaults to ImageNet values.

    Returns:
        Composed transform object.
    """
    mean = mean or [0.485, 0.456, 0.406]
    std  = std  or [0.229, 0.224, 0.225]

    return transforms.Compose([
        transforms.ToPILImage(),
        transforms.Resize((image_size, image_size)),
        transforms.ToTensor(),
        transforms.Normalize(mean=mean, std=std),
    ])
