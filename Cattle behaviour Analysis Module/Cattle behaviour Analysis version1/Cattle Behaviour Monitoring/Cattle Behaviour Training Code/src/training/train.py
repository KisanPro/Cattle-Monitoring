"""
train.py
Canonical training entry point for all cattle behaviour classification models.

Merges the best features from the previous 08_train.py / train_sam1.py:
  - AMP (Automatic Mixed Precision) for GPU acceleration
  - Class-balanced loss weights
  - Early stopping with configurable patience
  - ReduceLROnPlateau scheduler
  - Checkpoint save & resume
  - Per-epoch confusion matrix + classification report export
  - Optional TensorBoard logging

Usage:
    # Train posture model (Standing / Lying)
    python src/training/train.py --mode posture

    # Train feeding model (Feeding / Idle)
    python src/training/train.py --mode feeding

    # Train full 5-class model
    python src/training/train.py --mode all

    # Resume from checkpoint
    python src/training/train.py --mode posture --resume weights/standing_lying.pt

    # Override any config value via CLI
    python src/training/train.py --mode all --epochs 30 --batch-size 32
"""

from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path

import matplotlib
matplotlib.use("Agg")   # Non-interactive backend - avoids Tkinter crash in background/headless runs
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
import torch
from torch import nn, optim
from torch.utils.data import DataLoader
from torchvision import datasets

from sklearn.metrics import classification_report, confusion_matrix
from sklearn.utils.class_weight import compute_class_weight

# Allow running from project root
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from src.utils.config_loader import get_config
from src.utils.model_builder import build_efficientnetv2, load_behaviour_model
from src.utils.transforms import get_train_transform, get_val_transform


# ---------------------------------------------------------------------------
# Filtered dataset - loads only the class subfolders we need
# ---------------------------------------------------------------------------

class FilteredImageFolder(torch.utils.data.Dataset):
    """ImageFolder wrapper that only loads specified class subfolders.

    This lets us train a 2-class posture model (lying/standing) from the same
    Dataset/ directory that also contains drinking/eating/ruminating, without
    duplicating any data.

    Args:
        root:      Path to the split folder (e.g. Dataset/train).
        classes:   List of class names to include (must match subfolder names,
                   case-insensitive).
        transform: torchvision transform to apply to each image.
    """

    IMAGE_EXTS = (".jpg", ".jpeg", ".png")

    def __init__(self, root: Path, classes: list[str], transform=None):
        from PIL import Image as _PIL_Image
        self._PIL_Image = _PIL_Image
        self.transform = transform

        # Build case-insensitive lookup: lower(class_name) - folder path
        available = {d.name.lower(): d for d in Path(root).iterdir() if d.is_dir()}

        self.class_to_idx: dict[str, int] = {}
        self.samples: list[tuple[Path, int]] = []

        for idx, cls in enumerate(classes):
            folder = available.get(cls.lower())
            if folder is None:
                raise FileNotFoundError(
                    f"Class folder '{cls}' not found in {root}.\n"
                    f"Available folders: {list(available.keys())}"
                )
            self.class_to_idx[cls] = idx
            for img_path in sorted(folder.iterdir()):
                if img_path.suffix.lower() in self.IMAGE_EXTS:
                    self.samples.append((img_path, idx))

        self.classes = classes

    def __len__(self) -> int:
        return len(self.samples)

    def __getitem__(self, index: int):
        img_path, label = self.samples[index]
        img = self._PIL_Image.open(img_path).convert("RGB")
        if self.transform:
            img = self.transform(img)
        return img, label


# ---------------------------------------------------------------------------
# Plotting helpers
# ---------------------------------------------------------------------------

