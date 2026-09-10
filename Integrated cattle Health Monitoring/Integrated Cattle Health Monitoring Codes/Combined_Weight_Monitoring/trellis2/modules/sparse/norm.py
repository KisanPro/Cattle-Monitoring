import torch
import torch.nn as nn
import torch.nn.functional as F
from ..utils import manual_cast
from . import VarLenTensor
from . import config

__all__ = [
    'SparseGroupNorm',
    'SparseLayerNorm',
    'SparseGroupNorm32',
    'SparseLayerNorm32',
]


class SparseGroupNorm(nn.GroupNorm):
    def __init__(self, num_groups, num_channels, eps=1e-5, affine=True):
        super(SparseGroupNorm, self).__init__(num_groups, num_channels, eps, affine)

    def forward_with_params(self, input: VarLenTensor, weight=None, bias=None) -> VarLenTensor:
        nfeats = torch.zeros_like(input.feats)
        for k in range(input.shape[0]):
            bfeats = input.feats[input.layout[k]]
            bfeats = bfeats.permute(1, 0).reshape(1, input.shape[1], -1)
            bfeats = F.group_norm(bfeats, self.num_groups, weight, bias, self.eps)
            bfeats = bfeats.reshape(input.shape[1], -1).permute(1, 0)
            nfeats[input.layout[k]] = bfeats
        return input.replace(nfeats)

    def forward(self, input: VarLenTensor) -> VarLenTensor:
        return self.forward_with_params(input, self.weight, self.bias)


class SparseLayerNorm(nn.LayerNorm):
    def __init__(self, normalized_shape, eps=1e-5, elementwise_affine=True):
        super(SparseLayerNorm, self).__init__(normalized_shape, eps, elementwise_affine)

    def forward_with_params(self, input: VarLenTensor, weight=None, bias=None) -> VarLenTensor:
        nfeats = torch.zeros_like(input.feats)
        for k in range(input.shape[0]):
            bfeats = input.feats[input.layout[k]]
            bfeats = bfeats.permute(1, 0).reshape(1, input.shape[1], -1)
            bfeats = F.layer_norm(bfeats, self.normalized_shape, weight, bias, self.eps)
            bfeats = bfeats.reshape(input.shape[1], -1).permute(1, 0)
            nfeats[input.layout[k]] = bfeats
        return input.replace(nfeats)

    def forward(self, input: VarLenTensor) -> VarLenTensor:
        return self.forward_with_params(input, self.weight, self.bias)


class SparseGroupNorm32(SparseGroupNorm):
    """
    A GroupNorm layer that converts to float32 before the forward pass.
    """
    def forward(self, x: VarLenTensor) -> VarLenTensor:
        x_dtype = x.dtype
        x = manual_cast(x, torch.float32)
        weight = self.weight.float() if self.weight is not None else None
        bias = self.bias.float() if self.bias is not None else None
        o = self.forward_with_params(x, weight, bias)
        return manual_cast(o, x_dtype)


class SparseLayerNorm32(SparseLayerNorm):
    """
    A LayerNorm layer that converts to float32 before the forward pass.
    """
    def forward(self, x: VarLenTensor) -> VarLenTensor:
        x_dtype = x.dtype
        x = manual_cast(x, torch.float32)
        weight = self.weight.float() if self.weight is not None else None
        bias = self.bias.float() if self.bias is not None else None
        o = self.forward_with_params(x, weight, bias)
        return manual_cast(o, x_dtype)
