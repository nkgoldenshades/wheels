import 'package:flutter/foundation.dart';

/// Service to manage subscription pricing
/// Uses hardcoded pricing data instead of database queries
class PricingService {
  PricingService._();
  static final PricingService instance = PricingService._();

  // Hardcoded subscription pricing by currency
  static const Map<String, Map<String, dynamic>> _pricingData = {
    'INR': {
      'symbol': '₹',
      'premium': 999,
      'expert': 4999,
      'deposit': 50000,
      'tier': 2,
      'country': 'India',
      'continent': 'Asia',
    },
    'USD': {
      'symbol': '\$',
      'premium': 12.99,
      'expert': 64.99,
      'deposit': 650,
      'tier': 2,
      'country': 'United States',
      'continent': 'North America',
    },
    'EUR': {
      'symbol': '€',
      'premium': 11.99,
      'expert': 59.99,
      'deposit': 600,
      'tier': 2,
      'country': 'Europe',
      'continent': 'Europe',
    },
    'GBP': {
      'symbol': '£',
      'premium': 10.99,
      'expert': 54.99,
      'deposit': 550,
      'tier': 2,
      'country': 'United Kingdom',
      'continent': 'Europe',
    },
    'AUD': {
      'symbol': 'A\$',
      'premium': 19.99,
      'expert': 99.99,
      'deposit': 1000,
      'tier': 2,
      'country': 'Australia',
      'continent': 'Oceania',
    },
    'JPY': {
      'symbol': '¥',
      'premium': 1999,
      'expert': 9999,
      'deposit': 99000,
      'tier': 2,
      'country': 'Japan',
      'continent': 'Asia',
    },
    'CAD': {
      'symbol': 'C\$',
      'premium': 17.99,
      'expert': 89.99,
      'deposit': 900,
      'tier': 2,
      'country': 'Canada',
      'continent': 'North America',
    },
    'CHF': {
      'symbol': 'CHF',
      'premium': 11.99,
      'expert': 59.99,
      'deposit': 580,
      'tier': 2,
      'country': 'Switzerland',
      'continent': 'Europe',
    },
    'CNY': {
      'symbol': '¥',
      'premium': 99,
      'expert': 499,
      'deposit': 5000,
      'tier': 2,
      'country': 'China',
      'continent': 'Asia',
    },
    'SEK': {
      'symbol': 'kr',
      'premium': 129,
      'expert': 649,
      'deposit': 6500,
      'tier': 2,
      'country': 'Sweden',
      'continent': 'Europe',
    },
    'NZD': {
      'symbol': 'NZ\$',
      'premium': 21.99,
      'expert': 109.99,
      'deposit': 1100,
      'tier': 2,
      'country': 'New Zealand',
      'continent': 'Oceania',
    },
    'MXN': {
      'symbol': '\$',
      'premium': 219,
      'expert': 1099,
      'deposit': 11000,
      'tier': 2,
      'country': 'Mexico',
      'continent': 'North America',
    },
    'SGD': {
      'symbol': 'S\$',
      'premium': 17.99,
      'expert': 89.99,
      'deposit': 900,
      'tier': 2,
      'country': 'Singapore',
      'continent': 'Asia',
    },
    'HKD': {
      'symbol': 'HK\$',
      'premium': 99,
      'expert': 499,
      'deposit': 5000,
      'tier': 2,
      'country': 'Hong Kong',
      'continent': 'Asia',
    },
    'THB': {
      'symbol': '฿',
      'premium': 449,
      'expert': 2249,
      'deposit': 22500,
      'tier': 2,
      'country': 'Thailand',
      'continent': 'Asia',
    },
    'AED': {
      'symbol': 'د.إ',
      'premium': 49,
      'expert': 249,
      'deposit': 2500,
      'tier': 2,
      'country': 'UAE',
      'continent': 'Asia',
    },
    'SAR': {
      'symbol': '﷼',
      'premium': 49,
      'expert': 249,
      'deposit': 2500,
      'tier': 2,
      'country': 'Saudi Arabia',
      'continent': 'Asia',
    },
    'ZAR': {
      'symbol': 'R',
      'premium': 219,
      'expert': 1099,
      'deposit': 11000,
      'tier': 2,
      'country': 'South Africa',
      'continent': 'Africa',
    },
    'BRL': {
      'symbol': 'R\$',
      'premium': 59,
      'expert': 299,
      'deposit': 3000,
      'tier': 2,
      'country': 'Brazil',
      'continent': 'South America',
    },
    'PLN': {
      'symbol': 'zł',
      'premium': 49,
      'expert': 249,
      'deposit': 2500,
      'tier': 2,
      'country': 'Poland',
      'continent': 'Europe',
    },
    'TRY': {
      'symbol': '₺',
      'premium': 399,
      'expert': 1999,
      'deposit': 20000,
      'tier': 2,
      'country': 'Turkey',
      'continent': 'Europe',
    },
    'KRW': {
      'symbol': '₩',
      'premium': 16999,
      'expert': 84999,
      'deposit': 850000,
      'tier': 2,
      'country': 'South Korea',
      'continent': 'Asia',
    },
    'ILS': {
      'symbol': '₪',
      'premium': 49,
      'expert': 249,
      'deposit': 2500,
      'tier': 2,
      'country': 'Israel',
      'continent': 'Asia',
    },
    'NOK': {
      'symbol': 'kr',
      'premium': 129,
      'expert': 649,
      'deposit': 6500,
      'tier': 2,
      'country': 'Norway',
      'continent': 'Europe',
    },
    'DKK': {
      'symbol': 'kr',
      'premium': 89,
      'expert': 449,
      'deposit': 4500,
      'tier': 2,
      'country': 'Denmark',
      'continent': 'Europe',
    },
  };

