# 🔌 Kisan Pro: Sensors, Hardware Specifications & Pinout Guide

This document contains complete wiring schematics, hardware pin mappings, bus specifications, and power supply guidelines for the **Kisan Pro Livestock Collar** and **Farm Gateway**.

---

## 🐂 1. Collar Transmitter Node (ESP32 Sender)

The cattle collar is powered by an **ESP32-WROOM-32** interfaced with three primary sensor/radio modules:

```
                  +-----------------------------------+
                  |          ESP32-WROOM-32           |
                  |                                   |
[Quectel L89 GPS] | GPIO 16 (RXD2) <--- TXD           |
                  | GPIO 17 (TXD2) ---> RXD           |
                  |                                   |
[ST LSM6DSOX IMU] | GPIO 21 (SDA)  <--> SDA (I2C)     |
                  | GPIO 22 (SCL)  <--> SCL (I2C)     |
                  |                                   |
[SX1278 LoRa TX]  | GPIO 5  (SS)   ---> NSS / CS      |
                  | GPIO 14 (RST)  ---> RESET         |
                  | GPIO 26 (DIO0) <--- DIO0 / IRQ    |
                  | GPIO 18 (SCK)  ---> SCK (SPI)     |
                  | GPIO 19 (MISO) <--- MISO (SPI)    |
                  | GPIO 23 (MOSI) ---> MOSI (SPI)    |
                  |                                   |
[Battery Monitor] | GPIO 35 (ADC1) <--- Voltage Div.  |
                  +-----------------------------------+
```

---

### Detailed Pin Mapping Table:

| Module / Sensor | Sensor Pin | ESP32 GPIO Pin | Protocol / Bus | Voltage Level | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Quectel L89 GPS** | `TXD` | **`GPIO 16 (RXD2)`** | UART2 (9600 Baud) | 3.3V | Receives NMEA `$GPRMC` & `$GPGGA` sentences |
| **Quectel L89 GPS** | `RXD` | **`GPIO 17 (TXD2)`** | UART2 (9600 Baud) | 3.3V | GPS configuration commands |
| **Quectel L89 GPS** | `VCC` | `3V3` / `5V` | Power | 3.3V - 5.0V | Connected to 3.3V regulated rail |
| **Quectel L89 GPS** | `GND` | `GND` | Ground | 0V | Common ground |
| **ST LSM6DSOX IMU** | `SDA` | **`GPIO 21`** | I2C (Address: `0x6A`) | 3.3V | 100 Hz 6-axis Accel + Gyro stream |
| **ST LSM6DSOX IMU** | `SCL` | **`GPIO 22`** | I2C (`400 kHz` Fast Mode) | 3.3V | I2C clock line |
| **ST LSM6DSOX IMU** | `VCC` | `3V3` | Power | 3.3V | Powered from ESP32 3V3 pin |
| **ST LSM6DSOX IMU** | `GND` | `GND` | Ground | 0V | Common ground |
| **Semtech SX1278 LoRa** | `NSS / CS` | **`GPIO 5`** | SPI (Chip Select) | 3.3V | Hardware SS control |
| **Semtech SX1278 LoRa** | `RST / RESET` | **`GPIO 14`** | Digital Output | 3.3V | Radio hardware reset line |
| **Semtech SX1278 LoRa** | `DIO0` | **`GPIO 26`** | Digital Interrupt | 3.3V | Packet RX/TX done interrupt |
| **Semtech SX1278 LoRa** | `SCK` | **`GPIO 18`** | SPI (Clock) | 3.3V | SPI bus clock |
| **Semtech SX1278 LoRa** | `MISO` | **`GPIO 19`** | SPI (Master In) | 3.3V | SPI data from LoRa to ESP32 |
| **Semtech SX1278 LoRa** | `MOSI` | **`GPIO 23`** | SPI (Master Out) | 3.3V | SPI data from ESP32 to LoRa |
| **Semtech SX1278 LoRa** | `VCC` | `3V3` | Power | 3.3V | **Do NOT connect to 5V!** |
| **Semtech SX1278 LoRa** | `GND` | `GND` | Ground | 0V | Common ground |
| **Battery Voltage Divider** | `V_DIV` | **`GPIO 35`** | ADC1 (12-bit) | $0.0\text{V} - 3.3\text{V}$ | $100\text{k}\Omega / 100\text{k}\Omega$ divider from LiPo $(3.7\text{V} - 4.2\text{V})$ |

---

## 📡 2. Farm Gateway Node (ESP32 Receiver)

The Gateway Node receives 433 MHz LoRa packets and relays them to the AWS cloud over Wi-Fi:

```
                  +-----------------------------------+
                  |          ESP32-WROOM-32           |
                  |                                   |
[SX1278 LoRa RX]  | GPIO 5  (SS)   ---> NSS / CS      |
                  | GPIO 14 (RST)  ---> RESET         |
                  | GPIO 26 (DIO0) <--- DIO0 / IRQ    |
                  | GPIO 18 (SCK)  ---> SCK (SPI)     |
                  | GPIO 19 (MISO) <--- MISO (SPI)    |
                  | GPIO 23 (MOSI) ---> MOSI (SPI)    |
                  |                                   |
[Activity LED]    | GPIO 2         ---> Indicator LED |
                  |                                   |
[Wi-Fi Antenna]   | Internal 2.4 GHz RF (STA Mode)    |
                  +-----------------------------------+
```

---

### Gateway Pin Mapping Table:

| Module | Pin | ESP32 GPIO Pin | Protocol | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **SX1278 LoRa RX** | `NSS` | **`GPIO 5`** | SPI CS | Chip Select line |
| **SX1278 LoRa RX** | `RST` | **`GPIO 14`** | Digital Out | Hardware Reset line |
| **SX1278 LoRa RX** | `DIO0` | **`GPIO 26`** | Digital In | Interrupt triggered upon packet arrival |
| **SX1278 LoRa RX** | `SCK` | **`GPIO 18`** | SPI Clock | 10 MHz SPI Clock |
| **SX1278 LoRa RX** | `MISO` | **`GPIO 19`** | SPI MISO | SPI Data In |
| **SX1278 LoRa RX** | `MOSI` | **`GPIO 23`** | SPI MOSI | SPI Data Out |
| **Status LED** | `Anode` | **`GPIO 2`** | Digital Out | Blinks upon valid packet ingestion |

---

## 🔋 3. Power Supply & Battery Voltage Divider Circuit

### A. Voltage Divider Circuit Schematic:
```text
  LiPo Battery (+) (3.7V - 4.2V)
        |
      [R1: 100 kΩ]
        |
        +--------> To ESP32 GPIO 35 (ADC1 Channel 7)
        |
      [R2: 100 kΩ]
        |
     GND (0V)
```

### B. Mathematical Voltage & Percentage Formulation:
$$V_{\text{ADC}} = V_{\text{battery}} \times \left(\frac{R_2}{R_1 + R_2}\right) = \frac{V_{\text{battery}}}{2}$$
$$V_{\text{battery}} = 2.0 \times \left(\frac{\text{AnalogRead}(\text{GPIO 35})}{4095.0}\right) \times 3.3\text{V}$$
$$\text{Battery \%} = \left(\frac{V_{\text{battery}} - 3.40\text{V}}{4.20\text{V} - 3.40\text{V}}\right) \times 100\%$$

* **Full Charge ($4.20\text{V}$)** &rarr; `100%` (`FULL`)
* **Nominal ($3.70\text{V}$)** &rarr; `40%` (`NORMAL`)
* **Low Cutoff ($3.40\text{V}$)** &rarr; `0%` (`CRITICAL`)
