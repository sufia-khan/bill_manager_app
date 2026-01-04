import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../core/reminder_config.dart';
import '../data/currencies.dart';
import '../models/currency.dart';

part 'bill.g.dart';

/// Bill status enum for UI display
enum BillStatus { upcoming, overdue, paid }

/// Sync status for production offline-first architecture with dirty flags
/// - clean: No pending changes, in sync with cloud
/// - created: New bill not yet uploaded to cloud
/// - updated: Existing bill modified locally
/// - deleted: Bill marked for deletion from cloud
enum BillSyncStatus {
  clean, // No changes needed
  created, // New bill awaiting first upload
  updated, // Modified bill awaiting update
  deleted; // Bill marked for cloud deletion

  String get value => name;

  static BillSyncStatus fromString(String value) {
    return BillSyncStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BillSyncStatus.created,
    );
  }

  /// Check if this bill needs to be synced to cloud
  bool get isDirty => this != BillSyncStatus.clean;
}

/// Bill model with Hive adapter for local storage
///
/// This is the core data model used throughout the app.
/// Fields match the Firestore structure for seamless sync.
@HiveType(typeId: 0)
class Bill extends HiveObject {
  /// Unique identifier (UUID)
  @HiveField(0)
  final String id;

  /// Bill name/title (e.g., "Monthly Rent", "Netflix")
  @HiveField(1)
  String name;

  /// Bill amount in user's currency
  @HiveField(2)
  double amount;

  /// Due date for this bill
  @HiveField(3)
  DateTime dueDate;

  /// Repeat setting: 'one-time' or 'monthly'
  @HiveField(4)
  String repeat;

  /// Whether the bill has been paid
  @HiveField(5)
  bool paid;

  /// Dirty flag sync status: clean | created | updated | deleted
  /// Used to track which bills need cloud sync
  @HiveField(6)
  String? syncStatusValue;

  /// Last update timestamp (for conflict resolution during sync)
  /// This is the user-facing "when was bill modified" timestamp
  @HiveField(7)
  DateTime? updatedAt;

  /// Reminder preference: 'one_day_before' or 'same_day'
  /// Determines when notification should be triggered
  @HiveField(8)
  String? reminderPreferenceValue;

  ///Currency code for this bill (ISO 4217)
  /// Allows each bill to have its own currency
  @HiveField(9)
  String? currencyCode;

  /// Version number for optimistic locking and conflict detection
  /// Incremented on every local change
  @HiveField(10)
  int? version;

  /// Last modified timestamp (for incremental cloud pulls)
  /// Updated only on actual data changes, used for lastSyncTime comparisons
  @HiveField(11)
  DateTime? lastModified;

  /// Reminder time hour in 24-hour format (0-23)
  /// User's preferred time to receive notifications
  @HiveField(12)
  int? reminderTimeHour;

  /// Reminder time minute (0-59)
  @HiveField(13)
  int? reminderTimeMinute;

  /// Whether the "one day before" notification has been sent for this bill version
  @HiveField(14)
  bool? notificationOneDayBeforeSent;

  /// Whether the "same day" notification has been sent for this bill version
  @HiveField(15)
  bool? notificationSameDaySent;

  // ==================== COMPUTED PROPERTIES ====================

  /// Get sync status as enum
  BillSyncStatus get syncStatus =>
      BillSyncStatus.fromString(syncStatusValue ?? 'created');

  /// Set sync status from enum
  set syncStatus(BillSyncStatus status) {
    syncStatusValue = status.value;
  }

  /// Get the reminder preference as enum
  ReminderPreference get reminderPreference =>
      ReminderPreferenceExtension.fromStorageValue(
        reminderPreferenceValue ?? 'none',
      );

  /// Set the reminder preference from enum
  set reminderPreference(ReminderPreference value) {
    reminderPreferenceValue = value.storageValue;
  }

  /// Get non-nullable version
  int get billVersion => version ?? 1;

  /// Get non-nullable updatedAt
  DateTime get effectiveUpdatedAt => updatedAt ?? DateTime.now();

  /// Get non-nullable lastModified
  DateTime get effectiveLastModified =>
      lastModified ?? updatedAt ?? DateTime.now();

  /// Get the effective reminder time hour
  int get effectiveReminderTimeHour => reminderTimeHour ?? 9;

  /// Get the effective reminder time minute
  int get effectiveReminderTimeMinute => reminderTimeMinute ?? 0;

  /// Get non-nullable notificationOneDayBeforeSent
  bool get isNotificationOneDayBeforeSent =>
      notificationOneDayBeforeSent ?? false;

  /// Get non-nullable notificationSameDaySent
  bool get isNotificationSameDaySent => notificationSameDaySent ?? false;

