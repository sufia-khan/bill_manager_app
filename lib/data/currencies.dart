import '../models/currency.dart';

/// Complete list of ALL global currencies based on ISO 4217
/// This is a static, offline-first currency dataset
///
/// Features:
/// - All major world currencies
/// - Proper Unicode symbols
/// - Country flag emojis
/// - Correct decimal places
/// - Search helper methods
class CurrencyData {
  CurrencyData._();

  /// Default currency (US Dollar)
  static const Currency defaultCurrency = Currency(
    name: 'US Dollar',
    code: 'USD',
    symbol: '\$',
    flag: '🇺🇸',
    decimalDigits: 2,
  );

  /// Get currency by ISO code with safe fallback
  static Currency fromCode(String code) {
    try {
      return all.firstWhere(
        (c) => c.code.toUpperCase() == code.toUpperCase(),
        orElse: () => defaultCurrency,
      );
    } catch (e) {
      return defaultCurrency;
    }
  }

  /// Get currency by locale code (e.g., "en_US" -> USD, "hi_IN" -> INR)
  static Currency fromLocale(String localeCode) {
    final countryCode = localeCode.contains('_')
        ? localeCode.split('_').last.toUpperCase()
        : localeCode.toUpperCase();

    // Map country codes to currency codes
    final String? currencyCode = _localeToCurrency[countryCode];
    if (currencyCode != null) {
      return fromCode(currencyCode);
    }
    return defaultCurrency;
  }

