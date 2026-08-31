"""
Legacy dataset splitter.
Maintained for backward compatibility; delegates to src.dataset.split_dataset.
"""
import sys
from pathlib import Path

# Add project root to sys.path
PROJECT_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(PROJECT_ROOT))

from src.dataset.split_dataset import split_dataset
from src.utils.logger import setup_logger

logger = setup_logger("LegacySplitDataset")

if __name__ == "__main__":
    # Default relative paths within project
    raw_images = PROJECT_ROOT / "big_dataset" / "Cow eartag detection dataset" / "Images"
    raw_labels = PROJECT_ROOT / "big_dataset" / "Cow eartag detection dataset" / "labels"
    output_base = PROJECT_ROOT / "dataset"

    if not raw_images.exists():
        logger.error(f"Raw image directory not found at: {raw_images}")
        logger.info("Please run: python scripts/split_data.py --images <path> --labels <path>")
    else:
        results = split_dataset(
            images_dir=str(raw_images),
            labels_dir=str(raw_labels),
            output_base=str(output_base),
            ratios=(0.7, 0.2, 0.1)
        )
        logger.info(f"Dataset split completed: {results}")
