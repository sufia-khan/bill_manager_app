import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/bill.dart';
import '../core/reminder_config.dart';

/// Notification Info - Contains details about scheduled notifications
class NotificationInfo {
  final String timeDescription;

  const NotificationInfo({required this.timeDescription});
}

/// Notification Service - Local notifications for bill reminders
///
/// Works completely offline.
/// Triggers:
/// - 1 day before due date
/// - On due date
///
/// Key features:
/// - Schedules notifications locally
/// - Works when app is closed
/// - No network required
/// - User-scoped notifications
class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _userId;

  /// Initialize the notification plugin
  Future<void> initialize() async {
    if (_isInitialized) {
      print('[NotificationService] ⚠️ Already initialized, skipping...');
      return;
    }

    print('[NotificationService] 🚀 Initializing notification service...');

    // Initialize timezone
    tz_data.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      print('[NotificationService] ⏰ Timezone initialized: $timeZoneName');
    } catch (e) {
      print(
        '[NotificationService] ⚠️ Could not get local timezone, falling back to UTC: $e',
      );
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // Android settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Initialize
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    print('[NotificationService] 📱 Notification plugin initialized');

    // Request permissions (Android 13+)
    await _requestPermissions();

    _isInitialized = true;
    print('[NotificationService] ✅ Notification service ready');
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    print('[NotificationService] 📋 Requesting permissions...');

    // Android
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      print(
        '[NotificationService] 🤖 Android notification permission: ${granted == true ? "✅ Granted" : "❌ Denied"}',
      );

      // Check for exact alarm permission (Android 12+)
      final exactAlarmGranted = await androidPlugin
          .canScheduleExactNotifications();
      print(
        '[NotificationService] ⏰ Android exact alarm permission: ${exactAlarmGranted == true ? "✅ Granted" : "❌ Denied"}',
      );

      if (exactAlarmGranted == false) {
        print(
          '[NotificationService] ⚠️ WARNING: Exact alarms not permitted! Notifications may not be delivered at exact times.',
        );
        print(
          '[NotificationService] 💡 Go to: Settings → Apps → bill_manager_app → Alarms & reminders',
        );
      }
    }

    // iOS
    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      print(
        '[NotificationService] 🍎 iOS notification permission: ${granted == true ? "✅ Granted" : "❌ Denied"}',
      );
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Can be used to navigate to bill detail
    // The payload contains the bill ID
    print('Notification tapped: ${response.payload}');
  }

  /// Set user ID for notification scoping
  /// This is used to track which user's notifications are being managed
  void setUserId(String userId) {
    _userId = userId;
  }

  /// Schedule notification for a bill (singular wrapper)
  /// Returns NotificationInfo with scheduling details
  Future<NotificationInfo> scheduleBillReminder(Bill bill) async {
    await scheduleBillReminders(bill);

    // Use the bill's computed notification time description
    final timeDesc = bill.notificationTimeDescription;

    return NotificationInfo(timeDescription: timeDesc);
  }

  /// Schedule notification for a bill based on its reminder configuration
  ///
  /// Handles three notification preferences:
  /// - none: No notifications
  /// - oneDayBefore: Single notification 1 day before due date
  /// - sameDay: Single notification on due date
  ///
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
          final isFallback = notificationTime.difference(now).inSeconds <= 6;

          await _scheduleNotification(
            bill: bill,
            notificationId: bill.id.hashCode.abs() % 100000,
            notificationTime: notificationTime,
            title: 'Bill Due Tomorrow',
            body: '${bill.name} - ${bill.formattedAmount} is due tomorrow',
          );
          scheduledCount++;
          if (isFallback) {
            results['oneDayBefore'] = true;
          } else if (notificationTime.isBefore(now)) {
            // It was in the past and no fallback was triggered
            results['oneDayBefore'] = true;
          }
        } else {
          print(
            '[NotificationService] ⏭️ One day before notification time skipped (overdue or preference logic)',
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
          final isFallback = notificationTime.difference(now).inSeconds <= 6;

          await _scheduleNotification(
            bill: bill,
            notificationId: (bill.id.hashCode.abs() % 100000) + 1,
            notificationTime: notificationTime,
            title: 'Bill Due Today',
            body: '${bill.name} - ${bill.formattedAmount} is due today!',
          );
          scheduledCount++;
          if (isFallback) {
            results['sameDay'] = true;
          } else if (notificationTime.isBefore(now)) {
            // It was in the past and no fallback was triggered
            results['sameDay'] = true;
          }
        } else {
          print(
            '[NotificationService] ⏭️ Same day notification time skipped (overdue or preference logic)',
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
      useFallback:
          true, // Enable fallback to 5s if time is in past (especially for Dev Mode)
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
      print('[NotificationService] 💡 Timezone Location: ${tz.local.name}');
      print('[NotificationService] 📅 Original DateTime: $notificationTime');

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
      if (e.toString().contains('exact_alarms_not_permitted')) {
        print(
          '[NotificationService] 💡 TIP: Exact alarm permission missing in Settings!',
        );
      }
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
    await _notifications.cancelAll();
  }

  /// Reschedule all notifications for a list of bills
  Future<void> rescheduleAllReminders(List<Bill> bills) async {
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
      print('[NotificationService] ⚠️ Not initialized, initializing now...');
      await initialize();
    }

    print('[NotificationService] 📝 Creating test notification details...');
    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Test notifications for debugging',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    print('[NotificationService] 🔔 Showing test notification NOW...');
    try {
      await _notifications.show(
        0,
        'Test Notification 🎉',
        'BillMinder notifications are working! Current time: ${DateTime.now().toIso8601String()}',
        notificationDetails,
      );
      print('[NotificationService] ✅ Test notification sent successfully!');
      print('[NotificationService] 💡 If you don\'t see it, check:');
      print('[NotificationService] 1. Notification permission is granted');
      print('[NotificationService] 2. Battery optimization is disabled');
      print(
        '[NotificationService] 3. App notifications are enabled in system settings',
      );
    } catch (e) {
      print('[NotificationService] ❌ ERROR showing test notification: $e');
      rethrow;
    }

    print('[NotificationService] 🧪 === TEST NOTIFICATION END ===');
  }

  /// Show a scheduled test notification (fires in 5 seconds)
  /// This tests the zonedSchedule API specifically.
  Future<void> showScheduledTestNotification() async {
    print('[NotificationService] 🧪 === SCHEDULED TEST START (5s) ===');

    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Test notifications for debugging',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final scheduledTime = DateTime.now().add(const Duration(seconds: 5));
    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    print('[NotificationService] 🕒 Current system time: ${DateTime.now()}');
    print('[NotificationService] 🕒 Scheduled time (local): $scheduledTime');
    print('[NotificationService] 🕒 Scheduled time (tz): $tzTime');
    print('[NotificationService] 💡 Using location: ${tz.local.name}');

    try {
      await _notifications.zonedSchedule(
        999, // Unique test ID
        'Scheduled Test 🎉',
        'If you see this, the scheduling engine is working! (5s delay)',
        tzTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print(
        '[NotificationService] ✅ Scheduled test notification successfully!',
      );
    } catch (e) {
      print('[NotificationService] ❌ ERROR scheduling test notification: $e');
      rethrow;
    }

    print('[NotificationService] 🧪 === SCHEDULED TEST END ===');
  }
}
