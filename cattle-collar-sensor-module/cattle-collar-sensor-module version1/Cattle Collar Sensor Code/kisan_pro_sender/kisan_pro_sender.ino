#include <SPI.h>
#include <LoRa.h>
#include <TinyGPS++.h>
#include <HardwareSerial.h>
#include <Wire.h>
#include <Adafruit_LSM6DSOX.h>

// --- Configuration ---
const String COW_ID = "KA_1989"; // Unique Tag for this cattle

// --- LoRa Pins ---
#define ss 5
#define rst 14
#define dio0 26

// --- GPS Pins (L89) ---
#define RXD2 16
#define TXD2 17

// --- Battery Pin ---
#define BATTERY_PIN 35

// --- Objects ---
TinyGPSPlus gps;
HardwareSerial gpsSerial(2);
Adafruit_LSM6DSOX sox;

// --- Timers ---
unsigned long lastSendTime = 0;
unsigned long lastImuTime = 0;
const unsigned long sendInterval = 5000; // 5 seconds transmission rate for real-time tracking

// --- State Variables ---
int stepCount = 0;
bool isStepHigh = false;
unsigned long lastStepTime = 0;
float baselineAccel = 9.81;
String currentBehavior = "Unknown";
int currentBehaviorID = 0;

void setup() {
  Serial.begin(115200);
  delay(2000); // Give Serial Monitor 2 full seconds to open
  Serial.println("\n=============================================");
  Serial.println("=== Kisan Pro Collar: Master Node Started ===");
  Serial.println("ID: " + COW_ID);
  Serial.println("=============================================\n");

  // 1. Initialize LoRa SX1278 (433 MHz)
  LoRa.setPins(ss, rst, dio0);
  if (!LoRa.begin(433E6)) { 
    Serial.println("CRITICAL: LoRa failed to start! Check wiring.");
    while (1);
  }
  LoRa.setSyncWord(0x12);       // Standard LoRa sync word for SX1278 modules
  LoRa.setSpreadingFactor(7);   // Spreading Factor 7 (Default fast rate)
  LoRa.setSignalBandwidth(125E3); // 125 kHz Bandwidth
  LoRa.setTxPower(17);          // Set max reliable transmit power (17 dBm)
  LoRa.enableCrc();             // Hardware CRC check
  Serial.println("[OK] LoRa Radio Initialized at 433 MHz (SF7, 125kHz).");

  // 2. Initialize L89 GPS Module
  gpsSerial.begin(9600, SERIAL_8N1, RXD2, TXD2);
  Serial.println("[OK] GPS Module Initialized.");

  // 3. Initialize LSM6DSOX IMU (Non-blocking I2C)
  Wire.begin(21, 22); 
  if (!sox.begin_I2C(0x6A) && !sox.begin_I2C(0x6B)) {
    Serial.println("WARNING: Failed to find LSM6DSOX IMU! Continuing...");
  } else {
    Serial.println("[OK] LSM6DSOX IMU Initialized.");
    sox.setAccelRange(LSM6DS_ACCEL_RANGE_4_G);
    sox.setGyroRange(LSM6DS_GYRO_RANGE_500_DPS);
    sox.setAccelDataRate(LSM6DS_RATE_104_HZ);
    sox.setGyroDataRate(LSM6DS_RATE_104_HZ);
  }
  
  pinMode(BATTERY_PIN, INPUT);
}

// --- Function Declarations ---
float getBatteryVoltage();
int getBatteryPercentage();
String getBatteryStatus();

void processIMU() {
  sensors_event_t accel, gyro, temp;
  if (!sox.getEvent(&accel, &gyro, &temp)) {
    currentBehavior = "IMU_ERROR";
    currentBehaviorID = 0;
    return;
  }
  
  float aX = accel.acceleration.x;
  float aY = accel.acceleration.y;
  float aZ = accel.acceleration.z;
  float gX = gyro.gyro.x;
  float gY = gyro.gyro.y;
  float gZ = gyro.gyro.z;

  float accelMag = sqrt(aX*aX + aY*aY + aZ*aZ);
  float gyroMag = sqrt(gX*gX + gY*gY + gZ*gZ);

  // --- Step Counter ---
  baselineAccel = (baselineAccel * 0.9) + (accelMag * 0.1);
  if (accelMag > baselineAccel + 2.0) { 
    if (!isStepHigh && (millis() - lastStepTime > 300)) { 
      stepCount++;
      isStepHigh = true;
      lastStepTime = millis();
    }
  } else if (accelMag < baselineAccel + 0.5) {
    isStepHigh = false; 
  }

  // --- Behavior Classifier Engine ---
  if (accelMag > 25.0) {
    currentBehavior = "Fall"; currentBehaviorID = 5;
  } else if (accelMag > 15.0 && gyroMag > 3.0) {
    currentBehavior = "Super Active (Estrus)"; currentBehaviorID = 3;
  } else if (gyroMag > 4.0) {
    currentBehavior = "Head Shake"; currentBehaviorID = 6;
  } else if (aZ < -7.0 && accelMag > 9.0 && accelMag < 12.0 && gyroMag > 0.5) {
    currentBehavior = "Grazing"; currentBehaviorID = 7;
  } else if (accelMag > 11.0 && gyroMag > 1.0) {
    currentBehavior = "Walking"; currentBehaviorID = 2;
  } else if (abs(aX) > 8.0 || abs(aY) > 8.0) {
    currentBehavior = "Lying"; currentBehaviorID = 4;
  } else {
    currentBehavior = "Standing"; currentBehaviorID = 1;
  }
}

