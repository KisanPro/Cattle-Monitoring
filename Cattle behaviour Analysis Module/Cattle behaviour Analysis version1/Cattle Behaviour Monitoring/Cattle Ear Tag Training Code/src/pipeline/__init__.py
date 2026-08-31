"""
End-to-End Pipeline for Cattle Ear Tag Detection, Text Extraction, and Result Export.
"""

from .ear_tag_pipeline import EarTagPipeline, PipelineResult

__all__ = ["EarTagPipeline", "PipelineResult"]