  /// Get the reminder time as TimeOfDay
  TimeOfDay get reminderTime => TimeOfDay(
    hour: effectiveReminderTimeHour,
    minute: effectiveReminderTimeMinute,
  );

  /// Get the calculated notification time for this bill
  /// Returns null if bill is overdue or notifications should be skipped
  DateTime? get notificationTime => ReminderConfig.calculateNotificationTime(
    dueDate: dueDate,
    preference: reminderPreference,
    reminderHour: effectiveReminderTimeHour,
    reminderMinute: effectiveReminderTimeMinute,
    referenceTime: effectiveUpdatedAt,
  );

  /// Get human-readable description of notification timing
  String get notificationTimeDescription =>
      ReminderConfig.getNotificationTimeDescription(
        dueDate: dueDate,
        preference: reminderPreference,
        reminderHour: effectiveReminderTimeHour,
        reminderMinute: effectiveReminderTimeMinute,
        referenceTime: effectiveUpdatedAt,
      );

  /// Get the Currency object for this bill
  Currency get currency => CurrencyData.fromCode(currencyCode ?? 'INR');

  /// Get the currency symbol for this bill
  String get currencySymbol => currency.safeSymbol;

  /// Format the bill amount with currency symbol
  String get formattedAmount => currency.formatAmount(amount);

  /// Constructor
  Bill({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    this.repeat = 'one-time',
    this.paid = false,
    String? syncStatusValue,
    String? reminderPreferenceValue,
    String? currencyCode,
    int? version,
    int? reminderTimeHour,
    int? reminderTimeMinute,
    bool? notificationOneDayBeforeSent,
    bool? notificationSameDaySent,
    DateTime? updatedAt,
    DateTime? lastModified,
  }) : syncStatusValue = syncStatusValue ?? 'created',
       reminderPreferenceValue = reminderPreferenceValue ?? 'none',
       currencyCode = currencyCode ?? 'INR',
       version = version ?? 1,
       reminderTimeHour = reminderTimeHour ?? 9,
       reminderTimeMinute = reminderTimeMinute ?? 0,
       notificationOneDayBeforeSent = notificationOneDayBeforeSent ?? false,
       notificationSameDaySent = notificationSameDaySent ?? false,
       updatedAt = updatedAt ?? DateTime.now(),
       lastModified = lastModified ?? updatedAt ?? DateTime.now();

  /// Get the bill status based on due date and paid state
  BillStatus get status {
    if (paid) return BillStatus.paid;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (due.isBefore(today)) return BillStatus.overdue;
    return BillStatus.upcoming;
  }

  /// Check if bill is monthly recurring
  bool get isMonthly => repeat == 'monthly';

  /// Check if bill is one-time
  bool get isOneTime => repeat == 'one-time';

  // ==================== DIRTY FLAG METHODS ====================

  /// Check if this bill needs to be synced to cloud
  bool get isDirty => syncStatus.isDirty;

  /// Check if bill is clean (no pending changes)
  bool get isClean => syncStatus == BillSyncStatus.clean;

  /// Check if bill was just created (not yet on cloud)
  bool get isCreated => syncStatus == BillSyncStatus.created;

  /// Check if bill was updated locally
  bool get isUpdated => syncStatus == BillSyncStatus.updated;

  /// Check if bill is marked for deletion
  bool get isDeleted => syncStatus == BillSyncStatus.deleted;

  /// Mark bill as created (new bill awaiting first upload)
  void markAsCreated() {
    syncStatus = BillSyncStatus.created;
    version = (version ?? 1) + 1;
    lastModified = DateTime.now();
    updatedAt = DateTime.now();
  }

  /// Mark bill as updated (existing bill with local changes)
  void markAsUpdated() {
    // Don't override 'created' status - new bills stay 'created' until first sync
    if (syncStatus != BillSyncStatus.created) {
      syncStatus = BillSyncStatus.updated;
    }
    version = (version ?? 1) + 1;
    lastModified = DateTime.now();
    updatedAt = DateTime.now();
  }

  /// Reset notification sent flags (used when bill is modified or moved to next month)
  void resetNotificationFlags() {
    notificationOneDayBeforeSent = false;
    notificationSameDaySent = false;
  }

  /// Mark bill as deleted (awaiting cloud deletion)
  void markAsDeleted() {
    syncStatus = BillSyncStatus.deleted;
    version = (version ?? 1) + 1;
    lastModified = DateTime.now();
    updatedAt = DateTime.now();
  }

  /// Mark bill as clean (successfully synced to cloud)
  void markAsClean() {
    syncStatus = BillSyncStatus.clean;
    // Note: Don't increment version or update timestamps on clean
    // These are only updated on actual data changes
  }

