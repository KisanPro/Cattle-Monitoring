"""
OCR and Text Recognition Package for Cattle Ear Tags.
"""

from .ocr_engine import EasyOCREngine, OCRPrediction
from .text_cleaner import clean_tag_text, is_valid_tag

__all__ = ["EasyOCREngine", "OCRPrediction", "clean_tag_text", "is_valid_tag"]
