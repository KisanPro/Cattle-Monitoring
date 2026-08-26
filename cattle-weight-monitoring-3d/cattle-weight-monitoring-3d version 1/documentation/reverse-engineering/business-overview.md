# Business Overview

## Business Context Diagram
[Mermaid diagram showing the Business Context for Cattle Weight Monitoring 3D]

## Business Description
- **Business Description**: 3D body mesh reconstruction from depth camera feeds to estimate cattle mass/weight without physical scale usage.
- **Business Transactions**: 
  - 3D body mesh reconstruction from depth camera feeds
  - Weight estimation from 3D model
  - Depth data processing and point cloud generation
  - Weight reporting and analytics
- **Business Dictionary**: 
  - Depth camera: Camera that provides distance information for each pixel
  - Point cloud: Set of data points in coordinate system
  - 3D mesh: Mathematical representation of 3D surface
  - Volume: Amount of 3D space occupied
  - Mass estimation: Inferring weight from body volume

## Component Level Business Descriptions
### cattle_weight_app
- **Purpose**: Main application for cattle weight monitoring and 3D visualization
- **Responsibilities**: 
  - Process depth camera feeds
  - Generate 3D body meshes
  - Estimate mass/weight from 3D model
  - Display visualization to user

### cloud_gateway
- **Purpose**: Cloud connectivity and data transfer for weight monitoring data
- **Responsibilities**: 
  - Transmit processed weight data to cloud
  - Store historical weight records
  - Provide API access for external systems

### local_pc_worker
- **Purpose**: Local processing worker for 3D modeling on local machine
- **Responsibilities**: 
  - Process depth data locally
  - Generate 3D meshes without cloud dependency
  - Run reconstruction algorithms

### trellis2
- **Purpose**: 3D reconstruction framework/algorithm implementation
- **Responsibilities**: 
  - Implement mesh reconstruction algorithms
  - Provide 3D modeling capabilities
  - Handle point cloud processing

### wsl_3d_server
- **Purpose**: Windows Subsystem for Linux 3D server for reconstruction
- **Responsibilities**: 
  - Run 3D reconstruction in Linux environment
  - Provide server-side processing capabilities
  - Handle GPU-accelerated computations