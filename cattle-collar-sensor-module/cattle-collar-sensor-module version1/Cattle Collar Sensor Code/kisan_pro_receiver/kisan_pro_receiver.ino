#include <SPI.h>
#include <LoRa.h>
#include <WiFi.h>
#include <HTTPClient.h>

// --- LoRa SX1278 SPI Pins ---
#define ss 5
#define rst 14
#define dio0 26

// --- Status Indicator LED ---
#define LED_PIN 2

// --- WiFi Configuration ---
const char* ssid = "Geetha Shivaiah";
const char* password = "123456789";

// --- API Server Endpoints ---
// Primary Permanent AWS EC2 Elastic IP Endpoint (Port 5000):
String awsServerUrl = "http://15.206.32.94:5000/api/v1/telemetry";

// Secondary Local Laptop Server Endpoints:
String localServerUrl1 = "http://192.168.0.148:5005/api/v1/telemetry";
String localServerUrl2 = "http://10.143.174.22:5005/api/v1/telemetry";
String localServerUrl3 = "http://10.143.174.1:5005/api/v1/telemetry";

// --- Function Declarations ---
void sendTelemetryToCloud(String packetData, int rssi, float snr);
void connectWiFi();

// --- Global Timing & State ---
unsigned long lastWiFiRetryTime = 0;

void setup() {
  Serial.begin(115200);
  delay(2000);
  
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  Serial.println("\n=============================================");
  Serial.println("=== Kisan Pro Collar: AWS Master Gateway ===");
  Serial.println("=============================================\n");

  // 1. Connect to WiFi
  connectWiFi();

  // 2. Initialize LoRa SX1278 (433 MHz)
  LoRa.setPins(ss, rst, dio0);
  if (!LoRa.begin(433E6)) {
    Serial.println("[ERROR] Starting LoRa failed! Check wiring (SS=5, RST=14, DIO0=26).");
    while (1) {
      digitalWrite(LED_PIN, HIGH);
      delay(100);
      digitalWrite(LED_PIN, LOW);
      delay(100);
    }
  }

  // Radio Configurations (Must match Collar Sender node)
  LoRa.setSyncWord(0x12);
  LoRa.setSpreadingFactor(7);
  LoRa.setSignalBandwidth(125E3);
  LoRa.enableCrc();
  Serial.println("[OK] LoRa SX1278 Initialized at 433 MHz (SyncWord 0x12, SF7, 125kHz, CRC Enabled).");
  Serial.println("[READY] Listening for incoming cattle collar telemetry packets...\n");
}

void loop() {
  // Check for incoming LoRa packet
  int packetSize = LoRa.parsePacket();
  if (packetSize) {
    // Flash onboard LED on packet arrival
    digitalWrite(LED_PIN, HIGH);

    String incoming = "";
    while (LoRa.available()) {
      char c = (char)LoRa.read();
      if ((c >= 32 && c <= 126) || c == '\n' || c == '\r') {
        incoming += c;
      }
    }
    incoming.trim();

    int rssi = LoRa.packetRssi();
    float snr = LoRa.packetSnr();

    Serial.println("---------------------------------------------");
    Serial.print("[LoRa RX] Received packet (");
    Serial.print(packetSize);
    Serial.print(" bytes) | RSSI: ");
    Serial.print(rssi);
    Serial.print(" dBm | SNR: ");
    Serial.print(snr);
    Serial.println(" dB");
    Serial.print("[Raw Payload]: ");
    Serial.println(incoming);

    if (incoming.length() >= 5) {
      // Forward to Cloud/Local Server
      sendTelemetryToCloud(incoming, rssi, snr);
    } else {
      Serial.println("[WARNING] Noise frame filtered (<5 chars).");
    }
    Serial.println("---------------------------------------------\n");

    digitalWrite(LED_PIN, LOW);
  }

  // Non-blocking WiFi reconnect check (every 10 seconds)
  if (WiFi.status() != WL_CONNECTED && (millis() - lastWiFiRetryTime > 10000)) {
    lastWiFiRetryTime = millis();
    connectWiFi();
  }
}

