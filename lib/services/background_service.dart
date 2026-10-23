import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BackgroundService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'nodelink_foreground_channel';
  static const String channelName = 'NodeLink Foreground Tracking';
  static const String channelDescription =
      'Persistent notification keeping NodeLink polling logic alive in background.';
  static const int notificationId = 842915;

  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (kIsWeb || _isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(initSettings);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing background notification service: $e');
    }
  }

  static Future<void> showPersistentTrackingNotification({
    String title = 'NodeLink Active: Securely sharing Location',
    String body = 'Smart Adaptive Polling active (Interval: 1 min)',
  }) async {
    if (kIsWeb) return;
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true, // un-swipeable persistent notification
      autoCancel: false,
      showWhen: true,
      enableVibration: false,
      playSound: false,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      ),
    );

    try {
      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Error showing foreground notification: $e');
    }
  }

  static Future<void> cancelTrackingNotification() async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancel(notificationId);
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }
}
