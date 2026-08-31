import argparse
import sys
from pathlib import Path
import cv2

# Add project root to sys.path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from src.config_loader import load_config
from src.detection.detector import EarTagDetector
from src.utils.visualizer import Visualizer
from src.utils.logger import setup_logger

logger = setup_logger("RunInference")


def main():
    parser = argparse.ArgumentParser(description="Run Cattle Ear Tag YOLO Detection Inference")
    parser.add_argument("--input", type=str, default="dataset/algo_test", help="Input image or directory")
    parser.add_argument("--weights", type=str, default="models/best.pt", help="Path to trained YOLO weights")
    parser.add_argument("--output", type=str, default="testing_results/predict", help="Output directory")
    parser.add_argument("--conf", type=float, default=0.35, help="Confidence threshold")
    parser.add_argument("--iou", type=float, default=0.50, help="IoU threshold")
    parser.add_argument("--imgsz", type=int, default=640, help="Inference image resolution")
    parser.add_argument("--device", type=str, default="auto", help="Compute device ('auto', '0', 'cpu')")
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.is_absolute():
        input_path = PROJECT_ROOT / input_path

    weights_path = Path(args.weights)
    if not weights_path.is_absolute():
        weights_path = PROJECT_ROOT / weights_path

    output_dir = Path(args.output)
    if not output_dir.is_absolute():
        output_dir = PROJECT_ROOT / output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    detector = EarTagDetector(
        model_path=weights_path,
        conf_threshold=args.conf,
        iou_threshold=args.iou,
        img_size=args.imgsz,
        device=args.device
    )
    visualizer = Visualizer()

    valid_exts = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
    if input_path.is_file():
        image_files = [input_path]
    elif input_path.is_dir():
        image_files = [p for p in input_path.iterdir() if p.suffix.lower() in valid_exts]
    else:
        logger.error(f"Invalid input path: {input_path}")
        return

    logger.info(f"Running detection on {len(image_files)} image(s)...")

    for img_file in image_files:
        img_bgr = cv2.imread(str(img_file))
        if img_bgr is None:
            continue

        detections = detector.detect(img_bgr, extract_crops=False)
        annotated = img_bgr.copy()

        for det in detections:
            annotated = visualizer.draw_detection(
                image=annotated,
                box=det.box,
                label=det.class_name,
                det_conf=det.confidence
            )

        out_path = output_dir / f"pred_{img_file.name}"
        cv2.imwrite(str(out_path), annotated)
        logger.info(f"Saved: {out_path} ({len(detections)} tags found)")


if __name__ == "__main__":
    main()
