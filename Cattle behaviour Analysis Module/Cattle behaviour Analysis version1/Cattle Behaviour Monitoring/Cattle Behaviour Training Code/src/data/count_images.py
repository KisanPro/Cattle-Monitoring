"""
count_images.py
Step 5 of the data pipeline.

Counts images in every class subfolder of cleaned_frames_dir and
prints a formatted summary table.

Usage:
    python src/data/count_images.py
"""

import sys
from pathlib import Path

# Allow running from project root
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from src.utils.config_loader import get_config

IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png")


def count_images(cfg: dict) -> None:
    """Print image counts per class for the cleaned frames dataset.

    Args:
        cfg: Loaded configuration dictionary.
    """
    base_dir = Path(cfg["paths"]["cleaned_frames_dir"])

    if not base_dir.exists():
        print(f"[ERROR] Directory not found: {base_dir}")
        return

    class_dirs = sorted([d for d in base_dir.iterdir() if d.is_dir()])
    if not class_dirs:
        print(f"[WARNING] No class subdirectories found in: {base_dir}")
        return

    print(f"\nImage counts in: {base_dir}")
    print(f"{'Class':<20} {'Count':>8}")
    print("-" * 30)

    grand_total = 0
    for class_dir in class_dirs:
        count = sum(
            1 for f in class_dir.iterdir()
            if f.suffix.lower() in IMAGE_EXTENSIONS
        )
        grand_total += count
        print(f"  {class_dir.name:<18} {count:>8,}")

    print("-" * 30)
    print(f"  {'TOTAL':<18} {grand_total:>8,}\n")


if __name__ == "__main__":
    cfg = get_config()
    count_images(cfg)
