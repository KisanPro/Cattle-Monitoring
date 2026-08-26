import os
import sys
import torch
import torch.optim as optim
from torch.utils.data import DataLoader

project_dir = r"F:\Cattle Keypoints detection Training Code"
sys.path.append(project_dir)

from dataset import KeypointDataset
from models.keypoint_model.law_model import MobilePoseNetV3
from models.keypoint_model.loss import KeypointLoss

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

def train_view(view="side", num_keypoints=7, epochs=15, batch_size=16, lr=0.001):
    print(f"\n============================================================", flush=True)
    print(f"[TRAIN] Training MobilePoseNetV3 Model for {view.upper()} VIEW ({num_keypoints} Keypoints)...", flush=True)
    print(f"============================================================", flush=True)
    
    img_dir = os.path.join(project_dir, "dataset", f"{view}_view")
    ann_file = os.path.join(project_dir, "annotations", f"{view}_annotations.json")
    
    dataset = KeypointDataset(img_dir, ann_file, augment=True)
    dataloader = DataLoader(dataset, batch_size=batch_size, shuffle=True)
    
    model = MobilePoseNetV3(num_keypoints=num_keypoints).to(DEVICE)
    criterion = KeypointLoss()
    optimizer = optim.Adam(model.parameters(), lr=lr)
    
    best_loss = float('inf')
    save_path = os.path.join(project_dir, "models", "kp_weights", f"kp_{view}_best.pth")
    
    for epoch in range(1, epochs + 1):
        model.train()
        running_loss = 0.0
        
        for pyramid, keypoints in dataloader:
            pyramid = [p.to(DEVICE) for p in pyramid]
            keypoints = keypoints.to(DEVICE)
            
            optimizer.zero_grad()
            preds = model(pyramid)
            loss = criterion(preds, keypoints)
            loss.backward()
            optimizer.step()
            
            running_loss += loss.item() * keypoints.size(0)
            
        epoch_loss = running_loss / len(dataset)
        
        if epoch_loss < best_loss:
            best_loss = epoch_loss
            torch.save(model.state_dict(), save_path)
            
        print(f"  Epoch [{epoch:02d}/{epochs:02d}] - Loss: {epoch_loss:.4f} (Best: {best_loss:.4f})", flush=True)
            
    print(f"[SUCCESS] {view.upper()} View Keypoint Model trained and saved to: {save_path}\n", flush=True)

if __name__ == "__main__":
    train_view(view="side", num_keypoints=7, epochs=15, batch_size=16)
    train_view(view="back", num_keypoints=2, epochs=15, batch_size=16)
