import os
import torch
import numpy as np
import shutil
from torch import nn, optim
from torch.utils.data import DataLoader, Dataset
from datetime import datetime
from pathlib import Path
from app.core.config import settings

# --- 1. Vector Dataset Logic ---
class VectorDataset(Dataset):
    """
    Loads .npy vector files and their class labels from subdirectories.
    """
    def __init__(self, root_dir):
        self.root_dir = Path(root_dir)
        self.samples = []
        self.classes = sorted([d.name for d in self.root_dir.iterdir() if d.is_dir()])
        self.class_to_idx = {cls_name: i for i, cls_name in enumerate(self.classes)}
        
        for cls_name in self.classes:
            cls_dir = self.root_dir / cls_name
            for f in cls_dir.glob("*.npy"):
                self.samples.append((f, self.class_to_idx[cls_name]))

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        file_path, label = self.samples[idx]
        vector = np.load(file_path)
        # Handle shape (1, 1280), (1280, 1) or (1280,)
        vector = vector.squeeze()
        return torch.from_numpy(vector).float(), label

# --- 2. Vector Classifier Architecture ---
class VectorClassifier(nn.Module):
    """
    Simple MLP to classify behavior embeddings.
    """
    def __init__(self, input_dim=1280, num_classes=2):
        super(VectorClassifier, self).__init__()
        self.network = nn.Sequential(
            nn.Linear(input_dim, 512),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(512, 256),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(256, num_classes)
        )

    def forward(self, x):
        return self.network(x)

from app.core.config import settings, TenantContext

# --- 3. Training Orchestration ---
def run_fine_tuning(tenant_id: str):
    """
    Continuous Learning Engine: Trains on behavioral vectors for a specific tenant.
    """
    print(f"\n--- [HUB] Intelligence Hub: Starting Vector Training Session for tenant '{tenant_id}' ---")
    
    tenant = TenantContext(tenant_id, Path(settings.farms_dir))
    device = torch.device(settings.device)
    train_path = tenant.datasets_dir / "train"
    
    if not train_path.exists() or len(list(train_path.iterdir())) == 0:
        print(f"[!] No training data found for tenant {tenant_id}. Waiting for vector batches...")
        return
    
    # Initialize Data
    dataset = VectorDataset(train_path)
    if len(dataset) < 2:
        print(f"[!] Not enough data to train yet for tenant {tenant_id}. Need at least 2 samples.")
        return
        
    loader = DataLoader(dataset, batch_size=16, shuffle=True)
    num_classes = len(dataset.classes)
    
    print(f"[*] Training on {len(dataset)} vectors across {num_classes} classes: {dataset.classes}")
    
    # Initialize Model
    model = VectorClassifier(input_dim=1280, num_classes=num_classes)
    model.to(device)
    
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=1e-3) # Higher LR for vectors
    
    # Training Loop
    epochs = 25
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
            print(f"    Epoch [{epoch+1}/{epochs}] | Loss: {total_loss/len(loader):.4f}")
    
    # Save Versioned Model
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    versioned_dir = tenant.model_dir / "trained" / timestamp
    versioned_dir.mkdir(parents=True, exist_ok=True)
    
    model_path = versioned_dir / "smarter_behavior_model.pt"
    torch.save(model.state_dict(), model_path)
    
    # Update latest
    latest_path = tenant.model_dir / "latest" / "smarter_behavior_model.pt"
    latest_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(model_path, latest_path)
    
    print(f"[SUCCESS] Smarter Vector Model (v{timestamp}) saved to 'latest' for tenant {tenant_id}.")
    return model_path
