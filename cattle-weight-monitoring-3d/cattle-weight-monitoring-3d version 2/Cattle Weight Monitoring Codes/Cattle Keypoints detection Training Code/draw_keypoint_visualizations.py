import os
import sys
import torch
import cv2
import numpy as np

project_dir = r"F:\Cattle Keypoints detection Training Code"
sys.path.append(project_dir)

from models.keypoint_model.law_model import MobilePoseNetV3

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
print(f"[INFO] Visualizing Keypoints on DEVICE: {DEVICE}", flush=True)

# Load trained models
side_model = MobilePoseNetV3(num_keypoints=7).to(DEVICE)
back_model = MobilePoseNetV3(num_keypoints=2).to(DEVICE)

side_model.load_state_dict(torch.load(os.path.join(project_dir, "models", "kp_weights", "kp_side_best.pth"), map_location=DEVICE, weights_only=False))
back_model.load_state_dict(torch.load(os.path.join(project_dir, "models", "kp_weights", "kp_back_best.pth"), map_location=DEVICE, weights_only=False))

side_model.eval()
back_model.eval()

def get_pyramid(image_bgr, img_size=224):
    img_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    l0 = cv2.resize(img_rgb, (img_size, img_size))
    l1_small = cv2.pyrDown(img_rgb)
    l1 = cv2.resize(l1_small, (img_size, img_size))
    l2_small = cv2.pyrDown(l1_small)
    l2 = cv2.resize(l2_small, (img_size, img_size))
    def to_tensor(img):
        return torch.tensor(img).permute(2, 0, 1).float().unsqueeze(0) / 255.0
    return [to_tensor(l0).to(DEVICE), to_tensor(l1).to(DEVICE), to_tensor(l2).to(DEVICE)]

out_dir = os.path.join(project_dir, "outputs", "annotated_images")
os.makedirs(out_dir, exist_ok=True)

side_dir = os.path.join(project_dir, "dataset", "side_view")
back_dir = os.path.join(project_dir, "dataset", "back_view")

# 1. Annotate Side View Images
side_files = sorted(os.listdir(side_dir))[:10]  # First 10 samples
for fname in side_files:
    img_path = os.path.join(side_dir, fname)
    img = cv2.imread(img_path)
    if img is None: continue
    
    h, w = img.shape[:2]
    py = get_pyramid(img)
    with torch.no_grad():
        pts = side_model(py).cpu().numpy()[0]  # (7, 2) normalized to 224
        
    # Scale points to original image resolution
    scaled_pts = []
    for pt in pts:
        px = int(pt[0] * w / 224.0)
        py = int(pt[1] * h / 224.0)
        scaled_pts.append((px, py))
        
    annotated = img.copy()
    
    # Keypoint Labels:
    # 0: A (Pin bone), 1: B (Shoulder), 2: C (Withers), 3: D (Ground), 4: E (Chest Top), 5: F (Chest Bottom), 6: G (Hip)
    colors = [(0, 0, 255), (0, 255, 0), (255, 0, 0), (255, 255, 0), (0, 255, 255), (255, 0, 255), (128, 255, 0)]
    labels = ["A (Pin)", "B (Shoulder)", "C (Withers)", "D (Ground)", "E (Chest Top)", "F (Chest Bottom)", "G (Hip)"]
    
    # Draw OBL Line (A -> B)
    cv2.line(annotated, scaled_pts[0], scaled_pts[1], (255, 100, 0), 3)
    # Draw WH Line (C -> D)
    cv2.line(annotated, scaled_pts[2], scaled_pts[3], (0, 255, 255), 3)
    # Draw Chest Depth Line (E -> F) [Paper Fig 5]
    cv2.line(annotated, scaled_pts[4], scaled_pts[5], (0, 0, 255), 4)
    
    # Draw keypoint dots & labels
    for idx, (px, py) in enumerate(scaled_pts):
        cv2.circle(annotated, (px, py), 8, colors[idx], -1)
        cv2.circle(annotated, (px, py), 10, (255, 255, 255), 2)
        cv2.putText(annotated, labels[idx], (px + 10, py - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)

    save_out = os.path.join(out_dir, f"annotated_side_{fname}")
    cv2.imwrite(save_out, annotated)

# 2. Annotate Back View Images
back_files = sorted(os.listdir(back_dir))[:10]
for fname in back_files:
    img_path = os.path.join(back_dir, fname)
    img = cv2.imread(img_path)
    if img is None: continue
    
    h, w = img.shape[:2]
    py = get_pyramid(img)
    with torch.no_grad():
        pts = back_model(py).cpu().numpy()[0]  # (2, 2)
        
    scaled_pts = []
    for pt in pts:
        px = int(pt[0] * w / 224.0)
        py = int(pt[1] * h / 224.0)
        scaled_pts.append((px, py))
        
    annotated = img.copy()
    
    # Keypoint 0: H (Chest/Hip Left), Keypoint 1: I (Chest/Hip Right)
    cv2.line(annotated, scaled_pts[0], scaled_pts[1], (0, 255, 0), 4)  # Chest Width Line H -> I
    
    cv2.circle(annotated, scaled_pts[0], 8, (0, 165, 255), -1)
    cv2.circle(annotated, scaled_pts[0], 10, (255, 255, 255), 2)
    cv2.putText(annotated, "H (Chest Left)", (scaled_pts[0][0] - 120, scaled_pts[0][1] - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)

    cv2.circle(annotated, scaled_pts[1], 8, (255, 0, 0), -1)
    cv2.circle(annotated, scaled_pts[1], 10, (255, 255, 255), 2)
    cv2.putText(annotated, "I (Chest Right)", (scaled_pts[1][0] + 10, scaled_pts[1][1] - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)

    save_out = os.path.join(out_dir, f"annotated_back_{fname}")
    cv2.imwrite(save_out, annotated)

print(f"[SUCCESS] Keypoint Visualizations saved to: {out_dir}", flush=True)
