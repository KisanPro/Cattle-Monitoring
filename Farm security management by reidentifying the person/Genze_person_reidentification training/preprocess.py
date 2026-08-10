import os
import cv2
import numpy as np
from PIL import Image
from tqdm import tqdm
from facenet_pytorch import MTCNN

# Standard face templates for 160x160 crop
TARGET_LANDMARKS_160 = np.array([
    [48.0, 56.0],    # Left eye
    [112.0, 56.0],   # Right eye
    [80.0, 88.0],    # Nose
    [56.0, 120.0],   # Left mouth corner
    [104.0, 120.0]   # Right mouth corner
], dtype=np.float32)

def align_face(img_path, mtcnn):
    # Load image with OpenCV (BGR)
    img_bgr = cv2.imread(img_path)
    if img_bgr is None:
        return None
    
    # Convert to RGB for MTCNN
    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    pil_img = Image.fromarray(img_rgb)
    
    # Detect face landmarks
    # mtcnn.detect returns: boxes, probs, landmarks
    boxes, probs, landmarks = mtcnn.detect(pil_img, landmarks=True)
    
    if landmarks is None or len(landmarks) == 0:
        # Fallback: if landmarks fail, try running MTCNN to crop directly
        try:
            face = mtcnn(pil_img)
            if face is not None:
                # MTCNN returns PyTorch tensor of size (3, 160, 160) normalized to [-1, 1]
                # Convert back to uint8 BGR
                face_np = face.permute(1, 2, 0).numpy()
                face_np = ((face_np + 1) / 2 * 255).astype(np.uint8)
                return cv2.cvtColor(face_np, cv2.COLOR_RGB2BGR)
        except:
            pass
        return None
    
    # Take the face with the highest probability
    best_idx = np.argmax(probs)
    detected_landmarks = np.array(landmarks[best_idx], dtype=np.float32)
    
    # Calculate similarity transform matrix M
    # cv2.estimateAffinePartial2D finds 4 DOF similarity transform (rotation, scaling, translation)
    M, _ = cv2.estimateAffinePartial2D(detected_landmarks, TARGET_LANDMARKS_160)
    
    if M is None:
        # Fallback if matrix estimation fails
        box = boxes[best_idx].astype(int)
        x1, y1, x2, y2 = max(0, box[0]), max(0, box[1]), min(img_bgr.shape[1], box[2]), min(img_bgr.shape[0], box[3])
        cropped = img_bgr[y1:y2, x1:x2]
        if cropped.size > 0:
            return cv2.resize(cropped, (160, 160))
        return None
        
    # Perform warp affine
    aligned = cv2.warpAffine(img_bgr, M, (160, 160))
    return aligned

def preprocess_dataset():
    raw_dir = os.path.join("Dataset", "raw")
    processed_dir = os.path.join("Dataset", "processed")
    os.makedirs(processed_dir, exist_ok=True)
    
    # Initialize MTCNN
    print("Initializing MTCNN...")
    mtcnn = MTCNN(keep_all=True, device="cpu")
    
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
            
            # Align and crop
            aligned_face = align_face(src_path, mtcnn)
            if aligned_face is not None:
                cv2.imwrite(dest_path, aligned_face)
                success_count += 1
                
        print(f"Completed {person_name}: {success_count}/{len(img_names)} faces aligned and saved.")

if __name__ == "__main__":
    preprocess_dataset()
