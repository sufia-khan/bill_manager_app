import 'package:hive/hive.dart';

part 'bill.g.dart';

/// Bill status enum for UI display
enum BillStatus { upcoming, overdue, paid }

/// Sync status for offline-first architecture
enum SyncStatus { pending, synced }

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

  /// Sync status for offline-first: 'pending' or 'synced'
  @HiveField(6)
  String syncStatus;

  /// Last update timestamp (used for sync conflict resolution)
  @HiveField(7)
  DateTime updatedAt;

  /// Constructor
  Bill({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    this.repeat = 'one-time',
    this.paid = false,
    this.syncStatus = 'pending',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

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

  /// Check if sync is pending
  bool get isSyncPending => syncStatus == 'pending';

  /// Check if synced to cloud
  bool get isSynced => syncStatus == 'synced';

  /// Mark as needing sync
  void markPendingSync() {
    syncStatus = 'pending';
    updatedAt = DateTime.now();
  }

  /// Mark as synced
  void markSynced() {
    syncStatus = 'synced';
  }

  /// Create a copy of this bill with updated fields
  Bill copyWith({
    String? id,
    String? name,
    double? amount,
    DateTime? dueDate,
    String? repeat,
    bool? paid,
    String? syncStatus,
    DateTime? updatedAt,
  }) {
    return Bill(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      repeat: repeat ?? this.repeat,
      paid: paid ?? this.paid,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'repeat': repeat,
      'paid': paid,
      'updatedAt': updatedAt.toIso8601String(),
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
      syncStatus: 'synced', // From Firestore means it's synced
      updatedAt: DateTime.parse(data['updatedAt'] as String),
    );
  }

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
      syncStatus: 'pending',
    );
  }

  @override
  String toString() {
    return 'Bill(id: $id, name: $name, amount: $amount, dueDate: $dueDate, '
        'repeat: $repeat, paid: $paid, syncStatus: $syncStatus)';
  }
}
