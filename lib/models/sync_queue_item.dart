import 'package:hive/hive.dart';

part 'sync_queue_item.g.dart';

/// Action type for sync queue
enum SyncAction {
  create, // Upload new bill
  update, // Update existing bill
  delete; // Delete bill from cloud

  String get value => name;

  static SyncAction fromString(String value) {
    return SyncAction.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SyncAction.create,
    );
  }
}

/// Sync Queue Item - Crash-safe sync tracking
///
/// Stores pending sync operations in Hive to survive app crashes.
/// Each item represents a single bill operation awaiting cloud sync.
@HiveType(typeId: 1)
class SyncQueueItem extends HiveObject {
  /// Unique ID of the bill to sync
  @HiveField(0)
  final String billId;

  /// Action to perform: create | update | delete
  @HiveField(1)
  String actionValue;

  /// Timestamp when this item was added to queue
  @HiveField(2)
  final DateTime queuedAt;

  /// Number of retry attempts
  @HiveField(3)
  int retryCount;

  /// Last error message (if any)
  @HiveField(4)
  String? lastError;

  /// Last attempt timestamp
  @HiveField(5)
  DateTime? lastAttemptAt;

  // ==================== COMPUTED PROPERTIES ====================

  /// Get action as enum
  SyncAction get action => SyncAction.fromString(actionValue);

  /// Set action from enum
  set action(SyncAction value) {
    actionValue = value.value;
  }

  /// Constructor
  SyncQueueItem({
    required this.billId,
    required this.actionValue,
    DateTime? queuedAt,
    this.retryCount = 0,
    this.lastError,
    this.lastAttemptAt,
  }) : queuedAt = queuedAt ?? DateTime.now();

  /// Create from action enum
  factory SyncQueueItem.create({
    required String billId,
    required SyncAction action,
  }) {
    return SyncQueueItem(billId: billId, actionValue: action.value);
  }

  /// Record a failed attempt
  void recordFailure(String error) {
    retryCount++;
    lastError = error;
    lastAttemptAt = DateTime.now();
    save(); // Persist to Hive immediately
  }

  /// Check if should retry (max 5 attempts)
  bool get shouldRetry => retryCount < 5;

  /// Get backoff delay in seconds (exponential backoff)
  int get backoffSeconds {
    if (retryCount == 0) return 0;
    return [5, 10, 30, 60, 120][retryCount - 1];
  }

  /// Check if enough time has passed for retry
  bool get canRetryNow {
    if (lastAttemptAt == null) return true;
    final elapsed = DateTime.now().difference(lastAttemptAt!).inSeconds;
    return elapsed >= backoffSeconds;
  }

  @override
  String toString() {
    return 'SyncQueueItem(billId: $billId, action: $action, '
        'retryCount: $retryCount, queuedAt: $queuedAt)';
  }
}
