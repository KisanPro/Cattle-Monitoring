import sys
import os
from pathlib import Path

# Add project root to path
sys.path.append(os.getcwd())

from app.services.train_service import run_fine_tuning

if __name__ == "__main__":
    print("🚀 Triggering Manual Vector Training Session...")
    model_path = run_fine_tuning()
    if model_path:
        print(f"✅ Training completed. Model at: {model_path}")
    else:
        print("❌ Training failed or skipped.")
