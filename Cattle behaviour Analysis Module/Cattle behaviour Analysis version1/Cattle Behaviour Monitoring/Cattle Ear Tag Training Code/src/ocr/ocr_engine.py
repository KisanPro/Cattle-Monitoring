from dataclasses import dataclass
from typing import List, Optional, Union
import cv2
import easyocr
import numpy as np
import torch

from .text_cleaner import clean_tag_text, is_valid_tag
from ..utils.logger import setup_logger

logger = setup_logger("EasyOCREngine")


@dataclass
class OCRPrediction:
    """Represents the OCR extraction result from a cropped ear tag image."""
    text: str
    confidence: float
    raw_results: List[dict]


class EasyOCREngine:
    """
    Wraps EasyOCR with specialized image preprocessing for cattle ear tags.
    """

    def __init__(
        self,
        languages: List[str] = None,
        use_gpu: bool = True,
        conf_threshold: float = 0.30,
        min_text_length: int = 2
    ):
        if languages is None:
            languages = ["en"]

        # Check GPU availability
        gpu_enabled = use_gpu and torch.cuda.is_available()
        logger.info(f"Initializing EasyOCR Reader for languages: {languages} | GPU: {gpu_enabled}")
        self.reader = easyocr.Reader(languages, gpu=gpu_enabled)
        self.conf_threshold = conf_threshold
        self.min_text_length = min_text_length

    def preprocess_crop(
        self,
        crop_bgr: np.ndarray,
        resize_factor: float = 2.0,
        apply_clahe: bool = True,
        denoise: bool = True
    ) -> np.ndarray:
        """
        Applies image enhancements tailored for farm ear tag visibility.
        """
        if crop_bgr is None or crop_bgr.size == 0:
            return crop_bgr

        # 1. Resize if image is small
        if resize_factor > 1.0:
            crop_bgr = cv2.resize(
                crop_bgr,
                (0, 0),
                fx=resize_factor,
                fy=resize_factor,
                interpolation=cv2.INTER_CUBIC
            )

        # 2. Grayscale conversion
        if len(crop_bgr.shape) == 3:
            gray = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2GRAY)
        else:
            gray = crop_bgr.copy()

        # 3. Denoising
        if denoise:
            gray = cv2.bilateralFilter(gray, d=5, sigmaColor=50, sigmaSpace=50)

        # 4. Contrast Limited Adaptive Histogram Equalization (CLAHE)
        if apply_clahe:
            clahe = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8))
            gray = clahe.apply(gray)

        return gray

    def recognize(
        self,
        crop_bgr: np.ndarray,
        preprocess: bool = True,
        resize_factor: float = 2.0,
        apply_clahe: bool = True,
        denoise: bool = True
    ) -> OCRPrediction:
        """
        Extracts tag text from an ear tag crop.
        
        Args:
            crop_bgr: Cropped BGR image of the ear tag.
            preprocess: Whether to apply contrast & noise enhancement.
            
        Returns:
            OCRPrediction instance with cleaned text and confidence.
        """
        if crop_bgr is None or crop_bgr.size == 0:
            return OCRPrediction(text="", confidence=0.0, raw_results=[])

        if preprocess:
            processed_img = self.preprocess_crop(
                crop_bgr,
                resize_factor=resize_factor,
                apply_clahe=apply_clahe,
                denoise=denoise
            )
        else:
            processed_img = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2GRAY) if len(crop_bgr.shape) == 3 else crop_bgr

        raw_ocr = self.reader.readtext(processed_img)

        candidates = []
        raw_items = []

        for bbox, raw_text, conf in raw_ocr:
            cleaned = clean_tag_text(raw_text)
            raw_items.append({"bbox": bbox, "raw_text": raw_text, "clean_text": cleaned, "conf": float(conf)})

            if is_valid_tag(cleaned, min_length=self.min_text_length) and conf >= self.conf_threshold:
                candidates.append((cleaned, float(conf)))

        if not candidates:
            # Fallback: try raw without pre-cleaning if confidence is decent
            for item in raw_items:
                if item["conf"] >= self.conf_threshold and len(item["raw_text"].strip()) >= self.min_text_length:
                    candidates.append((item["raw_text"].strip().upper(), item["conf"]))

        if candidates:
            # Sort by confidence descending
            candidates.sort(key=lambda x: x[1], reverse=True)
            best_text, best_conf = candidates[0]
            return OCRPrediction(text=best_text, confidence=best_conf, raw_results=raw_items)

        return OCRPrediction(text="", confidence=0.0, raw_results=raw_items)
