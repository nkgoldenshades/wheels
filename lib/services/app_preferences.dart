import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SubscriptionPlan { basic, premium, expert }

class AppPreferences {
  AppPreferences._();

  static final AppPreferences instance = AppPreferences._();

  static const _currencyCodeKey = 'currencyCode';
  static const _preferredCountryKey = 'preferredCountry';
  static const _avatarBase64Key = 'avatarBase64';
  static const _subscriptionPlanKey = 'subscriptionPlan';
  static const _subscriptionExpiryKey = 'subscriptionExpiry';
  static const _preferredLanguageKey = 'preferredLanguage';
  static const _razorpayAccountIdKey = 'razorpayAccountId';

  // Multi-currency support enabled
  final ValueNotifier<String> currencyCode = ValueNotifier<String>(
    'INR',
  ); // Default to INR
  final ValueNotifier<String> preferredCountry = ValueNotifier<String>(
    'India', // Default to India
  );
  final ValueNotifier<String> preferredLanguage = ValueNotifier<String>(
    'English',
  );
  final ValueNotifier<String?> avatarBase64 = ValueNotifier<String?>(null);
  final ValueNotifier<SubscriptionPlan> subscriptionPlan =
      ValueNotifier<SubscriptionPlan>(SubscriptionPlan.basic);
  final ValueNotifier<DateTime?> subscriptionExpiry = ValueNotifier<DateTime?>(
    null,
  );
  final ValueNotifier<String?> razorpayAccountId = ValueNotifier<String?>(null);
  final ValueNotifier<bool> stripeEnabled = ValueNotifier<bool>(false);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to INR and India for new users
    currencyCode.value = prefs.getString(_currencyCodeKey) ?? 'INR';

    // Ensure currency code is never null or invalid
    if (currencyCode.value.isEmpty) {
      currencyCode.value = 'INR';
    }

    preferredCountry.value = prefs.getString(_preferredCountryKey) ?? 'India';
    preferredLanguage.value =
        prefs.getString(_preferredLanguageKey) ?? 'English';
    avatarBase64.value = prefs.getString(_avatarBase64Key);
    razorpayAccountId.value = prefs.getString(_razorpayAccountIdKey);

    final planRaw = prefs.getString(_subscriptionPlanKey);
    subscriptionPlan.value = SubscriptionPlan.values.firstWhere(
      (p) => p.name == planRaw,
      orElse: () => SubscriptionPlan.basic,
    );

    final expiryRaw = prefs.getString(_subscriptionExpiryKey);
    if (expiryRaw != null) {
      subscriptionExpiry.value = DateTime.tryParse(expiryRaw);
    }

    // Check if subscription has expired and auto-downgrade to basic
    await _checkAndHandleExpiredSubscription();
  }

  /// Check if current subscription has expired and downgrade to basic if needed
  Future<void> _checkAndHandleExpiredSubscription() async {
    if (subscriptionPlan.value == SubscriptionPlan.basic) return;

    final expiry = subscriptionExpiry.value;
    if (expiry == null) return;

    if (DateTime.now().isAfter(expiry)) {
      // Subscription expired - downgrade to basic
      await setSubscriptionPlan(SubscriptionPlan.basic);
    }
  }

  // Multi-currency support: User can select any currency
  Future<void> setCurrencyCode(String code) async {
    currencyCode.value = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyCodeKey, code);
  }

  Future<void> setPreferredCountry(String country) async {
    preferredCountry.value = country;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferredCountryKey, country);

    // Auto-set currency based on country
    final currency = _countryCurrencyMap[country] ?? 'INR';
    await setCurrencyCode(currency);
  }

  // Country → Currency mapping for international support
  static const Map<String, String> _countryCurrencyMap = {
    'India': 'INR',
    'United States': 'USD',
    'United Kingdom': 'GBP',
    'European Union': 'EUR',
    'UAE': 'AED',
    'Singapore': 'SGD',
    'Australia': 'AUD',
    'Canada': 'CAD',
    'Japan': 'JPY',
    'China': 'CNY',
    'South Korea': 'KRW',
    'Saudi Arabia': 'SAR',
    'Qatar': 'QAR',
    'Kuwait': 'KWD',
    'Bahrain': 'BHD',
    'Oman': 'OMR',
    'Pakistan': 'PKR',
    'Bangladesh': 'BDT',
    'Sri Lanka': 'LKR',
    'Nepal': 'NPR',
    'Thailand': 'THB',
    'Malaysia': 'MYR',
    'Indonesia': 'IDR',
    'Philippines': 'PHP',
    'South Africa': 'ZAR',
    'Nigeria': 'NGN',
    'Kenya': 'KES',
    'Brazil': 'BRL',
    'Mexico': 'MXN',
    'New Zealand': 'NZD',
    'Switzerland': 'CHF',
    'Turkey': 'TRY',
    'Russia': 'RUB',
  };

  Future<void> setPreferredLanguage(String language) async {
    preferredLanguage.value = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferredLanguageKey, language);
  }

  Future<void> setAvatarBase64(String? value) async {
    avatarBase64.value = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      await prefs.remove(_avatarBase64Key);
    } else {
      await prefs.setString(_avatarBase64Key, value);
    }
  }

  Future<void> setRazorpayAccountId(String? accountId) async {
    razorpayAccountId.value = accountId;
    final prefs = await SharedPreferences.getInstance();
    if (accountId == null || accountId.isEmpty) {
      await prefs.remove(_razorpayAccountIdKey);
    } else {
      await prefs.setString(_razorpayAccountIdKey, accountId);
    }
  }

  Future<void> setSubscriptionPlan(SubscriptionPlan plan) async {
    subscriptionPlan.value = plan;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subscriptionPlanKey, plan.name);

    // Set expiry date for paid plans (30 days from now)
    if (plan != SubscriptionPlan.basic) {
      final expiry = DateTime.now().add(const Duration(days: 30));
      subscriptionExpiry.value = expiry;
      await prefs.setString(_subscriptionExpiryKey, expiry.toIso8601String());
    } else {
      subscriptionExpiry.value = null;
      await prefs.remove(_subscriptionExpiryKey);
    }
  }

  String get currencySymbol {
    // Get the correct currency symbol based on selected currency code
    // Don't rely on NumberFormat.simpleCurrency which respects device locale
    final symbols = {
      'INR': '₹',
      'USD': '\$',
      'GBP': '£',
      'EUR': '€',
      'AED': 'د.إ',
      'SGD': 'S\$',
      'AUD': 'A\$',
      'CAD': 'C\$',
      'JPY': '¥',
      'CNY': '¥',
      'HKD': 'HK\$',
      'BRL': 'R\$',
      'MXN': 'MX\$',
    };
    return symbols[currencyCode.value] ?? currencyCode.value;
  }

  String formatMoney(num amount) {
    final fmt = NumberFormat.simpleCurrency(name: currencyCode.value);
    return fmt.format(amount);
  }
}
