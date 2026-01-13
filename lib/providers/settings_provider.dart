import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/currency.dart';
import '../data/currencies.dart';
import '../services/notification_service.dart';

// Re-export Currency for backwards compatibility
export '../models/currency.dart';
export '../data/currencies.dart' show CurrencyData;

/// Settings Provider - Manages app preferences
///
/// Features:
/// - Notification toggle with persistence
/// - Currency selection with full ISO 4217 support
/// - Default currency: USD (US Dollar)
/// - Local persistence with SharedPreferences
/// - Firestore sync for authenticated users
class SettingsProvider extends ChangeNotifier {
  static const String _notificationsKey = 'notifications_enabled';
  static const String _currencyKey = 'selected_currency';
  static const String _currencySetupCompleteKey = 'currency_setup_complete';
  static const String _firestoreCollection = 'users';
  static const String _firestoreSettingsField = 'settings';

  final NotificationService _notificationService;
  SharedPreferences? _prefs;
  bool _notificationsEnabled = true;
  Currency _selectedCurrency = CurrencyData.defaultCurrency;
  bool _isLoading = true;
  bool _needsCurrencySetup = false;

  SettingsProvider(this._notificationService);

  // Getters
  bool get notificationsEnabled => _notificationsEnabled;
  Currency get selectedCurrency => _selectedCurrency;
  String get currencySymbol => _selectedCurrency.safeSymbol;
  String get currencyCode => _selectedCurrency.code;
  bool get isLoading => _isLoading;
  List<Currency> get availableCurrencies => CurrencyData.all;
  List<Currency> get popularCurrencies => CurrencyData.popular;

  /// Whether the user needs to complete initial currency setup
  /// True only on first launch when currency hasn't been explicitly chosen
  bool get needsCurrencySetup => _needsCurrencySetup;

