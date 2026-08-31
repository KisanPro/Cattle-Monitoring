import requests
import tarfile
import os
import io
import shutil
import numpy as np
from pathlib import Path
import sys

# Add project root to path
sys.path.append(os.getcwd())

from app.services.train_service import run_fine_tuning
from app.core.config import settings

HUB_URL = "http://127.0.0.1:9000"

# Tenant keys mapping
TENANTS = {
    "Geetha_8796547890_Blessing_Farm": "kisan_secure_token_2026",
    "Sunita_7775533221_Samruddhi_Farm": "kisan_secure_token_sunita"
}

def create_mock_vector_batch(filename: str, classes=["standing", "lying"]):
    """
    Creates a tar.gz containing mock .npy vector files.
    """
    print(f"🛠️ Creating mock vector batch: {filename}...")
    
    # Generate dummy vector data (1280 dimensions)
    dummy_vector = np.random.randn(1, 1280).astype(np.float32)
    vector_bytes = io.BytesIO()
    np.save(vector_bytes, dummy_vector)
    vector_data = vector_bytes.getvalue()
    
    with tarfile.open(filename, "w:gz") as tar:
        for idx, cls in enumerate(classes):
            # Create two samples per class to satisfy dataset length requirements (>= 2 samples)
            for sample_idx in range(2):
                info = tarfile.TarInfo(f"{cls}/vector_{sample_idx}.npy")
                info.size = len(vector_data)
                tar.addfile(info, io.BytesIO(vector_data))

def cleanup():
    # Cleanup temporary local test files
    for key in ["geetha_test.tar.gz", "sunita_test.tar.gz"]:
        if os.path.exists(key):
            try:
                os.remove(key)
            except Exception:
                pass
    # Remove farms directory created by test
    farms_path = Path("farms")
    if farms_path.exists():
        try:
            shutil.rmtree(farms_path)
        except Exception:
            pass
    print("🧹 Cleaned up test artifacts.")

def run_test():
    print("🚀 Starting Multi-Tenant End-to-End Test...")
    
    # 1. Clean previous state
    cleanup()
    
    # 2. Create mock batches
    create_mock_vector_batch("geetha_test.tar.gz")
    create_mock_vector_batch("sunita_test.tar.gz")
    
    # 3. Test uploads
    for tenant_name, token in TENANTS.items():
        print(f"\n📡 Uploading batch for {tenant_name}...")
        headers = {"X-API-KEY": token}
        batch_filename = "geetha_test.tar.gz" if "Geetha" in tenant_name else "sunita_test.tar.gz"
        
        url = f"{HUB_URL}/api/upload?filename={batch_filename}"
        
        try:
            with open(batch_filename, "rb") as f:
                response = requests.post(url, headers=headers, files={"file": f})
            
            if response.status_code == 200:
                print(f"✅ Upload success for {tenant_name}: {response.json()['message']}")
            else:
                print(f"❌ Upload failed for {tenant_name}: {response.status_code} - {response.text}")
                return False
        except Exception as e:
            print(f"❌ Connection error during upload: {e}")
            return False
            
    # 4. Verify physical isolation in directories
    print("\n📁 Verifying directory structures...")
    for tenant_name in TENANTS.keys():
        tenant_dir = Path("farms") / tenant_name
        
        # Verify folders exist
        assert tenant_dir.exists(), f"Tenant folder {tenant_name} does not exist!"
        assert (tenant_dir / "uploads").exists(), "uploads folder missing!"
        assert (tenant_dir / "datasets" / "train").exists(), "datasets/train folder missing!"
        
        # Check files inside training directory
        standing_dir = tenant_dir / "datasets" / "train" / "standing"
        lying_dir = tenant_dir / "datasets" / "train" / "lying"
        
        assert standing_dir.exists(), "standing behavior class directory missing!"
        assert len(list(standing_dir.glob("*.npy"))) > 0, "No vector files extracted!"
        print(f"  - Tenant {tenant_name} directories and vector files verified.")
        
    # 5. Trigger model training manually to verify train isolation
    print("\n🧠 Verifying independent model training...")
    for tenant_name in TENANTS.keys():
        print(f"   Training model for tenant {tenant_name}...")
        model_path = run_fine_tuning(tenant_name)
        assert model_path is not None, f"Training failed for {tenant_name}!"
        assert Path(model_path).exists(), f"Model file not created for {tenant_name}!"
        
        # Verify model delivery endpoint returns the correct model file
        token = TENANTS[tenant_name]
        headers = {"X-API-KEY": token}
        response = requests.get(f"{HUB_URL}/api/model/latest", headers=headers)
        assert response.status_code == 200, f"Model retrieval failed for {tenant_name}!"
        assert "error" not in response.json() if response.headers.get("content-type") == "application/json" else True, "Received error message instead of file!"
        print(f"  - Tenant {tenant_name} model trained and delivery endpoint verified.")
        
    print("\n🎉 ALL MULTI-TENANCY VERIFICATION TESTS PASSED SUCCESSFULLY!")
    return True

if __name__ == "__main__":
    success = run_test()
    # Cleanup only if test succeeded
    if success:
        cleanup()
    else:
        print("❌ Test failed. Leaving directories for inspection.")
