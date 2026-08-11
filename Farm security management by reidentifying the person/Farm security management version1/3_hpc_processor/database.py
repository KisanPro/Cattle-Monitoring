import os
import pickle
import torch
from torch.utils.data import Dataset, DataLoader
from torchvision import transforms
from PIL import Image
import numpy as np
from facenet_pytorch import InceptionResnetV1

class SimpleDataset(Dataset):
    def __init__(self, image_paths, labels, transform=None):
        self.image_paths = image_paths
        self.labels = labels
        self.transform = transform

    def __len__(self):
        return len(self.image_paths)

    def __getitem__(self, idx):
        img_path = self.image_paths[idx]
        label = self.labels[idx]
        img = Image.open(img_path).convert('RGB')
        if self.transform:
            img = self.transform(img)
        return img, label

def main():
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Using device: {device}")
    
    # 1. Load splits
    splits_path = 'dataset_splits.pth'
    if not os.path.exists(splits_path):
        print(f"Error: {splits_path} not found. Please run train.py first to create data splits.")
        return
        
    splits = torch.load(splits_path)
    train_paths, train_labels = splits['train_data']
    class_to_idx = splits['class_to_idx']
    idx_to_class = {v: k for k, v in class_to_idx.items()}
    
    # 2. Load model
    checkpoint_path = 'best_checkpoint.pth'
    backbone = InceptionResnetV1(pretrained='vggface2').eval()
    if os.path.exists(checkpoint_path):
        print(f"Loading trained weights from {checkpoint_path}...")
        checkpoint = torch.load(checkpoint_path, map_location=device)
        backbone.load_state_dict(checkpoint['backbone_state_dict'])
    else:
        print("Warning: Trained checkpoint not found. Using pre-trained VGGFace2 weights for embedding extraction...")
        
    backbone = backbone.to(device)
    backbone.eval()
    
    # 3. Create loader
    facenet_norm = transforms.Compose([
        transforms.ToTensor(),
        transforms.Lambda(lambda x: (x * 255.0 - 127.5) / 128.0)
    ])
    
    train_dataset = SimpleDataset(train_paths, train_labels, transform=facenet_norm)
    loader = DataLoader(train_dataset, batch_size=32, shuffle=False, num_workers=0)
    
    # 4. Extract embeddings
    print("Extracting embeddings for training set...")
    embeddings_by_class = {c: [] for c in class_to_idx.keys()}
    
    with torch.no_grad():
        for images, labels in loader:
            images = images.to(device)
            # Get 512-D embeddings
            feats = backbone(images)
            feats = feats.cpu().numpy()
            
            for f, l in zip(feats, labels):
                cls_name = idx_to_class[l.item()]
                embeddings_by_class[cls_name].append(f)
                
    # 5. Create templates (average embeddings)
    templates = {}
    print("\nGenerating class templates (average + L2-normalized):")
    for cls_name, feats_list in embeddings_by_class.items():
        if len(feats_list) == 0:
            print(f"  {cls_name}: No training images found.")
            continue
        feats_arr = np.array(feats_list) # shape (N, 512)
        
        # Calculate mean embedding
        mean_feat = np.mean(feats_arr, axis=0) # shape (512,)
        
        # L2-normalize the mean embedding
        l2_norm = np.linalg.norm(mean_feat)
        if l2_norm > 0:
            mean_feat = mean_feat / l2_norm
            
        templates[cls_name] = mean_feat
        print(f"  {cls_name}: Compiled template using {len(feats_list)} faces. Template norm: {np.linalg.norm(mean_feat):.4f}")
        
    # 6. Save database
    db = {
        'templates': templates,
        'class_to_idx': class_to_idx
    }
    
    db_path = 'embeddings_db.pkl'
    with open(db_path, 'wb') as f:
        pickle.dump(db, f)
        
    print(f"\nEmbedding database successfully built and saved to {db_path}!")

if __name__ == "__main__":
    main()
