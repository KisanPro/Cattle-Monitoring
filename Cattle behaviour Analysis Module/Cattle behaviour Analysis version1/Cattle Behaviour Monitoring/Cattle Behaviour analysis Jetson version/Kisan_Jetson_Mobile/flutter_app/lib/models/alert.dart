class FarmAlert {
  final String message;
  final String category;
  final String severity;
  final String timestamp;
  final String? imageUrl;
  final String? trackId;
  final String? unknownPersonId;
  final String? phone;

  FarmAlert({
    required this.message,
    required this.category,
    required this.severity,
    required this.timestamp,
    this.imageUrl,
    this.trackId,
    this.unknownPersonId,
    this.phone,
  });

  factory FarmAlert.fromJson(dynamic json) {
    if (json is String) {
      return FarmAlert(
        message: json,
        category: "GENERAL",
        severity: "info",
        timestamp: DateTime.now().toIso8601String(),
      );
    }
    return FarmAlert(
      message: json['message'] ?? 'Alert triggered',
      category: json['category'] ?? 'GENERAL',
      severity: json['severity'] ?? 'info',
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
      imageUrl: json['photo_url'] ?? json['image'] ?? json['image_url'] ?? json['crop_url'] ?? json['crop_path'],
      trackId: json['track_id']?.toString() ?? json['unknown_person_id']?.toString() ?? json['person_id']?.toString() ?? json['id']?.toString(),
      unknownPersonId: json['unknown_person_id']?.toString() ?? json['person_id']?.toString() ?? json['track_id']?.toString(),
      phone: json['phone']?.toString(),
    );
  }
}
