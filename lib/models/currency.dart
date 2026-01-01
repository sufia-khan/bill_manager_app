/// Currency model representing an international currency
/// Based on ISO 4217 standard
///
/// Features:
/// - Currency name (e.g., "US Dollar")
/// - ISO 4217 code (e.g., "USD")
/// - Currency symbol (e.g., "$", "₹", "€")
/// - Country flag emoji for visual identification
class Currency {
  /// Full name of the currency (e.g., "US Dollar")
  final String name;

  /// ISO 4217 three-letter currency code (e.g., "USD")
  final String code;

  /// Currency symbol (e.g., "$", "₹", "€", "£")
  /// Some currencies may use the code as symbol if no unique symbol exists
  final String symbol;

  /// Country flag emoji for visual identification (e.g., "🇺🇸")
  final String flag;

  /// Number of decimal places typically used (default: 2)
  final int decimalDigits;

  const Currency({
    required this.name,
    required this.code,
    required this.symbol,
    this.flag = '',
    this.decimalDigits = 2,
  });

  /// Get a display-friendly representation
  /// Format: [Symbol] Currency Name (ISO Code)
  /// Example: "₹ Indian Rupee (INR)"
  String get displayName => '$symbol  $name ($code)';

  /// Get a short display format
  /// Format: [Symbol] [Code]
  /// Example: "₹ INR"
  String get shortDisplay => '$symbol $code';

  /// Get symbol with fallback to code if symbol is empty
  String get safeSymbol => symbol.isNotEmpty ? symbol : code;

  /// Format an amount with this currency's symbol
  /// Example: formatAmount(1000) => "₹1,000.00"
  String formatAmount(double amount, {bool showSymbol = true}) {
    final formatted = amount.toStringAsFixed(decimalDigits);
    // Add thousand separators
    final parts = formatted.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    final result = decimalDigits > 0 ? '$intPart.${parts[1]}' : intPart;
    return showSymbol ? '$safeSymbol$result' : result;
  }

  /// Create a Currency from JSON/Map
  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      flag: json['flag'] as String? ?? '',
      decimalDigits: json['decimalDigits'] as int? ?? 2,
    );
  }

  /// Convert to JSON/Map for storage
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'symbol': symbol,
      'flag': flag,
      'decimalDigits': decimalDigits,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Currency &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'Currency($code: $name, $symbol)';
}
