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
  static const _preferredLanguageKey = 'preferredLanguage';

  final ValueNotifier<String> currencyCode = ValueNotifier<String>('INR');
  final ValueNotifier<String> preferredCountry = ValueNotifier<String>('India');
  final ValueNotifier<String> preferredLanguage = ValueNotifier<String>('English');
  final ValueNotifier<String?> avatarBase64 = ValueNotifier<String?>(null);
  final ValueNotifier<SubscriptionPlan> subscriptionPlan =
      ValueNotifier<SubscriptionPlan>(SubscriptionPlan.basic);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    currencyCode.value = prefs.getString(_currencyCodeKey) ?? 'INR';
    preferredCountry.value =
        prefs.getString(_preferredCountryKey) ?? preferredCountry.value;
    preferredLanguage.value =
        prefs.getString(_preferredLanguageKey) ?? 'English';
    avatarBase64.value = prefs.getString(_avatarBase64Key);

    final planRaw = prefs.getString(_subscriptionPlanKey);
    subscriptionPlan.value = SubscriptionPlan.values.firstWhere(
      (p) => p.name == planRaw,
      orElse: () => SubscriptionPlan.basic,
    );
  }

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
    final autoCurrency = _countryCurrencyMap[country] ?? 'USD';
    await setCurrencyCode(autoCurrency);

  }

  // Country → Currency mapping
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

  Future<void> setSubscriptionPlan(SubscriptionPlan plan) async {
    subscriptionPlan.value = plan;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subscriptionPlanKey, plan.name);
  }

  String get currencySymbol {
    return NumberFormat.simpleCurrency(name: currencyCode.value).currencySymbol;
  }

  String formatMoney(num amount) {
    final fmt = NumberFormat.simpleCurrency(name: currencyCode.value);
    return fmt.format(amount);
  }
}



