import os
import sys
import json
import torch
import cv2
import numpy as np

project_dir = r"F:\Cattle Keypoints detection Training Code"
sys.path.append(project_dir)

from models.keypoint_model.law_model import MobilePoseNetV3

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
print(f"[INFO] Generating Keypoint Annotations on DEVICE: {DEVICE}", flush=True)

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

side_dir = os.path.join(project_dir, "dataset", "side_view")
back_dir = os.path.join(project_dir, "dataset", "back_view")

side_ann = {}
back_ann = {}

s_files = sorted(os.listdir(side_dir))
b_files = sorted(os.listdir(back_dir))

print(f"[INFO] Annotating {len(s_files)} Side View images...", flush=True)
for idx, f in enumerate(s_files, 1):
    if f.lower().endswith(('.png', '.jpg', '.jpeg')):
        img_path = os.path.join(side_dir, f)
        img = cv2.imread(img_path)
        if img is not None:
            py = get_pyramid(img)
            with torch.no_grad():
                pts = side_model(py).cpu().numpy()[0]
            side_ann[f] = pts.tolist()
    if idx % 25 == 0 or idx == len(s_files):
        print(f"  Side View progress: {idx}/{len(s_files)}", flush=True)

print(f"[INFO] Annotating {len(b_files)} Back View images...", flush=True)
for idx, f in enumerate(b_files, 1):
    if f.lower().endswith(('.png', '.jpg', '.jpeg')):
        img_path = os.path.join(back_dir, f)
        img = cv2.imread(img_path)
        if img is not None:
            py = get_pyramid(img)
            with torch.no_grad():
                pts = back_model(py).cpu().numpy()[0]
            back_ann[f] = pts.tolist()
    if idx % 25 == 0 or idx == len(b_files):
        print(f"  Back View progress: {idx}/{len(b_files)}", flush=True)

side_json = os.path.join(project_dir, "annotations", "side_annotations.json")
back_json = os.path.join(project_dir, "annotations", "back_annotations.json")

with open(side_json, "w") as f:
    json.dump(side_ann, f, indent=2)

with open(back_json, "w") as f:
    json.dump(back_ann, f, indent=2)

print(f"[SUCCESS] Annotations saved! Side: {len(side_ann)} entries, Back: {len(back_ann)} entries.", flush=True)
