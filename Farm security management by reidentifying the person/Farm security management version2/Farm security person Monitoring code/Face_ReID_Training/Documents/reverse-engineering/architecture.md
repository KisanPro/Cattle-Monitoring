# System Architecture

## System Overview
A PyTorch-based Deep Learning pipeline utilizing YOLOv8 for face detection and InceptionResnetV1 for feature extraction and metric learning (ArcFace).

## Architecture Diagram
```mermaid
graph TD
    Raw[Raw Images] -->|preprocess.py| YOLO[YOLOv8 Face]
    YOLO --> Processed[Processed Crops]
    Processed -->|train.py| Model[InceptionResnetV1]
    Model --> Checkpoint[best_checkpoint.pth]
    Checkpoint -->|database.py| DB[embeddings_db.pkl]
    DB -->|evaluate.py| Eval[Metrics & Graphs]
```

## Component Descriptions
### Model Trainer (train.py)
- **Purpose**: Fine-tunes the CNN on the processed dataset.
- **Responsibilities**: Backpropagation, loss calculation, checkpoint saving.
- **Dependencies**: PyTorch, facenet-pytorch.
- **Type**: Application / Model

## Data Flow
```mermaid
sequenceDiagram
    participant Data as Data Layer
    participant Train as Training Engine
    participant Eval as Evaluator
    Data->>Train: Processed face crops
    Train->>Train: 15 Epochs ArcFace Optimization
    Train->>Data: best_checkpoint.pth
    Data->>Eval: best_checkpoint.pth & Test Split
    Eval->>Eval: Cosine Similarity Matching
    Eval->>Data: confusion_matrix.png
```

## Integration Points
- **External APIs**: None (Offline Edge Training).
- **Databases**: Pickle file (embeddings_db.pkl) acting as a vector store.
