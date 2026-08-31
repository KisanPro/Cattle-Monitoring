"""
Legacy YOLO testing script.
Maintained for backward compatibility; delegates to src.detection.EarTagDetector.
"""
import sys
from pathlib import Path
import cv2

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from src.detection.detector import EarTagDetector
from src.utils.visualizer import Visualizer

if __name__ == "__main__":
    detector = EarTagDetector(model_path="models/best.pt", conf_threshold=0.25)
    visualizer = Visualizer()

    input_folder = PROJECT_ROOT / "dataset" / "algo_test"
    output_folder = PROJECT_ROOT / "testing_results" / "predict"
    output_folder.mkdir(parents=True, exist_ok=True)

    for img_file in input_folder.glob("*.jpg"):
        img = cv2.imread(str(img_file))
        if img is None:
            continue
        detections = detector.detect(img, extract_crops=False)
        annotated = img.copy()
        for det in detections:
            annotated = visualizer.draw_detection(annotated, det.box, det.class_name, det.confidence)
        cv2.imwrite(str(output_folder / f"predict_{img_file.name}"), annotated)

    print(f"✅ Detection test completed! Check results in: {output_folder}")
