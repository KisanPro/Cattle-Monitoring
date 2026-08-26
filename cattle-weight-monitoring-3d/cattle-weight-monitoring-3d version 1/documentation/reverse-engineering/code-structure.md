# Code Structure

## Build System
- **Type**: Python (no formal build system)
- **Configuration**: 
  - Python interpreter requirements
  - Dependencies: open3d, pcl, numpy

## Key Classes/Modules
[Mermaid class diagram or module hierarchy]

### Existing Files Inventory
- `ARCHITECTURE.md` - System architecture documentation
- `IMPLEMENTATION_SUMMARY.md` - Implementation summary and findings
- `README.md` - Project overview and getting started guide
- `RUN_GUIDE.md` - Execution guide and instructions
- `.gitignore` - Git ignore rules
- `cattle_weight_app/` - Main application source code
- `cloud_gateway/` - Cloud connectivity module
- `local_pc_worker/` - Local processing worker
- `trellis2/` - 3D reconstruction framework
- `wsl_3d_server/` - WSL 3D server

## Design Patterns
### [Pattern Name]
- **Location**: Various modules
- **Purpose**: 3D mesh reconstruction, point cloud processing
- **Implementation**: Open3D algorithms, custom mesh processing

## Critical Dependencies
### open3d
- **Version**: Latest stable release
- **Usage**: 3D vision and geometry processing
- **Purpose**: Point cloud processing, mesh generation, visualization

### Point Cloud Library (PCL)
- **Version**: Latest stable release
- **Usage**: 3D point cloud processing
- **Purpose**: Advanced geometric processing, filtering, estimation

### Python
- **Version**: 3.x
- **Usage**: Main scripting language for application logic
- **Purpose**: Orchestration and integration

### Intel RealSense SDK
- **Version**: Latest stable release
- **Usage**: Depth camera interface and data acquisition
- **Purpose**: Capture depth frames, color frames