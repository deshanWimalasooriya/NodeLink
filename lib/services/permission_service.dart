import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  static Future<Map<String, bool>> checkAllPermissions() async {
    if (kIsWeb) {
      return {
        'location': true,
        'background_location': true,
        'activity_recognition': true,
        'notification': true,
      };
    }

    final loc = await Permission.location.isGranted;
    final bgLoc = await Permission.locationAlways.isGranted;
    final activity = await Permission.activityRecognition.isGranted;
    final notification = await Permission.notification.isGranted;

    return {
      'location': loc,
      'background_location': bgLoc,
      'activity_recognition': activity,
      'notification': notification,
    };
  }

  static Future<bool> requestLocationPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.location.request();
    return status.isGranted;
  }

  static Future<bool> requestBackgroundLocation() async {
    if (kIsWeb) return true;
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  static Future<bool> requestActivityRecognition() async {
    if (kIsWeb) return true;
    final status = await Permission.activityRecognition.request();
    return status.isGranted;
  }

  static Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  static Future<bool> requestAll() async {
    if (kIsWeb) return true;

    // 1. Foreground Location
    await Permission.location.request();

    // 2. Background Location ("Always Allow")
    await Permission.locationAlways.request();

    // 3. Activity Recognition
    await Permission.activityRecognition.request();

    // 4. Notifications
    await Permission.notification.request();

    return true;
  }
}
