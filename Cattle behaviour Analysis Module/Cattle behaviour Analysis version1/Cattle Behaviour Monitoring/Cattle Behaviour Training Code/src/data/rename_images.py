"""
rename_images.py
Step 2 of the data pipeline.

Renames all images inside each class subfolder to the consistent format:
    <class_name>_<index>.jpg

Handles two scenarios:
  - Fresh rename: all images renamed from index 1.
  - Continuation: already-renamed files are detected via regex and new
    files are appended starting from max(existing_index) + 1.

Usage:
    python src/data/rename_images.py
"""

import os
import re
import sys
from pathlib import Path

# Allow running from project root
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from src.utils.config_loader import get_config

IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png")


def _get_pattern(class_name: str) -> re.Pattern:
    """Return regex that matches already-renamed files for a given class."""
    return re.compile(
        rf"^{re.escape(class_name)}_(\d+)\.(jpg|jpeg|png)$",
        re.IGNORECASE,
    )


def rename_class_folder(class_dir: Path) -> None:
    """Rename images in a single class directory.

    Args:
        class_dir: Path to a folder containing images for one behaviour class.
    """
    class_name = class_dir.name
    pattern = _get_pattern(class_name)

    all_images = [
        f for f in class_dir.iterdir()
        if f.suffix.lower() in IMAGE_EXTENSIONS
    ]

    existing_numbers: list[int] = []
    unrenamed: list[Path] = []

    for img in all_images:
        match = pattern.match(img.name)
        if match:
            existing_numbers.append(int(match.group(1)))
        else:
            unrenamed.append(img)

    start_idx = (max(existing_numbers) + 1) if existing_numbers else 1

    print(f"  [{class_name}] Already renamed: {len(existing_numbers)}, "
          f"to rename: {len(unrenamed)}, starting at index: {start_idx}")

    for counter, img_path in enumerate(sorted(unrenamed), start=start_idx):
        ext = img_path.suffix.lower().lstrip(".")
        new_name = class_dir / f"{class_name}_{counter}.{ext}"
        img_path.rename(new_name)

    print(f"  [{class_name}] Done - total images: {len(all_images)}")


def rename_all_classes(cfg: dict) -> None:
    """Rename images across all class subfolders in cleaned_frames_dir.

    Args:
        cfg: Loaded configuration dictionary.
    """
    base_dir = Path(cfg["paths"]["cleaned_frames_dir"])

    if not base_dir.exists():
        print(f"[ERROR] Cleaned frames directory not found: {base_dir}")
        return

    class_dirs = [d for d in base_dir.iterdir() if d.is_dir()]
    if not class_dirs:
        print(f"[WARNING] No class subdirectories found in: {base_dir}")
        return

    print(f"Renaming images in: {base_dir}")
    for class_dir in sorted(class_dirs):
        rename_class_folder(class_dir)

    print("\nRenaming completed successfully.")


if __name__ == "__main__":
    cfg = get_config()
    rename_all_classes(cfg)
