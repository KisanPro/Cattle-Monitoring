"""
split_dataset.py
Step 6 of the data pipeline.

Randomly splits each class subfolder from cleaned_frames_dir into
train / val / test sets (ratios configured in config.yaml) and copies
images into the Dataset/ ImageFolder-compatible layout.

Usage:
    python src/data/split_dataset.py
"""

import random
import shutil
import sys
from pathlib import Path

# Allow running from project root
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from src.utils.config_loader import get_config

IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png")
RANDOM_SEED = 42


def split_dataset(cfg: dict) -> None:
    """Split cleaned frames into train / val / test directories.

    Copies (does not move) images to keep the source dataset intact.

    Args:
        cfg: Loaded configuration dictionary.
    """
    source_dir  = Path(cfg["paths"]["cleaned_frames_dir"])
    target_dir  = Path(cfg["paths"]["dataset_dir"])
    ratios      = cfg["dataset"]["split_ratios"]

    train_r = ratios["train"]
    val_r   = ratios["val"]
    # test gets the remainder so floats always sum to 1.0

    splits = ["train", "val", "test"]

    class_dirs = sorted([d for d in source_dir.iterdir() if d.is_dir()])
    if not class_dirs:
        print(f"[ERROR] No class folders found in: {source_dir}")
        return

    # Create target folder structure
    for split in splits:
        for class_dir in class_dirs:
            (target_dir / split / class_dir.name).mkdir(parents=True, exist_ok=True)

    print(f"Splitting dataset: train={train_r:.0%}  val={val_r:.0%}  "
          f"test={1 - train_r - val_r:.0%}")
    print(f"Source : {source_dir}")
    print(f"Target : {target_dir}\n")

    random.seed(RANDOM_SEED)

    for class_dir in class_dirs:
        images = [
            f for f in class_dir.iterdir()
            if f.suffix.lower() in IMAGE_EXTENSIONS
        ]
        random.shuffle(images)

        total     = len(images)
        train_end = int(total * train_r)
        val_end   = train_end + int(total * val_r)

        splits_data = {
            "train": images[:train_end],
            "val":   images[train_end:val_end],
            "test":  images[val_end:],
        }

        for split_name, file_list in splits_data.items():
            dest_dir = target_dir / split_name / class_dir.name
            for img_path in file_list:
                shutil.copy(img_path, dest_dir / img_path.name)

        print(f"  [{class_dir.name}]  "
              f"train={len(splits_data['train'])}  "
              f"val={len(splits_data['val'])}  "
              f"test={len(splits_data['test'])}")

    print("\nDataset splitting complete.")
    print(f"Ready to train from: {target_dir}")


if __name__ == "__main__":
    cfg = get_config()
    split_dataset(cfg)
