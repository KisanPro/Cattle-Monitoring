import argparse
import sys
from pathlib import Path

# Add project root to sys.path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from src.dataset.split_dataset import split_dataset
from src.utils.logger import setup_logger

logger = setup_logger("SplitDataScript")


def main():
    parser = argparse.ArgumentParser(description="Split Raw Dataset into Train/Val/Test Subsets")
    parser.add_argument("--images", type=str, required=True, help="Directory containing raw image files")
    parser.add_argument("--labels", type=str, required=True, help="Directory containing YOLO .txt label files")
    parser.add_argument("--output", type=str, default="dataset", help="Output dataset destination directory")
    parser.add_argument("--train-ratio", type=float, default=0.7, help="Fraction for training (e.g. 0.7)")
    parser.add_argument("--val-ratio", type=float, default=0.2, help="Fraction for validation (e.g. 0.2)")
    parser.add_argument("--test-ratio", type=float, default=0.1, help="Fraction for testing (e.g. 0.1)")
    parser.add_argument("--seed", type=int, default=42, help="Random seed")
    args = parser.parse_args()

    ratios = (args.train_ratio, args.val_ratio, args.test_ratio)

    results = split_dataset(
        images_dir=args.images,
        labels_dir=args.labels,
        output_base=args.output,
        ratios=ratios,
        seed=args.seed
    )

    logger.info(f"Dataset split complete: {results}")


if __name__ == "__main__":
    main()
