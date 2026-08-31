"""
process_folder.py
Batch processes all images and videos inside a specified folder (default: cattle_testing/cattle_input/)
using YOLOv8 (cattle detection/tracking) + EfficientNetV2 behaviour model(s).

Supported Modes (--mode):
    - posture : Posture model only (standing_lying.pt -> Standing vs Lying)
    - feeding : Feeding model only (food_idle_behavior.pt -> Feeding vs Idle)
    - both    : Dual models simultaneously (Posture + Feeding stacked overlays) [DEFAULT]
    - all     : Full 5-class model (all_5_classes.pt -> drinking, eating, lying, ruminating, standing)

Outputs annotated results to cattle_testing/cattle_output/ (or custom --out).

Usage:
    python src/inference/process_folder.py
    python src/inference/process_folder.py --mode both
    python src/inference/process_folder.py --mode all
    python src/inference/process_folder.py --mode posture --input custom_in/ --out custom_out/
"""

from __future__ import annotations

import argparse
import sys
import time
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

IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png")
VIDEO_EXTENSIONS = (".mp4", ".avi", ".mov", ".mkv", ".MOV")


def predict_crop(
    crop: np.ndarray,
    model: torch.nn.Module,
    transform,
    device: torch.device,
    classes: list[str],
    thresholds: dict[str, float] | None = None,
) -> tuple[str, float]:
    """Classify a cropped image of a cow using a behaviour model."""
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


def process_single_image(
    img_path: Path,
    out_path: Path,
    detector: YOLO,
    models_dict: dict[str, dict],
    transform,
    device: torch.device,
    cow_class_id: int,
    infer_cfg: dict,
) -> None:
    """Process a single image file."""
    frame = cv2.imread(str(img_path))
    if frame is None:
        print(f"  [ERROR] Unreadable image: {img_path.name}", flush=True)
        return

    font_scale = infer_cfg["font_scale"]
    thickness  = infer_cfg["font_thickness"]

    results = detector(frame, verbose=False)[0]
    cow_count = 0

    for idx, box in enumerate(results.boxes):
        cls_id = int(box.cls)
        x1, y1, x2, y2 = map(int, box.xyxy[0])
        b_tuple = (x1, y1, x2, y2)

        if cls_id == cow_class_id:
            cow_count += 1
            crop = frame[y1:y2, x1:x2]
            if crop.size == 0:
                continue

            labels = []
            for name, mdata in models_dict.items():
                pred_label, score = predict_crop(
                    crop, mdata["model"], transform, device, mdata["classes"], mdata.get("thresholds")
                )
                if name == "all":
                    labels.append(f"Behaviour: {pred_label} ({score:.2f})")
                else:
                    labels.append(f"{name.capitalize()}: {pred_label} ({score:.2f})")

            draw_cow_overlay(frame, b_tuple, cow_count, labels, font_scale, thickness)

        elif cls_id == 0:
            draw_person_overlay(frame, b_tuple, idx + 1, font_scale, thickness)
        else:
            label = detector.names[cls_id]
            draw_other_overlay(frame, b_tuple, label, idx + 1, font_scale, thickness)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(out_path), frame)
    print(f"  [IMAGE DONE] {img_path.name} -> {out_path.name} ({cow_count} cows detected)", flush=True)


def process_single_video(
    video_path: Path,
    out_path: Path,
    detector: YOLO,
    models_dict: dict[str, dict],
    transform,
    device: torch.device,
    cow_class_id: int,
    infer_cfg: dict,
) -> None:
    """Process a single video file."""
    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        print(f"  [ERROR] Cannot open video: {video_path.name}", flush=True)
        return

    fps    = cap.get(cv2.CAP_PROP_FPS) or 25.0
    width  = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    writer = cv2.VideoWriter(
        str(out_path),
        cv2.VideoWriter_fourcc(*"mp4v"),
        fps,
        (width, height),
    )

    font_scale = infer_cfg["font_scale"]
    thickness  = infer_cfg["font_thickness"]

    frame_count = 0
    t0 = time.time()
    print(f"  [PROCESSING VIDEO] {video_path.name} ({total_frames} frames)...", flush=True)

    while True:
        ret, frame = cap.read()
        if not ret:
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

                if cls_id == cow_class_id:
                    crop = frame[y1:y2, x1:x2]
                    if crop.size == 0:
                        continue

                    labels = []
                    for name, mdata in models_dict.items():
                        pred_label, score = predict_crop(
                            crop, mdata["model"], transform, device, mdata["classes"], mdata.get("thresholds")
                        )
                        if name == "all":
                            labels.append(f"Behaviour: {pred_label} ({score:.2f})")
                        else:
                            labels.append(f"{name.capitalize()}: {pred_label} ({score:.2f})")

                    draw_cow_overlay(frame, box, track_id, labels, font_scale, thickness)

        writer.write(frame)

        if frame_count % 100 == 0 or frame_count == total_frames:
            pct = (frame_count / total_frames * 100) if total_frames > 0 else 0
            print(f"    -> {video_path.name}: {frame_count}/{total_frames} frames ({pct:.0f}%)", flush=True)

    cap.release()
    writer.release()
    elapsed = time.time() - t0
    print(f"  [VIDEO DONE] {video_path.name} -> {out_path.name} ({frame_count} frames, {elapsed:.1f}s)", flush=True)


