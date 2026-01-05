import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Reminder Preference Options (when to remind relative to due date)
enum ReminderPreference {
  none, // No notifications
  oneDayBefore, // 1 day before notification
  sameDay, // Same day notification
}

/// Reminder Time Options (what time of day to send notification)
enum ReminderTime {
  sixAM, // 6:00 AM
  nineAM, // 9:00 AM (default)
  twelvePM, // 12:00 PM
  sixPM, // 6:00 PM
  ninePM, // 9:00 PM
}

/// Extension methods for ReminderPreference
extension ReminderPreferenceExtension on ReminderPreference {
  /// Display name for UI
  String get displayName {
    switch (this) {
      case ReminderPreference.none:
        return 'None';
      case ReminderPreference.oneDayBefore:
        return 'One day before';
      case ReminderPreference.sameDay:
        return 'Same day';
    }
  }

  /// Short description for UI
  String get description {
    switch (this) {
      case ReminderPreference.none:
        return 'No notifications';
      case ReminderPreference.oneDayBefore:
        return 'Notify 1 day before due date';
      case ReminderPreference.sameDay:
        return 'Notify on the due date';
    }
  }

  /// Hive storage value
  String get storageValue {
    switch (this) {
      case ReminderPreference.none:
        return 'none';
      case ReminderPreference.oneDayBefore:
        return 'one_day_before';
      case ReminderPreference.sameDay:
        return 'same_day';
    }
  }

  /// Parse from storage value
  /// Legacy 'both' values are converted to 'oneDayBefore' for backward compatibility
  static ReminderPreference fromStorageValue(String? value) {
    switch (value) {
      case 'none':
        return ReminderPreference.none;
      case 'one_day_before':
        return ReminderPreference.oneDayBefore;
      case 'same_day':
        return ReminderPreference.sameDay;
      case 'both': // Legacy value - convert to oneDayBefore
        return ReminderPreference.oneDayBefore;
      default:
        return ReminderPreference.none; // Default to 'none' for unknown values
    }
  }
}

/// Extension methods for ReminderTime
extension ReminderTimeExtension on ReminderTime {
  /// Display name for UI
  String get displayName {
    switch (this) {
      case ReminderTime.sixAM:
        return '6:00 AM';
      case ReminderTime.nineAM:
        return '9:00 AM';
      case ReminderTime.twelvePM:
        return '12:00 PM';
      case ReminderTime.sixPM:
        return '6:00 PM';
      case ReminderTime.ninePM:
        return '9:00 PM';
    }
  }

  /// Short label for compact UI
  String get shortLabel {
    switch (this) {
      case ReminderTime.sixAM:
        return '6 AM';
      case ReminderTime.nineAM:
        return '9 AM';
      case ReminderTime.twelvePM:
        return '12 PM';
      case ReminderTime.sixPM:
        return '6 PM';
      case ReminderTime.ninePM:
        return '9 PM';
    }
  }

  /// Get the hour (24-hour format)
  int get hour {
    switch (this) {
      case ReminderTime.sixAM:
        return 6;
      case ReminderTime.nineAM:
        return 9;
      case ReminderTime.twelvePM:
        return 12;
      case ReminderTime.sixPM:
        return 18;
      case ReminderTime.ninePM:
        return 21;
    }
  }

  /// Get as TimeOfDay
  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: 0);

  /// Hive storage value
  String get storageValue {
    switch (this) {
      case ReminderTime.sixAM:
        return '6am';
      case ReminderTime.nineAM:
        return '9am';
      case ReminderTime.twelvePM:
        return '12pm';
      case ReminderTime.sixPM:
        return '6pm';
      case ReminderTime.ninePM:
        return '9pm';
    }
  }

  /// Parse from storage value
  static ReminderTime fromStorageValue(String? value) {
    switch (value) {
      case '6am':
        return ReminderTime.sixAM;
      case '12pm':
        return ReminderTime.twelvePM;
      case '6pm':
        return ReminderTime.sixPM;
      case '9pm':
        return ReminderTime.ninePM;
      case '9am':
      default:
        return ReminderTime.nineAM; // Default is 9 AM
    }
  }
}

/// Reminder Configuration
///
/// Handles dev mode and production mode durations.
/// In dev mode, uses shorter durations for testing.
class ReminderConfig {
  /// Check if running in debug/dev mode
  /// Uses Flutter's kDebugMode constant
  static bool get isDevMode => kDebugMode;

