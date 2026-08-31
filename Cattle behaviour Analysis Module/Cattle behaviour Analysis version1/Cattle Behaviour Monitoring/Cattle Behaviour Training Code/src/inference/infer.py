"""
infer.py
Unified real-time and video cattle behaviour inference pipeline.

Consolidates all 7 previous testing scripts into one clean entry point.
Uses YOLOv8 for detection + tracking and EfficientNetV2 for behaviour
classification.

Modes:
  posture  - Predicts Standing / Lying only
  feeding  - Predicts Feeding_Behaviour / Idle_Behaviour only
  both     - Runs both models simultaneously (full pipeline)

Sources:
  0, 1, 2  - Webcam index
  path/to/video.mp4  - Video file

Usage:
    # Live webcam - both models
    python src/inference/infer.py --source 0 --mode both

    # Video file - posture only
    python src/inference/infer.py --source path/to/video.mp4 --mode posture

    # Video file - feeding only
    python src/inference/infer.py --source path/to/video.mp4 --mode feeding

    # Save output video
    python src/inference/infer.py --source path/to/video.mp4 --mode both --save
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import cv2
import numpy as np
import torch
from ultralytics import YOLO

# Allow running from project root
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from src.utils.config_loader import get_config, resolve_weight_path
from src.utils.model_builder import load_behaviour_model
from src.utils.transforms import get_inference_transform
from src.utils.visualizer import (
    draw_cow_overlay,
    draw_other_overlay,
    draw_person_overlay,
)


# ---------------------------------------------------------------------------
# Prediction helpers
# ---------------------------------------------------------------------------

def predict_behaviour(
    crop: np.ndarray,
    model: torch.nn.Module,
    transform,
    device: torch.device,
    classes: list[str],
    thresholds: dict[str, float] | None = None,
) -> tuple[str, float]:
    """Run a single crop through a behaviour model.

    Args:
        crop:       BGR image crop (numpy array).
        model:      Loaded EfficientNetV2 behaviour model (eval mode).
        transform:  Inference transform pipeline.
        device:     Target device.
        classes:    Ordered list of class names.
        thresholds: Optional per-class confidence thresholds.
                    Prediction below threshold - returns ``"Uncertain"``.

    Returns:
        ``(predicted_class, confidence_score)``
    """
    tensor = transform(crop).unsqueeze(0).to(device)
    with torch.no_grad():
        logits = model(tensor)
        probs  = torch.softmax(logits, dim=1).squeeze().cpu().numpy()

    top_idx   = int(np.argmax(probs))
    behaviour = classes[top_idx]
    score     = float(probs[top_idx])

    if thresholds and score < thresholds.get(behaviour, 0.0):
        return "Uncertain", score

    return behaviour, score


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------

def run_inference(args: argparse.Namespace) -> None:
    cfg = get_config()

    # ---- Device -----------------------------------------------------------
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Using device : {device}")
    print(f"Mode         : {args.mode}")

    # ---- YOLO detector / tracker -----------------------------------------
    yolo_weights = resolve_weight_path(cfg, cfg["detection"]["yolo_weights"])
    print(f"YOLO weights : {yolo_weights}")
    detector = YOLO(str(yolo_weights))
    cow_class_id = cfg["detection"]["cow_class_id"]

    # ---- Behaviour models ------------------------------------------------
    image_size = cfg["dataset"]["image_size"]
    mean       = cfg["training"]["mean"]
    std        = cfg["training"]["std"]
    transform  = get_inference_transform(image_size, mean, std)
    backbone   = cfg["models"]["backbone"]

    posture_model = feed_model = all_model = None
    posture_classes = feed_classes = all_classes = []
    posture_thresholds = feed_thresholds = {}

    if args.mode in ("posture", "both"):
        pc          = cfg["models"]["posture"]
        posture_classes     = pc["classes"]
        posture_thresholds  = pc["confidence_thresholds"]
        posture_weights     = resolve_weight_path(cfg, pc["weights"])
        print(f"Posture weights: {posture_weights}")
        posture_model = load_behaviour_model(
            posture_weights, len(posture_classes), device, backbone,
        )

    if args.mode in ("feeding", "both"):
        fc         = cfg["models"]["feeding"]
        feed_classes    = fc["classes"]
        feed_thresholds = fc["confidence_thresholds"]
        feed_weights    = resolve_weight_path(cfg, fc["weights"])
        print(f"Feeding weights: {feed_weights}")
        feed_model = load_behaviour_model(
            feed_weights, len(feed_classes), device, backbone,
        )

    if args.mode == "all":
        ac = cfg["models"]["all_classes"]
        all_classes = ac["classes"]
        all_weights = resolve_weight_path(cfg, ac["weights"])
        print(f"5-Class Full Model weights: {all_weights}")
        all_model = load_behaviour_model(
            all_weights, len(all_classes), device, backbone,
        )

    # ---- Video / webcam source -------------------------------------------
    source = args.source
    try:
        source = int(source)   # webcam index
    except ValueError:
        pass                   # video file path

    cap = cv2.VideoCapture(source)
    if not cap.isOpened():
        print(f"[ERROR] Cannot open source: {source}")
        return

    # ---- Optional output video writer ------------------------------------
    writer = None
    if args.save:
        out_path  = Path(args.out)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        fps    = cap.get(cv2.CAP_PROP_FPS) or 25.0
        width  = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        writer = cv2.VideoWriter(
            str(out_path),
            cv2.VideoWriter_fourcc(*"mp4v"),
            fps,
            (width, height),
        )
        print(f"Saving output to: {out_path}")

    # ---- Inference configuration ----------------------------------------
    infer_cfg  = cfg["inference"]
    font_scale = infer_cfg["font_scale"]
    thickness  = infer_cfg["font_thickness"]

    source_label = f"Webcam {source}" if isinstance(source, int) else str(source)
    print(f"\n[INFO] Source: {source_label}")
    print("[INFO] Processing video frame by frame...\n")

    # ---- Main loop -------------------------------------------------------
    frame_count = 0
    while True:
        ret, frame = cap.read()
        if not ret:
            print("[INFO] End of video stream.")
            break

        frame_count += 1
        results = detector.track(
            frame,
            persist=True,
            classes=[cow_class_id],
            stream=True,
            verbose=False,
        )

        for result in results:
            boxes = result.boxes
            if boxes is None:
                continue

            for idx, obj in enumerate(boxes):
                x1, y1, x2, y2 = map(int, obj.xyxy[0])
                track_id = int(obj.id) if obj.id is not None else idx + 1
                cls_id   = int(obj.cls)
                box      = (x1, y1, x2, y2)

                # ---- Cow (class 19) -----------------------------------
                if cls_id == cow_class_id:
                    crop = frame[y1:y2, x1:x2]
                    if crop.size == 0:
                        continue

                    behaviour_labels: list[str] = []

                    if posture_model is not None:
                        posture, p_score = predict_behaviour(
                            crop, posture_model, transform, device,
                            posture_classes, posture_thresholds,
                        )
                        behaviour_labels.append(f"Posture: {posture} ({p_score:.2f})")

                    if feed_model is not None:
                        feeding, f_score = predict_behaviour(
                            crop, feed_model, transform, device,
                            feed_classes, feed_thresholds,
                        )
                        behaviour_labels.append(f"Feeding: {feeding} ({f_score:.2f})")

                    if all_model is not None:
                        beh, a_score = predict_behaviour(
                            crop, all_model, transform, device,
                            all_classes,
                        )
                        behaviour_labels.append(f"Behaviour: {beh} ({a_score:.2f})")

                    draw_cow_overlay(frame, box, track_id, behaviour_labels,
                                     font_scale, thickness)

                # ---- Person (class 0) ---------------------------------
                elif cls_id == 0:
                    draw_person_overlay(frame, box, track_id, font_scale, thickness)

                # ---- Other --------------------------------------------
                else:
                    label = detector.names[cls_id]
                    draw_other_overlay(frame, box, label, track_id, font_scale, thickness)

        if writer:
            writer.write(frame)

        try:
            cv2.imshow("Cattle Behaviour Monitor - press Q to quit", frame)
            if cv2.waitKey(1) & 0xFF == ord("q"):
                break
        except Exception:
            pass

    # ---- Cleanup ----------------------------------------------------------
    cap.release()
    if writer:
        writer.release()
    try:
        cv2.destroyAllWindows()
    except Exception:
        pass
    print(f"[SUCCESS] Inference complete. Processed {frame_count} frames.")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Real-time cattle behaviour inference (YOLO + EfficientNetV2).",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--source", required=True,
        help="Webcam index (0, 1, ...) or path to a video file.",
    )
    parser.add_argument(
        "--mode", required=True,
        choices=["posture", "feeding", "both", "all"],
        help="Which behaviour model(s) to run: posture, feeding, both, or all (5-class model).",
    )
    parser.add_argument(
        "--save", action="store_true",
        help="Save the annotated output video.",
    )
    parser.add_argument(
        "--out", default="results/inference/output.mp4",
        help="Output video path (only used with --save).",
    )
    args = parser.parse_args()
    run_inference(args)