def plot_confusion_matrix(cm: np.ndarray, class_names: list[str], out_path: Path) -> None:
    """Save a labelled confusion matrix heatmap as a PNG."""
    plt.figure(figsize=(max(6, len(class_names)), max(5, len(class_names))))
    sns.heatmap(
        cm, annot=True, fmt="d", cmap="Blues",
        xticklabels=class_names, yticklabels=class_names,
    )
    plt.ylabel("True Label")
    plt.xlabel("Predicted Label")
    plt.title("Confusion Matrix (Validation)")
    plt.tight_layout()
    plt.savefig(out_path)
    plt.close()


def plot_training_curves(log: dict, out_path: Path) -> None:
    """Save train / val loss and accuracy curves as a PNG."""
    fig, axes = plt.subplots(1, 2, figsize=(12, 4))

    axes[0].plot(log["epoch"], log["train_loss"], label="Train Loss")
    axes[0].plot(log["epoch"], log["val_loss"],   label="Val Loss")
    axes[0].set_xlabel("Epoch")
    axes[0].set_ylabel("Loss")
    axes[0].set_title("Loss Curves")
    axes[0].legend()

    axes[1].plot(log["epoch"], log["train_acc"], label="Train Acc")
    axes[1].plot(log["epoch"], log["val_acc"],   label="Val Acc")
    axes[1].set_xlabel("Epoch")
    axes[1].set_ylabel("Accuracy")
    axes[1].set_title("Accuracy Curves")
    axes[1].legend()

    plt.tight_layout()
    plt.savefig(out_path)
    plt.close()


# ---------------------------------------------------------------------------
# Train / Validate loops
# ---------------------------------------------------------------------------

def train_one_epoch(
    model: nn.Module,
    loader: DataLoader,
    optimizer: optim.Optimizer,
    criterion: nn.Module,
    device: torch.device,
    epoch: int,
    scaler: torch.amp.GradScaler | None = None,
    accum_steps: int = 1,
) -> tuple[float, float]:
    """Run a single training epoch.

    Returns:
        ``(epoch_loss, epoch_accuracy)``
    """
    model.train()
    running_loss = correct = total = 0
    t0 = time.time()

    optimizer.zero_grad()
    for batch_idx, (images, labels) in enumerate(loader):
        images = images.to(device, non_blocking=True)
        labels = labels.to(device, non_blocking=True)

        device_type = "cuda" if device.type == "cuda" else "cpu"
        with torch.amp.autocast(device_type=device_type, enabled=(scaler is not None)):
            outputs = model(images)
            loss = criterion(outputs, labels) / accum_steps

        if scaler is not None:
            scaler.scale(loss).backward()
        else:
            loss.backward()

        if (batch_idx + 1) % accum_steps == 0:
            if scaler is not None:
                scaler.step(optimizer)
                scaler.update()
            else:
                optimizer.step()
            optimizer.zero_grad()

        running_loss += loss.item() * images.size(0) * accum_steps
        _, preds = torch.max(outputs.detach(), 1)
        correct += (preds == labels).sum().item()
        total   += labels.size(0)

    epoch_loss = running_loss / total if total else 0.0
    epoch_acc  = correct / total if total else 0.0
    elapsed    = time.time() - t0
    print(f"  Epoch {epoch:03d} | Train  loss={epoch_loss:.4f}  acc={epoch_acc:.4f}  ({elapsed:.1f}s)")
    return epoch_loss, epoch_acc