  /// Get the reminder offset duration based on preference
  static Duration getReminderOffset(ReminderPreference preference) {
    if (isDevMode) {
      return _getDevModeOffset(preference);
    } else {
      return _getProductionOffset(preference);
    }
  }

  /// Production mode offsets (real durations)
  static Duration _getProductionOffset(ReminderPreference preference) {
    switch (preference) {
      case ReminderPreference.none:
        return Duration.zero;
      case ReminderPreference.oneDayBefore:
        return const Duration(days: 1);
      case ReminderPreference.sameDay:
        return Duration.zero;
    }
  }

  /// Dev mode offsets (testing durations)
  static Duration _getDevModeOffset(ReminderPreference preference) {
    switch (preference) {
      case ReminderPreference.none:
        return Duration.zero;
      case ReminderPreference.oneDayBefore:
        return const Duration(minutes: 1);
      case ReminderPreference.sameDay:
        return const Duration(seconds: 30);
    }
  }

  /// Calculate the notification time
  ///
  /// Strictly follows the requirement: Only return future times.
  /// If calculated time is in the past, returns null.
  static DateTime? calculateNotificationTime({
    required DateTime dueDate,
    required ReminderPreference preference,
    int? reminderHour,
    int? reminderMinute,
    DateTime? referenceTime,
  }) {
    final now = DateTime.now();
    final productionOffset = _getProductionOffset(preference);

    // 1. Calculate the ACTUAL production target time
    DateTime targetDate = dueDate.subtract(productionOffset);
    DateTime realNotifyAt = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      reminderHour ?? 9,
      reminderMinute ?? 0,
      0,
    );

    DateTime notifyAt = realNotifyAt;

    // 2. Apply Dev Mode acceleration ONLY if the real time is in the past
    // or very soon, to help test immediate feedback while respecting future dates.
    if (isDevMode) {
      final devOffset = _getDevModeOffset(preference);

      if (realNotifyAt.isAfter(now)) {
        _logDebug('🚀 Future time detected, respecting: $realNotifyAt');
        notifyAt = realNotifyAt;
      } else {
        // Accelerated path for past reminders in Dev Mode
        final base = referenceTime ?? now;
        notifyAt = base.add(devOffset);
        _logDebug('⚡ Accelerated Dev Mode notification: $notifyAt');
      }
    }

    // 3. Strict Future Logic:
    // If notifyAt is in the past, return null.
    // This strictly follows the "future notifications only" requirement.
    if (notifyAt.isBefore(now)) {
      _logDebug('⏭️ Notification time ($notifyAt) is in the past. Skipping.');
      return null;
    }

    _logDebug('📅 Due Date: $dueDate');
    _logDebug('⏰ Preference: ${preference.displayName}');
    _logDebug('⏱️ Production Offset: $productionOffset');
    _logDebug('🔔 Final Notify At: $notifyAt');
    _logDebug(
      '🏗️ Mode: ${isDevMode ? "DEV (Smart Acceleration)" : "PRODUCTION"}',
    );

    return notifyAt;
  }

  /// Calculate the RAW notification time
  /// Use for display purposes if needed.
  static DateTime? calculateRawNotificationTime({
    required DateTime dueDate,
    required ReminderPreference preference,
    int? reminderHour,
    int? reminderMinute,
    DateTime? referenceTime,
  }) {
    return calculateNotificationTime(
      dueDate: dueDate,
      preference: preference,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      referenceTime: referenceTime,
    );
  }

  /// Get human-readable description of when notification will fire
  static String getNotificationTimeDescription({
    required DateTime dueDate,
    required ReminderPreference preference,
    int? reminderHour,
    int? reminderMinute,
    DateTime? referenceTime,
  }) {
    if (preference == ReminderPreference.none) return 'None';

    final notifyAt = calculateNotificationTime(
      dueDate: dueDate,
      preference: preference,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      referenceTime: referenceTime,
    );

    if (notifyAt == null) {
      return 'No reminder (past due)';
    }

    final now = DateTime.now();
    final difference = notifyAt.difference(now);

    if (difference.isNegative) {
      return 'Immediately';
    } else if (difference.inDays > 0) {
      return 'In ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'In ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'In ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'In ${difference.inSeconds} second${difference.inSeconds > 1 ? 's' : ''}';
    }
  }

  /// Debug logging helper
  static void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[ReminderConfig] $message');
    }
  }
}
