import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/bill.dart';
import '../core/reminder_config.dart';
import '../services/local_db_service.dart';
import '../services/smart_sync_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/account_deletion_service.dart';
import '../providers/settings_provider.dart';

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
  final SettingsProvider _settingsProvider;

  final Uuid _uuid = const Uuid();

  List<Bill> _bills = [];
  bool _isLoading = false;
  bool _isDeleting = false;
  String? _error;

  /// Track the last logged-in user ID to detect account switching
  String? _lastLoggedInUserId;

  BillProvider({
    required LocalDbService localDb,
    required SmartSyncService syncService,
    required NotificationService notificationService,
    required AuthService authService,
    required SettingsProvider settingsProvider,
  }) : _localDb = localDb,
       _syncService = syncService,
       _notificationService = notificationService,
       _authService = authService,
       _settingsProvider = settingsProvider,
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
      // NOTE: We do NOT cancel notifications here anymore
      // Notifications should persist across app restarts
      // They are only cancelled when:
      // 1. User switches accounts (_handlePostSignIn)
      // 2. User signs out (signOut)
      // 3. User manually dismisses them

      _bills = _localDb.getAllBills();
      print('[BillProvider] ✅ Loaded ${_bills.length} bills');

      // Process notifications for all bills individually to ensure sent flags are persisted
      // and duplicates are not re-sent based on the new ReminderConfig logic.
      for (final bill in _bills) {
        await _rescheduleRemindersForBill(bill);
      }

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

  /// Reschedule all notifications for all bills
  /// Useful when global notification settings are changed
  Future<void> rescheduleAllReminders() async {
    _logDebug('🔔 Re-scheduling all bill reminders...');
    for (final bill in _bills) {
      await _rescheduleRemindersForBill(bill);
    }
    _logDebug('✅ All reminders re-scheduled');
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
      await _rescheduleRemindersForBill(bill);

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
      // Reset notification flags because the bill was manually modified
      bill.resetNotificationFlags();

      await _localDb.updateBill(bill);
      _bills = _localDb.getAllBills();
      notifyListeners();

      // Cancel existing notifications since settings may have changed
      await _notificationService.cancelBillReminders(bill.id);

      // Reschedule notifications with new settings
      await _rescheduleRemindersForBill(bill);

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

  /// Shared logic to initialize the app after any successful sign-in
  Future<void> _handlePostSignIn(User user) async {
    _logDebug('🔐 Initializing app for user: ${user.email ?? user.uid}');

    // Check if this is a different user than last time
    final isDifferentUser =
        _lastLoggedInUserId != null && _lastLoggedInUserId != user.uid;

    if (isDifferentUser) {
      _logDebug(
        '🔄 Different user detected (was: $_lastLoggedInUserId, now: ${user.uid})',
      );
      // Clear all existing notifications ONLY when switching accounts
      await _notificationService.cancelAllNotifications();
      _logDebug('🗑️ Cleared previous user\'s notifications');
    } else if (_lastLoggedInUserId == user.uid) {
      _logDebug('✅ Same user re-login, keeping notifications');
    } else {
      _logDebug('🆕 First login, no notifications to clear');
    }

    // Update the last logged-in user ID
    _lastLoggedInUserId = user.uid;

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

    // Sync user's settings from Firestore (currency, notifications)
    _logDebug('⚙️ Syncing user settings...');
    await _settingsProvider.syncFromFirestore();
    _logDebug('✅ User settings synced');

    // Reload bills from user's storage
    _bills = _localDb.getAllBills();

    // Schedule notifications for user's bills and persist status
    for (final bill in _bills) {
      await _rescheduleRemindersForBill(bill);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Sign up with email and password
  Future<bool> signUpWithEmail(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final user = await _authService.signUpWithEmail(email, password);
      if (user != null) {
        await _handlePostSignIn(user);
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _logDebug('Sign-up error: $e');
      _error = 'Failed to sign up: ${_getReadableError(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final user = await _authService.signInWithEmail(email, password);
      if (user != null) {
        await _handlePostSignIn(user);
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _logDebug('Email sign-in error: $e');
      _error = 'Failed to sign in: ${_getReadableError(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

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
        await _handlePostSignIn(user);
        return true;
      } else {
        // User cancelled the sign-in
        _logDebug('Sign-in cancelled by user');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _logDebug('Google sign-in error: $e');
      _error = 'Failed to sign in: ${_getReadableError(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.sendPasswordResetEmail(email);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _logDebug('Password reset error: $e');
      _error = 'Failed to send reset email: ${_getReadableError(e)}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get a user-friendly error message
  String _getReadableError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'invalid-credential':
          // Firebase returns this for both missing user AND wrong password in modern setups
          return 'Invalid email or password. No user found or wrong password.';
        case 'email-already-in-use':
          return 'An account already exists for this email.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'weak-password':
          return 'The password provided is too weak (minimum 6 characters).';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please try again later.';
        case 'user-disabled':
          return 'This account has been disabled.';
      }
    }

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

      // NOTE: We do NOT clear notifications on sign out
      // Notifications persist until:
      // 1. User manually dismisses them
      // 2. User logs in with a DIFFERENT account
      // This allows the same user to see their notifications after re-login

      // Clear in-memory state
      _bills = [];
      notifyListeners();

      // Sign out from Firebase/Google
      await _authService.signOut();

      // Clear sync user ID
      _syncService.setUserId(null);

      // Reset settings to defaults for next user
      await _settingsProvider.resetToDefaults();
      _logDebug('Settings reset to defaults');

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

      // Execute account deletion with re-auth support
      await _accountDeletionService.deleteAccount(
        onProgress: (message) {
          _logDebug('  → $message');
        },
        onReauthRequired: () async {
          _logDebug('🔐 Re-authentication required...');
          return await _authService.reauthenticateWithGoogle();
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

  /// Internal helper to reschedule reminders and track sent status
  Future<void> _rescheduleRemindersForBill(Bill bill) async {
    if (bill.isDeleted) return;

    final results = await _notificationService.scheduleBillReminders(bill);

    // If any notifications were triggered (sent via fallback), mark them as sent in the DB
    bool needsUpdate = false;
    final updatedBill = bill.copyWith();

    if (results['oneDayBefore'] == true &&
        !bill.isNotificationOneDayBeforeSent) {
      updatedBill.notificationOneDayBeforeSent = true;
      needsUpdate = true;
    }

    if (results['sameDay'] == true && !bill.isNotificationSameDaySent) {
      updatedBill.notificationSameDaySent = true;
      needsUpdate = true;
    }

    if (needsUpdate) {
      _logDebug(
        '🔔 Marking notifications as sent for "${bill.name}" (${updatedBill.isNotificationOneDayBeforeSent}, ${updatedBill.isNotificationSameDaySent})',
      );
      // Update locally first
      final index = _bills.indexWhere((b) => b.id == bill.id);
      if (index != -1) {
        _bills[index] = updatedBill;
      }
      // Persist to local DB WITHOUT marking as dirty for cloud sync
      await _localDb.updateBillLocally(updatedBill);
      notifyListeners();
    }
  }

  /// Mark a notification as sent (called externally if needed)
  Future<void> markNotificationAsSent(
    String billId, {
    required bool isSameDay,
  }) async {
    final index = _bills.indexWhere((b) => b.id == billId);
    if (index == -1) return;

    final bill = _bills[index];
    if (isSameDay) {
      bill.notificationSameDaySent = true;
    } else {
      bill.notificationOneDayBeforeSent = true;
    }
    await _localDb.updateBillLocally(bill);
    notifyListeners();
  }
}
