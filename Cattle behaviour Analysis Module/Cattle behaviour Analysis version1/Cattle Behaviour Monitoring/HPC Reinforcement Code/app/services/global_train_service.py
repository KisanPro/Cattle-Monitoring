import os
import torch
import numpy as np
import shutil
from pathlib import Path
from torch import nn, optim
from torch.utils.data import DataLoader, Dataset
from app.core.config import settings
from app.services.train_service import VectorClassifier, VectorDataset

class GlobalAnonymizedDataset(Dataset):
    """
    Scans all farms in the farms directory to collect training samples anonymized 
    of any individual farm identifiers.
    """
    def __init__(self, farms_dir: Path):
        self.samples = []
        self.classes = set()
        
        farms_path = Path(farms_dir)
        if not farms_path.exists():
            return
            
        # Collect unique classes across all farms
        for farm_dir in farms_path.iterdir():
            if not farm_dir.is_dir():
                continue
            train_dir = farm_dir / "datasets" / "train"
            if not train_dir.exists():
                continue
            for label_dir in train_dir.iterdir():
                if label_dir.is_dir():
                    self.classes.add(label_dir.name)
                    
        self.classes = sorted(list(self.classes))
        self.class_to_idx = {name: idx for idx, name in enumerate(self.classes)}
        
        # Load file lists across all farms
        for farm_dir in farms_path.iterdir():
            if not farm_dir.is_dir():
                continue
            train_dir = farm_dir / "datasets" / "train"
            if not train_dir.exists():
                continue
            for label_dir in train_dir.iterdir():
                if not label_dir.is_dir():
                    continue
                class_label = label_dir.name
                cls_idx = self.class_to_idx[class_label]
                for f in label_dir.glob("*.npy"):
                    self.samples.append((f, cls_idx))

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        file_path, label = self.samples[idx]
        vector = np.load(file_path)
        vector = vector.squeeze()
        return torch.from_numpy(vector).float(), label

def run_global_distillation():
    """
    Aggregates training data from all farm environments, trains a universal
    base model, and saves it in the global workspace.
    """
    print("\n--- [HPC] Running Global Model Distillation Pipeline ---")
    
    farms_root = Path(settings.farms_dir)
    global_model_dir = Path("global_workspace/models")
    global_model_dir.mkdir(parents=True, exist_ok=True)
    
    dataset = GlobalAnonymizedDataset(farms_root)
    if len(dataset) < 2:
        print("[!] Insufficient aggregated data for global training. Need at least 2 samples.")
        return None
        
    device = torch.device(settings.device)
    loader = DataLoader(dataset, batch_size=16, shuffle=True)
    num_classes = len(dataset.classes)
    
    print(f"[*] Aggregated {len(dataset)} vector samples across {num_classes} classes: {dataset.classes}")
    
    # Train Global Model
    model = VectorClassifier(input_dim=1280, num_classes=num_classes)
    model.to(device)
    
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=1e-3)
    
    epochs = 20
    for epoch in range(epochs):
        model.train()
        total_loss = 0
        for vectors, labels in loader:
            vectors, labels = vectors.to(device), labels.to(device)
            optimizer.zero_grad()
            outputs = model(vectors)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            total_loss += loss.item()
            
        if (epoch + 1) % 5 == 0 or epoch == 0:
            print(f"    Global Epoch [{epoch+1}/{epochs}] | Aggregation Loss: {total_loss/len(loader):.4f}")
            
    # Save base model
    base_model_path = global_model_dir / "base_behavior_model.pt"
    torch.save(model.state_dict(), base_model_path)
    print(f"[SUCCESS] Anonymized Global Model saved to: {base_model_path}")
    return base_model_path
