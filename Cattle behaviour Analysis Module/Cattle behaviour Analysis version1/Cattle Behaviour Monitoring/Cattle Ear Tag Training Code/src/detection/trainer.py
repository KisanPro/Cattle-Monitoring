import os
import shutil
from pathlib import Path
from typing import Optional, Dict, Any
import torch
from ultralytics import YOLO

from ..utils.logger import setup_logger

logger = setup_logger("EarTagTrainer")


class EarTagTrainer:
    """
    Manages YOLO model training, hyperparameters, logging, and weight saving.
    """

    def __init__(
        self,
        base_model: str = "yolov8n.pt",
        data_yaml: str = "config/data.yaml",
        project_name: str = "runs/detect",
        run_name: str = "cattle_ear_tag_best",
        device: str = "auto"
    ):
        self.base_model = base_model
        self.data_yaml = Path(data_yaml)
        self.project_name = project_name
        self.run_name = run_name

        if device == "auto":
            self.device = "0" if torch.cuda.is_available() else "cpu"
        else:
            self.device = device

    def train(
        self,
        epochs: int = 100,
        imgsz: int = 640,
        batch_size: int = 16,
        workers: int = 0,
        copy_best_to: Optional[str] = "models/best.pt",
        **kwargs: Any
    ) -> Dict[str, Any]:
        """
        Executes YOLO training loop.
        
        Args:
            epochs: Number of training epochs.
            imgsz: Input image resolution.
            batch_size: Batch size.
            workers: DataLoader workers (0 is safest on Windows).
            copy_best_to: Destination path to save best trained weights.
            **kwargs: Extra arguments passed to YOLO train.
        """
        logger.info(f"Initializing YOLO model from base: {self.base_model}")
        model = YOLO(self.base_model)

        logger.info(
            f"Starting training on {self.data_yaml} | "
            f"Epochs: {epochs} | Batch: {batch_size} | Device: {self.device}"
        )

        train_results = model.train(
            data=str(self.data_yaml),
            epochs=epochs,
            imgsz=imgsz,
            batch=batch_size,
            workers=workers,
            device=self.device,
            project=self.project_name,
            name=self.run_name,
            exist_ok=True,
            **kwargs
        )

        # Copy best.pt to models directory if requested
        if copy_best_to:
            save_dir = Path(train_results.save_dir) if hasattr(train_results, "save_dir") else Path(self.project_name) / self.run_name
            best_weights = save_dir / "weights" / "best.pt"

            if best_weights.exists():
                dst = Path(copy_best_to)
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(best_weights, dst)
                logger.info(f"Saved best weights successfully to: {dst.resolve()}")
            else:
                logger.warning(f"Could not locate best.pt at: {best_weights}")

        return train_results
