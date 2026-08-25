class AlertModel {
  final int id;
  final String cowId;
  final String alertType;
  final String severity;
  final String message;
  final String timestamp;
  final bool acknowledged;

  AlertModel({
    required this.id,
    required this.cowId,
    required this.alertType,
    required this.severity,
    required this.message,
    required this.timestamp,
    required this.acknowledged,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      cowId: json['cow_id']?.toString() ?? 'KA_1989',
      alertType: json['alert_type']?.toString() ?? 'SYSTEM_ALERT',
      severity: json['severity']?.toString() ?? 'INFO',
      message: json['message']?.toString() ?? 'Alert condition detected',
      timestamp: json['timestamp']?.toString() ?? '',
      acknowledged: json['acknowledged'] == true || json['acknowledged'] == 1,
    );
  }

  bool get isCritical => severity.toUpperCase() == 'CRITICAL';
  bool get isWarning => severity.toUpperCase() == 'WARNING';
}
