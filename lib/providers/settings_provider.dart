import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Currency model with symbol and name
class Currency {
  final String code;
  final String symbol;
  final String name;

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Currency &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// Available currencies
class Currencies {
  static const List<Currency> all = [
    Currency(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
    Currency(code: 'USD', symbol: '\$', name: 'US Dollar'),
    Currency(code: 'EUR', symbol: '€', name: 'Euro'),
    Currency(code: 'GBP', symbol: '£', name: 'British Pound'),
    Currency(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
    Currency(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar'),
    Currency(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar'),
    Currency(code: 'CHF', symbol: 'CHF', name: 'Swiss Franc'),
    Currency(code: 'CNY', symbol: '¥', name: 'Chinese Yuan'),
    Currency(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham'),
  ];

  static Currency fromCode(String code) {
    return all.firstWhere(
      (c) => c.code == code,
      orElse: () => all.first, // Default to INR
    );
  }
}

/// Settings Provider - Manages app preferences
/// Handles notification toggle and currency selection
class SettingsProvider extends ChangeNotifier {
  static const String _notificationsKey = 'notifications_enabled';
  static const String _currencyKey = 'selected_currency';

  SharedPreferences? _prefs;
  bool _notificationsEnabled = true;
  Currency _selectedCurrency = Currencies.all.first; // Default: INR
  bool _isLoading = true;

  // Getters
  bool get notificationsEnabled => _notificationsEnabled;
  Currency get selectedCurrency => _selectedCurrency;
  String get currencySymbol => _selectedCurrency.symbol;
  String get currencyCode => _selectedCurrency.code;
  bool get isLoading => _isLoading;
  List<Currency> get availableCurrencies => Currencies.all;

  /// Initialize the settings provider
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
  }

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    _isLoading = true;
    notifyListeners();

    if (_prefs != null) {
      // Load notifications setting (default: true)
      _notificationsEnabled = _prefs!.getBool(_notificationsKey) ?? true;

      // Load currency setting (default: INR)
      final currencyCode = _prefs!.getString(_currencyKey) ?? 'INR';
      _selectedCurrency = Currencies.fromCode(currencyCode);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Toggle notifications on/off
  Future<void> toggleNotifications(bool enabled) async {
    _notificationsEnabled = enabled;
    notifyListeners();

    await _prefs?.setBool(_notificationsKey, enabled);
  }

  /// Set the selected currency
  Future<void> setCurrency(Currency currency) async {
    _selectedCurrency = currency;
    notifyListeners();

    await _prefs?.setString(_currencyKey, currency.code);
  }

  /// Set currency by code
  Future<void> setCurrencyByCode(String code) async {
    final currency = Currencies.fromCode(code);
    await setCurrency(currency);
  }
}
