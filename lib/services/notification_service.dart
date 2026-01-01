import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
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
    print('[NotificationService] ⏰ Timezone initialized');

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
  /// Uses ReminderConfig to automatically handle:
  /// - Dev mode timing (30s for same day, 1min for one day before)
  /// - Production mode timing (actual dates at user's preferred time)
  /// - User's reminder preference (same day vs one day before)
  /// - Edge cases (schedules 5s from now if calculated time is in past)
  Future<void> scheduleBillReminders(Bill bill) async {
    print('[NotificationService] 📅 === SCHEDULING BILL REMINDER ===');
    print('[NotificationService] Bill: "${bill.name}"');
    print('[NotificationService] Due Date: ${bill.dueDate}');
    print(
      '[NotificationService] Reminder Preference: ${bill.reminderPreference.displayName}',
    );

    if (!_isInitialized) {
      print('[NotificationService] ⚠️ Not initialized, initializing...');
      await initialize();
    }

    // Don't schedule for paid bills
    if (bill.paid) {
      print('[NotificationService] ⏭️ Bill is paid, skipping notification');
      return;
    }

    final now = DateTime.now();
    print('[NotificationService] Current Time: $now');

    // Cancel any existing notifications for this bill
    await cancelBillReminders(bill.id);
    print('[NotificationService] 🗑️ Cancelled any existing notifications');

    // Get the calculated notification time from ReminderConfig
    // This respects dev mode, user preferences, and handles edge cases
    final notificationTime = bill.notificationTime;
    print(
      '[NotificationService] 🔔 Calculated Notification Time: $notificationTime',
    );
    print(
      '[NotificationService] ⏱️ Time Until Notification: ${bill.notificationTimeDescription}',
    );

    // Only schedule if the notification time is in the future
    if (notificationTime.isBefore(now)) {
      print(
        '[NotificationService] ⚠️ Notification time is in past, skipping: $notificationTime',
      );
      return;
    }

    // Notification details
    const androidDetails = AndroidNotificationDetails(
      'bill_reminders',
      'Bill Reminders',
      channelDescription: 'Reminders for upcoming bill due dates',
      importance: Importance.high,
      priority: Priority.high,
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

    // Generate unique notification ID from bill ID
    final notificationId = bill.id.hashCode.abs() % 100000;
    print('[NotificationService] 🔢 Notification ID: $notificationId');

    // Determine notification title and body based on preference
    final isSameDay = bill.reminderPreference == ReminderPreference.sameDay;
    final title = isSameDay ? 'Bill Due Today' : 'Bill Due Tomorrow';
    final body = isSameDay
        ? '${bill.name} - ${bill.formattedAmount} is due today!'
        : '${bill.name} - ${bill.formattedAmount} is due tomorrow';

    print('[NotificationService] 📝 Title: "$title"');
    print('[NotificationService] 📝 Body: "$body"');

    // Schedule the notification
    try {
      final tzDateTime = tz.TZDateTime.from(notificationTime, tz.local);
      print('[NotificationService] 🌍 TZ DateTime: $tzDateTime');

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
        '[NotificationService] ✅ Scheduled notification for "${bill.name}"',
      );
      print('[NotificationService] 📅 Due: ${bill.dueDate}');
      print('[NotificationService] 🔔 Notify at: $notificationTime');
      print(
        '[NotificationService] ⏱️ Time until notification: ${bill.notificationTimeDescription}',
      );
      print('[NotificationService] === SCHEDULING COMPLETE ===');
    } catch (e) {
      print('[NotificationService] ❌ ERROR scheduling notification: $e');
      print(
        '[NotificationService] 💡 This might be due to missing permissions',
      );
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
}
