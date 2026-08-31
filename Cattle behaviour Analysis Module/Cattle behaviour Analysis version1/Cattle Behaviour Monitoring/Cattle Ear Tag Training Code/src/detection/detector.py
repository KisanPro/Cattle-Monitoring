from dataclasses import dataclass
from pathlib import Path
from typing import List, Union, Optional
import cv2
import numpy as np
import torch
from ultralytics import YOLO

from ..utils.logger import setup_logger

logger = setup_logger("EarTagDetector")


@dataclass
class DetectionResult:
    """Represents a single detected ear tag bounding box."""
    box: List[int]             # [x1, y1, x2, y2]
    confidence: float          # Detection confidence score
    class_id: int              # Class index (0 for ear_tag)
    class_name: str            # Class name
    crop: Optional[np.ndarray] = None  # Cropped region of interest (BGR)


class EarTagDetector:
    """
    Handles YOLO model loading, inference, and ear tag region extraction.
    """

    def __init__(
        self,
        model_path: Union[str, Path] = "models/best.pt",
        conf_threshold: float = 0.35,
        iou_threshold: float = 0.50,
        img_size: int = 640,
        device: str = "auto"
    ):
        self.model_path = Path(model_path)
        if not self.model_path.exists():
            raise FileNotFoundError(f"YOLO weights not found at: {self.model_path}")

        self.conf_threshold = conf_threshold
        self.iou_threshold = iou_threshold
        self.img_size = img_size

        # Resolve compute device
        if device == "auto":
            self.device = "0" if torch.cuda.is_available() else "cpu"
        else:
            self.device = device

        logger.info(f"Loading YOLO detector: {self.model_path.name} on device [{self.device}]")
        self.model = YOLO(str(self.model_path))

    def detect(
        self,
        image_or_path: Union[str, Path, np.ndarray],
        extract_crops: bool = True
    ) -> List[DetectionResult]:
        """
        Runs ear tag detection on a single image.
        
        Args:
            image_or_path: Image path or numpy BGR image array.
            extract_crops: Whether to crop detected tag regions.
            
        Returns:
            List of DetectionResult instances.
        """
        # Load image if path string was provided
        if isinstance(image_or_path, (str, Path)):
            img_bgr = cv2.imread(str(image_or_path))
            if img_bgr is None:
                logger.error(f"Failed to read image at: {image_or_path}")
                return []
        else:
            img_bgr = image_or_path

        h, w = img_bgr.shape[:2]

        results = self.model.predict(
            source=img_bgr,
            conf=self.conf_threshold,
            iou=self.iou_threshold,
            imgsz=self.img_size,
            device=self.device,
            verbose=False
        )

        detections: List[DetectionResult] = []
        if not results:
            return detections

        first_res = results[0]
        if first_res.boxes is None or len(first_res.boxes) == 0:
            return detections

        boxes = first_res.boxes.xyxy.cpu().numpy()
        confs = first_res.boxes.conf.cpu().numpy()
        cls_ids = first_res.boxes.cls.cpu().numpy().astype(int)
        names = first_res.names

        for box, conf, cls_id in zip(boxes, confs, cls_ids):
            x1, y1, x2, y2 = map(int, box)
            # Clip bounds to image dimensions
            x1, y1 = max(0, x1), max(0, y1)
            x2, y2 = min(w, x2), min(h, y2)

            crop = None
            if extract_crops and (x2 > x1 and y2 > y1):
                crop = img_bgr[y1:y2, x1:x2].copy()

            class_name = names.get(cls_id, "ear_tag")

            detections.append(
                DetectionResult(
                    box=[x1, y1, x2, y2],
                    confidence=float(conf),
                    class_id=int(cls_id),
                    class_name=class_name,
                    crop=crop
                )
            )

        return detections
