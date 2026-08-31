"""
Legacy execution script for Cattle Ear Tag Detection & OCR.
Maintained for backward compatibility; delegates to src.pipeline.EarTagPipeline.
"""
import sys
from pathlib import Path

# Add project root to sys.path
PROJECT_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(PROJECT_ROOT))

from src.pipeline.ear_tag_pipeline import EarTagPipeline
from src.utils.logger import setup_logger

logger = setup_logger("LegacyOCR")

if __name__ == "__main__":
    logger.info("Running via legacy ocr_1.py entrypoint...")
    input_dir = PROJECT_ROOT / "dataset" / "algo_test"
    output_dir = PROJECT_ROOT / "output" / "results"

    pipeline = EarTagPipeline()
    records = pipeline.process_directory(
        input_dir=input_dir,
        output_dir=output_dir,
        export_csv=True,
        export_json=True
    )
    logger.info(f"Completed! {len(records)} ear tag(s) processed. Results saved in: {output_dir}")