void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;

  Serial.print("[WiFi] Connecting to '");
  Serial.print(ssid);
  Serial.print("'");

  WiFi.disconnect(true);
  delay(100);
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false); // Disable WiFi power sleep to prevent connection drops & resets
  WiFi.begin(ssid, password);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 15) {
    delay(400);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[OK] Connected to WiFi!");
    Serial.print("[IP Address]: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\n[WARNING] WiFi Connection pending. Will retry in 10 seconds...");
  }
}

void sendTelemetryToCloud(String packetData, int rssi, float snr) {
  // Packet CSV Format: COW_ID, Latitude, Longitude, Speed, Altitude, Satellites, BehaviorID, Battery, Steps
  // Example: KA_1989,12.971598,77.594562,0.5,920.0,8,7,95,248

  String cow_id = "KA_1989";
  float latitude = 0.0;
  float longitude = 0.0;
  float speed = 0.0;
  float altitude = 0.0;
  int satellites = 0;
  int behavior_id = 0;
  int battery = 0;
  int steps = 0;

  int count = 0;
  int lastIdx = 0;
  
  String tokens[9];
  for (int i = 0; i < packetData.length(); i++) {
    if (packetData.charAt(i) == ',') {
      if (count < 9) {
        tokens[count++] = packetData.substring(lastIdx, i);
      }
      lastIdx = i + 1;
    }
  }
  if (count < 9 && lastIdx < packetData.length()) {
    tokens[count++] = packetData.substring(lastIdx);
  }

  if (count >= 8) {
    cow_id = tokens[0];
    cow_id.trim();

    // Auto-correct RF bit flips / corrupted preamble bytes (e.g. 'rA_1989' -> 'KA_1989')
    if (cow_id.indexOf("1989") != -1) cow_id = "KA_1989";
    else if (cow_id.indexOf("1990") != -1) cow_id = "KA_1990";
    else if (cow_id.indexOf("1991") != -1) cow_id = "KA_1991";
    else if (cow_id.indexOf("1992") != -1) cow_id = "KA_1992";
    else {
      cow_id.toUpperCase();
      // If missing KA_ prefix due to RF preamble corruption, auto-prefix
      if (!cow_id.startsWith("KA_") && cow_id.length() >= 3) {
        int numIdx = -1;
        for (int k = 0; k < cow_id.length(); k++) {
          if (isDigit(cow_id.charAt(k))) { numIdx = k; break; }
        }
        if (numIdx != -1) {
          cow_id = "KA_" + cow_id.substring(numIdx);
        }
      }
    }

    latitude = (tokens[1] == "NO_GPS" || tokens[1] == "0.0") ? 0.0 : tokens[1].toFloat();
    longitude = (tokens[2] == "NO_GPS" || tokens[2] == "0.0") ? 0.0 : tokens[2].toFloat();
    speed = tokens[3].toFloat();
    altitude = tokens[4].toFloat();
    satellites = tokens[5].toInt();
    behavior_id = tokens[6].toInt();
    battery = tokens[7].toInt();
    if (count >= 9) {
      steps = tokens[8].toInt();
    }
  } else {
    Serial.println("[WARNING] Packet format incomplete. Dropping corrupted frame.");
    return;
  }

  // Derive Battery Status
  String battery_status = "NORMAL";
  if (battery >= 85) battery_status = "FULL";
  else if (battery >= 30) battery_status = "NORMAL";
  else if (battery >= 15) battery_status = "LOW";
  else battery_status = "CRITICAL";

  // Construct JSON Body for FastAPI /api/v1/telemetry
  String jsonBody = "{";
  jsonBody += "\"cow_id\":\"" + cow_id + "\",";
  jsonBody += "\"latitude\":" + String(latitude, 6) + ",";
  jsonBody += "\"longitude\":" + String(longitude, 6) + ",";
  jsonBody += "\"speed\":" + String(speed, 2) + ",";
  jsonBody += "\"altitude\":" + String(altitude, 2) + ",";
  jsonBody += "\"satellites\":" + String(satellites) + ",";
  jsonBody += "\"behavior_id\":" + String(behavior_id) + ",";
  jsonBody += "\"battery\":" + String(battery) + ",";
  jsonBody += "\"battery_status\":\"" + battery_status + "\",";
  jsonBody += "\"steps\":" + String(steps);
  jsonBody += "}";

  Serial.println("[BATTERY DIAGNOSTIC]: " + String(battery) + "% | Status: " + battery_status);
  Serial.print("[JSON Payload]: ");
  Serial.println(jsonBody);


  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[HTTP Error] ESP32 Gateway is NOT connected to Wi-Fi! Reconnecting...");
    connectWiFi();
    if (WiFi.status() != WL_CONNECTED) return;
  }

  // Primary Attempt: AWS Cloud Server
  WiFiClient client;
  HTTPClient http;
  http.setTimeout(5000); // 5 sec timeout
  
  if (http.begin(client, awsServerUrl)) {
    http.addHeader("Content-Type", "application/json");
    http.addHeader("User-Agent", "ESP32-LoRa-Gateway");
    
    int httpResponseCode = http.POST(jsonBody);

    if (httpResponseCode > 0) {
      String response = http.getString();
      Serial.print("[HTTP Success] AWS Cloud Code: ");
      Serial.print(httpResponseCode);
      Serial.print(" | Response: ");
      Serial.println(response);
      http.end();
      return;
    } else {
      Serial.print("[HTTP Warning] AWS POST failed (Code: ");
      Serial.print(httpResponseCode);
      Serial.print(" - ");
      Serial.print(http.errorToString(httpResponseCode));
      Serial.println("). Attempting Local Backup 1...");
    }
    http.end();
  }

  // Backup Attempt 1: Local Laptop Server IP 1 (172.23.146.59)
  WiFiClient client1;
  if (http.begin(client1, localServerUrl1)) {
    http.setTimeout(4000);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("User-Agent", "ESP32-LoRa-Gateway");
    int localCode = http.POST(jsonBody);
    
    if (localCode > 0) {
      Serial.print("[HTTP Success] Local Backup Server 1 Code: ");
      Serial.println(localCode);
      http.end();
      return;
    } else {
      Serial.print("[HTTP Warning] Local Backup 1 failed (Code: ");
      Serial.print(localCode);
      Serial.println("). Attempting Local Backup 2 (10.143.174.221)...");
    }
    http.end();
  }

  // Backup Attempt 2: Local Laptop Server IP 2 (10.143.174.22)
  WiFiClient client2;
  if (http.begin(client2, localServerUrl2)) {
    http.setTimeout(3000);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("User-Agent", "ESP32-LoRa-Gateway");
    int localCode2 = http.POST(jsonBody);
    if (localCode2 > 0) {
      Serial.print("[HTTP Success] Local Backup Server 2 Code: ");
      Serial.println(localCode2);
      http.end();
      return;
    }
    http.end();
  }

  // Backup Attempt 3: Local Laptop Server IP 3 (10.143.174.1 Hotspot Gateway)
  WiFiClient client3;
  if (http.begin(client3, localServerUrl3)) {
    http.setTimeout(3000);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("User-Agent", "ESP32-LoRa-Gateway");
    int localCode3 = http.POST(jsonBody);
    if (localCode3 > 0) {
      Serial.print("[HTTP Success] Local Backup Server 3 Code: ");
      Serial.println(localCode3);
    } else {
      Serial.println("[HTTP Warning] All local server endpoints returned connection timeout/refused.");
    }
    http.end();
  }
}
