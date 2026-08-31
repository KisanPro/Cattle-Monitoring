# Technology Stack

## Programming Languages
- **Python** - `3.10 / 3.11` - Primary server language, data processing, machine learning, and REST APIs.
- **SQL (SQLite3)** - Embedded relational query language for isolated farm databases.
- **Batch / PowerShell** - Windows server startup scripting and test automation.

## Frameworks
- **FastAPI** - `0.110+` - Production asynchronous ASGI web framework for REST API endpoints.
- **PyTorch (`torch`)** - `2.4.0+` - Deep learning framework for `VectorClassifier` MLP and training loops.
- **Pydantic / Pydantic-Settings** - `v2.0+` - Type validation, JSON serialization, and environment variable configuration.
- **Uvicorn** - `0.28+` - Lightning-fast ASGI server implementation for Python.

## Infrastructure
- **Cloudflare Quick Tunnel (`cloudflared`)** - Encrypted edge-to-cloud Zero-Trust tunnel proxying HTTP port 8000.
- **NVIDIA CUDA & cuDNN** - Hardware acceleration runtime for GPU tensor computation.
- **Local / Network File System** - Directory-partitioned multi-tenant file storage.

## Build Tools
- **Pip / Virtualenv** - Python package manager and isolated runtime environment.
- **Setuptools / Wheel** - Standard distribution packaging tools.

## Testing Tools
- **PyTest / Python `unittest`** - Python testing ecosystem for running automated verification test suites.
- **Requests / urllib3** - HTTP client library used within verification and sync scripts.
