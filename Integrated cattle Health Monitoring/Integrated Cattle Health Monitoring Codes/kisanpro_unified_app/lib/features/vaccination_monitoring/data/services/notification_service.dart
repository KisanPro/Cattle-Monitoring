import 'package:flutter/foundation.dart';

class NotificationService {
  static NotificationService? _instance;
  factory NotificationService() {
    _instance ??= NotificationService._internal();
    return _instance!;
  }
  NotificationService._internal();

  bool _initialized = true;
  bool get isInitialized => _initialized;

  final List<Map<String, dynamic>> _scheduledNotifications = [];
  List<Map<String, dynamic>> get scheduledNotifications => _scheduledNotifications;

  Future<void> initialize() async {
    _initialized = true;
    debugPrint("NotificationService: Initialized successfully.");
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    _scheduledNotifications.add({
      'id': id,
      'title': title,
      'body': body,
      'scheduledDate': scheduledDate,
      'payload': payload,
    });
    debugPrint("Notification scheduled: [$title] - '$body' for $scheduledDate");
  }

  Future<void> cancelNotification(int id) async {
    _scheduledNotifications.removeWhere((n) => n['id'] == id);
    debugPrint("Notification $id cancelled.");
  }

  Future<void> cancelAll() async {
    _scheduledNotifications.clear();
    debugPrint("All notifications cancelled.");
  }
}
