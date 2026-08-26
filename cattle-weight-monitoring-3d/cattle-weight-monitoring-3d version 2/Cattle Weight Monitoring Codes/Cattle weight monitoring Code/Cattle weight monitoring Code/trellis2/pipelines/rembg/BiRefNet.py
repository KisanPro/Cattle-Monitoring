from typing import *
from transformers import AutoModelForImageSegmentation
import torch
from torchvision import transforms
from PIL import Image


class BiRefNet:
    def __init__(self, model_name: str = "ZhengPeng7/BiRefNet"):
        import os
        local_model_path = os.path.join("models", "BiRefNet")
        if os.path.exists(local_model_path):
            model_name = local_model_path
            print(f"Using local BiRefNet weights from: {model_name}")

        # Patch torch.linspace to prevent meta-tensor .item() crash during Swin loading
        orig_linspace = torch.linspace
        def safe_linspace(start, end, steps, **kwargs):
            if 'device' in kwargs and str(kwargs['device']) == 'meta':
                kwargs['device'] = 'cpu'
            res = orig_linspace(start, end, steps, **kwargs)
            if not getattr(res, 'is_meta', False) and res.device.type == 'meta':
                # Workaround if context manager forced it
                return orig_linspace(start, end, steps, device='cpu')
            return res
        torch.linspace = safe_linspace
        
        try:
            self.model = AutoModelForImageSegmentation.from_pretrained(
                model_name, trust_remote_code=True, low_cpu_mem_usage=False
            )
        finally:
            torch.linspace = orig_linspace
            
        self.model.eval()
        self.transform_image = transforms.Compose(
            [
                transforms.Resize((1024, 1024)),
                transforms.ToTensor(),
                transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
            ]
        )
    
    def to(self, device: str):
        self.model.to(device)

    def cuda(self):
        self.model.cuda()

    def cpu(self):
        self.model.cpu()
        
    def __call__(self, image: Image.Image) -> Image.Image:
        image_size = image.size
        # Extract device and dtype from model parameters
        dev = next(self.model.parameters()).device
        dtype = next(self.model.parameters()).dtype
        input_images = self.transform_image(image).unsqueeze(0).to(dev, dtype=dtype)
        # Prediction
        with torch.no_grad():
            preds = self.model(input_images)[-1].sigmoid().cpu()
        pred = preds[0].squeeze()
        pred_pil = transforms.ToPILImage()(pred)
        mask = pred_pil.resize(image_size)
        image.putalpha(mask)
        return image
    