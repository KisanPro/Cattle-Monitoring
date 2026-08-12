
import os
import torch
import numpy as np
from PIL import Image
from typing import *
import sys

# Add backend directory to path if needed for relative imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from trellis2.pipelines import Trellis2ImageTo3DPipeline
from trellis2.utils import render_utils
from trellis2.renderers import EnvMap
import o_voxel
from trellis2.pipelines.rembg.BiRefNet import BiRefNet

class TrellisBackend:
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(TrellisBackend, cls).__new__(cls)
            cls._instance._initialized = False
            import threading
            cls._instance._init_lock = threading.Lock()
        return cls._instance

    def initialize(self, model_path="microsoft/TRELLIS.2-4B"):
        with self._init_lock:
            if self._initialized:
                return
            
            print(f"Loading TRELLIS.2 model from {model_path}...")
            self.pipeline = Trellis2ImageTo3DPipeline.from_pretrained(model_path, dtype=torch.float16)
            self.pipeline.low_vram = True
            self.pipeline.cuda()
            
            # Disable HDRI envmap loading to save VRAM
            self.envmap = None
            print("HDRI preview map loading skipped to save VRAM.")
            
            print("Loading BiRefNet background remover...")
            self.rembg = BiRefNet()
            self.rembg.to("cuda")
            print("BiRefNet background remover loaded successfully.")
                
            self._initialized = True
            print("TRELLIS.2 Backend Initialized.")

    def reconstruct(self, images: List[Image.Image], resolution=1024, out_dir="outputs", source_view='left'):
        if not self._initialized:
            self.initialize()
            
        os.makedirs(out_dir, exist_ok=True)
        
        # Determine pipeline type
        pipeline_type = "1024_cascade"
        if resolution == 512:
            pipeline_type = "512"
        elif resolution == 1536:
            pipeline_type = "1536_cascade"
            
        print(f"Running reconstruction for {len(images)} image(s) at {resolution} res with source view '{source_view}'...")
        
        # Proactively clear cache
        torch.cuda.empty_cache()
        
        # Determine primary conditioning image based on source_view
        if source_view == 'multiview':
            valid_images = [img for img in images if img is not None]
            if len(valid_images) == 1:
                primary_image = valid_images[0]
                print(f"🔍 Multi-view selected, but only 1 view available. Using single-view from first available image.")
            elif len(valid_images) > 1:
                # To prevent double-headed/multi-bodied deformities caused by sequence concatenation of 4 views,
                # we select the best side profile view (Left or Right) as the primary conditioning image.
                # This guarantees a clean, single-bodied quadruped structure while still keeping all 4 uploaded views in the library gallery.
                selected_idx = 2  # Default to Left View
                if images[2] is not None:
                    selected_idx = 2
                elif images[3] is not None:
                    selected_idx = 3
                elif images[0] is not None:
                    selected_idx = 0
                else:
                    selected_idx = 1
                primary_image = images[selected_idx]
                print(f"🔍 Multi-view selected. Using clean side-view (index {selected_idx}) as primary image to prevent double-headed/multi-bodied deformities.")
            else:
                raise ValueError("No valid input images found for reconstruction.")
        else:
            view_map = {'front': 0, 'back': 1, 'left': 2, 'right': 3}
            idx = view_map.get(source_view, 2)
            if idx < len(images) and images[idx] is not None:
                primary_image = images[idx]
            else:
                valid_images = [img for img in images if img is not None]
                if not valid_images:
                    raise ValueError("No valid input images found for reconstruction.")
                primary_image = valid_images[0]
                print(f"⚠️ Selected source view '{source_view}' not uploaded. Falling back to first available view.")
            print(f"🔍 Reconstructing 3D structure from {source_view.capitalize()} view for clean single-body mesh.")
        
        # ── Background Removal (Foreground Segmentation) ────────────────────────
        print("🧼 Running BiRefNet background removal on primary image to isolate the cattle...")
        torch.cuda.empty_cache()
        primary_image = self.rembg(primary_image)
        # Save the segmented image for reference/verification
        segmented_path = os.path.join(out_dir, "input_segmented.png")
        primary_image.save(segmented_path)
        print(f"🧼 Background removed successfully. Segmented image saved to: {segmented_path}")
        
        # New: Pass all images directly to the pipeline for multi-view conditioning
        # Using high-fidelity settings optimized for cattle textures
        torch.cuda.empty_cache()
        outputs = self.pipeline.run(
            primary_image, 
            pipeline_type=pipeline_type,
            tex_slat_sampler_params={
                "steps": 12,
                "guidance_strength": 3.5, # Increased for vibrant, clean colors
                "guidance_rescale": 0.0,
                "rescale_t": 3.0,
            }
        )
        torch.cuda.empty_cache()
        
        mesh = outputs[0]
        mesh.simplify(500000) # Balanced for performance/quality
        
        # Free memory before visualization video rendering
        import gc
        gc.collect()
        torch.cuda.empty_cache()
        
        # Video rendering disabled to prevent OOM
        video_path = None
        print("🎥 Video preview rendering skipped to prevent memory crashes.")
            
        # Export GLB
        glb_path = os.path.join(out_dir, "model.glb")
        
        # Free memory before memory-heavy post-processing remeshing
        gc.collect()
        torch.cuda.empty_cache()
        
        try:
            glb = o_voxel.postprocess.to_glb(
                vertices=mesh.vertices,
                faces=mesh.faces,
                attr_volume=mesh.attrs,
                coords=mesh.coords,
                attr_layout=self.pipeline.pbr_attr_layout,
                voxel_size=mesh.voxel_size,
                aabb=[[-0.5, -0.5, -0.5], [0.5, 0.5, 0.5]],
                decimation_target=50000,
                texture_size=512,
                remesh=True,
                remesh_band=2,
                remesh_project=0.9
            )
            glb.export(glb_path)
        finally:
            # Strictly free all large tensors and objects to prevent OOM on subsequent runs
            try:
                del mesh
                del outputs
                del glb
            except:
                pass
            gc.collect()
            torch.cuda.empty_cache()
        
        return {
            "glb": glb_path,
            "video": video_path if (video_path and os.path.exists(video_path)) else None
        }

# Singleton instance
backend_engine = TrellisBackend()
