import argparse
import sys
from pathlib import Path

# Add project root to sys.path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from src.config_loader import load_config
from src.detection.trainer import EarTagTrainer
from src.utils.logger import setup_logger

logger = setup_logger("TrainScript")


def main():
    parser = argparse.ArgumentParser(description="Train YOLO Model for Cattle Ear Tag Detection")
    parser.add_argument("--config", type=str, default=None, help="Path to config.yaml")
    parser.add_argument("--model", type=str, default=None, help="Base model weights (e.g. yolov8n.pt, yolo11n.pt)")
    parser.add_argument("--data", type=str, default=None, help="Path to data.yaml")
    parser.add_argument("--epochs", type=int, default=None, help="Number of training epochs")
    parser.add_argument("--batch-size", type=int, default=None, help="Batch size")
    parser.add_argument("--imgsz", type=int, default=None, help="Image size (e.g. 640)")
    parser.add_argument("--name", type=str, default=None, help="Run name")
    parser.add_argument("--device", type=str, default=None, help="Compute device ('auto', '0', 'cpu')")
    parser.add_argument("--workers", type=int, default=0, help="DataLoader workers (0 recommended on Windows)")
    args = parser.parse_args()

    config = load_config(args.config)
    train_cfg = config.get("training", {})

    base_model = args.model or train_cfg.get("model", "yolov8n.pt")
    data_yaml = args.data or train_cfg.get("data", "config/data.yaml")
    epochs = args.epochs or train_cfg.get("epochs", 100)
    batch_size = args.batch_size or train_cfg.get("batch_size", 16)
    imgsz = args.imgsz or train_cfg.get("imgsz", 640)
    run_name = args.name or train_cfg.get("name", "cattle_ear_tag_best")
    device = args.device or train_cfg.get("device", "auto")
    workers = args.workers

    trainer = EarTagTrainer(
        base_model=base_model,
        data_yaml=data_yaml,
        run_name=run_name,
        device=device
    )

    trainer.train(
        epochs=epochs,
        imgsz=imgsz,
        batch_size=batch_size,
        workers=workers,
        copy_best_to="models/best.pt"
    )


if __name__ == "__main__":
    main()
