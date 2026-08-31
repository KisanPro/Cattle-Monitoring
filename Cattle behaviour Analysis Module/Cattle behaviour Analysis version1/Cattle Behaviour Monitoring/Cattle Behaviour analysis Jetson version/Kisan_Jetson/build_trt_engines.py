import os
import sys
import torch
from ultralytics import YOLO

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

def build_fp16_engine(model_rel_path):
    pt_path = os.path.join(SCRIPT_DIR, model_rel_path)
    engine_path = pt_path.replace(".pt", ".engine")
    
    if not os.path.exists(pt_path):
        print(f"❌ PyTorch model not found: {pt_path}")
        return False
        
    print(f"\n⚡ Compiling TensorRT FP16 Engine for {model_rel_path} on {torch.cuda.get_device_name(0)}...")
    try:
        model = YOLO(pt_path)
        # Export to TensorRT format with half precision (FP16) for Jetson Orin
        exported_path = model.export(format="engine", half=True, device=0, verbose=True)
        print(f"✅ Successfully created TensorRT FP16 engine: {exported_path}")
        return True
    except Exception as e:
        print(f"❌ Export failed for {model_rel_path}: {e}")
        return False

if __name__ == "__main__":
    if not torch.cuda.is_available():
        print("❌ CUDA GPU is not available on this device!")
        sys.exit(1)
        
    print(f"🚀 Found GPU: {torch.cuda.get_device_name(0)}")
    
    models_to_build = [
        "yolo26.pt",
        os.path.join("models", "ear_tag_model.pt"),
        os.path.join("models", "yolov8n-face.pt")
    ]
    
    for m in models_to_build:
        build_fp16_engine(m)