  /// Increment version (for manual conflict resolution)
  void incrementVersion() {
    version = (version ?? 1) + 1;
    lastModified = DateTime.now();
  }

  // ==================== LEGACY COMPATIBILITY ====================

  /// Backward compatibility: Check if sync is pending (isDirty)
  bool get isSyncPending => isDirty;

  /// Backward compatibility: Check if synced (isClean)
  bool get isSynced => isClean;

  /// Backward compatibility: Mark as needing sync
  void markPendingSync() => markAsUpdated();

  /// Backward compatibility: Mark as synced
  void markSynced() => markAsClean();

  // ==================== COPY WITH ====================

  /// Create a copy of this bill with updated fields
  Bill copyWith({
    String? id,
    String? name,
    double? amount,
    DateTime? dueDate,
    String? repeat,
    bool? paid,
    String? syncStatusValue,
    String? reminderPreferenceValue,
    String? currencyCode,
    int? version,
    DateTime? updatedAt,
    DateTime? lastModified,
    int? reminderTimeHour,
    int? reminderTimeMinute,
    bool? notificationOneDayBeforeSent,
    bool? notificationSameDaySent,
  }) {
    return Bill(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      repeat: repeat ?? this.repeat,
      paid: paid ?? this.paid,
      syncStatusValue: syncStatusValue ?? this.syncStatusValue,
      reminderPreferenceValue:
          reminderPreferenceValue ?? this.reminderPreferenceValue,
      currencyCode: currencyCode ?? this.currencyCode,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      lastModified: lastModified ?? this.lastModified,
      reminderTimeHour: reminderTimeHour ?? this.reminderTimeHour,
      reminderTimeMinute: reminderTimeMinute ?? this.reminderTimeMinute,
      notificationOneDayBeforeSent:
          notificationOneDayBeforeSent ?? this.notificationOneDayBeforeSent,
      notificationSameDaySent:
          notificationSameDaySent ?? this.notificationSameDaySent,
    );
  }

  // ==================== FIRESTORE SERIALIZATION ====================

  /// Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'repeat': repeat,
      'paid': paid,
      'reminderPreference': reminderPreferenceValue,
      'currencyCode': currencyCode,
      'version': version,
      'updatedAt': effectiveUpdatedAt.toIso8601String(),
      'lastModified': effectiveLastModified.toIso8601String(),
      'reminderTimeHour': reminderTimeHour,
      'reminderTimeMinute': reminderTimeMinute,
      'notificationOneDayBeforeSent': notificationOneDayBeforeSent,
      'notificationSameDaySent': notificationSameDaySent,
    };
  }

  /// Create Bill from Firestore document
  factory Bill.fromFirestore(String id, Map<String, dynamic> data) {
    return Bill(
      id: id,
      name: data['name'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: DateTime.parse(data['dueDate'] as String),
      repeat: data['repeat'] as String? ?? 'one-time',
      paid: data['paid'] as bool? ?? false,
      syncStatusValue: 'clean', // From Firestore means it's synced
      reminderPreferenceValue:
          data['reminderPreference'] as String? ?? 'one_day_before',
      currencyCode: data['currencyCode'] as String? ?? 'INR',
      version: data['version'] as int? ?? 1,
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'] as String)
          : DateTime.now(),
      lastModified: data['lastModified'] != null
          ? DateTime.parse(data['lastModified'] as String)
          : (data['updatedAt'] != null
                ? DateTime.parse(data['updatedAt'] as String)
                : DateTime.now()),
      reminderTimeHour: data['reminderTimeHour'] as int? ?? 9, // Default 9 AM
      reminderTimeMinute: data['reminderTimeMinute'] as int? ?? 0,
      notificationOneDayBeforeSent:
          data['notificationOneDayBeforeSent'] as bool? ?? false,
      notificationSameDaySent:
          data['notificationSameDaySent'] as bool? ?? false,
    );
  }

  // ==================== RECURRING BILLS ====================

  /// Create next month's bill for recurring bills
  Bill createNextMonthBill(String newId) {
    final nextDueDate = DateTime(dueDate.year, dueDate.month + 1, dueDate.day);

    return Bill(
      id: newId,
      name: name,
      amount: amount,
      dueDate: nextDueDate,
      repeat: repeat,
      paid: false,
      syncStatusValue: 'created', // New bill awaiting sync
      reminderPreferenceValue:
          reminderPreferenceValue, // Inherit reminder preference
      currencyCode: currencyCode, // Inherit currency
    );
  }

  @override
  String toString() {
    return 'Bill(id: $id, name: $name, amount: $amount, currency: $currencyCode, '
        'dueDate: $dueDate, repeat: $repeat, paid: $paid, syncStatus: $syncStatus, '
        'version: $version, reminderPreference: $reminderPreferenceValue)';
  }
}
