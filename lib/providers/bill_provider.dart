import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/bill.dart';
import '../core/reminder_config.dart';
import '../services/local_db_service.dart';
import '../services/smart_sync_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/account_deletion_service.dart';

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
  final SmartSyncService _syncService;
  final NotificationService _notificationService;
  final AuthService _authService;
  final AccountDeletionService _accountDeletionService;

  final Uuid _uuid = const Uuid();

  List<Bill> _bills = [];
  bool _isLoading = false;
  bool _isDeleting = false;
  String? _error;

  BillProvider({
    required LocalDbService localDb,
    required SmartSyncService syncService,
    required NotificationService notificationService,
    required AuthService authService,
  }) : _localDb = localDb,
       _syncService = syncService,
       _notificationService = notificationService,
       _authService = authService,
       _accountDeletionService = AccountDeletionService(notificationService);

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

  /// Account deletion in progress
  bool get isDeleting => _isDeleting;

  /// Error message
  String? get error => _error;

  /// Is user signed in
  bool get isSignedIn => _authService.isSignedIn;

  /// User email
  String? get userEmail => _authService.userEmail;

  /// Notification service access for UI
  NotificationService get notificationService => _notificationService;

  // ==================== SYNC STATUS ====================

  /// Number of bills pending sync
  int get pendingSyncCount => _localDb.getDirtyBills().length;

  /// Last successful sync time
  DateTime? get lastSyncTime => _localDb.lastSyncTime;

  /// Current sync state
  SyncState get syncState => _syncService.currentState;

  /// Manual sync now
  Future<SyncResult> syncNow() async {
    return await _syncService.syncNow();
  }

  // ==================== INITIALIZATION ====================

  /// Load bills from local database
  Future<void> loadBills() async {
    print('[BillProvider] 📂 === LOADING BILLS ===');
    print('[BillProvider] User Email: $userEmail');
    print('[BillProvider] Auth User ID: ${_authService.userId}');
    print('[BillProvider] LocalDB User ID: ${_localDb.currentUserId}');

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _bills = _localDb.getAllBills();
      print('[BillProvider] ✅ Loaded ${_bills.length} bills');

      // Schedule notifications for all unpaid bills
      await _notificationService.rescheduleAllReminders(_bills);

      _isLoading = false;
      notifyListeners();

      // Schedule initial sync
      _syncService.scheduleDebouncedSync();
      print('[BillProvider] 📂 === BILLS LOADED ===');
    } catch (e) {
      print('[BillProvider] ❌ ERROR loading bills: $e');
      _error = 'Failed to load bills: $e';
      _isLoading = false;
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
    ReminderPreference reminderPreference =
        ReminderPreference.none, // Default: no notifications
    String currencyCode = 'INR',
    int reminderTimeHour = 9, // Default: 9 AM
    int reminderTimeMinute = 0,
  }) async {
    try {
      final bill = Bill(
        id: _uuid.v4(),
        name: name,
        amount: amount,
        dueDate: dueDate,
        repeat: repeat,
        reminderPreferenceValue: reminderPreference.storageValue,
        currencyCode: currencyCode,
        reminderTimeHour: reminderTimeHour, // Pass reminder time
        reminderTimeMinute: reminderTimeMinute,
      );

      // Save locally immediately
      await _localDb.addBill(bill);
      _bills = _localDb.getAllBills();
      notifyListeners();

      // Schedule notifications
      final notificationInfo = await _notificationService.scheduleBillReminder(
        bill,
      );
      _logDebug(
        '📅 Scheduled notification: ${notificationInfo.timeDescription}',
      );

      // Schedule debounced sync
      _syncService.scheduleDebouncedSync();

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

      // Schedule debounced sync
      _syncService.scheduleDebouncedSync();

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

      // Delete from cloud (background)
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

      // Schedule debounced sync
      _syncService.scheduleDebouncedSync();

      return true;
    } catch (e) {
      _error = 'Failed to mark bill as paid: $e';
      notifyListeners();
      return false;
    }
  }

  // ==================== AUTHENTICATION ====================

  /// Sign in with Google
  Future<bool> signInWithGoogle({Function? onAccountSelected}) async {
    try {
      _error = null;
      // Note: We don't set _isLoading here to avoid showing loader before account picker

      final user = await _authService.signInWithGoogle(
        onAccountSelected: () {
          _isLoading = true;
          notifyListeners();
          if (onAccountSelected != null) onAccountSelected();
        },
      );

      if (user != null) {
        _logDebug('🔐 Sign-in successful for user: ${user.email}');

        // Initialize local database with user ID
        await _localDb.initialize(user.uid);
        _logDebug('✅ Initialized local DB for user: ${user.uid}');

        // Set user ID in notification service
        _notificationService.setUserId(user.uid);

        // Set up sync with user ID
        _syncService.setUserId(user.uid);

        // Full sync to get cloud data
        _logDebug('🔄 Starting full sync...');
        await _syncService.fullSync();

        // Reload bills from user's storage
        _bills = _localDb.getAllBills();

        // Schedule notifications for user's bills
        await _notificationService.rescheduleAllReminders(_bills);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // User cancelled the sign-in
        _logDebug('Sign-in cancelled by user');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _logDebug('Sign-in error: $e');
      _error = 'Failed to sign in: ${_getReadableError(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get a user-friendly error message
  String _getReadableError(dynamic error) {
    final errorStr = error.toString();

    // Check for specific Google Sign-In error codes
    if (errorStr.contains('ApiException: 7')) {
      return 'No internet connection. Please check your network and try again.';
    } else if (errorStr.contains('network')) {
      return 'Network error. Please check your internet connection.';
    } else if (errorStr.contains('credential')) {
      return 'Authentication failed. Please try again.';
    } else if (errorStr.contains('cancelled') ||
        errorStr.contains('canceled')) {
      return 'Sign-in was cancelled.';
    } else if (errorStr.contains('PlatformException')) {
      // Check for common platform exceptions
      if (errorStr.contains('sign_in_failed')) {
        return 'Google Sign-In failed. Please check your Google Play Services.';
      } else if (errorStr.contains('10:')) {
        return 'Configuration error. SHA-1 fingerprint may be missing from Firebase.';
      }
    }

    return errorStr.length > 100
        ? '${errorStr.substring(0, 100)}...'
        : errorStr;
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      _logDebug('Starting sign out process...');

      // Cancel all notifications for current user
      await _notificationService.cancelAllNotifications();
      _logDebug('Cancelled all notifications');

      // Clear in-memory state
      _bills = [];
      notifyListeners();

      // Sign out from Firebase/Google
      await _authService.signOut();

      // Clear sync user ID
      _syncService.setUserId(null);

      _logDebug('Sign out complete');
      notifyListeners();
    } catch (e) {
      _logDebug('Sign out error: $e');
      _error = 'Failed to sign out: $e';
      notifyListeners();
    }
  }

  // ==================== ACCOUNT DELETION ====================

  /// Delete the current user's account permanently
  /// This will:
  /// - Cancel all notifications
  /// - Delete all Firestore data (bills, settings)
  /// - Delete Firebase Authentication account
  /// - Clear all local Hive boxes
  /// - Clear SharedPreferences
  /// - Reset app to fresh state
  ///
  /// Returns true if deletion was successful
  /// Throws exception on error
  Future<bool> deleteAccount() async {
    try {
      _isDeleting = true;
      _error = null;
      notifyListeners();

      _logDebug('🗑️ Starting account deletion...');

      // Execute account deletion
      await _accountDeletionService.deleteAccount(
        onProgress: (message) {
          _logDebug('  → $message');
        },
      );

      _logDebug('✅ Account deletion completed successfully');

      // Reset all state to fresh install
      _bills = [];
      _isLoading = false;
      _isDeleting = false;
      _error = null;

      // Clear sync user ID
      _syncService.setUserId(null);

      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _logDebug('❌ Account deletion failed: $e');
      _logDebug('Stack trace: $stackTrace');

      _error = _getAccountDeletionErrorMessage(e);
      _isDeleting = false;
      notifyListeners();
      return false;
    }
  }

  /// Get user-friendly error message for account deletion
  String _getAccountDeletionErrorMessage(dynamic error) {
    final errorStr = error.toString();

    if (errorStr.contains('No user is currently signed in')) {
      return 'No user is signed in. Please sign in first.';
    } else if (errorStr.contains('requires-recent-login')) {
      return 'For security, please sign out and sign in again before deleting your account.';
    } else if (errorStr.contains('network')) {
      return 'Network error. Please check your internet connection and try again.';
    } else if (errorStr.contains('Firestore')) {
      return 'Failed to delete cloud data. Please try again.';
    }

    return 'Failed to delete account: $errorStr';
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

  /// Debug logging helper
  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('[BillProvider] $message');
    }
  }
}
