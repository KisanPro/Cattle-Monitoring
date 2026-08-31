import argparse
import sys
from pathlib import Path

# Add project root to sys.path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from src.config_loader import load_config
from src.pipeline.ear_tag_pipeline import EarTagPipeline
from src.utils.logger import setup_logger

logger = setup_logger("RunOCRPipeline")


def main():
    parser = argparse.ArgumentParser(description="Run End-to-End Cattle Ear Tag Detection & OCR Pipeline")
    parser.add_argument("--input", type=str, default="dataset/algo_test", help="Input image file or directory")
    parser.add_argument("--weights", type=str, default=None, help="Trained YOLO weights path (default: models/best.pt)")
    parser.add_argument("--output", type=str, default="output/results", help="Output directory for results & CSV")
    parser.add_argument("--det-conf", type=float, default=None, help="Detection confidence threshold (e.g. 0.35)")
    parser.add_argument("--ocr-conf", type=float, default=None, help="OCR confidence threshold (e.g. 0.30)")
    parser.add_argument("--save-crops", action="store_true", help="Save cropped ear tag images to output/crops")
    parser.add_argument("--no-csv", action="store_true", help="Disable CSV export")
    parser.add_argument("--no-json", action="store_true", help="Disable JSON export")
    parser.add_argument("--device", type=str, default=None, help="Compute device ('auto', '0', 'cpu')")
    parser.add_argument("--config", type=str, default=None, help="Path to custom config.yaml")
    args = parser.parse_args()

    config = load_config(args.config)

    pipeline = EarTagPipeline(
        config=config,
        model_path=args.weights,
        det_conf=args.det_conf,
        ocr_conf=args.ocr_conf,
        device=args.device
    )

    input_path = Path(args.input)
    if not input_path.is_absolute():
        input_path = PROJECT_ROOT / input_path

    output_dir = Path(args.output)
    if not output_dir.is_absolute():
        output_dir = PROJECT_ROOT / output_dir

    if input_path.is_file():
        save_path = output_dir / f"annotated_{input_path.name}"
        crops_dir = output_dir / "crops" if args.save_crops else None
        res = pipeline.process_image(input_path, save_annotated_to=save_path, save_crops_to=crops_dir)
        logger.info(f"✅ Finished processing single image. Results: {len(res.records)} tag(s) found.")
        for rec in res.records:
            logger.info(f"   -> Tag ID: '{rec.tag_id}' | Det Conf: {rec.det_confidence} | OCR Conf: {rec.ocr_confidence}")
    elif input_path.is_dir():
        records = pipeline.process_directory(
            input_dir=input_path,
            output_dir=output_dir,
            save_crops=args.save_crops,
            export_csv=not args.no_csv,
            export_json=not args.no_json
        )
        logger.info(f"✅ Finished processing directory. Total detections across files: {len(records)}")
    else:
        logger.error(f"Input path does not exist: {input_path}")


if __name__ == "__main__":
    main()
