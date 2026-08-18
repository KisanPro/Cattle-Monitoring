# Business Overview

## Business Context Diagram
[Mermaid diagram showing the Business Context for Cattle Behaviour Analysis]

## Business Description
- **Business Description**: Computer vision & sensor-based activity tracking for cattle. Analyzes animal behavior (grazing, resting, ruminating, standing, walking) using camera feeds or collar-mounted sensors.
- **Business Transactions**: 
  - Activity classification (grazing, resting, ruminating, standing, walking)
  - Behavior pattern detection
  - Activity period tracking
- **Business Dictionary**: 
  - Grazing: Feeding on grass or forage
  - Resting: Period of inactivity/sleep
  - Ruminating: Chewing cud
  - Standing: Upright posture
  - Walking: Locomotion activity

## Component Level Business Descriptions
### cattle-behaviour-analysis
- **Purpose**: Analyze animal behavior using computer vision and sensor data
- **Responsibilities**: 
  - Process camera feeds or collar sensor data
  - Classify animal postures and activities
  - Track behavior patterns over time
  - Generate activity reports