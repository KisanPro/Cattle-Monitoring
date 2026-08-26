import os
import cv2
import numpy as np
from PIL import Image
from tqdm import tqdm
from ultralytics import YOLO

def align_face(img_path, face_yolo):
    # Load image with OpenCV (BGR)
    img_bgr = cv2.imread(img_path)
    if img_bgr is None:
        return None
    
    h, w = img_bgr.shape[:2]
    # Resize to 640 width just like pipeline for face YOLO
    scale = 640.0 / w
    h_new = int(h * scale)
    small_frm = cv2.resize(img_bgr, (640, h_new))
    
    # Run face detection
    results = face_yolo(small_frm, conf=0.50, verbose=False)[0]
    if results.boxes is None or len(results.boxes.xyxy) == 0:
        return None
        
    # Take the face with the highest confidence
    best_idx = np.argmax(results.boxes.conf.cpu().numpy())
    box = results.boxes.xyxy[best_idx].cpu().numpy()
    x1, y1, x2, y2 = box
    
    # Scale back to original frame
    x1o, y1o, x2o, y2o = int(x1 / scale), int(y1 / scale), int(x2 / scale), int(y2 / scale)
    
    # Crop face with the exact 20% top, 10% bottom, 10% left, 10% right padding used in inference
    h_face = y2o - y1o
    w_face = x2o - x1o
    fpy1 = max(0, int(y1o - 0.20 * h_face))
    fpy2 = min(h, int(y2o + 0.10 * h_face))
    fpx1 = max(0, int(x1o - 0.10 * w_face))
    fpx2 = min(w, int(x2o + 0.10 * w_face))
    
    face_crop = img_bgr[fpy1:fpy2, fpx1:fpx2]
    if face_crop.size > 0:
        return cv2.resize(face_crop, (160, 160))
    return None

def preprocess_dataset():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    raw_dir = os.path.join(script_dir, "Dataset", "raw")
    processed_dir = os.path.join(script_dir, "Dataset", "processed")
    os.makedirs(processed_dir, exist_ok=True)
    
    # Locate YOLOv8-face weights
    face_model_path = os.path.join(script_dir, "..", "Kisan_Jetson", "models", "yolov8n-face.pt")
    if not os.path.exists(face_model_path):
        face_model_path = os.path.join(script_dir, "yolov8n-face.pt")
        
    print(f"Loading YOLOv8-face from {face_model_path}...")
    if not os.path.exists(face_model_path):
        raise FileNotFoundError(f"YOLOv8-face model not found at {face_model_path}")
        
    face_yolo = YOLO(face_model_path)
    
    for person_name in os.listdir(raw_dir):
        person_raw_path = os.path.join(raw_dir, person_name)
        if not os.path.isdir(person_raw_path):
            continue
            
        person_proc_path = os.path.join(processed_dir, person_name)
        os.makedirs(person_proc_path, exist_ok=True)
        
        print(f"Preprocessing images for {person_name}...")
        img_names = [f for f in os.listdir(person_raw_path) if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
        
        success_count = 0
        for img_name in tqdm(img_names):
            src_path = os.path.join(person_raw_path, img_name)
            dest_path = os.path.join(person_proc_path, img_name)
            
            # Align and crop using identical YOLO face detection logic
            aligned_face = align_face(src_path, face_yolo)
            if aligned_face is not None:
                cv2.imwrite(dest_path, aligned_face)
                success_count += 1
                
        print(f"Completed {person_name}: {success_count}/{len(img_names)} faces aligned and saved.")

if __name__ == "__main__":
    preprocess_dataset()