def batch_process(args: argparse.Namespace) -> None:
    cfg = get_config()

    input_dir  = Path(args.input).resolve() if args.input else Path(cfg["paths"]["cattle_test_input_dir"])
    output_dir = Path(args.out).resolve()   if args.out   else Path(cfg["paths"]["cattle_test_output_dir"])
    output_dir.mkdir(parents=True, exist_ok=True)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print("============================================================", flush=True)
    print(f"Batch Processing Cattle Testing Directory (Mode: {args.mode.upper()})", flush=True)
    print(f"Device    : {device}", flush=True)
    print(f"Input Dir : {input_dir}", flush=True)
    print(f"Output Dir: {output_dir}", flush=True)
    print("============================================================\n", flush=True)

    if not input_dir.exists():
        print(f"[ERROR] Input directory not found: {input_dir}", flush=True)
        return

    # Load YOLO
    yolo_weights = resolve_weight_path(cfg, cfg["detection"]["yolo_weights"])
    print(f"Loading YOLO detector: {yolo_weights}", flush=True)
    detector = YOLO(str(yolo_weights))
    cow_class_id = cfg["detection"]["cow_class_id"]

    # Load requested behaviour models
    backbone = cfg["models"]["backbone"]
    models_dict = {}

    if args.mode in ("posture", "both"):
        p_cfg = cfg["models"]["posture"]
        p_weights = resolve_weight_path(cfg, p_cfg["weights"])
        print(f"Loading Posture model: {p_weights}", flush=True)
        models_dict["posture"] = {
            "model": load_behaviour_model(p_weights, len(p_cfg["classes"]), device, backbone),
            "classes": p_cfg["classes"],
            "thresholds": p_cfg.get("confidence_thresholds", {}),
        }

    if args.mode in ("feeding", "both"):
        f_cfg = cfg["models"]["feeding"]
        f_weights = resolve_weight_path(cfg, f_cfg["weights"])
        print(f"Loading Feeding model: {f_weights}", flush=True)
        models_dict["feeding"] = {
            "model": load_behaviour_model(f_weights, len(f_cfg["classes"]), device, backbone),
            "classes": f_cfg["classes"],
            "thresholds": f_cfg.get("confidence_thresholds", {}),
        }

    if args.mode == "all":
        a_cfg = cfg["models"]["all_classes"]
        a_weights = resolve_weight_path(cfg, a_cfg["weights"])
        print(f"Loading 5-Class Full Behaviour model: {a_weights}", flush=True)
        models_dict["all"] = {
            "model": load_behaviour_model(a_weights, len(a_cfg["classes"]), device, backbone),
            "classes": a_cfg["classes"],
            "thresholds": {},
        }

    # Transforms & Config
    image_size = cfg["dataset"]["image_size"]
    mean       = cfg["training"]["mean"]
    std        = cfg["training"]["std"]
    transform  = get_inference_transform(image_size, mean, std)
    infer_cfg  = cfg["inference"]

    # Collect files
    input_files = sorted([
        f for f in input_dir.iterdir()
        if f.is_file() and f.suffix.lower() in (IMAGE_EXTENSIONS + VIDEO_EXTENSIONS)
    ])

    if not input_files:
        print(f"[WARNING] No images or videos found in: {input_dir}", flush=True)
        return

    print(f"\nFound {len(input_files)} file(s) to process:\n", flush=True)

    for i, fpath in enumerate(input_files, 1):
        print(f"[{i}/{len(input_files)}] Processing: {fpath.name}", flush=True)
        ext = fpath.suffix.lower()
        out_path = output_dir / fpath.name

        if ext in IMAGE_EXTENSIONS:
            process_single_image(
                fpath, out_path, detector, models_dict,
                transform, device, cow_class_id, infer_cfg,
            )
        elif ext in VIDEO_EXTENSIONS:
            process_single_video(
                fpath, out_path, detector, models_dict,
                transform, device, cow_class_id, infer_cfg,
            )

    print("\n============================================================", flush=True)
    print(f"ALL {len(input_files)} FILES PROCESSED SUCCESSFULLY!", flush=True)
    print(f"Output directory: {output_dir}", flush=True)
    print("============================================================", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Batch process cattle testing directory for images and videos.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--mode", default="both",
        choices=["posture", "feeding", "both", "all"],
        help="Which model(s) to run: posture, feeding, both (dual overlay), or all (5-class model).",
    )
    parser.add_argument(
        "--input", default=None,
        help="Input folder path (defaults to cattle_testing/cattle_input).",
    )
    parser.add_argument(
        "--out", default=None,
        help="Output folder path (defaults to cattle_testing/cattle_output).",
    )
    args = parser.parse_args()
    batch_process(args)
