"""
extract_frames.py
Step 1 of the data pipeline.

Reads raw video files, runs a YOLO cattle detector on each frame,
crops the highest-confidence cow Region of Interest (ROI), resizes it
to the configured target size, and saves each ROI as a JPEG image.

Usage:
    python src/data/extract_frames.py
"""

import os
import sys
from pathlib import Path

import cv2
from ultralytics import YOLO

# Allow running from project root
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from src.utils.config_loader import get_config


def extract_roi_frames(cfg: dict) -> None:
    """Extract cattle ROI frames from all videos in raw_videos_dir.

    Args:
        cfg: Loaded configuration dictionary.
    """
    raw_videos_dir  = Path(cfg["paths"]["raw_videos_dir"])
    output_dir      = Path(cfg["paths"]["cleaned_frames_dir"])
    target_size     = cfg["dataset"]["raw_roi_size"]
    cow_class_id    = cfg["detection"]["cow_class_id"]
    yolo_weights    = Path(cfg["paths"]["weights_dir"]) / cfg["detection"]["yolo_weights"]

    output_dir.mkdir(parents=True, exist_ok=True)

    if not raw_videos_dir.exists():
        print(f"[ERROR] Raw videos directory not found: {raw_videos_dir}")
        return

    # Load YOLO detector
    print(f"Loading YOLO detector from: {yolo_weights}")
    model = YOLO(str(yolo_weights))

    # Gather video files
    video_extensions = (".mp4", ".avi", ".mkv", ".mov", ".MOV")
    video_files = [
        f for f in raw_videos_dir.iterdir()
        if f.suffix in video_extensions
    ]

    if not video_files:
        print(f"[WARNING] No video files found in: {raw_videos_dir}")
        return

    total_saved = 0

    for video_path in sorted(video_files):
        cap = cv2.VideoCapture(str(video_path))
        frame_id = 0
        saved = 0
        print(f"\nProcessing: {video_path.name}")

        while True:
            ret, frame = cap.read()
            if not ret:
                break

            # Detect cattle
            results = model(frame, verbose=False)
            if len(results[0].boxes) == 0:
                continue

            # Filter for cow class only
            cow_boxes = [
                b for b in results[0].boxes
                if int(b.cls) == cow_class_id
            ]
            if not cow_boxes:
                continue

            # Take the highest-confidence cow box
            best_box = max(cow_boxes, key=lambda b: float(b.conf))
            x1, y1, x2, y2 = best_box.xyxy[0].cpu().numpy().astype(int)

            roi = frame[y1:y2, x1:x2]
            if roi.size == 0:
                continue

            resized_roi = cv2.resize(roi, (target_size, target_size))

            save_path = output_dir / f"{video_path.stem}_frame{frame_id:06d}.jpg"
            cv2.imwrite(str(save_path), resized_roi)
            frame_id += 1
            saved += 1

        cap.release()
        print(f"  Saved {saved} ROI frames from {video_path.name}")
        total_saved += saved

    print(f"\nROI extraction complete. Total frames saved: {total_saved}")
    print(f"Output directory: {output_dir}")


if __name__ == "__main__":
    cfg = get_config()
    extract_roi_frames(cfg)
