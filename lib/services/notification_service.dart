import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/bill.dart';

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

  /// Initialize the notification plugin
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz_data.initializeTimeZones();

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

    // Request permissions (Android 13+)
    await _requestPermissions();

    _isInitialized = true;
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    // Android
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    // iOS
    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Can be used to navigate to bill detail
    // The payload contains the bill ID
    print('Notification tapped: ${response.payload}');
  }

  /// Schedule notifications for a bill
  /// Schedules two notifications:
  /// 1. One day before due date
  /// 2. On due date
  Future<void> scheduleBillReminders(Bill bill) async {
    if (!_isInitialized) await initialize();

    // Don't schedule for paid or past due bills
    if (bill.paid) return;

    final now = DateTime.now();
    final dueDate = bill.dueDate;

    // Cancel any existing notifications for this bill
    await cancelBillReminders(bill.id);

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

    // Generate unique notification IDs from bill ID
    final baseId = bill.id.hashCode.abs() % 100000;

    // Schedule 1 day before notification
    final oneDayBefore = dueDate.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(now)) {
      await _notifications.zonedSchedule(
        baseId,
        'Bill Due Tomorrow',
        '${bill.name} - \$${bill.amount.toStringAsFixed(2)} is due tomorrow',
        tz.TZDateTime.from(
          DateTime(
            oneDayBefore.year,
            oneDayBefore.month,
            oneDayBefore.day,
            9,
            0,
          ),
          tz.local,
        ),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: bill.id,
      );
    }

    // Schedule due date notification
    if (dueDate.isAfter(now)) {
      await _notifications.zonedSchedule(
        baseId + 1,
        'Bill Due Today',
        '${bill.name} - \$${bill.amount.toStringAsFixed(2)} is due today!',
        tz.TZDateTime.from(
          DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0),
          tz.local,
        ),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: bill.id,
      );
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
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(
      0,
      'Test Notification',
      'BillMinder notifications are working!',
      notificationDetails,
    );
  }
}