void loop() {
  // 1. ALWAYS feed the GPS data non-blocking
  while (gpsSerial.available() > 0) {
    gps.encode(gpsSerial.read());
  }

  // 2. Read IMU 10 times a second (100ms interval)
  if (millis() - lastImuTime >= 100) {
    processIMU();
    lastImuTime = millis();
  }

  // 3. Send LoRa Packet
  if (millis() - lastSendTime >= sendInterval) {
    int battery = getBatteryPercentage();
    float bVoltage = getBatteryVoltage();
    String bStatus = getBatteryStatus();
    
    // Default GPS values
    float latitude = 0.0, longitude = 0.0, speed = 0.0, alt = 0.0;
    int sats = 0;
    String gpsStatus = "NO_GPS";

    if (gps.location.isValid()) {
      latitude = gps.location.lat();
      longitude = gps.location.lng();
      speed = gps.speed.kmph();
      alt = gps.altitude.meters();
      sats = gps.satellites.value();
      gpsStatus = "OK";
    } else {
      if (gps.charsProcessed() < 10) {
        Serial.println("  [GPS DIAGNOSTIC] 0 Bytes from GPS module! Check TX/RX wiring (GPS TX -> ESP32 RX2 Pin 16).");
      } else {
        Serial.println("  [GPS DIAGNOSTIC] Receiving data (" + String(gps.charsProcessed()) + " bytes), searching for satellites... (Move near window/outdoors).");
      }
    }

    String latStr = "NO_GPS";
    String lonStr = "0.0";
    if (gpsStatus == "OK") {
      latStr = String(latitude, 6);
      lonStr = String(longitude, 6);
    }

    // Packet Structure: CowID,Lat,Lon,Speed,Alt,Satellites,BehaviorID,Battery,Steps
    String packet = COW_ID + "," + 
                    latStr + "," + 
                    lonStr + "," + 
                    String(speed, 2) + "," + 
                    String(alt, 1) + "," + 
                    String(sats) + "," + 
                    String(currentBehaviorID) + "," + 
                    String(battery) + "," + 
                    String(stepCount);
                    
    Serial.println("-----------------------------------");
    Serial.println("STATUS: " + currentBehavior + " | Steps: " + String(stepCount) + " | Battery: " + String(battery) + "% (" + String(bVoltage, 2) + "V - " + bStatus + ")");
    Serial.println("SENDING: " + packet);
    
    LoRa.beginPacket();
    LoRa.print(packet);
    if (LoRa.endPacket()) {
      Serial.println("[TX SUCCESS] Packet sent over RF.");
    } else {
      Serial.println("[TX FAIL] LoRa transmission error!");
    }
    
    lastSendTime = millis();
  }
}

// --- Battery ADC Helper Functions ---
float getBatteryVoltage() {
  int raw = analogRead(BATTERY_PIN);
  // ESP32 12-bit ADC (0-4095), 3.3V VREF with 100k/100k voltage divider (2.0x factor)
  float voltage = (raw / 4095.0) * 3.3 * 2.0 * 1.05;
  if (voltage < 0.5) voltage = 3.95; // Default fallback for unconnected pin testing
  return voltage;
}

int getBatteryPercentage() {
  float v = getBatteryVoltage();
  if (v >= 4.2) return 100;
  if (v <= 3.3) return 5;
  int pct = (int)(((v - 3.3) / (4.2 - 3.3)) * 100.0);
  return constrain(pct, 5, 100);
}

String getBatteryStatus() {
  int pct = getBatteryPercentage();
  if (pct >= 85) return "FULL";
  if (pct >= 30) return "NORMAL";
  if (pct >= 15) return "LOW";
  return "CRITICAL";
}

