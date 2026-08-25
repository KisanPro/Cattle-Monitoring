class CattleModel {
  final String cowId;
  final String name;
  final String breed;
  final double ageYears;
  final String lactationStage;
  final String hardwareImei;
  final String latestBehavior;
  final int behaviorId;
  final int batteryLevel;
  final String batteryStatus;
  final int totalSteps;
  final double latitude;
  final double longitude;
  final double speed;
  final double altitude;
  final int satellites;
  final String gpsStatus;
  final String lastUpdated;

  CattleModel({
    required this.cowId,
    required this.name,
    required this.breed,
    required this.ageYears,
    required this.lactationStage,
    required this.hardwareImei,
    required this.latestBehavior,
    required this.behaviorId,
    required this.batteryLevel,
    required this.batteryStatus,
    required this.totalSteps,
    required this.latitude,
    required this.longitude,
    this.speed = 0.0,
    this.altitude = 0.0,
    this.satellites = 0,
    required this.gpsStatus,
    required this.lastUpdated,
  });

  factory CattleModel.fromJson(Map<String, dynamic> json) {
    int battery = json['battery_level'] ?? json['battery'] ?? 0;
    String bStatus = json['battery_status'] ?? '';
    if (bStatus.isEmpty) {
      if (battery >= 85) {
        bStatus = 'FULL';
      } else if (battery >= 30) {
        bStatus = 'NORMAL';
      } else if (battery >= 15) {
        bStatus = 'LOW';
      } else {
        bStatus = 'CRITICAL';
      }
    }

    return CattleModel(
      cowId: json['cow_id']?.toString() ?? 'UNKNOWN',
      name: json['name']?.toString() ?? (json['cow_id']?.toString() ?? 'Cattle'),
      breed: json['breed']?.toString() ?? 'Livestock',
      ageYears: (json['age_years'] is num) ? (json['age_years'] as num).toDouble() : 3.0,
      lactationStage: json['lactation_stage']?.toString() ?? 'Active',
      hardwareImei: json['hardware_imei']?.toString() ?? 'ESP32-LoRa',
      latestBehavior: json['latest_behavior']?.toString() ?? (json['behavior']?.toString() ?? 'Unknown'),
      behaviorId: json['behavior_id'] is int ? json['behavior_id'] : int.tryParse(json['behavior_id']?.toString() ?? '0') ?? 0,
      batteryLevel: battery,
      batteryStatus: bStatus,
      totalSteps: json['total_steps'] ?? json['steps'] ?? 0,
      latitude: (json['latitude'] is num) ? (json['latitude'] as num).toDouble() : 0.0,
      longitude: (json['longitude'] is num) ? (json['longitude'] as num).toDouble() : 0.0,
      speed: (json['speed'] is num) ? (json['speed'] as num).toDouble() : 0.0,
      altitude: (json['altitude'] is num) ? (json['altitude'] as num).toDouble() : 0.0,
      satellites: json['satellites'] ?? 0,
      gpsStatus: json['gps_status']?.toString() ?? (json['latitude'] != null && (json['latitude'] as num) != 0 ? 'OK' : 'NO_GPS'),
      lastUpdated: json['last_updated']?.toString() ?? '',
    );
  }

  String get behaviorName {
    switch (behaviorId) {
      case 0: return 'IMU Fault';
      case 1: return 'Standing';
      case 2: return 'Walking';
      case 3: return 'Running';
      case 4: return 'Lying';
      case 5: return 'Fall / Emergency';
      case 6: return 'Head Shake';
      case 7: return 'Grazing';
      default: return latestBehavior;
    }
  }

  bool get isGpsFix => gpsStatus == 'OK' && latitude != 0.0 && longitude != 0.0;
}
