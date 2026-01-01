import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/currency.dart';
import '../data/currencies.dart';

// Re-export Currency for backwards compatibility
export '../models/currency.dart';
export '../data/currencies.dart' show CurrencyData;

/// Settings Provider - Manages app preferences
///
/// Features:
/// - Notification toggle with persistence
/// - Currency selection with full ISO 4217 support
/// - Locale-based default currency detection
/// - Local persistence with SharedPreferences
/// - Firestore sync for authenticated users
class SettingsProvider extends ChangeNotifier {
  static const String _notificationsKey = 'notifications_enabled';
  static const String _currencyKey = 'selected_currency';
  static const String _firestoreCollection = 'users';
  static const String _firestoreSettingsField = 'settings';

  SharedPreferences? _prefs;
  bool _notificationsEnabled = true;
  Currency _selectedCurrency = CurrencyData.defaultCurrency;
  bool _isLoading = true;

  // Getters
  bool get notificationsEnabled => _notificationsEnabled;
  Currency get selectedCurrency => _selectedCurrency;
  String get currencySymbol => _selectedCurrency.safeSymbol;
  String get currencyCode => _selectedCurrency.code;
  bool get isLoading => _isLoading;
  List<Currency> get availableCurrencies => CurrencyData.all;
  List<Currency> get popularCurrencies => CurrencyData.popular;

  /// Initialize the settings provider
  /// Detects device locale for default currency
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
  }

  /// Load settings from SharedPreferences
  /// Falls back to locale-based currency if not set
  Future<void> _loadSettings() async {
    _isLoading = true;
    notifyListeners();

    if (_prefs != null) {
      // Load notifications setting (default: true)
      _notificationsEnabled = _prefs!.getBool(_notificationsKey) ?? true;

      // Load currency setting
      final savedCurrencyCode = _prefs!.getString(_currencyKey);

      if (savedCurrencyCode != null && savedCurrencyCode.isNotEmpty) {
        // Use saved currency
        _selectedCurrency = CurrencyData.fromCode(savedCurrencyCode);
      } else {
        // Detect from device locale
        _selectedCurrency = _detectLocaleCurrency();
        // Save the detected currency
        await _prefs!.setString(_currencyKey, _selectedCurrency.code);
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Detect currency from device locale
  /// Falls back to INR if detection fails
  Currency _detectLocaleCurrency() {
    try {
      // Get device locale
      final locale = ui.PlatformDispatcher.instance.locale;
      final localeString = '${locale.languageCode}_${locale.countryCode ?? ''}';

      if (kDebugMode) {
        print('[SettingsProvider] Detected locale: $localeString');
      }

      final detectedCurrency = CurrencyData.fromLocale(localeString);

      if (kDebugMode) {
        print('[SettingsProvider] Detected currency: ${detectedCurrency.code}');
      }

      return detectedCurrency;
    } catch (e) {
      if (kDebugMode) {
        print('[SettingsProvider] Locale detection failed: $e');
      }
      return CurrencyData.defaultCurrency;
    }
  }

  /// Toggle notifications on/off
  Future<void> toggleNotifications(bool enabled) async {
    _notificationsEnabled = enabled;
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

  /// Load settings from Firestore (for authenticated users)
  Future<void> syncFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection(_firestoreCollection)
          .doc(user.uid)
          .get();

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

          notifyListeners();

          if (kDebugMode) {
            print('[SettingsProvider] Settings loaded from Firestore');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SettingsProvider] Failed to load settings from Firestore: $e');
      }
    }
  }
}
