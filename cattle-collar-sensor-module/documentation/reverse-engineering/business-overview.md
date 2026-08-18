# Business Overview

## Business Context Diagram
[Mermaid diagram showing the Business Context for Cattle Collar Sensor Module]

## Business Description
- **Business Description**: IoT firmware for cattle collars. Captures telemetry (GPS coordinates, accelerometer axis readings, skin temperature) and transmits data.
- **Business Transactions**: 
  - GPS location tracking
  - Accelerometer data capture (3-axis)
  - Skin temperature monitoring
  - Data transmission to central system
- **Business Dictionary**: 
  - GPS: Global Positioning System coordinates
  - Accelerometer: 3-axis motion sensor (x, y, z)
  - Skin temperature: Body temperature measurement
  - Telemetry: Transmission of measurement data

## Component Level Business Descriptions
### cattle-collar-sensor-module
- **Purpose**: Firmware for physical IoT collars capturing cattle telemetry
- **Responsibilities**: 
  - Capture GPS coordinates
  - Read accelerometer data
  - Measure skin temperature
  - Transmit data wirelessly (LoRaWAN/NB-IoT)
  - Manage power consumption