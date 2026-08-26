# System Architecture

## System Overview
Cattle Weight Monitoring & 3D Visualization system - depth-sensing volume modeling and weight estimation.

## Architecture Diagram
[Mermaid diagram showing all packages, services, data stores, relationships]

## Component Descriptions
### cattle_weight_app
- **Purpose**: Main application for cattle weight monitoring and 3D visualization
- **Responsibilities**: 
  - Process depth camera feeds
  - Generate 3D body meshes
  - Estimate mass/weight from 3D model
  - Display visualization to user
- **Dependencies**: 
  - Python, Open3D, Point Cloud Library (PCL)
  - Depth camera (Intel RealSense)
- **Type**: Application

### cloud_gateway
- **Purpose**: Cloud connectivity and data transfer for weight monitoring data
- **Responsibilities**: 
  - Transmit processed weight data to cloud
  - Store historical weight records
  - Provide API access for external systems
- **Dependencies**: 
  - REST APIs, PostgreSQL/InfluxDB
- **Type**: Infrastructure

### local_pc_worker
- **Purpose**: Local processing worker for 3D modeling on local machine
- **Responsibilities**: 
  - Process depth data locally
  - Generate 3D meshes without cloud dependency
  - Run reconstruction algorithms
- **Dependencies**: 
  - Python, Open3D, PCL
- **Type**: Application

### trellis2
- **Purpose**: 3D reconstruction framework/algorithm implementation
- **Responsibilities**: 
  - Implement mesh reconstruction algorithms
  - Provide 3D modeling capabilities
  - Handle point cloud processing
- **Dependencies**: 
  - Open3D, Point Cloud Library
- **Type**: Shared/Framework

### wsl_3d_server
- **Purpose**: Windows Subsystem for Linux 3D server for reconstruction
- **Responsibilities**: 
  - Run 3D reconstruction in Linux environment
  - Provide server-side processing capabilities
  - Handle GPU-accelerated computations
- **Dependencies**: 
  - Linux WS2, GPU drivers
- **Type**: Infrastructure

## Data Flow
[Mermaid sequence diagram of key workflows: depth camera input -> point cloud -> mesh reconstruction -> weight estimation -> user visualization]

## Integration Points
- **External APIs**: REST APIs for data export, cloud services
- **Databases**: PostgreSQL/InfluxDB for yield analytics
- **Third-party Services**: Intel RealSense SDK, Open3D library, PCL

## Infrastructure Components
- **CDK Stacks**: N/A
- **Deployment Model**: Python application with optional cloud sync
- **Networking**: Network for cloud data transmission
- **GPU**: Required for 3D reconstruction acceleration