@torch.no_grad()
def validate(
    model: nn.Module,
    loader: DataLoader,
    criterion: nn.Module,
    device: torch.device,
    scaler: torch.amp.GradScaler | None = None,
) -> tuple[float, float, np.ndarray, np.ndarray]:
    """Run evaluation on a data loader.

    Returns:
        ``(val_loss, val_accuracy, predictions_array, ground_truth_array)``
    """
    model.eval()
    running_loss = correct = total = 0
    all_preds:  list[int] = []
    all_labels: list[int] = []

    for images, labels in loader:
        images = images.to(device, non_blocking=True)
        labels = labels.to(device, non_blocking=True)

        device_type = "cuda" if device.type == "cuda" else "cpu"
        with torch.amp.autocast(device_type=device_type, enabled=(scaler is not None)):
            outputs = model(images)
            loss = criterion(outputs, labels)

        running_loss += loss.item() * images.size(0)
        _, preds = torch.max(outputs, 1)
        all_preds.extend(preds.cpu().numpy())
        all_labels.extend(labels.cpu().numpy())
        correct += (preds == labels).sum().item()
        total   += labels.size(0)

    val_loss = running_loss / total if total else 0.0
    val_acc  = correct / total if total else 0.0
    print(f"           | Val    loss={val_loss:.4f}  acc={val_acc:.4f}")
    return val_loss, val_acc, np.array(all_preds), np.array(all_labels)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(args: argparse.Namespace) -> None:
    cfg = get_config()

    # ---- Resolve mode - classes & weight filename -------------------------
    mode_map = {
        "posture": cfg["models"]["posture"],
        "feeding": cfg["models"]["feeding"],
        "all":     cfg["models"]["all_classes"],
    }
    if args.mode not in mode_map:
        raise ValueError(f"Unknown --mode '{args.mode}'. Choose from: posture, feeding, all")

    model_cfg   = mode_map[args.mode]
    classes     = model_cfg["classes"]
    num_classes = len(classes)
    weight_file = model_cfg["weights"]

    # ---- Paths ------------------------------------------------------------
    dataset_dir  = Path(cfg["paths"]["dataset_dir"])
    weights_dir  = Path(cfg["paths"]["weights_dir"])
    results_dir  = Path(cfg["paths"]["results_dir"])
    weights_dir.mkdir(parents=True, exist_ok=True)
    results_dir.mkdir(parents=True, exist_ok=True)

    train_dir = dataset_dir / "train"
    val_dir   = dataset_dir / "val"

    # ---- Hyperparameters (config + CLI overrides) -------------------------
    tcfg      = cfg["training"]
    epochs    = args.epochs     or tcfg["epochs"]
    batch     = args.batch_size or tcfg["batch_size"]
    lr        = tcfg["learning_rate"]
    use_cuda  = tcfg["use_cuda"]
    use_amp   = tcfg["use_amp"]
    patience  = tcfg["early_stopping_patience"]
    accum     = tcfg["accumulation_steps"]
    mean      = tcfg["mean"]
    std       = tcfg["std"]
    image_sz  = cfg["dataset"]["image_size"]

    # ---- Device -----------------------------------------------------------
    device = torch.device("cuda" if (torch.cuda.is_available() and use_cuda) else "cpu")
    print(f"\n{'='*60}")
    print(f"  Mode     : {args.mode}  ({num_classes} classes: {classes})")
    print(f"  Device   : {device}")
    print(f"  Epochs   : {epochs}  |  Batch: {batch}  |  LR: {lr}")
    print(f"{'='*60}\n")

    # ---- Transforms -------------------------------------------------------
    train_transform = get_train_transform(image_sz, mean, std)
    val_transform   = get_val_transform(image_sz, mean, std)

    # For posture/feeding mode - load only the 2 relevant class folders.
    # For 'all' mode - load all 5 class folders from Dataset/.
    if args.mode == "all":
        train_ds = datasets.ImageFolder(train_dir, transform=train_transform)
        val_ds   = datasets.ImageFolder(val_dir,   transform=val_transform)
    else:
        train_ds = FilteredImageFolder(train_dir, classes, transform=train_transform)
        val_ds   = FilteredImageFolder(val_dir,   classes, transform=val_transform)

    print(f"Train samples : {len(train_ds)}  |  Val samples: {len(val_ds)}")

    # ---- Class weights ----------------------------------------------------
    y_labels      = [label for _, label in train_ds]
    cw_numpy      = compute_class_weight("balanced", classes=np.unique(y_labels), y=y_labels)
    class_weights = torch.tensor(cw_numpy, dtype=torch.float32)
    print(f"Class weights: { {classes[i]: f'{w:.3f}' for i, w in enumerate(cw_numpy)} }\n")

    # ---- Data loaders -----------------------------------------------------
    nw = tcfg["num_workers"]
    train_loader = DataLoader(
        train_ds, batch_size=batch, shuffle=True,
        num_workers=nw, pin_memory=tcfg["pin_memory"],
    )
    val_loader = DataLoader(
        val_ds, batch_size=batch, shuffle=False,
        num_workers=nw, pin_memory=tcfg["pin_memory"],
    )

    # ---- Model ------------------------------------------------------------
    # Strategy:
    #   1. If a local weights file already exists - load it (no internet needed).
    #   2. Otherwise try to download pretrained ImageNet weights from timm/HuggingFace.
    #      If SSL fails (common on corporate/restricted networks) - fall back to
    #      random init so training still starts.
    local_weights = weights_dir / weight_file
    if local_weights.exists():
        print(f"Found existing weights: {local_weights}")
        print("  Loading as starting point for continued training...\n")
        model = build_efficientnetv2(
            num_classes=num_classes,
            pretrained=False,           # don't download - we have local weights
            drop_rate=tcfg["drop_rate"],
            drop_path_rate=tcfg["drop_path_rate"],
            backbone=cfg["models"]["backbone"],
        )
        state = torch.load(local_weights, map_location="cpu", weights_only=False)
        # Support checkpoint dicts
        if isinstance(state, dict) and "state_dict" in state:
            state = state["state_dict"]
        # Strip DataParallel prefix if any
        state = {k.replace("module.", ""): v for k, v in state.items()}
        model.load_state_dict(state, strict=False)
        model = model.to(device)
    else:
        print("No local weights found - downloading pretrained ImageNet weights...")
        import ssl as _ssl
        import os as _os
        # Bypass SSL cert issues on Windows with corporate proxies
        _os.environ.setdefault("CURL_CA_BUNDLE", "")
        _os.environ.setdefault("REQUESTS_CA_BUNDLE", "")
        try:
            import timm as _timm
            _orig_ctx = _ssl._create_default_https_context
            _ssl._create_default_https_context = _ssl._create_unverified_context
            model = build_efficientnetv2(
                num_classes=num_classes,
                pretrained=tcfg["pretrained"],
                drop_rate=tcfg["drop_rate"],
                drop_path_rate=tcfg["drop_path_rate"],
                backbone=cfg["models"]["backbone"],
            ).to(device)
            _ssl._create_default_https_context = _orig_ctx
        except Exception as e:
            print(f"[WARNING] Pretrained download failed: {e}")
            print("[WARNING] Starting with random init. Training will still work.\n")
            model = build_efficientnetv2(
                num_classes=num_classes,
                pretrained=False,
                drop_rate=tcfg["drop_rate"],
                drop_path_rate=tcfg["drop_path_rate"],
                backbone=cfg["models"]["backbone"],
            ).to(device)

    # ---- Loss / optimiser / scheduler ------------------------------------
    criterion = nn.CrossEntropyLoss(weight=class_weights.to(device))
    optimizer = optim.Adam(model.parameters(), lr=lr, weight_decay=tcfg["weight_decay"])
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(
        optimizer,
        patience=tcfg["lr_scheduler_patience"],
        factor=tcfg["lr_scheduler_factor"],
    )

    # ---- AMP scaler -------------------------------------------------------
    scaler = torch.amp.GradScaler(enabled=True) if (use_amp and device.type == "cuda") else None

    # ---- Resume from checkpoint ------------------------------------------
    start_epoch = 1
    best_val    = -1.0

    if args.resume:
        resume_path = Path(args.resume)
        if resume_path.exists():
            ckpt = torch.load(resume_path, map_location=device)
            if "state_dict" in ckpt:
                model.load_state_dict(ckpt["state_dict"])
                optimizer.load_state_dict(ckpt.get("optimizer", {}))
                start_epoch = ckpt.get("epoch", 1) + 1
                best_val    = ckpt.get("best_val", -1.0)
                print(f"Resumed from {resume_path}  (epoch {start_epoch}, best_val={best_val:.4f})")
            else:
                model.load_state_dict(ckpt)
                print(f"Loaded weights from {resume_path}")
        else:
            print(f"[WARNING] Resume path not found: {resume_path}")

    # ---- Training loop ----------------------------------------------------
    log = {"epoch": [], "train_loss": [], "train_acc": [], "val_loss": [], "val_acc": []}
    patience_counter = 0
    best_epoch = None

    try:
        for epoch in range(start_epoch, epochs + 1):
            if device.type == "cuda":
                alloc  = torch.cuda.memory_allocated() / (1024**2)
                reserv = torch.cuda.memory_reserved()  / (1024**2)
                print(f"[GPU] allocated={alloc:.0f}MiB  reserved={reserv:.0f}MiB")

            train_loss, train_acc = train_one_epoch(
                model, train_loader, optimizer, criterion, device,
                epoch, scaler=scaler, accum_steps=accum,
            )
            val_loss, val_acc, preds, gts = validate(
                model, val_loader, criterion, device, scaler=scaler,
            )

            scheduler.step(val_loss)

            # Log
            log["epoch"].append(epoch)
            log["train_loss"].append(train_loss)
            log["train_acc"].append(train_acc)
            log["val_loss"].append(val_loss)
            log["val_acc"].append(val_acc)
            pd.DataFrame(log).to_csv(results_dir / "training_log.csv", index=False)

            # Save best
            if val_acc > best_val:
                best_val = val_acc
                best_epoch = epoch
                patience_counter = 0
                ckpt_path = weights_dir / weight_file
                torch.save(
                    {
                        "epoch":      epoch,
                        "state_dict": model.state_dict(),
                        "optimizer":  optimizer.state_dict(),
                        "best_val":   best_val,
                        "classes":    classes,
                    },
                    ckpt_path,
                )
                print(f"  [BEST] New best! Saved -> {ckpt_path}  (val_acc={best_val:.4f})")
            else:
                patience_counter += 1

            # Confusion matrix & report
            cm = confusion_matrix(gts, preds)
            plot_confusion_matrix(cm, classes, results_dir / "confusion_matrix.png")

            report_dict = classification_report(
                gts, preds, target_names=classes, output_dict=True,
            )
            pd.DataFrame(report_dict).T.to_csv(results_dir / "classification_report.csv")

            # Early stopping
            if patience_counter >= patience:
                print(f"\nEarly stopping triggered (no improvement for {patience} epochs).")
                break

            if device.type == "cuda":
                torch.cuda.empty_cache()

            print()

    except RuntimeError as exc:
        print(f"\n[RuntimeError] {exc}")
        print("Tip: reduce --batch-size or add --accum-steps to handle OOM errors.")
    finally:
        print(f"\n{'='*60}")
        print(f"Training complete. Best val_acc={best_val:.4f} at epoch {best_epoch}")
        print(f"{'='*60}\n")
        plot_training_curves(log, results_dir / "training_curves.png")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Train a cattle behaviour classification model.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--mode", required=True,
        choices=["posture", "feeding", "all"],
        help="Which model to train: posture (Standing/Lying), "
             "feeding (Feeding/Idle), or all (5-class).",
    )
    parser.add_argument("--epochs",     type=int,  default=None, help="Override config epochs.")
    parser.add_argument("--batch-size", type=int,  default=None, help="Override config batch size.")
    parser.add_argument(
        "--resume", type=str, default=None,
        help="Path to a checkpoint (.pt) to resume training from.",
    )
    args = parser.parse_args()
    main(args)
