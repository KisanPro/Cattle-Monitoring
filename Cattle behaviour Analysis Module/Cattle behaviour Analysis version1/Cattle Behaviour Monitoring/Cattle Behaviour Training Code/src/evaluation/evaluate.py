"""
evaluate.py
Evaluates a trained behaviour classification model on the held-out test set.

Outputs:
  - Classification report (CSV)
  - Confusion matrix (CSV + PNG)

Usage:
    python src/evaluation/evaluate.py --mode posture
    python src/evaluation/evaluate.py --mode feeding
    python src/evaluation/evaluate.py --mode all
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")   # Non-interactive backend - avoids Tkinter crash in background runs
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns
import torch
from torch.utils.data import DataLoader
from torchvision import datasets

from sklearn.metrics import classification_report, confusion_matrix

# Allow running from project root
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from src.utils.config_loader import get_config
from src.utils.model_builder import load_behaviour_model
from src.utils.transforms import get_val_transform
from src.training.train import FilteredImageFolder


def evaluate(args: argparse.Namespace) -> None:
    cfg = get_config()

    # ---- Resolve mode -> model config ------------------------------------
    mode_map = {
        "posture": cfg["models"]["posture"],
        "feeding": cfg["models"]["feeding"],
        "all":     cfg["models"]["all_classes"],
    }
    if args.mode not in mode_map:
        raise ValueError(f"Unknown --mode '{args.mode}'. Choose: posture, feeding, all")

    model_cfg   = mode_map[args.mode]
    classes     = model_cfg["classes"]
    num_classes = len(classes)
    weights_path = Path(cfg["paths"]["weights_dir"]) / model_cfg["weights"]
    results_dir  = Path(cfg["paths"]["results_dir"])
    results_dir.mkdir(parents=True, exist_ok=True)

    # ---- Device -----------------------------------------------------------
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Device    : {device}")
    print(f"Mode      : {args.mode}  |  Classes: {classes}")
    print(f"Weights   : {weights_path}\n")

    # ---- Dataset ----------------------------------------------------------
    test_dir    = Path(cfg["paths"]["dataset_dir"]) / "test"
    transform   = get_val_transform(
        cfg["dataset"]["image_size"],
        cfg["training"]["mean"],
        cfg["training"]["std"],
    )
    if args.mode == "all":
        test_ds = datasets.ImageFolder(test_dir, transform=transform)
    else:
        test_ds = FilteredImageFolder(test_dir, classes, transform=transform)

    test_loader = DataLoader(test_ds, batch_size=32, shuffle=False, num_workers=0)
    print(f"Test set  : {len(test_ds)} images in {test_dir}")

    # ---- Model ------------------------------------------------------------
    model = load_behaviour_model(weights_path, num_classes, device, cfg["models"]["backbone"])

    # ---- Inference --------------------------------------------------------
    y_true: list[int] = []
    y_pred: list[int] = []

    with torch.no_grad():
        for images, labels in test_loader:
            images = images.to(device)
            outputs = model(images)
            preds   = torch.argmax(outputs, dim=1)
            y_true.extend(labels.numpy())
            y_pred.extend(preds.cpu().numpy())

    # ---- Classification report -------------------------------------------
    print("\nClassification Report:")
    report_str = classification_report(y_true, y_pred, target_names=classes)
    print(report_str)

    report_dict = classification_report(y_true, y_pred, target_names=classes, output_dict=True)
    report_path = results_dir / f"test_classification_report_{args.mode}.csv"
    pd.DataFrame(report_dict).T.to_csv(report_path)
    print(f"Saved: {report_path}")

    # ---- Confusion matrix ------------------------------------------------
    cm = confusion_matrix(y_true, y_pred)
    print("\nConfusion Matrix:")
    print(cm)

    cm_csv_path = results_dir / f"test_confusion_matrix_{args.mode}.csv"
    pd.DataFrame(cm, index=classes, columns=classes).to_csv(cm_csv_path)
    print(f"Saved: {cm_csv_path}")

    cm_png_path = results_dir / f"test_confusion_matrix_{args.mode}.png"
    plt.figure(figsize=(max(6, num_classes), max(5, num_classes)))
    sns.heatmap(
        cm, annot=True, fmt="d", cmap="Blues",
        xticklabels=classes, yticklabels=classes,
    )
    plt.title(f"Test Confusion Matrix - {args.mode}")
    plt.xlabel("Predicted")
    plt.ylabel("Actual")
    plt.tight_layout()
    plt.savefig(cm_png_path)
    plt.close()
    print(f"Saved: {cm_png_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Evaluate a trained cattle behaviour model on the test set.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--mode", required=True,
        choices=["posture", "feeding", "all"],
        help="Which model to evaluate.",
    )
    args = parser.parse_args()
    evaluate(args)
