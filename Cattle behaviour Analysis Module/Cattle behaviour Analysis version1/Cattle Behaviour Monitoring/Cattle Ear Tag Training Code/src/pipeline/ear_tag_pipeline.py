import json
import time
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import List, Union, Optional, Dict, Any
import cv2
import numpy as np
import pandas as pd
from tqdm import tqdm

from ..config_loader import load_config
from ..detection.detector import EarTagDetector, DetectionResult
from ..ocr.ocr_engine import EasyOCREngine, OCRPrediction
from ..utils.logger import setup_logger
from ..utils.visualizer import Visualizer

logger = setup_logger("EarTagPipeline")


@dataclass
class EarTagRecord:
    """Structured data record for a detected ear tag."""
    image_name: str
    tag_id: str
    det_confidence: float
    ocr_confidence: float
    box_x1: int
    box_y1: int
    box_x2: int
    box_y2: int
    timestamp: str


@dataclass
class PipelineResult:
    """Result for a processed image."""
    image_path: str
    records: List[EarTagRecord]
    annotated_image: Optional[np.ndarray] = None


class EarTagPipeline:
    """
    End-to-end pipeline connecting YOLO ear tag localization, EasyOCR extraction,
    visual annotation, and structured data export (CSV/JSON).
    """

    def __init__(
        self,
        config: Optional[Dict[str, Any]] = None,
        model_path: Optional[str] = None,
        det_conf: Optional[float] = None,
        ocr_conf: Optional[float] = None,
        device: Optional[str] = None,
        use_gpu_ocr: bool = True
    ):
        # Load default config if not provided
        self.config = config or load_config()

        # Resolve paths & thresholds from config or CLI overrides
        weights = model_path or self.config.get("paths", {}).get("default_detection_model", "models/best.pt")
        d_conf = det_conf if det_conf is not None else self.config.get("detection", {}).get("conf_threshold", 0.35)
        d_iou = self.config.get("detection", {}).get("iou_threshold", 0.50)
        d_imgsz = self.config.get("detection", {}).get("img_size", 640)
        d_device = device or self.config.get("detection", {}).get("device", "auto")

        o_conf = ocr_conf if ocr_conf is not None else self.config.get("ocr", {}).get("conf_threshold", 0.30)
        o_langs = self.config.get("ocr", {}).get("languages", ["en"])
        o_minlen = self.config.get("ocr", {}).get("min_text_length", 2)
        o_gpu = use_gpu_ocr and self.config.get("ocr", {}).get("use_gpu", True)

        self.ocr_preprocess_cfg = self.config.get("ocr", {}).get("preprocess", {})

        # Initialize sub-modules
        self.detector = EarTagDetector(
            model_path=weights,
            conf_threshold=d_conf,
            iou_threshold=d_iou,
            img_size=d_imgsz,
            device=d_device
        )

        self.ocr_engine = EasyOCREngine(
            languages=o_langs,
            use_gpu=o_gpu,
            conf_threshold=o_conf,
            min_text_length=o_minlen
        )

        self.visualizer = Visualizer()

    def process_image(
        self,
        image_input: Union[str, Path, np.ndarray],
        save_annotated_to: Optional[Union[str, Path]] = None,
        save_crops_to: Optional[Union[str, Path]] = None
    ) -> PipelineResult:
        """
        Runs full pipeline on a single image.
        """
        if isinstance(image_input, (str, Path)):
            img_path = Path(image_input)
            img_name = img_path.name
            img_bgr = cv2.imread(str(img_path))
            if img_bgr is None:
                logger.error(f"Unable to read image: {img_path}")
                return PipelineResult(image_path=str(img_path), records=[])
        else:
            img_bgr = image_input
            img_name = f"frame_{int(time.time() * 1000)}.jpg"
            img_path = Path(img_name)

        detections = self.detector.detect(img_bgr, extract_crops=True)
        records: List[EarTagRecord] = []
        annotated_img = img_bgr.copy()

        current_time = time.strftime("%Y-%m-%d %H:%M:%S")

        for idx, det in enumerate(detections):
            # Run OCR on crop
            ocr_res = OCRPrediction(text="", confidence=0.0, raw_results=[])
            if det.crop is not None:
                ocr_res = self.ocr_engine.recognize(
                    det.crop,
                    preprocess=True,
                    resize_factor=self.ocr_preprocess_cfg.get("resize_factor", 2.0),
                    apply_clahe=self.ocr_preprocess_cfg.get("apply_clahe", True),
                    denoise=self.ocr_preprocess_cfg.get("denoise", True)
                )

                # Save crop image if requested
                if save_crops_to:
                    crops_dir = Path(save_crops_to)
                    crops_dir.mkdir(parents=True, exist_ok=True)
                    crop_filename = f"{img_path.stem}_tag{idx}_{ocr_res.text or 'unknown'}.jpg"
                    cv2.imwrite(str(crops_dir / crop_filename), det.crop)

            display_text = ocr_res.text if ocr_res.text else "ear_tag"

            # Create structured record
            record = EarTagRecord(
                image_name=img_name,
                tag_id=ocr_res.text,
                det_confidence=round(det.confidence, 4),
                ocr_confidence=round(ocr_res.confidence, 4),
                box_x1=det.box[0],
                box_y1=det.box[1],
                box_x2=det.box[2],
                box_y2=det.box[3],
                timestamp=current_time
            )
            records.append(record)

            # Annotate visual frame
            annotated_img = self.visualizer.draw_detection(
                image=annotated_img,
                box=det.box,
                label=display_text,
                det_conf=det.confidence,
                ocr_conf=ocr_res.confidence
            )

        if save_annotated_to:
            out_file = Path(save_annotated_to)
            out_file.parent.mkdir(parents=True, exist_ok=True)
            cv2.imwrite(str(out_file), annotated_img)

        return PipelineResult(
            image_path=str(img_path),
            records=records,
            annotated_image=annotated_img
        )

    def process_directory(
        self,
        input_dir: Union[str, Path],
        output_dir: Union[str, Path] = "output/results",
        save_crops: bool = False,
        export_csv: bool = True,
        export_json: bool = True
    ) -> List[EarTagRecord]:
        """
        Processes all images in a directory, saves annotated copies, and exports reports.
        """
        input_path = Path(input_dir)
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        crops_dir = output_path / "crops" if save_crops else None

        valid_exts = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
        image_files = [p for p in input_path.iterdir() if p.suffix.lower() in valid_exts]

        if not image_files:
            logger.warning(f"No valid image files found in {input_path}")
            return []

        logger.info(f"Processing {len(image_files)} images from: {input_path}")
        all_records: List[EarTagRecord] = []

        for img_file in tqdm(image_files, desc="Running Pipeline"):
            save_path = output_path / f"annotated_{img_file.name}"
            result = self.process_image(
                image_input=img_file,
                save_annotated_to=save_path,
                save_crops_to=crops_dir
            )
            all_records.extend(result.records)

        # Export structured reports
        if all_records:
            df = pd.DataFrame([asdict(r) for r in all_records])
            if export_csv:
                csv_path = output_path / "ear_tag_results.csv"
                df.to_csv(csv_path, index=False)
                logger.info(f"📊 Exported CSV results to: {csv_path}")

            if export_json:
                json_path = output_path / "ear_tag_results.json"
                with open(json_path, "w", encoding="utf-8") as f:
                    json.dump([asdict(r) for r in all_records], f, indent=2)
                logger.info(f"📊 Exported JSON results to: {json_path}")
        else:
            logger.info("No ear tags detected across input files.")

        return all_records
