import os
import sys
import pickle
import time
import cv2
import torch
import numpy as np
from PIL import Image
from torchvision import transforms
from facenet_pytorch import MTCNN, InceptionResnetV1

# Reuse landmark alignment coordinates
TARGET_LANDMARKS_160 = np.array([
    [48.0, 56.0],
    [112.0, 56.0],
    [80.0, 88.0],
    [56.0, 120.0],
    [104.0, 120.0]
], dtype=np.float32)

def align_and_crop(img_bgr, mtcnn):
    # Convert to RGB for MTCNN
    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    pil_img = Image.fromarray(img_rgb)
    
    # Detect face landmarks
    boxes, probs, landmarks = mtcnn.detect(pil_img, landmarks=True)
    
    if landmarks is None or len(landmarks) == 0:
        return None, None
        
    best_idx = np.argmax(probs)
    detected_landmarks = np.array(landmarks[best_idx], dtype=np.float32)
    box = boxes[best_idx]
    
    # Calculate similarity transform matrix M
    M, _ = cv2.estimateAffinePartial2D(detected_landmarks, TARGET_LANDMARKS_160)
    
    if M is None:
        # Fallback to simple crop
        x1, y1, x2, y2 = max(0, int(box[0])), max(0, int(box[1])), min(img_bgr.shape[1], int(box[2])), min(img_bgr.shape[0], int(box[3]))
        cropped = img_bgr[y1:y2, x1:x2]
        if cropped.size > 0:
            return cv2.resize(cropped, (160, 160)), box
        return None, None
        
    # Perform warp affine
    aligned = cv2.warpAffine(img_bgr, M, (160, 160))
    return aligned, box

def run_inference(image_path, db_path='embeddings_db.pkl', checkpoint_path='best_checkpoint.pth', output_path='output_inference.jpg'):
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Using device: {device}")
    
    # 1. Load database and threshold
    if not os.path.exists(db_path):
        print(f"Error: {db_path} not found. Please build the database first.")
        return
        
    with open(db_path, 'rb') as f:
        db = pickle.load(f)
    templates = db['templates']
    threshold = db.get('threshold', 0.75) # Default to 0.75 if not set
    print(f"Database loaded successfully. Recognition threshold: {threshold:.4f}")
    
    # 2. Load Models
    print("Loading models...")
    mtcnn = MTCNN(keep_all=True, device="cpu")
    
    backbone = InceptionResnetV1(pretrained='vggface2').eval()
    if os.path.exists(checkpoint_path):
        print(f"Loading trained weights from {checkpoint_path}...")
        checkpoint = torch.load(checkpoint_path, map_location=device)
        backbone.load_state_dict(checkpoint['backbone_state_dict'])
    else:
        print("Warning: Trained checkpoint not found. Using pre-trained VGGFace2 weights for inference.")
        
    backbone = backbone.to(device)
    
    # 3. Read image
    img_bgr = cv2.imread(image_path)
    if img_bgr is None:
        print(f"Error: Could not read image at {image_path}")
        return
        
    # 4. Detect and align face
    print("Detecting and aligning face...")
    aligned_face, bbox = align_and_crop(img_bgr, mtcnn)
    
    if aligned_face is None:
        print("No face detected in the image.")
        return
        
    # 5. Extract embedding
    # Standardize image
    facenet_norm = transforms.Compose([
        transforms.ToTensor(),
        transforms.Lambda(lambda x: (x * 255.0 - 127.5) / 128.0)
    ])
    
    # Convert BGR to RGB aligned face
    aligned_rgb = cv2.cvtColor(aligned_face, cv2.COLOR_BGR2RGB)
    aligned_pil = Image.fromarray(aligned_rgb)
    img_tensor = facenet_norm(aligned_pil).unsqueeze(0).to(device)
    
    start_time = time.perf_counter()
    with torch.no_grad():
        emb = backbone(img_tensor)
        # L2-normalize
        emb = emb / torch.norm(emb, p=2, dim=1, keepdim=True)
        emb = emb[0].cpu().numpy()
    end_time = time.perf_counter()
    
    # 6. Compare with database
    best_sim = -1.0
    best_match = "Unknown"
    
    for name, template in templates.items():
        sim = np.dot(emb, template)
        print(f"Similarity with {name}: {sim:.4f}")
        if sim > best_sim:
            best_sim = sim
            best_match = name
            
    # Check threshold
    final_identity = best_match if best_sim >= threshold else "Unknown"
    
    inference_time = (end_time - start_time) * 1000.0
    print(f"\nResult: Identified as '{final_identity}' (Similarity: {best_sim:.4f})")
    print(f"Inference time: {inference_time:.2f} ms")
    
    # 7. Draw and save visualization
    vis_img = img_bgr.copy()
    x1, y1, x2, y2 = int(bbox[0]), int(bbox[1]), int(bbox[2]), int(bbox[3])
    
    # Choose color: green for known, red for unknown
    color = (0, 255, 0) if final_identity != "Unknown" else (0, 0, 255)
    
    cv2.rectangle(vis_img, (x1, y1), (x2, y2), color, 2)
    label = f"{final_identity} ({best_sim:.2f})"
    
    # Draw label box
    (w, h), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 1)
    cv2.rectangle(vis_img, (x1, y1 - 25), (x1 + w, y1), color, -1)
    cv2.putText(vis_img, label, (x1, y1 - 7), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1, cv2.LINE_AA)
    
    cv2.imwrite(output_path, vis_img)
    print(f"Visualization saved to {output_path}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python inference.py <path_to_image>")
        # Let's run a test if there are files in Dataset/raw/Geetha/
        raw_geetha = os.path.join("Dataset", "raw", "Geetha")
        if os.path.exists(raw_geetha) and len(os.listdir(raw_geetha)) > 0:
            test_img = os.path.join(raw_geetha, os.listdir(raw_geetha)[0])
            print(f"No image path provided, running on default test image: {test_img}")
            run_inference(test_img)
        else:
            print("No default test image found.")
    else:
        run_inference(sys.argv[1])
