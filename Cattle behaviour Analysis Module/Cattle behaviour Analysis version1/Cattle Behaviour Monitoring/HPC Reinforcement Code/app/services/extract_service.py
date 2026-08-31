import tarfile
import os
import shutil
from pathlib import Path
from app.core.config import settings, TenantContext

def extract_and_organize(file_path: Path, tenant_id: str):
    """
    Unpacks a tar.gz batch and moves contents to the tenant's isolated training directory.
    """
    if not file_path.suffix == ".gz": # Simple check for .tar.gz
        print(f"[!] {file_path.name} is not a compressed batch. Skipping extraction.")
        return False
        
    tenant = TenantContext(tenant_id, Path(settings.farms_dir))
    temp_extract = tenant.extracted_dir / "temp_batch"
    temp_extract.mkdir(parents=True, exist_ok=True)
    
    print(f"[*] Extracting {file_path.name} for tenant {tenant_id}...")
    try:
        with tarfile.open(file_path, "r:gz") as tar:
            tar.extractall(path=temp_extract)
        
        # Organize files into farms/<tenant_id>/datasets/train/<class_name>/
        found_data = False
        for root, dirs, files in os.walk(temp_extract):
            for file in files:
                if file.lower().endswith(('.jpg', '.png', '.jpeg', '.npy')):
                    # Extract class name from the folder structure inside the tar
                    rel_path = os.path.relpath(root, temp_extract)
                    dest_dir = tenant.datasets_dir / "train" / rel_path
                    dest_dir.mkdir(parents=True, exist_ok=True)
                    
                    # Use batch name as prefix to prevent overwriting
                    new_filename = f"{file_path.stem}_{file}"
                    shutil.move(os.path.join(root, file), dest_dir / new_filename)
                    found_data = True
        
        if found_data:
            print(f"[+] Successfully integrated {file_path.name} into {tenant_id} training dataset.")
        else:
            print(f"[!] No valid training data found in {file_path.name} for {tenant_id}")
            
    except Exception as e:
        print(f"[ERORR] Extraction failed for {file_path.name}: {e}")
    finally:
        # Cleanup
        if temp_extract.exists():
            shutil.rmtree(temp_extract)
            
    return True
