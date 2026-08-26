import os
import random
import math
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
from torchvision import transforms
from PIL import Image
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

# Import custom ArcFace loss module
from arcface_loss import ArcMarginProduct
from facenet_pytorch import InceptionResnetV1

# Set seeds for reproducibility
def set_seed(seed=42):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)

class FaceDataset(Dataset):
    def __init__(self, image_paths, labels, transform=None):
        self.image_paths = image_paths
        self.labels = labels
        self.transform = transform

    def __len__(self):
        return len(self.image_paths)

    def __getitem__(self, idx):
        img_path = self.image_paths[idx]
        label = self.labels[idx]
        
        # Open image and convert to RGB
        img = Image.open(img_path).convert('RGB')
        
        if self.transform:
            img = self.transform(img)
            
        return img, torch.tensor(label, dtype=torch.long)

def get_splits(processed_dir, train_ratio=0.70, val_ratio=0.15, test_ratio=0.15):
    categories = sorted(os.listdir(processed_dir))
    class_to_idx = {cat: idx for idx, cat in enumerate(categories)}
    idx_to_class = {idx: cat for cat, idx in class_to_idx.items()}
    
    train_paths, train_labels = [], []
    val_paths, val_labels = [], []
    test_paths, test_labels = [], []
    
    for cat in categories:
        cat_path = os.path.join(processed_dir, cat)
        if not os.path.isdir(cat_path):
            continue
            
        img_names = [f for f in os.listdir(cat_path) if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
        # Chronological split (no shuffle to prevent frame-leakage between train and validation)
        
        n_total = len(img_names)
        n_train = int(n_total * train_ratio)
        n_val = int(n_total * val_ratio)
        
        train_files = img_names[:n_train]
        val_files = img_names[n_train:n_train + n_val]
        test_files = img_names[n_train + n_val:]
        
        # Add to lists
        for f in train_files:
            train_paths.append(os.path.join(cat_path, f))
            train_labels.append(class_to_idx[cat])
            
        for f in val_files:
            val_paths.append(os.path.join(cat_path, f))
            val_labels.append(class_to_idx[cat])
            
        for f in test_files:
            test_paths.append(os.path.join(cat_path, f))
            test_labels.append(class_to_idx[cat])
            
    print(f"Dataset split summary:")
    print(f"  Train: {len(train_paths)} images")
    print(f"  Val:   {len(val_paths)} images")
    print(f"  Test:  {len(test_paths)} images")
    print(f"  Classes: {class_to_idx}")
    
    return (train_paths, train_labels), (val_paths, val_labels), (test_paths, test_labels), class_to_idx

def main():
    set_seed(42)
    
    processed_dir = os.path.join("Dataset", "processed")
    if not os.path.exists(processed_dir) or len(os.listdir(processed_dir)) == 0:
        print(f"Error: Processed directory '{processed_dir}' is empty or does not exist. Please run preprocess.py first.")
        return
        
    # Get dataset splits
    train_data, val_data, test_data, class_to_idx = get_splits(processed_dir)
    
    # Save the splits filenames to avoid leakage and for evaluation
    torch.save({
        'train_data': train_data,
        'val_data': val_data,
        'test_data': test_data,
        'class_to_idx': class_to_idx
    }, 'dataset_splits.pth')
    
    # Transforms
    # Standard FaceNet normalization: scale input [0.0, 1.0] tensor to [-0.996, 1.0] using (x*255 - 127.5)/128.0
    facenet_norm = transforms.Compose([
        transforms.ToTensor(),
        transforms.Lambda(lambda x: (x * 255.0 - 127.5) / 128.0)
    ])
    
    # Strong augmentations to prevent overfitting to specific camera angles and lighting
    train_transform = transforms.Compose([
        transforms.RandomHorizontalFlip(p=0.5),
        transforms.RandomRotation(degrees=15),
        transforms.RandomAffine(degrees=10, translate=(0.05, 0.05), scale=(0.95, 1.05)),
        transforms.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.3, hue=0.05),
        facenet_norm
    ])
    
    val_transform = facenet_norm
    
    # Datasets and Loaders
    train_dataset = FaceDataset(train_data[0], train_data[1], transform=train_transform)
    val_dataset = FaceDataset(val_data[0], val_data[1], transform=val_transform)
    
    train_loader = DataLoader(train_dataset, batch_size=32, shuffle=True, num_workers=0)
    val_loader = DataLoader(val_dataset, batch_size=32, shuffle=False, num_workers=0)
    
    # Models
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Using device: {device}")
    
    # Load InceptionResnetV1 backbone
    backbone = InceptionResnetV1(pretrained='vggface2').eval()
    
    # Freeze backbone weights EXCEPT last_linear and last_bn to prevent overfitting
    # and retain the generalized FaceNet features pre-trained on VGGFace2
    for name, param in backbone.named_parameters():
        if "last_linear" in name or "last_bn" in name:
            param.requires_grad = True
        else:
            param.requires_grad = False
            
    # Initialize ArcFace layer
    num_classes = len(class_to_idx)
    arcface_layer = ArcMarginProduct(in_features=512, out_features=num_classes, s=30.0, m=0.50)
    
    backbone = backbone.to(device)
    arcface_layer = arcface_layer.to(device)
    
    # Define Optimizer and Scheduler
    # We only pass trainable parameters to optimizer
    trainable_params = [
        {'params': filter(lambda p: p.requires_grad, backbone.parameters()), 'lr': 1e-4},
        {'params': arcface_layer.parameters(), 'lr': 1e-3}
    ]
    optimizer = optim.AdamW(trainable_params, weight_decay=1e-4)
    scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=15)
    
    criterion = nn.CrossEntropyLoss()
    
    epochs = 15
    train_losses, val_losses = [], []
    train_accs, val_accs = [], []
    
    best_val_acc = 0.0
    
    for epoch in range(1, epochs + 1):
        # Training Phase
        backbone.train()
        arcface_layer.train()
        # Set frozen BN layers to eval mode to keep running statistics stable
        for m in backbone.modules():
            if isinstance(m, (nn.BatchNorm2d, nn.BatchNorm1d)):
                if m.weight is not None and not m.weight.requires_grad:
                    m.eval()
        
        running_loss = 0.0
        correct = 0
        total = 0
        
        for images, labels in train_loader:
            images = images.to(device)
            labels = labels.to(device)
            
            optimizer.zero_grad()
            
            # Forward pass: extract features
            features = backbone(images) # Shape: (batch_size, 512)
            
            # ArcFace classification
            logits = arcface_layer(features, labels)
            
            loss = criterion(logits, labels)
            loss.backward()
            optimizer.step()
            
            running_loss += loss.item() * images.size(0)
            
            # Calculate training accuracy (based on logits)
            _, predicted = logits.max(1)
            total += labels.size(0)
            correct += predicted.eq(labels).sum().item()
            
        epoch_train_loss = running_loss / len(train_loader.dataset)
        epoch_train_acc = correct / total
        
        # Validation Phase
        backbone.eval()
        arcface_layer.eval()
        
        val_running_loss = 0.0
        val_correct = 0
        val_total = 0
        
        with torch.no_grad():
            for images, labels in val_loader:
                images = images.to(device)
                labels = labels.to(device)
                
                features = backbone(images)
                # For validation evaluation, we compare features against classifier weights directly
                # Cosine similarity classification
                logits = arcface_layer(features, labels)
                loss = criterion(logits, labels)
                
                val_running_loss += loss.item() * images.size(0)
                
                _, predicted = logits.max(1)
                val_total += labels.size(0)
                val_correct += predicted.eq(labels).sum().item()
                
        epoch_val_loss = val_running_loss / len(val_loader.dataset)
        epoch_val_acc = val_correct / val_total
        
        train_losses.append(epoch_train_loss)
        val_losses.append(epoch_val_loss)
        train_accs.append(epoch_train_acc)
        val_accs.append(epoch_val_acc)
        
        scheduler.step()
        
        print(f"Epoch [{epoch:02d}/{epochs:02d}] "
              f"Train Loss: {epoch_train_loss:.4f} | Train Acc: {epoch_train_acc * 100:.2f}% | "
              f"Val Loss: {epoch_val_loss:.4f} | Val Acc: {epoch_val_acc * 100:.2f}%")
              
        # Save best model
        if epoch_val_acc > best_val_acc:
            best_val_acc = epoch_val_acc
            print(f"  --> Best Validation Accuracy improved to {best_val_acc * 100:.2f}%. Saving checkpoint...")
            checkpoint = {
                'backbone_state_dict': backbone.state_dict(),
                'arcface_state_dict': arcface_layer.state_dict(),
                'class_to_idx': class_to_idx,
                'epoch': epoch,
                'val_acc': best_val_acc
            }
            torch.save(checkpoint, 'best_checkpoint.pth')
            
    print(f"Training completed. Best validation accuracy: {best_val_acc * 100:.2f}%")
    
    # Save training curves
    plt.figure(figsize=(12, 5))
    
    plt.subplot(1, 2, 1)
    plt.plot(range(1, epochs + 1), train_losses, label='Train Loss')
    plt.plot(range(1, epochs + 1), val_losses, label='Val Loss')
    plt.xlabel('Epoch')
    plt.ylabel('Loss')
    plt.title('Training and Validation Loss')
    plt.legend()
    
    plt.subplot(1, 2, 2)
    plt.plot(range(1, epochs + 1), train_accs, label='Train Accuracy')
    plt.plot(range(1, epochs + 1), val_accs, label='Val Accuracy')
    plt.xlabel('Epoch')
    plt.ylabel('Accuracy')
    plt.title('Training and Validation Accuracy')
    plt.legend()
    
    plt.tight_layout()
    plt.savefig('training_curves.png')
    print("Training curves saved as training_curves.png")

if __name__ == "__main__":
    main()