  /// Search currencies by name, code, or symbol
  static List<Currency> search(String query) {
    if (query.isEmpty) return all;

    final lowerQuery = query.toLowerCase().trim();
    return all.where((currency) {
      return currency.name.toLowerCase().contains(lowerQuery) ||
          currency.code.toLowerCase().contains(lowerQuery) ||
          currency.symbol.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Commonly used/popular currencies (shown at top)
  static const List<Currency> popular = [
    Currency(name: 'US Dollar', code: 'USD', symbol: '\$', flag: '🇺🇸'),
    Currency(name: 'Indian Rupee', code: 'INR', symbol: '₹', flag: '🇮🇳'),
    Currency(name: 'Euro', code: 'EUR', symbol: '€', flag: '🇪🇺'),
    Currency(name: 'British Pound', code: 'GBP', symbol: '£', flag: '🇬🇧'),
    Currency(
      name: 'Japanese Yen',
      code: 'JPY',
      symbol: '¥',
      flag: '🇯🇵',
      decimalDigits: 0,
    ),
    Currency(
      name: 'Australian Dollar',
      code: 'AUD',
      symbol: 'A\$',
      flag: '🇦🇺',
    ),
    Currency(name: 'Canadian Dollar', code: 'CAD', symbol: 'C\$', flag: '🇨🇦'),
    Currency(name: 'Swiss Franc', code: 'CHF', symbol: 'CHF', flag: '🇨🇭'),
    Currency(name: 'Chinese Yuan', code: 'CNY', symbol: '¥', flag: '🇨🇳'),
    Currency(name: 'UAE Dirham', code: 'AED', symbol: 'د.إ', flag: '🇦🇪'),
  ];

  /// Complete list of ALL world currencies (ISO 4217)
  static const List<Currency> all = [
    // Popular currencies first
    Currency(name: 'US Dollar', code: 'USD', symbol: '\$', flag: '🇺🇸'),
    Currency(name: 'Indian Rupee', code: 'INR', symbol: '₹', flag: '🇮🇳'),
    Currency(name: 'Euro', code: 'EUR', symbol: '€', flag: '🇪🇺'),
    Currency(name: 'British Pound', code: 'GBP', symbol: '£', flag: '🇬🇧'),
    Currency(
      name: 'Japanese Yen',
      code: 'JPY',
      symbol: '¥',
      flag: '🇯🇵',
      decimalDigits: 0,
    ),
    Currency(
      name: 'Australian Dollar',
      code: 'AUD',
      symbol: 'A\$',
      flag: '🇦🇺',
    ),
    Currency(name: 'Canadian Dollar', code: 'CAD', symbol: 'C\$', flag: '🇨🇦'),
    Currency(name: 'Swiss Franc', code: 'CHF', symbol: 'CHF', flag: '🇨🇭'),
    Currency(name: 'Chinese Yuan', code: 'CNY', symbol: '¥', flag: '🇨🇳'),
    Currency(name: 'UAE Dirham', code: 'AED', symbol: 'د.إ', flag: '🇦🇪'),

    // A
    Currency(name: 'Afghan Afghani', code: 'AFN', symbol: '؋', flag: '🇦🇫'),
    Currency(name: 'Albanian Lek', code: 'ALL', symbol: 'L', flag: '🇦🇱'),
    Currency(name: 'Algerian Dinar', code: 'DZD', symbol: 'د.ج', flag: '🇩🇿'),
    Currency(name: 'Angolan Kwanza', code: 'AOA', symbol: 'Kz', flag: '🇦🇴'),
    Currency(name: 'Argentine Peso', code: 'ARS', symbol: '\$', flag: '🇦🇷'),
    Currency(name: 'Armenian Dram', code: 'AMD', symbol: '֏', flag: '🇦🇲'),
    Currency(name: 'Aruban Florin', code: 'AWG', symbol: 'ƒ', flag: '🇦🇼'),
    Currency(name: 'Azerbaijani Manat', code: 'AZN', symbol: '₼', flag: '🇦🇿'),

    // B
    Currency(name: 'Bahamian Dollar', code: 'BSD', symbol: '\$', flag: '🇧🇸'),
    Currency(
      name: 'Bahraini Dinar',
      code: 'BHD',
      symbol: '.د.ب',
      flag: '🇧🇭',
      decimalDigits: 3,
    ),
    Currency(name: 'Bangladeshi Taka', code: 'BDT', symbol: '৳', flag: '🇧🇩'),
    Currency(name: 'Barbadian Dollar', code: 'BBD', symbol: '\$', flag: '🇧🇧'),
    Currency(name: 'Belarusian Ruble', code: 'BYN', symbol: 'Br', flag: '🇧🇾'),
    Currency(name: 'Belize Dollar', code: 'BZD', symbol: 'BZ\$', flag: '🇧🇿'),
    Currency(name: 'Bermudian Dollar', code: 'BMD', symbol: '\$', flag: '🇧🇲'),
    Currency(
      name: 'Bhutanese Ngultrum',
      code: 'BTN',
      symbol: 'Nu.',
      flag: '🇧🇹',
    ),
    Currency(
      name: 'Bolivian Boliviano',
      code: 'BOB',
      symbol: 'Bs.',
      flag: '🇧🇴',
    ),
    Currency(name: 'Bosnia Mark', code: 'BAM', symbol: 'KM', flag: '🇧🇦'),
    Currency(name: 'Botswana Pula', code: 'BWP', symbol: 'P', flag: '🇧🇼'),
    Currency(name: 'Brazilian Real', code: 'BRL', symbol: 'R\$', flag: '🇧🇷'),
    Currency(name: 'Brunei Dollar', code: 'BND', symbol: '\$', flag: '🇧🇳'),
    Currency(name: 'Bulgarian Lev', code: 'BGN', symbol: 'лв', flag: '🇧🇬'),
    Currency(
      name: 'Burundian Franc',
      code: 'BIF',
      symbol: 'FBu',
      flag: '🇧🇮',
      decimalDigits: 0,
    ),

    // C
    Currency(name: 'Cambodian Riel', code: 'KHR', symbol: '៛', flag: '🇰🇭'),
    Currency(
      name: 'Cape Verdean Escudo',
      code: 'CVE',
      symbol: 'Esc',
      flag: '🇨🇻',
    ),
    Currency(
      name: 'Cayman Islands Dollar',
      code: 'KYD',
      symbol: '\$',
      flag: '🇰🇾',
    ),
    Currency(
      name: 'Central African CFA Franc',
      code: 'XAF',
      symbol: 'FCFA',
      flag: '🇨🇲',
      decimalDigits: 0,
    ),
    Currency(
      name: 'CFP Franc',
      code: 'XPF',
      symbol: '₣',
      flag: '🇵🇫',
      decimalDigits: 0,
    ),
    Currency(
      name: 'Chilean Peso',
      code: 'CLP',
      symbol: '\$',
      flag: '🇨🇱',
      decimalDigits: 0,
    ),
    Currency(name: 'Colombian Peso', code: 'COP', symbol: '\$', flag: '🇨🇴'),
    Currency(
      name: 'Comorian Franc',
      code: 'KMF',
      symbol: 'CF',
      flag: '🇰🇲',
      decimalDigits: 0,
    ),
    Currency(name: 'Congolese Franc', code: 'CDF', symbol: 'FC', flag: '🇨🇩'),
    Currency(name: 'Costa Rican Colón', code: 'CRC', symbol: '₡', flag: '🇨🇷'),
    Currency(name: 'Croatian Kuna', code: 'HRK', symbol: 'kn', flag: '🇭🇷'),
    Currency(name: 'Cuban Peso', code: 'CUP', symbol: '\$', flag: '🇨🇺'),
    Currency(name: 'Czech Koruna', code: 'CZK', symbol: 'Kč', flag: '🇨🇿'),

    // D
    Currency(name: 'Danish Krone', code: 'DKK', symbol: 'kr', flag: '🇩🇰'),
    Currency(
      name: 'Djiboutian Franc',
      code: 'DJF',
      symbol: 'Fdj',
      flag: '🇩🇯',
      decimalDigits: 0,
    ),
    Currency(name: 'Dominican Peso', code: 'DOP', symbol: 'RD\$', flag: '🇩🇴'),

    // E
    Currency(
      name: 'East Caribbean Dollar',
      code: 'XCD',
      symbol: '\$',
      flag: '🇦🇬',
    ),
    Currency(name: 'Egyptian Pound', code: 'EGP', symbol: 'E£', flag: '🇪🇬'),
    Currency(name: 'Eritrean Nakfa', code: 'ERN', symbol: 'Nfk', flag: '🇪🇷'),
    Currency(name: 'Ethiopian Birr', code: 'ETB', symbol: 'Br', flag: '🇪🇹'),

    // F
    Currency(
      name: 'Falkland Islands Pound',
      code: 'FKP',
      symbol: '£',
      flag: '🇫🇰',
    ),
    Currency(name: 'Fijian Dollar', code: 'FJD', symbol: '\$', flag: '🇫🇯'),

    // G
    Currency(name: 'Gambian Dalasi', code: 'GMD', symbol: 'D', flag: '🇬🇲'),
    Currency(name: 'Georgian Lari', code: 'GEL', symbol: '₾', flag: '🇬🇪'),
    Currency(name: 'Ghanaian Cedi', code: 'GHS', symbol: '₵', flag: '🇬🇭'),
    Currency(name: 'Gibraltar Pound', code: 'GIP', symbol: '£', flag: '🇬🇮'),
    Currency(
      name: 'Guatemalan Quetzal',
      code: 'GTQ',
      symbol: 'Q',
      flag: '🇬🇹',
    ),
    Currency(
      name: 'Guinean Franc',
      code: 'GNF',
      symbol: 'FG',
      flag: '🇬🇳',
      decimalDigits: 0,
    ),
    Currency(name: 'Guyanese Dollar', code: 'GYD', symbol: '\$', flag: '🇬🇾'),

    // H
    Currency(name: 'Haitian Gourde', code: 'HTG', symbol: 'G', flag: '🇭🇹'),
    Currency(name: 'Honduran Lempira', code: 'HNL', symbol: 'L', flag: '🇭🇳'),
    Currency(
      name: 'Hong Kong Dollar',
      code: 'HKD',
      symbol: 'HK\$',
      flag: '🇭🇰',
    ),
    Currency(name: 'Hungarian Forint', code: 'HUF', symbol: 'Ft', flag: '🇭🇺'),

    // I
    Currency(
      name: 'Icelandic Króna',
      code: 'ISK',
      symbol: 'kr',
      flag: '🇮🇸',
      decimalDigits: 0,
    ),
    Currency(
      name: 'Indonesian Rupiah',
      code: 'IDR',
      symbol: 'Rp',
      flag: '🇮🇩',
    ),
    Currency(name: 'Iranian Rial', code: 'IRR', symbol: '﷼', flag: '🇮🇷'),
    Currency(
      name: 'Iraqi Dinar',
      code: 'IQD',
      symbol: 'ع.د',
      flag: '🇮🇶',
      decimalDigits: 3,
    ),
    Currency(name: 'Israeli Shekel', code: 'ILS', symbol: '₪', flag: '🇮🇱'),

    // J
    Currency(name: 'Jamaican Dollar', code: 'JMD', symbol: 'J\$', flag: '🇯🇲'),
    Currency(
      name: 'Jordanian Dinar',
      code: 'JOD',
      symbol: 'د.ا',
      flag: '🇯🇴',
      decimalDigits: 3,
    ),

    // K
    Currency(name: 'Kazakhstani Tenge', code: 'KZT', symbol: '₸', flag: '🇰🇿'),
    Currency(name: 'Kenyan Shilling', code: 'KES', symbol: 'KSh', flag: '🇰🇪'),
    Currency(
      name: 'Kuwaiti Dinar',
      code: 'KWD',
      symbol: 'د.ك',
      flag: '🇰🇼',
      decimalDigits: 3,
    ),
    Currency(name: 'Kyrgyzstani Som', code: 'KGS', symbol: 'с', flag: '🇰🇬'),

    // L
    Currency(name: 'Lao Kip', code: 'LAK', symbol: '₭', flag: '🇱🇦'),
    Currency(name: 'Lebanese Pound', code: 'LBP', symbol: 'ل.ل', flag: '🇱🇧'),
    Currency(name: 'Lesotho Loti', code: 'LSL', symbol: 'L', flag: '🇱🇸'),
    Currency(name: 'Liberian Dollar', code: 'LRD', symbol: '\$', flag: '🇱🇷'),
    Currency(
      name: 'Libyan Dinar',
      code: 'LYD',
      symbol: 'ل.د',
      flag: '🇱🇾',
      decimalDigits: 3,
    ),

    // M
    Currency(
      name: 'Macanese Pataca',
      code: 'MOP',
      symbol: 'MOP\$',
      flag: '🇲🇴',
    ),
    Currency(name: 'Malagasy Ariary', code: 'MGA', symbol: 'Ar', flag: '🇲🇬'),
    Currency(name: 'Malawian Kwacha', code: 'MWK', symbol: 'MK', flag: '🇲🇼'),
    Currency(
      name: 'Malaysian Ringgit',
      code: 'MYR',
      symbol: 'RM',
      flag: '🇲🇾',
    ),
    Currency(
      name: 'Maldivian Rufiyaa',
      code: 'MVR',
      symbol: 'Rf',
      flag: '🇲🇻',
    ),
    Currency(
      name: 'Mauritanian Ouguiya',
      code: 'MRU',
      symbol: 'UM',
      flag: '🇲🇷',
    ),
    Currency(name: 'Mauritian Rupee', code: 'MUR', symbol: '₨', flag: '🇲🇺'),
    Currency(name: 'Mexican Peso', code: 'MXN', symbol: '\$', flag: '🇲🇽'),
    Currency(name: 'Moldovan Leu', code: 'MDL', symbol: 'L', flag: '🇲🇩'),
    Currency(name: 'Mongolian Tugrik', code: 'MNT', symbol: '₮', flag: '🇲🇳'),
    Currency(
      name: 'Moroccan Dirham',
      code: 'MAD',
      symbol: 'د.م.',
      flag: '🇲🇦',
    ),
    Currency(
      name: 'Mozambican Metical',
      code: 'MZN',
      symbol: 'MT',
      flag: '🇲🇿',
    ),
    Currency(name: 'Myanmar Kyat', code: 'MMK', symbol: 'K', flag: '🇲🇲'),

    // N
    Currency(name: 'Namibian Dollar', code: 'NAD', symbol: '\$', flag: '🇳🇦'),
    Currency(name: 'Nepalese Rupee', code: 'NPR', symbol: '₨', flag: '🇳🇵'),
    Currency(
      name: 'Netherlands Antillean Guilder',
      code: 'ANG',
      symbol: 'ƒ',
      flag: '🇨🇼',
    ),
    Currency(
      name: 'New Taiwan Dollar',
      code: 'TWD',
      symbol: 'NT\$',
      flag: '🇹🇼',
    ),
    Currency(
      name: 'New Zealand Dollar',
      code: 'NZD',
      symbol: '\$',
      flag: '🇳🇿',
    ),
    Currency(
      name: 'Nicaraguan Córdoba',
      code: 'NIO',
      symbol: 'C\$',
      flag: '🇳🇮',
    ),
    Currency(name: 'Nigerian Naira', code: 'NGN', symbol: '₦', flag: '🇳🇬'),
    Currency(name: 'North Korean Won', code: 'KPW', symbol: '₩', flag: '🇰🇵'),
    Currency(name: 'Norwegian Krone', code: 'NOK', symbol: 'kr', flag: '🇳🇴'),

    // O
    Currency(
      name: 'Omani Rial',
      code: 'OMR',
      symbol: 'ر.ع.',
      flag: '🇴🇲',
      decimalDigits: 3,
    ),

    // P
    Currency(name: 'Pakistani Rupee', code: 'PKR', symbol: '₨', flag: '🇵🇰'),
    Currency(
      name: 'Panamanian Balboa',
      code: 'PAB',
      symbol: 'B/.',
      flag: '🇵🇦',
    ),
    Currency(
      name: 'Papua New Guinean Kina',
      code: 'PGK',
      symbol: 'K',
      flag: '🇵🇬',
    ),
    Currency(
      name: 'Paraguayan Guarani',
      code: 'PYG',
      symbol: '₲',
      flag: '🇵🇾',
      decimalDigits: 0,
    ),
    Currency(name: 'Peruvian Sol', code: 'PEN', symbol: 'S/', flag: '🇵🇪'),
    Currency(name: 'Philippine Peso', code: 'PHP', symbol: '₱', flag: '🇵🇭'),
    Currency(name: 'Polish Zloty', code: 'PLN', symbol: 'zł', flag: '🇵🇱'),

    // Q
    Currency(name: 'Qatari Riyal', code: 'QAR', symbol: 'ر.ق', flag: '🇶🇦'),

    // R
    Currency(name: 'Romanian Leu', code: 'RON', symbol: 'lei', flag: '🇷🇴'),
    Currency(name: 'Russian Ruble', code: 'RUB', symbol: '₽', flag: '🇷🇺'),
    Currency(
      name: 'Rwandan Franc',
      code: 'RWF',
      symbol: 'FRw',
      flag: '🇷🇼',
      decimalDigits: 0,
    ),

    // S
    Currency(
      name: 'Saint Helena Pound',
      code: 'SHP',
      symbol: '£',
      flag: '🇸🇭',
    ),
    Currency(name: 'Samoan Tala', code: 'WST', symbol: 'WS\$', flag: '🇼🇸'),
    Currency(name: 'São Tomé Dobra', code: 'STN', symbol: 'Db', flag: '🇸🇹'),
    Currency(name: 'Saudi Riyal', code: 'SAR', symbol: 'ر.س', flag: '🇸🇦'),
    Currency(name: 'Serbian Dinar', code: 'RSD', symbol: 'дин.', flag: '🇷🇸'),
    Currency(name: 'Seychellois Rupee', code: 'SCR', symbol: '₨', flag: '🇸🇨'),
    Currency(
      name: 'Sierra Leonean Leone',
      code: 'SLE',
      symbol: 'Le',
      flag: '🇸🇱',
    ),
    Currency(
      name: 'Singapore Dollar',
      code: 'SGD',
      symbol: 'S\$',
      flag: '🇸🇬',
    ),
    Currency(
      name: 'Solomon Islands Dollar',
      code: 'SBD',
      symbol: '\$',
      flag: '🇸🇧',
    ),
    Currency(name: 'Somali Shilling', code: 'SOS', symbol: 'S', flag: '🇸🇴'),
    Currency(
      name: 'South African Rand',
      code: 'ZAR',
      symbol: 'R',
      flag: '🇿🇦',
    ),
    Currency(
      name: 'South Korean Won',
      code: 'KRW',
      symbol: '₩',
      flag: '🇰🇷',
      decimalDigits: 0,
    ),
    Currency(
      name: 'South Sudanese Pound',
      code: 'SSP',
      symbol: '£',
      flag: '🇸🇸',
    ),
    Currency(name: 'Sri Lankan Rupee', code: 'LKR', symbol: 'Rs', flag: '🇱🇰'),
    Currency(name: 'Sudanese Pound', code: 'SDG', symbol: 'ج.س.', flag: '🇸🇩'),
    Currency(
      name: 'Surinamese Dollar',
      code: 'SRD',
      symbol: '\$',
      flag: '🇸🇷',
    ),
    Currency(name: 'Swazi Lilangeni', code: 'SZL', symbol: 'L', flag: '🇸🇿'),
    Currency(name: 'Swedish Krona', code: 'SEK', symbol: 'kr', flag: '🇸🇪'),
    Currency(name: 'Syrian Pound', code: 'SYP', symbol: '£S', flag: '🇸🇾'),

    // T
    Currency(
      name: 'Tajikistani Somoni',
      code: 'TJS',
      symbol: 'ЅМ',
      flag: '🇹🇯',
    ),
    Currency(
      name: 'Tanzanian Shilling',
      code: 'TZS',
      symbol: 'TSh',
      flag: '🇹🇿',
    ),
    Currency(name: 'Thai Baht', code: 'THB', symbol: '฿', flag: '🇹🇭'),
    Currency(name: 'Tongan Paʻanga', code: 'TOP', symbol: 'T\$', flag: '🇹🇴'),
    Currency(
      name: 'Trinidad Dollar',
      code: 'TTD',
      symbol: 'TT\$',
      flag: '🇹🇹',
    ),
    Currency(
      name: 'Tunisian Dinar',
      code: 'TND',
      symbol: 'د.ت',
      flag: '🇹🇳',
      decimalDigits: 3,
    ),
    Currency(name: 'Turkish Lira', code: 'TRY', symbol: '₺', flag: '🇹🇷'),
    Currency(
      name: 'Turkmenistani Manat',
      code: 'TMT',
      symbol: 'm',
      flag: '🇹🇲',
    ),

    // U
    Currency(
      name: 'Ugandan Shilling',
      code: 'UGX',
      symbol: 'USh',
      flag: '🇺🇬',
      decimalDigits: 0,
    ),
    Currency(name: 'Ukrainian Hryvnia', code: 'UAH', symbol: '₴', flag: '🇺🇦'),
    Currency(name: 'Uruguayan Peso', code: 'UYU', symbol: '\$U', flag: '🇺🇾'),
    Currency(
      name: 'Uzbekistani Som',
      code: 'UZS',
      symbol: "so'm",
      flag: '🇺🇿',
    ),

    // V
    Currency(
      name: 'Vanuatu Vatu',
      code: 'VUV',
      symbol: 'VT',
      flag: '🇻🇺',
      decimalDigits: 0,
    ),
    Currency(
      name: 'Venezuelan Bolívar',
      code: 'VES',
      symbol: 'Bs.',
      flag: '🇻🇪',
    ),
    Currency(
      name: 'Vietnamese Dong',
      code: 'VND',
      symbol: '₫',
      flag: '🇻🇳',
      decimalDigits: 0,
    ),

    // W
    Currency(
      name: 'West African CFA Franc',
      code: 'XOF',
      symbol: 'CFA',
      flag: '🇸🇳',
      decimalDigits: 0,
    ),

    // Y
    Currency(name: 'Yemeni Rial', code: 'YER', symbol: '﷼', flag: '🇾🇪'),

    // Z
    Currency(name: 'Zambian Kwacha', code: 'ZMW', symbol: 'ZK', flag: '🇿🇲'),
    Currency(
      name: 'Zimbabwean Dollar',
      code: 'ZWL',
      symbol: 'Z\$',
      flag: '🇿🇼',
    ),
  ];

  /// Map of country codes to currency codes for locale detection
  static const Map<String, String> _localeToCurrency = {
    'IN': 'INR', // India
    'US': 'USD', // United States
    'GB': 'GBP', // United Kingdom
    'UK': 'GBP', // United Kingdom (alternate)
    'EU': 'EUR', // European Union
    'JP': 'JPY', // Japan
    'AU': 'AUD', // Australia
    'CA': 'CAD', // Canada
    'CH': 'CHF', // Switzerland
    'CN': 'CNY', // China
    'AE': 'AED', // UAE
    'DE': 'EUR', // Germany
    'FR': 'EUR', // France
    'IT': 'EUR', // Italy
    'ES': 'EUR', // Spain
    'NL': 'EUR', // Netherlands
    'BE': 'EUR', // Belgium
    'AT': 'EUR', // Austria
    'PT': 'EUR', // Portugal
    'IE': 'EUR', // Ireland
    'FI': 'EUR', // Finland
    'GR': 'EUR', // Greece
    'BR': 'BRL', // Brazil
    'MX': 'MXN', // Mexico
    'KR': 'KRW', // South Korea
    'RU': 'RUB', // Russia
    'SG': 'SGD', // Singapore
    'HK': 'HKD', // Hong Kong
    'TW': 'TWD', // Taiwan
    'TH': 'THB', // Thailand
    'MY': 'MYR', // Malaysia
    'ID': 'IDR', // Indonesia
    'PH': 'PHP', // Philippines
    'VN': 'VND', // Vietnam
    'PK': 'PKR', // Pakistan
    'BD': 'BDT', // Bangladesh
    'LK': 'LKR', // Sri Lanka
    'NP': 'NPR', // Nepal
    'ZA': 'ZAR', // South Africa
    'NG': 'NGN', // Nigeria
    'KE': 'KES', // Kenya
    'EG': 'EGP', // Egypt
    'SA': 'SAR', // Saudi Arabia
    'QA': 'QAR', // Qatar
    'KW': 'KWD', // Kuwait
    'BH': 'BHD', // Bahrain
    'OM': 'OMR', // Oman
    'JO': 'JOD', // Jordan
    'LB': 'LBP', // Lebanon
    'IL': 'ILS', // Israel
    'TR': 'TRY', // Turkey
    'PL': 'PLN', // Poland
    'CZ': 'CZK', // Czech Republic
    'HU': 'HUF', // Hungary
    'RO': 'RON', // Romania
    'BG': 'BGN', // Bulgaria
    'UA': 'UAH', // Ukraine
    'SE': 'SEK', // Sweden
    'NO': 'NOK', // Norway
    'DK': 'DKK', // Denmark
    'NZ': 'NZD', // New Zealand
    'AR': 'ARS', // Argentina
    'CL': 'CLP', // Chile
    'CO': 'COP', // Colombia
    'PE': 'PEN', // Peru
  };
}
