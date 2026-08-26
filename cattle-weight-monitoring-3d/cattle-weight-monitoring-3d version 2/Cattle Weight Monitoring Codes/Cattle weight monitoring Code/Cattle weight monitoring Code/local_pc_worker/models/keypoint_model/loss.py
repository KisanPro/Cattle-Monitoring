import torch.nn as nn

class KeypointLoss(nn.Module):
    def __init__(self):
        super().__init__()
        self.mse = nn.MSELoss()
        
    def forward(self, preds, targets):
        return self.mse(preds, targets)
