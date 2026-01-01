import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;

/// Permission Service - Handle runtime permission checks
///
/// Manages all permission-related logic for notifications and exact alarms.
/// Provides methods to check permission status without forcing users.
///
/// Key features:
/// - Check if exact alarms are available (Android 12+)
/// - Check if notification permission is granted (Android 13+)
/// - Automatic platform detection (iOS/Android)
/// - No forced permission requests - just checking
class PermissionService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Check if the app can schedule exact alarms
  ///
  /// Returns true if:
  /// - On iOS (always true)
  /// - On Android with USE_EXACT_ALARM permission granted
  /// - On Android API < 31 (no permission needed)
  ///
  /// This does NOT request permission, just checks current status.
  Future<bool> canScheduleExactAlarms() async {
    try {
      // iOS always allows exact alarms
      if (!Platform.isAndroid) {
        return true;
      }

      // Android 12+ requires permission check
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin == null) {
        _logDebug('⚠️ Android plugin not available');
        return false;
      }

      // Check if exact alarms are allowed
      // This returns true if:
      // - USE_EXACT_ALARM is declared in manifest (auto-granted)
      // - SCHEDULE_EXACT_ALARM is granted by user
      // - Android API < 31
      final canSchedule = await androidPlugin.canScheduleExactNotifications();

      _logDebug('✅ Can schedule exact alarms: $canSchedule');
      return canSchedule ?? false;
    } catch (e) {
      _logDebug('❌ Error checking exact alarm permission: $e');
      return false;
    }
  }

  /// Check if notification permission is granted (Android 13+)
  ///
  /// Returns true if:
  /// - On iOS (handled by system)
  /// - On Android with POST_NOTIFICATIONS permission granted
  /// - On Android API < 33 (no permission needed)
  Future<bool> hasNotificationPermission() async {
    try {
      // iOS handles notification permissions differently
      if (!Platform.isAndroid) {
        return true;
      }

      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin == null) {
        return false;
      }

      // For Android 13+, check POST_NOTIFICATIONS permission
      final hasPermission = await androidPlugin.areNotificationsEnabled();

      _logDebug('📱 Notification permission: $hasPermission');
      return hasPermission ??
          true; // Default to true for older Android versions
    } catch (e) {
      _logDebug('❌ Error checking notification permission: $e');
      return true; // Assume granted on error (older Android)
    }
  }

  /// Request notification permission (Android 13+)
  ///
  /// Only requests if needed (Android 13+).
  /// Returns true if granted, false otherwise.
  Future<bool> requestNotificationPermission() async {
    try {
      if (!Platform.isAndroid) {
        // iOS handles this through initialization
        return true;
      }

      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin == null) {
        return false;
      }

      // Request notification permission (Android 13+)
      final granted = await androidPlugin.requestNotificationsPermission();

      _logDebug('📲 Notification permission requested: $granted');
      return granted ?? false;
    } catch (e) {
      _logDebug('❌ Error requesting notification permission: $e');
      return false;
    }
  }

  /// Get a summary of all permission statuses
  ///
  /// Useful for debugging and settings UI.
  Future<PermissionStatus> getPermissionStatus() async {
    final canExact = await canScheduleExactAlarms();
    final hasNotif = await hasNotificationPermission();

    return PermissionStatus(
      canScheduleExactAlarms: canExact,
      hasNotificationPermission: hasNotif,
      platform: Platform.isAndroid ? 'Android' : 'iOS',
    );
  }

  /// Debug logging helper
  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[PermissionService] $message');
    }
  }
}

/// Permission status information
class PermissionStatus {
  final bool canScheduleExactAlarms;
  final bool hasNotificationPermission;
  final String platform;

  PermissionStatus({
    required this.canScheduleExactAlarms,
    required this.hasNotificationPermission,
    required this.platform,
  });

  /// Check if all required permissions are granted
  bool get allGranted => canScheduleExactAlarms && hasNotificationPermission;

  /// Human-readable summary
  String get summary {
    if (allGranted) {
      return '✅ All permissions granted';
    }

    final issues = <String>[];
    if (!canScheduleExactAlarms) {
      issues.add('Exact alarms not available');
    }
    if (!hasNotificationPermission) {
      issues.add('Notification permission needed');
    }

    return '⚠️ ${issues.join(', ')}';
  }

  @override
  String toString() {
    return 'PermissionStatus(exact: $canScheduleExactAlarms, notif: $hasNotificationPermission, platform: $platform)';
  }
}