  /// Get pricing for a specific currency
  /// Returns hardcoded pricing, defaults to INR if currency not found
  Future<Map<String, dynamic>> getPricing(String currency) async {
    final curr = currency.toUpperCase();

    if (_pricingData.containsKey(curr)) {
      debugPrint('[PricingService] ✅ Returning pricing for $curr');
      return _pricingData[curr]!;
    }

    debugPrint(
      '[PricingService] ⚠️ Currency $curr not found, falling back to INR',
    );
    return _getDefaultPricing();
  }

  /// Preload pricing for multiple currencies (not needed with hardcoded data)
  Future<void> preloadPricing(List<String> currencies) async {
    debugPrint(
      '[PricingService] Pricing preloaded for ${_pricingData.length} currencies',
    );
  }

  /// Get all available currencies and their pricing
  List<Map<String, dynamic>> getAllPricing() {
    debugPrint(
      '[PricingService] Returning all ${_pricingData.length} currencies',
    );
    return _pricingData.values.toList();
  }

  /// Get pricing by continent (for reference only)
  List<Map<String, dynamic>> getPricingByContinent(String continent) {
    final filtered = _pricingData.entries
        .where((e) => e.value['continent'] == continent)
        .map((e) => e.value)
        .toList();

    debugPrint(
      '[PricingService] Found ${filtered.length} currencies for $continent',
    );
    return filtered;
  }

  /// Get pricing by tier (for reference only)
  List<Map<String, dynamic>> getPricingByTier(int tier) {
    final filtered = _pricingData.entries
        .where((e) => e.value['tier'] == tier)
        .map((e) => e.value)
        .toList();

    debugPrint(
      '[PricingService] Found ${filtered.length} currencies for tier $tier',
    );
    return filtered;
  }

  /// Get default pricing (INR - fallback)
  Map<String, dynamic> _getDefaultPricing() {
    return {
      'symbol': '₹',
      'premium': 999,
      'expert': 4999,
      'deposit': 50000,
      'tier': 2,
      'country': 'India',
      'continent': 'Asia',
    };
  }

  /// Get available currencies
  List<String> getAvailableCurrencies() {
    return _pricingData.keys.toList();
  }

