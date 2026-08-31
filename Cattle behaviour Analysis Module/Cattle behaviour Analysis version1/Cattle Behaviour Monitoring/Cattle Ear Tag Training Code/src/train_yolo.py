"""
Legacy YOLO training script.
Maintained for backward compatibility; delegates to src.detection.EarTagTrainer.
"""
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from src.detection.trainer import EarTagTrainer

if __name__ == "__main__":
    trainer = EarTagTrainer(
        base_model="yolov8n.pt",
        data_yaml="config/data.yaml",
        run_name="cattle_ear_tag_best"
    )
    trainer.train(epochs=100, imgsz=640, batch_size=16, workers=0)
