# Cattle Collar Sensor Module

Firmware codebase for the physical IoT collar device attached to individual cows. Reads spatial, environmental, and physiological metrics, and transmits data using low-power wide-area networks.

## 🚀 Key Objectives
* Collect accelerometer telemetry for activity classifications.
* Monitor GPS positioning for pasture geofencing and cattle recovery.
* Read temperature sensors to check for heat stress or fever.
* Optimize battery life using sleep cycles and low-power transmission.

## 🛠️ Project Structure
```text
cattle-collar-sensor-module/
├── firmware/
│   ├── src/
│   │   ├── gps_module.cpp      # Interface with GPS sensor
│   │   ├── imu_sensor.cpp      # Accelerometer/Gyroscope readings
│   │   ├── transmission.cpp    # LoRa/NB-IoT message encoding
│   │   └── main.cpp            # Main loop & low-power sleep schedules
│   └── include/                # Header files
├── platformio.ini              # PlatformIO project configuration
└── schematic/                  # PCB layout schematics & PDF files
```
