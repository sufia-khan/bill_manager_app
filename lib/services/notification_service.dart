import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/bill.dart';
import '../core/reminder_config.dart';

/// Notification Service - Manages local bill reminders
///
/// Features:
/// - Exact scheduling for "One day before" and "Same day"
/// - Android exact alarm support
/// - Dev mode acceleration (short durations)
/// - Master global toggle support
class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Global toggle for all notifications
  bool globalEnabled = true;

  /// User ID filter for multi-user isolation
  String? _userId;

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('[NotificationService] 🚀 Initializing...');

    // Initialize timezones
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        print(
          '[NotificationService] 🔔 Notification clicked: ${details.payload}',
        );
      },
    );

    _isInitialized = true;
    print('[NotificationService] ✅ Initialization complete');
  }

  /// Sets the current user ID for notification isolation
  void setUserId(String? id) {
    _userId = id;
    print('[NotificationService] 👤 User ID set for isolation: $id');
  }

  /// Uses user's custom reminder time (hour:minute) for all notifications
  /// Schedule reminders for a specific bill
  /// Returns a Map indicating which notifications were triggered (true = scheduled/sent)
  Future<Map<String, bool>> scheduleBillReminders(Bill bill) async {
    print('[NotificationService] 📅 === SCHEDULING BILL REMINDER ===');
    print('[NotificationService] Bill: "${bill.name}"');
    print('[NotificationService] ID: ${bill.id}');

    final Map<String, bool> results = {'oneDayBefore': false, 'sameDay': false};

    if (!_isInitialized) {
      print('[NotificationService] ⚠️ Not initialized, initializing...');
      await initialize();
    }

    if (!globalEnabled) {
      print(
        '[NotificationService] 🚫 Global notifications are DISABLED, skipping...',
      );
      await cancelBillReminders(bill.id);
      return results;
    }

    // Don't schedule for paid bills
    if (bill.paid) {
      print('[NotificationService] ⏭️ Bill is paid, skipping notification');
      return results;
    }

    // Don't schedule if preference is 'none'
    if (bill.reminderPreference == ReminderPreference.none) {
      print(
        '[NotificationService] 🔕 Preference is NONE, skipping notifications',
      );
      return results;
    }

    final now = DateTime.now();
    print('[NotificationService] Current Time: $now');

    // Cancel any existing notifications for this bill
    await cancelBillReminders(bill.id);
    print('[NotificationService] 🗑️ Cancelled any existing notifications');

    // Determine which notifications to schedule based on preference
    final bool scheduleOneDayBefore =
        bill.reminderPreference == ReminderPreference.oneDayBefore;
    final bool scheduleSameDay =
        bill.reminderPreference == ReminderPreference.sameDay;

    int scheduledCount = 0;

    // Schedule "one day before" notification
    if (scheduleOneDayBefore) {
      if (bill.isNotificationOneDayBeforeSent) {
        print(
          '[NotificationService] ⏭️ One day before notification already sent, skipping',
        );
      } else {
        final notificationTime = _calculateNotificationTime(
          bill,
          oneDayBefore: true,
        );

        if (notificationTime != null) {
          await _scheduleNotification(
            bill: bill,
            notificationId: bill.id.hashCode.abs() % 100000,
            notificationTime: notificationTime,
            title: 'Bill Due Tomorrow',
            body: '${bill.name} - ${bill.formattedAmount} is due tomorrow',
          );
          scheduledCount++;
          print(
            '[NotificationService] 🔔 Scheduled ONE DAY BEFORE for: $notificationTime',
          );
        } else {
          // If null is returned, it means it's either overdue or in the past
          // Mark as handled (true) so we don't keep trying to schedule it
          results['oneDayBefore'] = true;
          print(
            '[NotificationService] ⏭️ One day before notification skipped (past/missing), marking as handled',
          );
        }
      }
    }

    // Schedule "same day" notification
    if (scheduleSameDay) {
      if (bill.isNotificationSameDaySent) {
        print(
          '[NotificationService] ⏭️ Same day notification already sent, skipping',
        );
      } else {
        final notificationTime = _calculateNotificationTime(
          bill,
          oneDayBefore: false,
        );

        if (notificationTime != null) {
          await _scheduleNotification(
            bill: bill,
            notificationId: (bill.id.hashCode.abs() % 100000) + 1,
            notificationTime: notificationTime,
            title: 'Bill Due Today',
            body: '${bill.name} - ${bill.formattedAmount} is due today!',
          );
          scheduledCount++;
          print(
            '[NotificationService] 🔔 Scheduled SAME DAY for: $notificationTime',
          );
        } else {
          // If null is returned, it means it's either overdue or in the past
          // Mark as handled (true) so we don't keep trying to schedule it
          results['sameDay'] = true;
          print(
            '[NotificationService] ⏭️ Same day notification skipped (past/missing), marking as handled',
          );
        }
      }
    }

    print(
      '[NotificationService] ✅ Scheduled $scheduledCount notification(s) for "${bill.name}"',
    );
    print('[NotificationService] === SCHEDULING COMPLETE ===');
    return results;
  }

  /// Calculate notification time based on due date, reminder time, and whether it's one day before
  DateTime? _calculateNotificationTime(
    Bill bill, {
    required bool oneDayBefore,
  }) {
    final preference = oneDayBefore
        ? ReminderPreference.oneDayBefore
        : ReminderPreference.sameDay;

    return ReminderConfig.calculateNotificationTime(
      dueDate: bill.dueDate,
      preference: preference,
      reminderHour: bill.reminderTimeHour,
      reminderMinute: bill.reminderTimeMinute,
      referenceTime: bill.updatedAt,
    );
  }

  /// Helper method to schedule a single notification
  Future<void> _scheduleNotification({
    required Bill bill,
    required int notificationId,
    required DateTime notificationTime,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'bill_reminders',
      'Bill Reminders',
      channelDescription: 'Reminders for upcoming bill due dates',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      final tzDateTime = tz.TZDateTime.from(notificationTime, tz.local);
      print('[NotificationService] 🕒 Scheduling for: $tzDateTime');

      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: bill.id,
      );

      print(
        '[NotificationService] ✅ Successfully scheduled: "$title" at $tzDateTime',
      );
    } catch (e) {
      print('[NotificationService] ❌ ERROR scheduling notification: $e');
      rethrow;
    }
  }

  /// Cancel notifications for a bill
  Future<void> cancelBillReminders(String billId) async {
    final baseId = billId.hashCode.abs() % 100000;
    await _notifications.cancel(baseId);
    await _notifications.cancel(baseId + 1);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    print('[NotificationService] 🗑️ Cancelling all notifications...');
    await _notifications.cancelAll();
  }

  /// Reschedule all notifications for a list of bills
  Future<void> rescheduleAllReminders(List<Bill> bills) async {
    print(
      '[NotificationService] 🔄 Rescheduling all reminders for ${bills.length} bills...',
    );
    await cancelAllNotifications();

    for (final bill in bills) {
      if (!bill.paid) {
        await scheduleBillReminders(bill);
      }
    }
  }

  /// Show an immediate notification (for testing)
  Future<void> showTestNotification() async {
    print('[NotificationService] 🧪 === TEST NOTIFICATION START ===');

    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(
      0,
      'Test Notification 🎉',
      'Notifications are working! Current time: ${DateTime.now().toIso8601String()}',
      notificationDetails,
    );

    print('[NotificationService] 🧪 === TEST NOTIFICATION END ===');
  }
}
