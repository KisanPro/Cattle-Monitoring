"""
resize_images.py
Step 3 of the data pipeline.

Verifies all images in every class subfolder are the target size.
Resizes and overwrites any images that are not already the correct size.

Usage:
    python src/data/resize_images.py
"""

import sys
from pathlib import Path

import cv2

# Allow running from project root
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from src.utils.config_loader import get_config

IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png")


def resize_class_folder(class_dir: Path, target_size: tuple[int, int]) -> dict:
    """Check and resize all images in a class folder.

    Args:
        class_dir:   Path to a class subfolder.
        target_size: ``(width, height)`` target dimensions.

    Returns:
        Dictionary with keys ``total``, ``resized``, ``skipped``, ``errors``.
    """
    stats = {"total": 0, "resized": 0, "skipped": 0, "errors": 0}

    images = [f for f in class_dir.iterdir() if f.suffix.lower() in IMAGE_EXTENSIONS]
    stats["total"] = len(images)

    for img_path in images:
        img = cv2.imread(str(img_path))
        if img is None:
            print(f"  [SKIP] Unreadable: {img_path.name}")
            stats["errors"] += 1
            continue

        h, w = img.shape[:2]
        if (w, h) == target_size:
            stats["skipped"] += 1
            continue

        resized = cv2.resize(img, target_size)
        cv2.imwrite(str(img_path), resized)
        stats["resized"] += 1

    return stats


def resize_all_classes(cfg: dict) -> None:
    """Resize images across all class subfolders.

    Args:
        cfg: Loaded configuration dictionary.
    """
    base_dir = Path(cfg["paths"]["cleaned_frames_dir"])
    raw_size = cfg["dataset"]["raw_roi_size"]
    target_size = (raw_size, raw_size)

    if not base_dir.exists():
        print(f"[ERROR] Directory not found: {base_dir}")
        return

    class_dirs = [d for d in base_dir.iterdir() if d.is_dir()]
    if not class_dirs:
        print(f"[WARNING] No class subdirectories found in: {base_dir}")
        return

    print(f"Checking & resizing images to {target_size} in: {base_dir}\n")

    grand_total = grand_resized = grand_skipped = grand_errors = 0
    for class_dir in sorted(class_dirs):
        stats = resize_class_folder(class_dir, target_size)
        grand_total   += stats["total"]
        grand_resized += stats["resized"]
        grand_skipped += stats["skipped"]
        grand_errors  += stats["errors"]
        print(f"  [{class_dir.name}] total={stats['total']}  "
              f"resized={stats['resized']}  "
              f"already_ok={stats['skipped']}  "
              f"errors={stats['errors']}")

    print(f"\nSummary - total: {grand_total}, resized: {grand_resized}, "
          f"already_ok: {grand_skipped}, errors: {grand_errors}")


if __name__ == "__main__":
    cfg = get_config()
    resize_all_classes(cfg)
