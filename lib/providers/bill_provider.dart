import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/bill.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

/// Bill Provider - State management for all bill operations
///
/// Uses Provider pattern for state management.
/// Orchestrates between local DB, sync, and notifications.
///
/// Key features:
/// - Immediate local saves (offline-first)
/// - Background sync to Firebase
/// - Auto-scheduled notifications
/// - Sort and filter support
class BillProvider extends ChangeNotifier {
  final LocalDbService _localDb;
  final SyncService _syncService;
  final NotificationService _notificationService;
  final AuthService _authService;

  final Uuid _uuid = const Uuid();

  List<Bill> _bills = [];
  bool _isLoading = false;
  String? _error;

  BillProvider({
    required LocalDbService localDb,
    required SyncService syncService,
    required NotificationService notificationService,
    required AuthService authService,
  }) : _localDb = localDb,
       _syncService = syncService,
       _notificationService = notificationService,
       _authService = authService;

  // ==================== GETTERS ====================

  /// All bills
  List<Bill> get bills => List.unmodifiable(_bills);

  /// Bills sorted by due date
  List<Bill> get billsSortedByDueDate {
    final sorted = List<Bill>.from(_bills);
    sorted.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return sorted;
  }

  /// Unpaid bills only
  List<Bill> get unpaidBills => _bills.where((b) => !b.paid).toList();

  /// Overdue bills only
  List<Bill> get overdueBills =>
      _bills.where((b) => b.status == BillStatus.overdue).toList();

  /// Total outstanding amount
  double get totalOutstanding =>
      unpaidBills.fold(0.0, (sum, bill) => sum + bill.amount);

  /// Number of overdue bills
  int get overdueCount => overdueBills.length;

  /// Loading state
  bool get isLoading => _isLoading;

  /// Error message
  String? get error => _error;

  /// Is user signed in
  bool get isSignedIn => _authService.isSignedIn;

  /// Is user in guest mode
  bool get isGuest => _authService.isGuest;

  /// User email
  String? get userEmail => _authService.userEmail;

  // ==================== INITIALIZATION ====================

  /// Load bills from local database
  Future<void> loadBills() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _bills = _localDb.getAllBills();

      // Schedule notifications for all unpaid bills
      await _notificationService.rescheduleAllReminders(_bills);

      _isLoading = false;
      notifyListeners();

      // Try to sync in background
      _backgroundSync();
    } catch (e) {
      _error = 'Failed to load bills: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Background sync (won't block UI)
  Future<void> _backgroundSync() async {
    if (_authService.isSignedIn) {
      _syncService.setUserId(_authService.currentUser?.uid);
      await _syncService.fullSync();

      // Reload bills after sync
      _bills = _localDb.getAllBills();
      notifyListeners();
    }
  }

  // ==================== BILL CRUD OPERATIONS ====================

  /// Add a new bill
  /// Saves locally immediately, syncs in background
  Future<bool> addBill({
    required String name,
    required double amount,
    required DateTime dueDate,
    String repeat = 'one-time',
  }) async {
    try {
      final bill = Bill(
        id: _uuid.v4(),
        name: name,
        amount: amount,
        dueDate: dueDate,
        repeat: repeat,
      );

      // Save locally immediately
      await _localDb.addBill(bill);
      _bills = _localDb.getAllBills();
      notifyListeners();

      // Schedule notifications
      await _notificationService.scheduleBillReminders(bill);

      // Sync in background
      _syncService.syncPendingBills();

      return true;
    } catch (e) {
      _error = 'Failed to add bill: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update an existing bill
  Future<bool> updateBill(Bill bill) async {
    try {
      await _localDb.updateBill(bill);
      _bills = _localDb.getAllBills();
      notifyListeners();

      // Reschedule notifications
      await _notificationService.scheduleBillReminders(bill);

      // Sync in background
      _syncService.syncPendingBills();

      return true;
    } catch (e) {
      _error = 'Failed to update bill: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete a bill
  Future<bool> deleteBill(String billId) async {
    try {
      await _localDb.deleteBill(billId);
      _bills = _localDb.getAllBills();
      notifyListeners();

      // Cancel notifications
      await _notificationService.cancelBillReminders(billId);

      // Delete from cloud
      _syncService.deleteBillFromCloud(billId);

      return true;
    } catch (e) {
      _error = 'Failed to delete bill: $e';
      notifyListeners();
      return false;
    }
  }

  /// Mark a bill as paid
  /// For monthly bills, auto-creates next month's entry
  Future<bool> markBillPaid(String billId) async {
    try {
      final String? newBillId = _uuid.v4();
      final nextBill = await _localDb.markBillPaid(
        billId,
        newBillId: newBillId,
      );

      _bills = _localDb.getAllBills();
      notifyListeners();

      // Cancel old notifications
      await _notificationService.cancelBillReminders(billId);

      // Schedule notifications for new recurring bill
      if (nextBill != null) {
        await _notificationService.scheduleBillReminders(nextBill);
      }

      // Sync in background
      _syncService.syncPendingBills();

      return true;
    } catch (e) {
      _error = 'Failed to mark bill as paid: $e';
      notifyListeners();
      return false;
    }
  }

  // ==================== AUTHENTICATION ====================

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = await _authService.signInWithGoogle();

      if (user != null) {
        // Set up sync
        _syncService.setUserId(user.uid);

        // Check if we need to migrate guest data
        if (_localDb.isGuestMode && _bills.isNotEmpty) {
          await _syncService.migrateGuestData();
        }

        // Full sync
        await _syncService.fullSync();
        _bills = _localDb.getAllBills();

        await _localDb.setGuestMode(false);
      }

      _isLoading = false;
      notifyListeners();
      return user != null;
    } catch (e) {
      _error = 'Failed to sign in: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Continue as guest
  Future<bool> continueAsGuest() async {
    try {
      await _authService.continueAsGuest();
      await _localDb.setGuestMode(true);
      return true;
    } catch (e) {
      _error = 'Failed to continue as guest: $e';
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _syncService.setUserId(null);
      await _localDb.setGuestMode(true);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to sign out: $e';
      notifyListeners();
    }
  }

  /// Get a bill by ID
  Bill? getBill(String id) {
    try {
      return _bills.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
