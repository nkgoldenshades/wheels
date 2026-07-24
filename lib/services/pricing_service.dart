import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to fetch subscription pricing from Supabase database
/// Provides caching to reduce database calls and improve performance
class PricingService {
  PricingService._();
  static final PricingService instance = PricingService._();

  // Cache pricing data for 1 hour to reduce database calls
  static final Map<String, Map<String, dynamic>> _cache = {};
  static DateTime? _lastFetch;
  static const Duration _cacheDuration = Duration(hours: 1);

  /// Get pricing for a specific currency from database
  /// Falls back to hardcoded default if database fails
  Future<Map<String, dynamic>> getPricing(String currency) async {
    final curr = currency.toUpperCase();

    // Check cache first
    if (_isCacheValid() && _cache.containsKey(curr)) {
      debugPrint('[PricingService] Using cached pricing for $curr');
      return _cache[curr]!;
    }

    // Fetch from database
    try {
      debugPrint('[PricingService] Fetching pricing for $curr from database');
      final response = await Supabase.instance.client
          .from('subscription_pricing')
          .select()
          .eq('currency_code', curr)
          .eq('is_active', true)
          .single()
          .timeout(const Duration(seconds: 5));

      final pricing = {
        'symbol': response['currency_symbol'] as String,
        'premium': (response['premium_monthly'] as num).toDouble(),
        'expert': (response['expert_monthly'] as num).toDouble(),
        'deposit': (response['expert_deposit'] as num).toDouble(),
        'tier': response['tier'] as int,
        'country': response['country_name'] as String?,
        'continent': response['continent'] as String?,
      };

      // Update cache
      _cache[curr] = pricing;
      _lastFetch = DateTime.now();

      debugPrint(
        '[PricingService] ✅ Fetched pricing for $curr: ${pricing['symbol']}${pricing['premium']}',
      );
      return pricing;
    } catch (e) {
      debugPrint('[PricingService] ⚠️ Database fetch failed for $curr: $e');
      debugPrint('[PricingService] Falling back to default USD Tier 1 pricing');

      // Fallback to default USD Tier 1 pricing
      return _getDefaultPricing();
    }
  }

  /// Preload pricing for multiple currencies (useful for app startup)
  Future<void> preloadPricing(List<String> currencies) async {
    debugPrint(
      '[PricingService] Preloading pricing for ${currencies.length} currencies',
    );

    try {
      final response = await Supabase.instance.client
          .from('subscription_pricing')
          .select()
          .inFilter(
            'currency_code',
            currencies.map((c) => c.toUpperCase()).toList(),
          )
          .eq('is_active', true)
          .timeout(const Duration(seconds: 10));

      for (final row in response as List<dynamic>) {
        final curr = row['currency_code'] as String;
        _cache[curr] = {
          'symbol': row['currency_symbol'] as String,
          'premium': (row['premium_monthly'] as num).toDouble(),
          'expert': (row['expert_monthly'] as num).toDouble(),
          'deposit': (row['expert_deposit'] as num).toDouble(),
          'tier': row['tier'] as int,
          'country': row['country_name'] as String?,
          'continent': row['continent'] as String?,
        };
      }

      _lastFetch = DateTime.now();
      debugPrint('[PricingService] ✅ Preloaded ${_cache.length} currencies');
    } catch (e) {
      debugPrint('[PricingService] ⚠️ Preload failed: $e');
    }
  }

  /// Get all pricing data (for admin panel or analytics)
  Future<List<Map<String, dynamic>>> getAllPricing() async {
    try {
      final response = await Supabase.instance.client
          .from('subscription_pricing')
          .select()
          .eq('is_active', true)
          .order('continent')
          .order('tier')
          .order('country_name')
          .timeout(const Duration(seconds: 10));

      return (response as List<dynamic>)
          .map(
            (row) => {
              'currency_code': row['currency_code'] as String,
              'currency_symbol': row['currency_symbol'] as String,
              'country_name': row['country_name'] as String?,
              'continent': row['continent'] as String?,
              'tier': row['tier'] as int,
              'premium_monthly': (row['premium_monthly'] as num).toDouble(),
              'expert_monthly': (row['expert_monthly'] as num).toDouble(),
              'expert_deposit': (row['expert_deposit'] as num).toDouble(),
            },
          )
          .toList();
    } catch (e) {
      debugPrint('[PricingService] ⚠️ Failed to fetch all pricing: $e');
      return [];
    }
  }

  /// Get pricing by continent (useful for regional analysis)
  Future<List<Map<String, dynamic>>> getPricingByContinent(
    String continent,
  ) async {
    try {
      final response = await Supabase.instance.client
          .from('subscription_pricing')
          .select()
          .eq('continent', continent)
          .eq('is_active', true)
          .order('tier')
          .order('country_name')
          .timeout(const Duration(seconds: 5));

      return (response as List<dynamic>)
          .map(
            (row) => {
              'currency_code': row['currency_code'] as String,
              'currency_symbol': row['currency_symbol'] as String,
              'country_name': row['country_name'] as String?,
              'tier': row['tier'] as int,
              'premium_monthly': (row['premium_monthly'] as num).toDouble(),
              'expert_monthly': (row['expert_monthly'] as num).toDouble(),
              'expert_deposit': (row['expert_deposit'] as num).toDouble(),
            },
          )
          .toList();
    } catch (e) {
      debugPrint(
        '[PricingService] ⚠️ Failed to fetch pricing for $continent: $e',
      );
      return [];
    }
  }

  /// Get pricing by tier (useful for analytics)
  Future<List<Map<String, dynamic>>> getPricingByTier(int tier) async {
    try {
      final response = await Supabase.instance.client
          .from('subscription_pricing')
          .select()
          .eq('tier', tier)
          .eq('is_active', true)
          .order('continent')
          .order('country_name')
          .timeout(const Duration(seconds: 5));

      return (response as List<dynamic>)
          .map(
            (row) => {
              'currency_code': row['currency_code'] as String,
              'currency_symbol': row['currency_symbol'] as String,
              'country_name': row['country_name'] as String?,
              'continent': row['continent'] as String?,
              'premium_monthly': (row['premium_monthly'] as num).toDouble(),
              'expert_monthly': (row['expert_monthly'] as num).toDouble(),
              'expert_deposit': (row['expert_deposit'] as num).toDouble(),
            },
          )
          .toList();
    } catch (e) {
      debugPrint(
        '[PricingService] ⚠️ Failed to fetch pricing for tier $tier: $e',
      );
      return [];
    }
  }

  /// Clear cache (useful for forcing refresh)
  void clearCache() {
    _cache.clear();
    _lastFetch = null;
    debugPrint('[PricingService] Cache cleared');
  }

  /// Check if cache is still valid
  bool _isCacheValid() {
    if (_lastFetch == null) return false;
    final age = DateTime.now().difference(_lastFetch!);
    return age < _cacheDuration;
  }

  /// Get default pricing (fallback when database fails)
  Map<String, dynamic> _getDefaultPricing() {
    return {
      'symbol': '₹',
      'premium': 12.99,
      'expert': 59.99,
      'deposit': 599.0,
      'tier': 1,
      'country': 'Default (India)',
      'continent': null,
    };
  }

  /// Get cache statistics (for debugging)
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_currencies': _cache.length,
      'last_fetch': _lastFetch?.toIso8601String(),
      'cache_valid': _isCacheValid(),
      'cache_age_minutes': _lastFetch != null
          ? DateTime.now().difference(_lastFetch!).inMinutes
          : null,
    };
  }
}
