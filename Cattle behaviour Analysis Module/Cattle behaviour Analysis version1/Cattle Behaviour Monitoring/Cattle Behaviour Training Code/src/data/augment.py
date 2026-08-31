"""
augment.py
Step 4 of the data pipeline.

Generates augmented images for under-represented behaviour classes
to reduce class imbalance before training.

Augmentation strategy (configurable via config.yaml):
  - Horizontal flip
  - Small rotation (-5-)
  - Random brightness / contrast
  - Gaussian noise
  - Random scale

Usage:
    python src/data/augment.py
"""

import sys
from pathlib import Path

import cv2
import numpy as np
import albumentations as A

# Allow running from project root
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from src.utils.config_loader import get_config

IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png")


def build_augmentation_pipeline(aug_cfg: dict, target_size: int) -> A.Compose:
    """Build the Albumentations augmentation pipeline from config.

    Args:
        aug_cfg:     ``config['preprocessing']['augmentation']`` sub-dict.
        target_size: Output image size (square).

    Returns:
        Composed Albumentations transform.
    """
    return A.Compose([
        A.HorizontalFlip(p=aug_cfg["horizontal_flip_p"]),
        A.Rotate(limit=aug_cfg["rotate_limit"], p=aug_cfg["rotate_p"]),
        A.RandomBrightnessContrast(
            brightness_limit=aug_cfg["brightness_limit"],
            contrast_limit=aug_cfg["contrast_limit"],
            p=aug_cfg["color_jitter_p"],
        ),
        A.GaussNoise(
            var_limit=tuple(aug_cfg["gauss_noise_var"]),
            p=aug_cfg["gauss_noise_p"],
        ),
        A.RandomScale(scale_limit=aug_cfg["scale_limit"], p=aug_cfg["scale_p"]),
        A.Resize(target_size, target_size),
    ])


def augment_class(class_dir: Path, pipeline: A.Compose) -> int:
    """Apply augmentation to all images in a class folder.

    Each original image produces exactly one augmented image.
    Augmented files are named ``<class>_aug_<index:04d>.jpg``.

    Args:
        class_dir: Path to the class subfolder.
        pipeline:  Albumentations augmentation pipeline.

    Returns:
        Number of augmented images generated.
    """
    images = [
        f for f in class_dir.iterdir()
        if f.suffix.lower() in IMAGE_EXTENSIONS
        and "_aug_" not in f.stem          # skip already-augmented files
    ]

    aug_count = 0
    for img_path in sorted(images):
        img = cv2.imread(str(img_path))
        if img is None:
            continue

        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        aug_result = pipeline(image=img_rgb)
        aug_img = cv2.cvtColor(aug_result["image"], cv2.COLOR_RGB2BGR)

        save_name = class_dir / f"{class_dir.name}_aug_{aug_count:04d}.jpg"
        cv2.imwrite(str(save_name), aug_img)
        aug_count += 1

    return aug_count


def augment_dataset(cfg: dict) -> None:
    """Run augmentation on all configured target classes.

    Args:
        cfg: Loaded configuration dictionary.
    """
    base_dir        = Path(cfg["paths"]["cleaned_frames_dir"])
    target_classes  = cfg["preprocessing"]["augment_classes"]
    aug_cfg         = cfg["preprocessing"]["augmentation"]
    target_size     = cfg["dataset"]["raw_roi_size"]

    pipeline = build_augmentation_pipeline(aug_cfg, target_size)

    print(f"Augmenting classes: {target_classes}")
    print(f"Source directory  : {base_dir}\n")

    for class_name in target_classes:
        class_dir = base_dir / class_name
        if not class_dir.exists():
            print(f"  [SKIP] Class folder not found: {class_dir}")
            continue

        count = augment_class(class_dir, pipeline)
        total = len(list(class_dir.glob("*.jpg")))
        print(f"  [{class_name}] Generated {count} augmented images. "
              f"Total now: {total}")

    print("\nAugmentation complete.")


if __name__ == "__main__":
    cfg = get_config()
    augment_dataset(cfg)
