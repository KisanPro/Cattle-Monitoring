"""
Detection package for Cattle Ear Tag localization and YOLO training.
"""

from .detector import EarTagDetector
from .trainer import EarTagTrainer

__all__ = ["EarTagDetector", "EarTagTrainer"]