  /// Exchange rates relative to USD (1 USD = X)
  /// Used for converting credit package prices
  /// Covers 135+ Stripe-supported currencies
  static const Map<String, double> _exchangeRates = {
    // Major currencies
    'USD': 1.0, // United States Dollar
    'EUR': 0.92, // Euro
    'GBP': 0.79, // British Pound
    'JPY': 149.50, // Japanese Yen
    'CHF': 0.88, // Swiss Franc
    'CNY': 7.24, // Chinese Yuan
    'INR': 83.0, // Indian Rupee
    'AUD': 1.51, // Australian Dollar
    'CAD': 1.36, // Canadian Dollar
    'SGD': 1.33, // Singapore Dollar
    'HKD': 7.78, // Hong Kong Dollar
    'NZD': 1.63, // New Zealand Dollar
    'SEK': 10.50, // Swedish Krona
    'NOK': 10.58, // Norwegian Krone
    'DKK': 6.85, // Danish Krone
    'ZAR': 18.50, // South African Rand
    'MXN': 17.05, // Mexican Peso
    'BRL': 4.97, // Brazilian Real
    'RUB': 96.50, // Russian Ruble (approximate)
    'KRW': 1319.0, // South Korean Won
    'AED': 3.67, // UAE Dirham
    'SAR': 3.75, // Saudi Arabian Riyal
    'QAR': 3.64, // Qatari Riyal
    'KWD': 0.31, // Kuwaiti Dinar
    'BHD': 0.376, // Bahraini Dinar
    'OMR': 0.385, // Omani Rial
    'JOD': 0.709, // Jordanian Dinar
    'EGP': 30.50, // Egyptian Pound
    'PKR': 278.0, // Pakistani Rupee
    'BDT': 117.0, // Bangladeshi Taka
    'LKR': 303.0, // Sri Lankan Rupee
    'NPR': 132.50, // Nepalese Rupee
    'THB': 35.50, // Thai Baht
    'MYR': 4.75, // Malaysian Ringgit
    'IDR': 16050.0, // Indonesian Rupiah
    'PHP': 56.50, // Philippine Peso
    'VND': 24650.0, // Vietnamese Dong
    'TRY': 32.50, // Turkish Lira
    'PLN': 3.97, // Polish Zloty
    'CZK': 23.50, // Czech Koruna
    'HUF': 360.0, // Hungarian Forint
    'RON': 4.57, // Romanian Leu
    'BGN': 1.80, // Bulgarian Lev
    'HRK': 6.93, // Croatian Kuna
    'ISK': 134.0, // Icelandic Króna
    'ILS': 3.65, // Israeli Shekel
    'CLP': 950.0, // Chilean Peso
    'COP': 3985.0, // Colombian Peso
    'PEN': 3.75, // Peruvian Sol
    'UYU': 39.50, // Uruguayan Peso
    'PYG': 7380.0, // Paraguayan Guaraní
    'ARS': 820.0, // Argentine Peso
    'GHS': 12.50, // Ghanaian Cedi
    'KES': 130.0, // Kenyan Shilling
    'NGN': 1550.0, // Nigerian Naira
    'HNL': 24.65, // Honduran Lempira
    'CRC': 520.0, // Costa Rican Colón
    'GTQ': 7.75, // Guatemalan Quetzal
    'VEF': 2850.0, // Venezuelan Bolívar
    'TTD': 6.80, // Trinidad and Tobago Dollar
    'JMD': 155.0, // Jamaican Dollar
    'DZD': 134.0, // Algerian Dinar
    'TND': 3.16, // Tunisian Dinar
    'MAD': 9.80, // Moroccan Dirham
    'BZD': 2.02, // Belize Dollar
    'SVC': 8.75, // Salvadoran Colón
    'BSD': 1.0, // Bahamian Dollar
    'BBD': 2.0, // Barbadian Dollar
    'BMD': 1.0, // Bermudian Dollar
    'KYD': 0.835, // Caymanian Dollar
    'GYD': 209.0, // Guyanese Dollar
    'MUR': 43.50, // Mauritian Rupee
    'SCR': 13.40, // Seychellois Rupee
    'UAH': 41.50, // Ukrainian Hryvnia
    'BYN': 3.28, // Belarusian Ruble
    'KZT': 433.0, // Kazakhstani Tenge
    'GEL': 2.68, // Georgian Lari
    'AMD': 387.0, // Armenian Dram
    'AZN': 1.70, // Azerbaijani Manat
    'KGS': 86.0, // Kyrgyzstani Som
    'TJS': 10.70, // Tajikistani Somoni
    'UZS': 12950.0, // Uzbekistani Som
    'TMT': 3.50, // Turkmenistani Manat
    'AFN': 71.0, // Afghan Afghani
    'MVR': 15.45, // Maldivian Rufiyaa
    'XOF': 603.0, // West African CFA Franc
    'XAF': 603.0, // Central African CFA Franc
    'MWK': 1050.0, // Malawian Kwacha
    'ZMW': 26.50, // Zambian Kwacha
    'RWF': 1301.0, // Rwandan Franc
    'ETB': 53.0, // Ethiopian Birr
    'TZS': 2540.0, // Tanzanian Shilling
    'UGX': 3765.0, // Ugandan Shilling
  };

  /// Convert a USD price to the target currency
  /// [usdPrice] - Price in USD
  /// [targetCurrency] - Target currency code (e.g., 'INR', 'EUR')
  /// Returns the converted price rounded appropriately
  double convertPrice(double usdPrice, String targetCurrency) {
    final curr = targetCurrency.toUpperCase();
    final rate = _exchangeRates[curr] ?? 1.0;
    final converted = usdPrice * rate;

    // Round based on currency:
    // INR: round to nearest rupee (no decimals for whole numbers)
    // EUR/GBP: 2 decimals
    // AUD: 2 decimals
    if (curr == 'INR') {
      return converted.roundToDouble();
    } else {
      return (converted * 100).roundToDouble() / 100;
    }
  }

  /// Format a credit package price for display
  /// [creditCount] - Number of credits in the package
  /// [targetCurrency] - Target currency code
  /// Returns: Formatted price string (e.g., "₹150" or "$10.99")
  String formatCreditPrice(int creditCount, String targetCurrency) {
    // Base USD prices for credit packages
    // 50 credits = $3, 200 credits = $10, 1000 credits = $50
    final usdPrices = {50: 3.0, 200: 10.0, 1000: 50.0};

    if (!usdPrices.containsKey(creditCount)) {
      debugPrint(
        '⚠️ Credit package $creditCount not found, using default pricing',
      );
      return 'Custom';
    }

    final usdPrice = usdPrices[creditCount]!;
    final convertedPrice = convertPrice(usdPrice, targetCurrency);
    final symbol =
        _pricingData[targetCurrency.toUpperCase()]?['symbol'] ?? '\$';

    // Format based on currency
    if (targetCurrency.toUpperCase() == 'INR') {
      return '$symbol${convertedPrice.toInt()}';
    } else {
      return '$symbol${convertedPrice.toStringAsFixed(2)}';
    }
  }
}
