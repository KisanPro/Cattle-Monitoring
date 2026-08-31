class FarmTelemetry {
  final int totalCattle;
  final int healthy;
  final int warning;
  final int critical;
  final int attendance;
  final String modelVersion;
  final double cpuUsage;
  final double ramUsage;
  final double cpuTemp;
  final double gpuTemp;

  // Enriched telemetry data streams
  final Map<String, dynamic> cattleSummary;
  final List<dynamic> securityAttendance;
  final List<dynamic> securityUnknown;
  final List<dynamic> securityLogs;
  final List<String> masterIds;

  FarmTelemetry({
    required this.totalCattle,
    required this.healthy,
    required this.warning,
    required this.critical,
    required this.attendance,
    required this.modelVersion,
    required this.cpuUsage,
    required this.ramUsage,
    required this.cpuTemp,
    required this.gpuTemp,
    required this.cattleSummary,
    required this.securityAttendance,
    required this.securityUnknown,
    required this.securityLogs,
    required this.masterIds,
  });

  factory FarmTelemetry.fromJson(Map<String, dynamic> json) {
    final systemStatus = json['system_status'] ?? {};
    return FarmTelemetry(
      totalCattle: json['total_cattle'] ?? 0,
      healthy: json['healthy'] ?? 0,
      warning: json['warning'] ?? 0,
      critical: json['critical'] ?? 0,
      attendance: json['attendance'] ?? 0,
      modelVersion: json['model_version'] ?? 'Unknown',
      cpuUsage: (systemStatus['cpu_usage'] ?? 0.0).toDouble(),
      ramUsage: (systemStatus['ram_usage'] ?? 0.0).toDouble(),
      cpuTemp: (systemStatus['cpu_temp'] ?? 0.0).toDouble(),
      gpuTemp: (systemStatus['gpu_temp'] ?? 0.0).toDouble(),
      cattleSummary: json['cattle_summary'] ?? {},
      securityAttendance: json['security_attendance'] ?? [],
      securityUnknown: json['security_unknown'] ?? [],
      securityLogs: json['security_logs'] ?? [],
      masterIds: List<String>.from(json['master_ids'] ?? []),
    );
  }
}