  /// Initialize the settings provider
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
  }

  /// Load settings from SharedPreferences
  /// Uses USD as default if no currency is saved
  Future<void> _loadSettings() async {
    _isLoading = true;
    notifyListeners();

    if (_prefs != null) {
      // Load notifications setting (default: true)
      _notificationsEnabled = _prefs!.getBool(_notificationsKey) ?? true;
      _notificationService.globalEnabled = _notificationsEnabled;

      // Check if currency setup has been completed
      final currencySetupComplete =
          _prefs!.getBool(_currencySetupCompleteKey) ?? false;
      _needsCurrencySetup = !currencySetupComplete;

      // Load currency setting (default: USD)
      final savedCurrencyCode = _prefs!.getString(_currencyKey);

      if (savedCurrencyCode != null && savedCurrencyCode.isNotEmpty) {
        // Use saved currency
        _selectedCurrency = CurrencyData.fromCode(savedCurrencyCode);
      } else {
        // Use default currency (USD)
        _selectedCurrency = CurrencyData.defaultCurrency;
        // Save the default currency
        await _prefs!.setString(_currencyKey, _selectedCurrency.code);
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Toggle notifications on/off
  Future<void> toggleNotifications(bool enabled) async {
    _notificationsEnabled = enabled;
    _notificationService.globalEnabled = enabled;

    if (!enabled) {
      print('[SettingsProvider] 🗑️ Notifications disabled: Cancelling all');
      await _notificationService.cancelAllNotifications();
    } else {
      print('[SettingsProvider] 🔔 Notifications enabled: Re-scheduling');
      // Request permissions (Android 13+) if they are being turned on
      await _notificationService.requestPermissions();
      // Note: Full reschedule usually happens when user returns to Home/Detail
      // which triggers loadBills or _rescheduleRemindersForBill.
    }

    notifyListeners();

    await _prefs?.setBool(_notificationsKey, enabled);
    await _syncToFirestore();
  }

  /// Set the selected currency
  Future<void> setCurrency(Currency currency) async {
    _selectedCurrency = currency;
    notifyListeners();

    await _prefs?.setString(_currencyKey, currency.code);
    await _syncToFirestore();

    if (kDebugMode) {
      print('[SettingsProvider] Currency changed to: ${currency.code}');
    }
  }

  /// Mark currency setup as complete
  /// Call this after the user has chosen their currency on first launch
  Future<void> completeCurrencySetup() async {
    _needsCurrencySetup = false;
    notifyListeners();

    await _prefs?.setBool(_currencySetupCompleteKey, true);
    await _syncToFirestore(); // Sync to Firestore for user-specific persistence

    if (kDebugMode) {
      print('[SettingsProvider] Currency setup completed');
    }
  }

  /// Set currency by code
  Future<void> setCurrencyByCode(String code) async {
    final currency = CurrencyData.fromCode(code);
    await setCurrency(currency);
  }

  /// Search currencies by query
  List<Currency> searchCurrencies(String query) {
    return CurrencyData.search(query);
  }

  /// Format an amount with the selected currency
  String formatAmount(double amount, {bool showSymbol = true}) {
    return _selectedCurrency.formatAmount(amount, showSymbol: showSymbol);
  }

  /// Sync settings to Firestore for authenticated users
  Future<void> _syncToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection(_firestoreCollection)
          .doc(user.uid)
          .set({
            _firestoreSettingsField: {
              'notificationsEnabled': _notificationsEnabled,
              'currencyCode': _selectedCurrency.code,
              'currencySetupComplete': !_needsCurrencySetup,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          }, SetOptions(merge: true));

      if (kDebugMode) {
        print('[SettingsProvider] Settings synced to Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SettingsProvider] Failed to sync settings: $e');
      }
    }
  }

  /// Reset settings to defaults (used during sign-out)
  /// Clears local preferences and resets to default values
  Future<void> resetToDefaults() async {
    _selectedCurrency = CurrencyData.defaultCurrency;
    _notificationsEnabled = true;
    _needsCurrencySetup = true; // Reset so next user sees the setup prompt
    notifyListeners();

    // Clear local preferences
    await _prefs?.remove(_currencyKey);
    await _prefs?.remove(_notificationsKey);
    await _prefs?.remove(_currencySetupCompleteKey);

    if (kDebugMode) {
      print('[SettingsProvider] Settings reset to defaults');
    }
  }

  /// Load settings from Firestore (for authenticated users)
  Future<void> syncFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection(_firestoreCollection)
          .doc(user.uid)
          .get();

      // Track if we found setup complete status in Firestore
      bool foundSetupStatus = false;

      if (doc.exists && doc.data() != null) {
        final settings =
            doc.data()![_firestoreSettingsField] as Map<String, dynamic>?;

        if (settings != null) {
          // Load notifications setting
          if (settings['notificationsEnabled'] != null) {
            _notificationsEnabled = settings['notificationsEnabled'] as bool;
            await _prefs?.setBool(_notificationsKey, _notificationsEnabled);
          }

          // Load currency setting
          if (settings['currencyCode'] != null) {
            final currencyCode = settings['currencyCode'] as String;
            _selectedCurrency = CurrencyData.fromCode(currencyCode);
            await _prefs?.setString(_currencyKey, currencyCode);
          }

          // Load currency setup complete status
          if (settings['currencySetupComplete'] != null) {
            final setupComplete = settings['currencySetupComplete'] as bool;
            _needsCurrencySetup = !setupComplete;
            await _prefs?.setBool(_currencySetupCompleteKey, setupComplete);
            foundSetupStatus = true;
          }

          if (kDebugMode) {
            print('[SettingsProvider] Settings loaded from Firestore');
          }
        }
      }

      // If no setup status was found in Firestore, this is a new user or
      // a user who hasn't completed setup - ensure dialog will show
      if (!foundSetupStatus) {
        _needsCurrencySetup = true;
        await _prefs?.setBool(_currencySetupCompleteKey, false);
        if (kDebugMode) {
          print(
            '[SettingsProvider] New user or incomplete setup - will show currency dialog',
          );
        }
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('[SettingsProvider] Failed to load settings from Firestore: $e');
      }
    }
  }
}
