import torch
import torch.nn as nn
import torchvision.models as models
import torch.nn.functional as F

class MobilePoseNetV3(nn.Module):
    """
    Implements the Cattle Keypoints Generation module from Fig 1.
    Uses MobileNetV3 Small as backbone with multi-scale fusion.
    """
    def __init__(self, num_keypoints=7):
        super().__init__()
        self.num_keypoints = num_keypoints
        
        # Share the backbone across scales as per many multi-scale architectures
        # The paper suggests extracting features from multi-scale images.
        backbone = models.mobilenet_v3_small(weights="DEFAULT")
        self.features = backbone.features
        self.pool = nn.AdaptiveAvgPool2d((1, 1))
        
        # Regression head (PoseNet head in the paper)
        # MobileNetV3 Small features output 576 channels
        self.regressor = nn.Sequential(
            nn.Linear(576, 256),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(256, num_keypoints * 2)
        )

    def forward_single(self, x):
        """Forward pass for a single scale"""
        x = self.features(x)
        x = self.pool(x)
        x = torch.flatten(x, 1)
        x = self.regressor(x)
        return x.view(-1, self.num_keypoints, 2)

    def forward(self, pyramid):
        """
        Input: list of 3 tensors [scale1, scale2, scale3]
        scale1 = 224x224 (Level 0)
        scale2 = 224x224 (Level 1)
        scale3 = 224x224 (Level 2)
        
        Section 4.1.3: "weights w of the three scales to 0.4, 0.4, and 0.2 respectively"
        """
        outputs = []
        for scale_img in pyramid:
            outputs.append(self.forward_single(scale_img))
            
        # Weighted Fusion (LaWE Section 4.1.3)
        # Prediction = w1*P1 + w2*P2 + w3*P3
        weights = [0.4, 0.4, 0.2]
        
        fused_output = (
            outputs[0] * weights[0] + 
            outputs[1] * weights[1] + 
            outputs[2] * weights[2]
        )
        return fused_output

class LaWEWeightNet(nn.Module):
    """
    Cattle Weight Estimation Network module (Section 4.3).
    Includes pruning/quantization hooks potentially, but here we define the base architecture.
    """
    def __init__(self):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(4, 64),
            nn.ReLU(),
            nn.Linear(64, 32),
            nn.ReLU(),
            nn.Linear(32, 1)
        )
        
    def forward(self, x):
        return self.net(x)
