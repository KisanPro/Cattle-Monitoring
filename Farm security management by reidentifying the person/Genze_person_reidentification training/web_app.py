import os
import base64
import pickle
import numpy as np
import cv2
import torch
from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from PIL import Image
from torchvision import transforms
from facenet_pytorch import MTCNN, InceptionResnetV1

# Define requests schema
class ImageRequest(BaseModel):
    image: str

app = FastAPI(title="Face Recognition API")

# Enable CORS for external testing
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Constants & Paths
DB_PATH = 'embeddings_db.pkl'
CHECKPOINT_PATH = 'best_checkpoint.pth'
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# Global variables for models and templates
templates = {}
class_to_idx = {}
mtcnn = None
backbone = None

# Landmark target layout for similarity transform (160x160)
TARGET_LANDMARKS_160 = np.array([
    [48.0, 56.0],
    [112.0, 56.0],
    [80.0, 88.0],
    [56.0, 120.0],
    [104.0, 120.0]
], dtype=np.float32)

@app.on_event("startup")
def load_models_and_db():
    global templates, class_to_idx, mtcnn, backbone
    
    # 1. Load Database
    if not os.path.exists(DB_PATH):
        print(f"Error: {DB_PATH} not found. Please compile database first.")
        # Create a dummy database if it doesn't exist to prevent crash
        templates = {}
        class_to_idx = {}
    else:
        with open(DB_PATH, 'rb') as f:
            db = pickle.load(f)
        templates = db['templates']
        class_to_idx = db['class_to_idx']
        print(f"Loaded {len(templates)} templates from {DB_PATH}")
        
    # 2. Initialize MTCNN on CPU (recommended for simple frames)
    mtcnn = MTCNN(keep_all=True, device="cpu")
    print("MTCNN face detector initialized.")
    
    # 3. Initialize InceptionResnetV1
    backbone = InceptionResnetV1(pretrained='vggface2').eval()
    if os.path.exists(CHECKPOINT_PATH):
        print(f"Loading trained weights from {CHECKPOINT_PATH}...")
        checkpoint = torch.load(CHECKPOINT_PATH, map_location=device)
        backbone.load_state_dict(checkpoint['backbone_state_dict'])
    else:
        print("Warning: Trained checkpoint not found. Using pre-trained VGGFace2 weights.")
        
    backbone = backbone.to(device)
    print("InceptionResnetV1 backbone loaded and ready.")

def align_and_crop(img_bgr):
    # Convert BGR to RGB
    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    pil_img = Image.fromarray(img_rgb)
    
    # Detect face landmarks
    boxes, probs, landmarks = mtcnn.detect(pil_img, landmarks=True)
    
    if landmarks is None or len(landmarks) == 0:
        return None, None
        
    # Select best face (highest probability)
    best_idx = np.argmax(probs)
    detected_landmarks = np.array(landmarks[best_idx], dtype=np.float32)
    box = boxes[best_idx]
    
    # Estimate similarity transform matrix M
    M, _ = cv2.estimateAffinePartial2D(detected_landmarks, TARGET_LANDMARKS_160)
    
    if M is None:
        # Fallback to simple crop
        x1, y1, x2, y2 = max(0, int(box[0])), max(0, int(box[1])), min(img_bgr.shape[1], int(box[2])), min(img_bgr.shape[0], int(box[3]))
        cropped = img_bgr[y1:y2, x1:x2]
        if cropped.size > 0:
            return cv2.resize(cropped, (160, 160)), [x1, y1, x2, y2]
        return None, None
        
    # Apply affine warp to get 160x160 aligned face chip
    aligned = cv2.warpAffine(img_bgr, M, (160, 160))
    return aligned, [int(box[0]), int(box[1]), int(box[2]), int(box[3])]

@app.post("/api/recognize")
def recognize_face(req: ImageRequest):
    # Decode base64 image
    try:
        base64_str = req.image
        if "," in base64_str:
            base64_str = base64_str.split(",")[1]
        img_bytes = base64.b64decode(base64_str)
        nparr = np.frombuffer(img_bytes, np.uint8)
        img_bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    except Exception as e:
        raise HTTPException(status_code=400, detail="Invalid image encoding.")
        
    if img_bgr is None:
        raise HTTPException(status_code=400, detail="Failed to decode image.")
        
    # Align and crop face
    aligned_face, bbox = align_and_crop(img_bgr)
    
    if aligned_face is None:
        return {"face_found": False}
        
    # Normalize aligned face
    facenet_norm = transforms.Compose([
        transforms.ToTensor(),
        transforms.Lambda(lambda x: (x * 255.0 - 127.5) / 128.0)
    ])
    
    aligned_rgb = cv2.cvtColor(aligned_face, cv2.COLOR_BGR2RGB)
    aligned_pil = Image.fromarray(aligned_rgb)
    img_tensor = facenet_norm(aligned_pil).unsqueeze(0).to(device)
    
    # Extract embedding
    with torch.no_grad():
        emb = backbone(img_tensor)
        emb = emb / torch.norm(emb, p=2, dim=1, keepdim=True)
        emb = emb[0].cpu().numpy()
        
    # Calculate similarities with database templates
    best_sim = -1.0
    best_match = "Unknown"
    similarity_by_class = {}
    
    for name, template in templates.items():
        sim = float(np.dot(emb, template))
        similarity_by_class[name] = sim
        if sim > best_sim:
            best_sim = sim
            best_match = name
            
    return {
        "face_found": True,
        "bbox": bbox,
        "best_match": best_match,
        "similarity": best_sim,
        "similarity_by_class": similarity_by_class
    }

@app.get("/api/members")
def get_members():
    return {"members": list(templates.keys())}

# Mount static folder
os.makedirs("static", exist_ok=True)
app.mount("/", StaticFiles(directory="static", html=True), name="static")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("web_app:app", host="0.0.0.0", port=8000, reload=True)
