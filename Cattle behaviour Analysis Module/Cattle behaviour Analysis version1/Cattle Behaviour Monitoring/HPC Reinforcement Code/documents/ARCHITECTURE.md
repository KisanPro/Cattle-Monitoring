# 🧠 Kisan Intelligence Hub (HPC) - Architecture Specification

## 1. Executive Summary
The **Kisan Intelligence Hub (HPC)** is an enterprise-grade, multi-tenant continuous learning server designed to orchestrate data collection, localized behavioral model training, baseline anomaly detection, and automated model delivery across thousands of farm-deployed **Jetson Orin Nano** edge devices.

---

## 2. System Architecture Overview

```text
                        ┌────────────────────────────────────────────┐
                        │        KISAN INTELLIGENCE HUB (HPC)        │
                        └────────────────────────────────────────────┘

         ┌────────────────────────────────────────────────────────────┐
         │                  API Gateway / FastAPI                     │
         └────────────────────────────────────────────────────────────┘
                              │
                Authentication + Token Validation
                              │
                              ▼
         ┌────────────────────────────────────────────────────────────┐
         │              Multi-Tenant Farm Manager                     │
         └────────────────────────────────────────────────────────────┘
                              │
          Identify Farmer using API Key Header Mapping
          (X-API-KEY -> Farm ID)
                              │
                              ▼
              Isolated Tenant Farm Workspace Path
                              │
                              ▼
         ┌────────────────────────────────────────────────────────────┐
         │              Multi-Tenant Processing Pipeline              │
         └────────────────────────────────────────────────────────────┘
          ├── Ingestion & Extraction Layer (tar.gz -> datasets/train)
          ├── Behavior Knowledge Base (Isolated SQLite per farm)
          ├── Rolling Baseline Engine (21-Day Moving Average & Z-Score)
          ├── Alert Intelligence Engine (Severity Rules & Thresholds)
          ├── Personalized Fine-Tuning Engine (Tenant-Specific PyTorch MLP)
          └── Global Model Distillation (Anonymized Multi-Tenant Aggregator)
```

---

## 3. Multi-Tenant Farm Isolation Strategy
To guarantee complete tenant isolation, compliance, and data privacy:

### 3.1 Physical Directory Partitioning
Every tenant farm is allocated an isolated directory structure inside the `farms/` root folder:
```text
farms/
└── <Tenant_ID>/                   # e.g., Geetha_8796547890_Blessing_Farm
    ├── uploads/                   # Staging zone for uploaded tar.gz batches
    ├── extracted/                 # Temporary landing zone for decompression
    ├── datasets/
    │   └── train/                 # Labeled training features (.npy / images)
    ├── behavior_database/
    │   └── farm.db                # Isolated SQLite Database
    ├── models/
    │   ├── trained/               # Versioned historical checkpoints
    │   └── latest/                # Currently deployed model binary (.pt)
    └── logs/                      # Execution logs
```

### 3.2 Database Isolation
Each farm maintains its own SQLite database file (`farms/<Tenant_ID>/behavior_database/farm.db`). No farm can query, read, or modify another farm's database records.

---

## 4. Ingestion & Compression Workflow
1. **Edge Packaging**: The Jetson Orin Nano client compresses vector features (`.npy`) and crop images into timestamped archives (`.tar.gz`).
2. **Secure Ingestion**: Client sends a `POST /api/upload` multipart request with an `X-API-KEY` header.
3. **Tenant Resolution**: The API Gateway maps the token to a `TenantContext` instance.
4. **Extraction**: The archive is decompressed into `farms/<Tenant_ID>/extracted/` and organized into class-specific dataset folders under `farms/<Tenant_ID>/datasets/train/<label>/`.
5. **Background Training**: FastAPI enqueues `run_fine_tuning(tenant_id)` as a background task.

---

## 5. Machine Learning Pipelines

### 5.1 Personalized Fine-Tuning Pipeline
* **Input**: Tenant-specific feature vectors (1280 dimensions) loaded from `farms/<Tenant_ID>/datasets/train/`.
* **Architecture**: Multi-Layer Perceptron (`VectorClassifier`) with Dropout layers to prevent overfitting.
* **Checkpointing**: Saved to `farms/<Tenant_ID>/models/trained/<timestamp>/smarter_behavior_model.pt` and updated at `farms/<Tenant_ID>/models/latest/smarter_behavior_model.pt`.

### 5.2 Global Model Distillation Pipeline
* Aggregates vector samples across all tenant workspaces (`farms/*/datasets/train/`).
* Anonymizes samples (strips tenant IDs, device details, positional tags).
* Trains a universal base classifier saved to `global_workspace/models/base_behavior_model.pt` to serve as a cold-start default for new farms.

---

## 6. Baseline & Alert Intelligence Engine
1. **21-Day Rolling Baseline**: Calculates moving averages and standard deviations for `standing_duration`, `lying_duration`, `eating_duration`, and `rumination_duration`.
2. **Z-Score Anomaly Detection**:
   $$Z = \frac{\text{Observed Value} - \mu}{\sigma}$$
3. **Alert Rules**:
   * **CRITICAL**: Rumination drop $< 45\%$ of baseline mean.
   * **HIGH**: Lying duration $Z > 2.5$ (potential lameness warning).
   * **Health Score**: Daily 0-100 score penalized proportionally by deviation magnitudes.

---

## 7. Cryptography & Security Layer
* **Authentication**: Token-based `X-API-KEY` mapping.
* **UTF-8 Protocol Enforcers**: Forced `set PYTHONUTF8=1` on Windows consoles to ensure crash-free emoji logging.
* **Safe Squeeze Vector Logic**: Safe dimension reduction logic (`vector.squeeze()`) to handle variations in vector shapes (`(1, 1280)`, `(1280, 1)`, `(1280,)`) without runtime exceptions.
