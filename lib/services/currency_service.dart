import 'dart:io';
import 'package:flutter/material.dart';

class CurrencyService {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  // Currency mapping based on country codes
  static const Map<String, String> _countryCurrencyMap = {
    'US': 'USD',
    'IN': 'INR',
    'GB': 'GBP',
    'CA': 'CAD',
    'AU': 'AUD',
    'DE': 'EUR',
    'FR': 'EUR',
    'IT': 'EUR',
    'ES': 'EUR',
    'NL': 'EUR',
    'JP': 'JPY',
    'CN': 'CNY',
    'KR': 'KRW',
    'BR': 'BRL',
    'MX': 'MXN',
    'SG': 'SGD',
    'HK': 'HKD',
    'AE': 'AED',
    'SA': 'SAR',
    'ZA': 'ZAR',
    'NG': 'NGN',
    'EG': 'EGP',
    'PK': 'PKR',
    'BD': 'BDT',
    'LK': 'LKR',
    'NP': 'NPR',
    'MY': 'MYR',
    'TH': 'THB',
    'ID': 'IDR',
    'PH': 'PHP',
    'VN': 'VND',
  };

  // Currency symbols for display
  static const Map<String, String> _currencySymbols = {
    'USD': '\$',
    'INR': '₹',
    'GBP': '£',
    'EUR': '€',
    'CAD': 'C\$',
    'AUD': 'A\$',
    'JPY': '¥',
    'CNY': '¥',
    'KRW': '₩',
    'BRL': 'R\$',
    'MXN': '\$',
    'SGD': 'S\$',
    'HKD': 'HK\$',
    'AED': 'د.إ',
    'SAR': '﷼',
    'ZAR': 'R',
    'NGN': '₦',
    'EGP': '£',
    'PKR': '₨',
    'BDT': '৳',
    'LKR': '₨',
    'NPR': '₨',
    'MYR': 'RM',
    'THB': '฿',
    'IDR': 'Rp',
    'PHP': '₱',
    'VND': '₫',
  };

  /// Get currency code based on device locale
  String getDeviceCurrency() {
    // Force USD for all users (international app)
    return 'USD';
    
    /* Original multi-currency code (disabled):
    try {
      // Get device locale
      final locale = Platform.localeName; // e.g., "en_US", "hi_IN"
      final countryCode = locale.split('_').last; // Extract country code
      
      // Return currency for country, default to USD
      return _countryCurrencyMap[countryCode] ?? 'USD';
    } catch (e) {
      debugPrint('Error detecting device currency: $e');
      return 'USD'; // Fallback to USD
    }
    */
  }

  /// Get currency code from Flutter locale (alternative method)
  String getCurrencyFromLocale(Locale locale) {
    // Force USD for all users (international app)
    return 'USD';
    
    /* Original multi-currency code (disabled):
    final countryCode = locale.countryCode?.toUpperCase();
    if (countryCode != null) {
      return _countryCurrencyMap[countryCode] ?? 'USD';
    }
    return 'USD';
    */
  }

  /// Get currency symbol for display
  String getCurrencySymbol(String currencyCode) {
    return _currencySymbols[currencyCode] ?? currencyCode;
  }

  /// Format price with currency symbol
  String formatPrice(double price, String currencyCode) {
    final symbol = getCurrencySymbol(currencyCode);
    
    // Format based on currency
    switch (currencyCode) {
      case 'INR':
        // Indian format: ₹500, ₹1,500, ₹1,50,000
        return '$symbol${_formatIndianNumber(price)}';
      case 'USD':
      case 'CAD':
      case 'AUD':
        // US format: $500, $1,500, $150,000
        return '$symbol${_formatUSNumber(price)}';
      case 'EUR':
        // European format: €500, €1.500, €150.000
        return '$symbol${_formatEuropeanNumber(price)}';
      case 'JPY':
      case 'KRW':
        // No decimal places for these currencies
        return '$symbol${price.toInt()}';
      default:
        return '$symbol${price.toStringAsFixed(2)}';
    }
  }

  String _formatIndianNumber(double number) {
    final parts = number.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    
    if (intPart.length <= 3) {
      return decPart == '00' ? intPart : '$intPart.$decPart';
    }
    
    // Indian numbering system: 1,23,45,678
    String result = '';
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count == 3 || (count > 3 && (count - 3) % 2 == 0)) {
        result = ',$result';
      }
      result = intPart[i] + result;
      count++;
    }
    
    return decPart == '00' ? result : '$result.$decPart';
  }

  String _formatUSNumber(double number) {
    final parts = number.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    
    // US numbering system: 1,234,567
    String result = '';
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        result += ',';
      }
      result += intPart[i];
    }
    
    return decPart == '00' ? result : '$result.$decPart';
  }

  String _formatEuropeanNumber(double number) {
    final parts = number.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    
    // European numbering system: 1.234.567,00
    String result = '';
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        result += '.';
      }
      result += intPart[i];
    }
    
    return decPart == '00' ? result : '$result,$decPart';
  }

  /// Get list of supported currencies for manual selection
  List<Map<String, String>> getSupportedCurrencies() {
    return _countryCurrencyMap.entries.map((entry) {
      final currencyCode = entry.value;
      final symbol = getCurrencySymbol(currencyCode);
      return {
        'code': currencyCode,
        'symbol': symbol,
        'display': '$currencyCode ($symbol)',
      };
    }).toSet().toList()..sort((a, b) => a['code']!.compareTo(b['code']!));
  }

  /// Check if currency requires decimal places
  bool requiresDecimals(String currencyCode) {
    return !['JPY', 'KRW', 'VND'].contains(currencyCode);
  }
}