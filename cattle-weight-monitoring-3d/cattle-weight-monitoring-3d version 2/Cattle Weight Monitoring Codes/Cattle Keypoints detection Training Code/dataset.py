import os
import json
import torch
import cv2
import numpy as np
from torch.utils.data import Dataset

class KeypointDataset(Dataset):
    """
    PyTorch Dataset for Cattle Keypoint Detection using 3-level Gaussian Image Pyramid
    (LaWE Model - Bai, Guo & Song, 2024).
    """
    def __init__(self, img_dir, annotation_file, img_size=224, augment=True):
        self.img_dir = img_dir
        self.img_size = img_size
        self.augment = augment
        
        if not os.path.exists(annotation_file):
            raise FileNotFoundError(f"Annotation file not found: {annotation_file}")
            
        with open(annotation_file, 'r') as f:
            self.annotations = json.load(f)
            
        self.image_files = [f for f in sorted(os.listdir(img_dir)) if f in self.annotations]
        
    def __len__(self):
        return len(self.image_files)
        
    def __getitem__(self, idx):
        img_name = self.image_files[idx]
        img_path = os.path.join(self.img_dir, img_name)
        
        image = cv2.imread(img_path)
        if image is None:
            raise FileNotFoundError(f"Image not found at {img_path}")
            
        image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        
        keypoints = np.array(self.annotations[img_name], dtype=np.float32)
        if len(keypoints.shape) == 1:
            keypoints = keypoints.reshape(-1, 2)
            
        # Data Augmentation (Color Jitter & Scaling)
        if self.augment:
            if np.random.random() > 0.5:
                alpha = np.random.uniform(0.85, 1.15)
                beta = np.random.uniform(-15, 15)
                image = cv2.convertScaleAbs(image, alpha=alpha, beta=beta)
                
        # Build 3-level Gaussian Pyramid (L0: 224x224, L1: downsample 1x, L2: downsample 2x)
        l0 = cv2.resize(image, (self.img_size, self.img_size))
        l1_small = cv2.pyrDown(image)
        l1 = cv2.resize(l1_small, (self.img_size, self.img_size))
        l2_small = cv2.pyrDown(l1_small)
        l2 = cv2.resize(l2_small, (self.img_size, self.img_size))
        
        def to_tensor(img):
            return torch.tensor(img).permute(2, 0, 1).float() / 255.0
            
        pyramid = [to_tensor(l0), to_tensor(l1), to_tensor(l2)]
        
        keypoints = torch.tensor(keypoints).float()
        return pyramid, keypoints
