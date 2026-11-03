import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String messageChannelId = 'nodelink_chat_messages';
  static const String messageChannelName = 'NodeLink Chat Messages';
  static const String messageChannelDescription =
      'Instant heads-up notifications for incoming encrypted messages.';

  bool _isInitialized = false;

  Future<void> initialize({
    void Function(String? payload)? onSelectNotification,
  }) async {
    if (kIsWeb || _isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null && onSelectNotification != null) {
            onSelectNotification(response.payload);
          }
        },
      );

      // Create high-priority notification channel for Android 8.0+
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            messageChannelId,
            messageChannelName,
            description: messageChannelDescription,
            importance: Importance.max,
            enableVibration: true,
            playSound: true,
            showBadge: true,
          ),
        );
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('[NotificationService] Init error: $e');
    }
  }

  /// Displays an instant Heads-Up notification for an incoming chat message
  Future<void> showIncomingMessageNotification({
    required String senderName,
    required String messagePreview,
    required String senderId,
    int? notificationId,
  }) async {
    if (kIsWeb) return;
    if (!_isInitialized) {
      await initialize();
    }

    final id = notificationId ?? senderId.hashCode.abs() % 100000;

    const androidDetails = AndroidNotificationDetails(
      messageChannelId,
      messageChannelName,
      channelDescription: messageChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'New encrypted message',
      enableVibration: true,
      playSound: true,
      showWhen: true,
      category: AndroidNotificationCategory.message,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'message',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        id,
        senderName,
        messagePreview,
        notificationDetails,
        payload: senderId,
      );
    } catch (e) {
      debugPrint('[NotificationService] Show error: $e');
    }
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancel(id);
    } catch (e) {
      debugPrint('[NotificationService] Cancel error: $e');
    }
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('[NotificationService] CancelAll error: $e');
    }
  }
}
