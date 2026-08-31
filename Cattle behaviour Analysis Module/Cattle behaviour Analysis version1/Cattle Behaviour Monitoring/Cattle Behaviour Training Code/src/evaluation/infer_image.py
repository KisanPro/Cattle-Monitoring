"""
infer_image.py
Run batch inference on a single image or a folder of images.

For each image, the predicted class and confidence score are overlaid
and saved to the output folder. A summary CSV is also written.

Usage:
    # Single image
    python src/evaluation/infer_image.py --mode posture --input path/to/image.jpg

    # Folder of images
    python src/evaluation/infer_image.py --mode all --input path/to/folder/

    # Custom output directory
    python src/evaluation/infer_image.py --mode feeding --input path/to/ --out results/batch_run
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import cv2
import numpy as np
import pandas as pd
import torch
from PIL import Image
from torchvision import transforms

# Allow running from project root
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from src.utils.config_loader import get_config
from src.utils.model_builder import load_behaviour_model

IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png")


def get_inference_transform(image_size: int, mean: list, std: list) -> transforms.Compose:
    """PIL-compatible transform for inference."""
    return transforms.Compose([
        transforms.Resize((image_size, image_size)),
        transforms.ToTensor(),
        transforms.Normalize(mean=mean, std=std),
    ])


def predict_images(args: argparse.Namespace) -> None:
    cfg = get_config()

    # ---- Resolve mode ---------------------------------------------------
    mode_map = {
        "posture": cfg["models"]["posture"],
        "feeding": cfg["models"]["feeding"],
        "all":     cfg["models"]["all_classes"],
    }
    if args.mode not in mode_map:
        raise ValueError(f"Unknown --mode '{args.mode}'. Choose: posture, feeding, all")

    model_cfg    = mode_map[args.mode]
    classes      = model_cfg["classes"]
    num_classes  = len(classes)
    weights_path = Path(cfg["paths"]["weights_dir"]) / model_cfg["weights"]

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Device   : {device}")
    print(f"Mode     : {args.mode}  |  Classes: {classes}")
    print(f"Weights  : {weights_path}")

    # ---- Collect input files -------------------------------------------
    input_path = Path(args.input)
    if input_path.is_dir():
        files = sorted(
            f for f in input_path.iterdir()
            if f.suffix.lower() in IMAGE_EXTENSIONS
        )
    elif input_path.is_file():
        files = [input_path]
    else:
        raise FileNotFoundError(f"Input not found: {input_path}")

    if not files:
        print("[WARNING] No image files found.")
        return

    # ---- Setup ---------------------------------------------------------
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    image_size = cfg["dataset"]["image_size"]
    transform  = get_inference_transform(image_size, cfg["training"]["mean"], cfg["training"]["std"])
    model      = load_behaviour_model(weights_path, num_classes, device, cfg["models"]["backbone"])

    infer_cfg  = cfg["inference"]
    font_scale = infer_cfg["font_scale"]
    thickness  = infer_cfg["font_thickness"]

    results = []
    print(f"\nProcessing {len(files)} image(s) -> {out_dir}\n")

    for img_path in files:
        img_pil = Image.open(img_path).convert("RGB")
        tensor  = transform(img_pil).unsqueeze(0).to(device)

        with torch.no_grad():
            output = model(tensor)
            probs  = torch.softmax(output, dim=1).cpu().numpy()[0]
            pred   = int(output.argmax(dim=1).cpu())

        label = classes[pred]
        score = float(probs[pred])
        results.append({"image": str(img_path), "prediction": label, "confidence": score})
        print(f"  {img_path.name:<40}  ->  {label}  ({score:.2%})")

        # Save annotated image
        vis = np.array(img_pil)[:, :, ::-1].copy()   # RGB - BGR
        cv2.putText(
            vis, f"{label} {score:.2f}", (10, 35),
            cv2.FONT_HERSHEY_SIMPLEX, font_scale, (0, 255, 0), thickness,
        )
        cv2.imwrite(str(out_dir / img_path.name), vis)

    # ---- Save CSV -------------------------------------------------------
    csv_path = out_dir / "predictions.csv"
    pd.DataFrame(results).to_csv(csv_path, index=False)
    print(f"\nSaved annotated images and predictions CSV to: {out_dir}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Run batch inference on images using a trained cattle behaviour model.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--mode", required=True, choices=["posture", "feeding", "all"])
    parser.add_argument("--input", required=True, help="Image file or folder path.")
    parser.add_argument("--out", default="results/inference", help="Output folder.")
    args = parser.parse_args()
    predict_images(args)
