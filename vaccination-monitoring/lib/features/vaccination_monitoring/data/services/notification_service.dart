import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static NotificationService? _instance;
  factory NotificationService() {
    _instance ??= NotificationService._internal();
    return _instance!;
  }
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize timezone database
      tz_data.initializeTimeZones();
      // Set local location (default to UTC or generic if detection fails)
      final String localName = 'Asia/Kolkata'; // KisanPro primary region
      tz.setLocalLocation(tz.getLocation(localName));

      // Android initialization settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS / Darwin initialization settings
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          print("Notification clicked: ${details.payload}");
        },
      );

      _initialized = true;
      print("NotificationService: Initialized successfully.");
    } catch (e) {
      print("NotificationService initialization failed: $e. Running in debug stub mode.");
    }
  }

  // Schedule a notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_initialized) {
      print("Stub Notification Scheduled: [$title] - '$body' at $scheduledDate");
      return;
    }

    try {
      final tz.TZDateTime scheduledTZDate = tz.TZDateTime.from(scheduledDate, tz.local);
      
      // If scheduled date is in the past, don't schedule or schedule slightly in the future for demo
      if (scheduledTZDate.isBefore(tz.TZDateTime.now(tz.local))) {
        print("Warning: Notification date $scheduledDate is in the past. Skipping scheduling.");
        return;
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'vaccination_reminders_channel',
        'Vaccination Reminders',
        channelDescription: 'Alerts for upcoming livestock vaccinations',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTZDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      print("Notification scheduled successfully: '$title' at $scheduledTZDate");
    } catch (e) {
      print("Error scheduling notification: $e. Falling back to log print.");
      print("Backup Alert: [$title] - '$body' at $scheduledDate");
    }
  }

  // Cancel notification
  Future<void> cancelNotification(int id) async {
    if (!_initialized) return;
    try {
      await _notificationsPlugin.cancel(id);
      print("Notification $id cancelled.");
    } catch (e) {
      print("Error cancelling notification: $e");
    }
  }

  // Cancel all notifications
  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _notificationsPlugin.cancelAll();
      print("All notifications cancelled.");
    } catch (e) {
      print("Error cancelling all notifications: $e");
    }
  }
}
