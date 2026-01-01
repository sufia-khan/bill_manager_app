# Bill Reminder Implementation Guide

## Overview

This implementation provides a **production-ready bill reminder system** with a **safe dev mode for testing** without waiting for actual time intervals.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      ReminderConfig                              │
│  (Core logic for calculating reminder times)                     │
│                                                                  │
│  ┌─────────────────┐        ┌─────────────────┐                 │
│  │   DEV MODE      │        │ PRODUCTION MODE │                 │
│  │ (kDebugMode)    │        │ (Release builds)│                 │
│  │                 │        │                  │                 │
│  │ 1 day → 1 min   │        │ 1 day → 24 hrs  │                 │
│  │ Same day → 30s  │        │ Same day → 0    │                 │
│  └─────────────────┘        └─────────────────┘                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    NotificationService                           │
│                                                                  │
│  • scheduleBillReminder(Bill bill)                               │
│  • calculateNotificationTime(dueDate, preference)                │
│  • Prevents duplicate notifications                              │
│  • Handles edge case: past time → 5 seconds from now             │
│  • Battery optimization: exactAllowWhileIdle                     │
│  • Works when: app closed, phone locked, offline                 │
└─────────────────────────────────────────────────────────────────┘
```

## Files Modified/Created

### New Files:
- `lib/core/reminder_config.dart` - Core reminder calculation logic with dev/prod mode switching

### Modified Files:
- `lib/models/bill.dart` - Added `reminderPreferenceValue` field (HiveField 8)
- `lib/services/notification_service.dart` - Rewrote with new reminder logic
- `lib/providers/bill_provider.dart` - Updated to accept reminderPreference
- `lib/screens/add_bill_sheet.dart` - Added reminder preference selector + preview
- `lib/screens/bill_detail_view.dart` - Shows reminder preference and notification time
- `lib/screens/settings_screen.dart` - Added Dev Testing section (only in debug mode)
- `lib/main.dart` - Updated to pass reminderPreference to provider

## Core Logic

### Reminder Calculation Formula

```dart
notifyAt = dueDate - reminderOffset

where:
  - "One day before" → Duration(days: 1) in production, Duration(minutes: 1) in dev
  - "Same day" → Duration.zero in production, Duration(seconds: 30) in dev
```

### Edge Case Handling

```dart
if (notifyAt.isBefore(now)) {
  // If calculated time is in the past, schedule 5 seconds from now
  notifyAt = now.add(const Duration(seconds: 5));
}
```

## Reminder Preference Enum

```dart
enum ReminderPreference {
  oneDayBefore,  // Stored as 'one_day_before'
  sameDay,       // Stored as 'same_day'
}
```

## DEV Mode Testing

In debug builds (`flutter run`), the app uses accelerated timings:

| Preference         | Production Mode | Dev Mode        |
|--------------------|-----------------|-----------------|
| "One day before"   | 24 hours        | **1 minute**    |
| "Same day"         | 0 (due date)    | **30 seconds**  |

### How DEV Mode is Enabled

```dart
// Automatically enabled in debug builds via Flutter's kDebugMode
static bool get isDevMode => kDebugMode;
```

This means:
- ✅ `flutter run` → DEV mode (accelerated timings)
- ✅ `flutter run -d <device>` → DEV mode
- ❌ `flutter build apk --release` → Production mode (real timings)
- ❌ `flutter build ios --release` → Production mode

## UI Features

### Add Bill Sheet
- Reminder preference selector with two options
- Notification time preview showing exact scheduled time
- DEV mode indicator showing accelerated timings

### Bill Detail View
- Shows the reminder preference for each bill
- Displays "Notification scheduled: In X minutes/seconds"

### Settings Screen (Dev Mode Only)
- **🔧 Dev Testing** section visible only in debug builds
- **Send Test Notification** - Immediately trigger a notification
- **View Pending Notifications** - See all scheduled notifications
- **Reminder Durations** - Shows current dev mode timing info

## Notification Behavior

### Works in All Conditions:
- ✅ App closed (background)
- ✅ Phone locked
- ✅ Offline (no internet)
- ✅ Battery optimization enabled (uses `exactAllowWhileIdle`)

### Notification Channel
- Channel ID: `bill_reminders`
- Channel Name: `Bill Reminders`
- Importance: High
- Priority: High
- Full-screen intent: Enabled (for locked screen)

## Testing Workflow

1. **Run in debug mode**: `flutter run`
2. **Add a new bill** with a due date a few minutes in the future
3. **Select reminder preference** (observe the preview)
4. **Save the bill** and watch console logs for:
   ```
   [NotificationService] ✅ Scheduled notification for "Bill Name"
   [NotificationService]    📅 Due Date: 2024-12-24 02:00:00
   [NotificationService]    ⏰ Preference: One day before
   [NotificationService]    🔔 Notify At: 2024-12-24 01:59:00
   ```
5. **Wait for notification** (1 minute or 30 seconds depending on preference)
6. **Verify in Settings > Dev Testing > View Pending Notifications**

## Duplicate Prevention

```dart
// Each bill gets a unique notification ID based on its UUID
int _generateNotificationId(String billId) {
  return billId.hashCode.abs() % 100000;
}

// Before scheduling, cancel any existing notification for this bill
await cancelBillReminder(bill.id);
```

## Debug Logging

All notification operations are logged in debug mode:
```
[NotificationService] ✅ NotificationService initialized
[NotificationService] 🏗️ Mode: DEV
[NotificationService] ✅ Scheduled notification for "Netflix"
[NotificationService]    📅 Due Date: 2024-12-24 12:00:00
[NotificationService]    ⏰ Preference: One day before
[NotificationService]    🔔 Notify At: 2024-12-24 11:59:00
[NotificationService]    🆔 Notification ID: 45678
```

## Production Deployment

When building for release:

```bash
flutter build apk --release
flutter build ios --release
```

The `isDevMode` check (`kDebugMode`) automatically becomes `false`, and:
- Real durations are used (24 hours / 0)
- DEV badges are hidden from UI
- Dev Testing section is hidden from Settings
