# API Documentation

## REST APIs
*No external REST APIs exposed in the offline training module.*

## Internal APIs
### ArcMarginProduct
- **Methods**: `forward(input, label)`
- **Parameters**: `input` (Tensor of shape [batch, features]), `label` (Tensor of shape [batch])
- **Return Types**: `Tensor` (logits)

## Data Models
### FaceDataset
- **Fields**: `image_paths` (List), `labels` (List)
- **Relationships**: Feeds PyTorch `DataLoader`.
