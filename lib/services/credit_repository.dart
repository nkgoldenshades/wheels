import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

import '../models/credit_transaction.dart';
import 'auth_repository.dart';

/// Manages user credit balance, purchases, and usage.
/// Follows singleton pattern consistent with other repositories.
class CreditRepository {
  CreditRepository._();

  static final CreditRepository instance = CreditRepository._();

  static const _storageKey = 'credit_balance';
  static const _transactionsKey = 'credit_transactions';

  final ValueNotifier<int> creditBalance = ValueNotifier<int>(0);
  final ValueNotifier<List<CreditTransaction>> transactions =
      ValueNotifier<List<CreditTransaction>>([]);

  Future<void> init() async {
    await _load();
    _listenToAuthChanges();
  }

  /// Listen to auth changes and refresh credits when user changes
  void _listenToAuthChanges() {
    AuthRepository.instance.currentUserListenable.addListener(() async {
      await refreshFromSupabase();
    });
  }

  /// Refresh credits from Supabase (source of truth)
  Future<void> refreshFromSupabase() async {
    try {
      final authUser = AuthRepository.instance.currentUser;
      if (authUser == null) {
        creditBalance.value = 0;
        transactions.value = [];
        return;
      }

      final supabase = Supabase.instance.client;

      // Get current credit balance from profiles_private
      final profileResponse = await supabase
          .from('profiles_private')
          .select('ai_credits_available')
          .eq('profile_id', authUser.id)
          .maybeSingle();

      if (profileResponse != null) {
        creditBalance.value =
            profileResponse['ai_credits_available'] as int? ?? 0;
      }

      // Get transaction history
      final txnResponse = await supabase
          .from('credit_transactions')
          .select()
          .eq('user_id', authUser.id)
          .order('created_at', ascending: false)
          .limit(100);

      transactions.value = (txnResponse as List)
          .map((e) => CreditTransaction.fromJson(e as Map<String, dynamic>))
          .toList();

      await _persist();
    } catch (e) {
      debugPrint('❌ [CreditRepository] refreshFromSupabase error: $e');
    }
  }

  /// Load credits from local storage (cache)
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load balance
      final balanceStr = prefs.getString(_storageKey);
      if (balanceStr != null) {
        creditBalance.value = int.tryParse(balanceStr) ?? 0;
      }

      // Load transactions
      final txnStr = prefs.getString(_transactionsKey);
      if (txnStr != null) {
        try {
          final List<dynamic> decoded = jsonDecode(txnStr);
          transactions.value = decoded
              .map((e) => CreditTransaction.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (_) {
          transactions.value = [];
        }
      }
    } catch (e) {
      debugPrint('⚠️ [CreditRepository] _load error: $e');
    }
  }

  /// Persist to local storage (cache for offline access)
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save balance
      await prefs.setString(_storageKey, creditBalance.value.toString());

      // Save transactions
      final txnJson = jsonEncode(
        transactions.value.map((e) => e.toJson()).toList(),
      );
      await prefs.setString(_transactionsKey, txnJson);
    } catch (e) {
      debugPrint('⚠️ [CreditRepository] _persist error: $e');
    }
  }

  /// Deduct credits for AI message usage
  /// Returns true if enough credits available, false otherwise
  Future<bool> deductCredits({
    required int inputTokens,
    required int outputTokens,
    String? relatedBookingId,
    String? conversationId,
  }) async {
    try {
      final authUser = AuthRepository.instance.currentUser;
      if (authUser == null) {
        debugPrint('❌ [CreditRepository] No authenticated user');
        return false;
      }

      // Calculate cost in credits
      // Gemini pricing: $0.30 per 1M input tokens, $2.50 per 1M output tokens
      // 1 credit = $0.06, so cost = (tokens * price) / 1_000_000 / 0.06
      const double inputPrice = 0.30 / 1_000_000 / 0.06;
      const double outputPrice = 2.50 / 1_000_000 / 0.06;

      final creditsCost =
          (inputTokens * inputPrice + outputTokens * outputPrice).ceil();

      // Check balance
      if (creditBalance.value < creditsCost) {
        debugPrint(
          '❌ [CreditRepository] Insufficient credits: have ${creditBalance.value}, need $creditsCost',
        );
        return false;
      }

      // Deduct locally first (optimistic update)
      creditBalance.value -= creditsCost;

      // Record transaction
      final transaction = CreditTransaction(
        id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
        userId: authUser.id,
        type: 'usage',
        creditsChanged: -creditsCost,
        description: 'AI message',
        relatedBookingId: relatedBookingId,
        createdAt: DateTime.now(),
        metadata: {
          'input_tokens': inputTokens,
          'output_tokens': outputTokens,
          'input_price': inputPrice,
          'output_price': outputPrice,
          if (conversationId != null) 'conversation_id': conversationId,
        },
      );

      transactions.value.insert(0, transaction);
      await _persist();

      // Sync to Supabase (fire-and-forget, don't fail if network down)
      _syncDeductionToSupabase(
        userId: authUser.id,
        creditsCost: creditsCost,
        transaction: transaction,
      );

      return true;
    } catch (e) {
      debugPrint('❌ [CreditRepository] deductCredits error: $e');
      return false;
    }
  }

  /// Sync credit deduction to Supabase
  Future<void> _syncDeductionToSupabase({
    required String userId,
    required int creditsCost,
    required CreditTransaction transaction,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // Decrease balance in profiles_private
      await supabase
          .from('profiles_private')
          .update({
            'ai_credits_available': creditBalance
                .value, // Could also use SQL: ai_credits_available - creditsCost
          })
          .eq('profile_id', userId);

      // Record transaction
      await supabase.from('credit_transactions').insert({
        'id': transaction.id,
        'user_id': userId,
        'type': transaction.type,
        'credits_changed': transaction.creditsChanged,
        'description': transaction.description,
        'related_booking_id': transaction.relatedBookingId,
        'created_at': transaction.createdAt.toIso8601String(),
        'metadata': transaction.metadata,
      });

      debugPrint('✅ [CreditRepository] Deduction synced: $creditsCost credits');
    } catch (e) {
      debugPrint('⚠️ [CreditRepository] Sync deduction failed: $e');
      // Don't throw - allow app to continue with local state
    }
  }

  /// Check if user has enough credits
  bool hasEnoughCredits({required int inputTokens, required int outputTokens}) {
    const double inputPrice = 0.30 / 1_000_000 / 0.06;
    const double outputPrice = 2.50 / 1_000_000 / 0.06;
    final creditsCost = (inputTokens * inputPrice + outputTokens * outputPrice)
        .ceil();
    return creditBalance.value >= creditsCost;
  }

  /// Check if user has sufficient credits before sending AI message
  /// Returns true if balance >= estimatedCredits
  Future<bool> hasEnoughCreditsForAI({required int estimatedCredits}) async {
    return creditBalance.value >= estimatedCredits;
  }

  /// Estimate credit cost based on message length
  /// Returns estimated credits needed (conservative estimate)
  static int estimateCreditCostForMessage(String message) {
    // Conservative estimate: always use at least 1 credit
    // to account for AI response generation
    // Actual cost will be calculated after getting token counts from API
    return 1; // Safe default for display purposes
  }

  /// Get cost estimate for specific token counts
  /// Used for displaying predicted cost to user
  static int estimateCreditCostForTokens({
    required int inputTokens,
    required int outputTokens,
  }) {
    // Gemini pricing: $0.30 per 1M input, $2.50 per 1M output
    // 1 credit = $0.06
    // cost = (inputTokens * 0.30 + outputTokens * 2.50) / 1_000_000 / 0.06
    const double inputPrice = 0.30 / 1_000_000 / 0.06;
    const double outputPrice = 2.50 / 1_000_000 / 0.06;
    return ((inputTokens * inputPrice) + (outputTokens * outputPrice)).ceil();
  }

  /// Record a credit purchase (called after successful payment)
  Future<void> recordPurchase({
    required int credits,
    required double amountUSD,
    required String paymentGatewayId,
  }) async {
    try {
      final authUser = AuthRepository.instance.currentUser;
      if (authUser == null) {
        throw 'No authenticated user';
      }

      // Add credits locally (optimistic update)
      creditBalance.value += credits;

      // Record transaction
      final transaction = CreditTransaction(
        id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
        userId: authUser.id,
        type: 'purchase',
        creditsChanged: credits,
        amountUSD: amountUSD,
        paymentGatewayId: paymentGatewayId,
        createdAt: DateTime.now(),
      );

      transactions.value.insert(0, transaction);
      await _persist();

      // Sync to Supabase
      _syncPurchaseToSupabase(
        userId: authUser.id,
        credits: credits,
        transaction: transaction,
      );
    } catch (e) {
      debugPrint('❌ [CreditRepository] recordPurchase error: $e');
      rethrow;
    }
  }

  /// Sync purchase to Supabase
  Future<void> _syncPurchaseToSupabase({
    required String userId,
    required int credits,
    required CreditTransaction transaction,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // Increase balance
      await supabase
          .from('profiles_private')
          .update({'ai_credits_available': creditBalance.value})
          .eq('profile_id', userId);

      // Record transaction
      await supabase.from('credit_transactions').insert({
        'id': transaction.id,
        'user_id': userId,
        'type': transaction.type,
        'credits_changed': transaction.creditsChanged,
        'amount_usd': transaction.amountUSD,
        'payment_gateway_id': transaction.paymentGatewayId,
        'created_at': transaction.createdAt.toIso8601String(),
      });

      debugPrint('✅ [CreditRepository] Purchase synced: +$credits credits');
    } catch (e) {
      debugPrint('⚠️ [CreditRepository] Sync purchase failed: $e');
    }
  }

  /// Add bonus credits (e.g., on signup)
  Future<void> addBonusCredits({
    required int credits,
    String? description,
  }) async {
    try {
      final authUser = AuthRepository.instance.currentUser;
      if (authUser == null) return;

      // Add credits locally
      creditBalance.value += credits;

      // Record transaction
      final transaction = CreditTransaction(
        id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
        userId: authUser.id,
        type: 'bonus',
        creditsChanged: credits,
        description: description ?? 'Bonus credits',
        createdAt: DateTime.now(),
      );

      transactions.value.insert(0, transaction);
      await _persist();

      // Sync to Supabase
      _syncBonusToSupabase(
        userId: authUser.id,
        credits: credits,
        transaction: transaction,
      );
    } catch (e) {
      debugPrint('❌ [CreditRepository] addBonusCredits error: $e');
    }
  }

  /// Sync bonus to Supabase
  Future<void> _syncBonusToSupabase({
    required String userId,
    required int credits,
    required CreditTransaction transaction,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase
          .from('profiles_private')
          .update({'ai_credits_available': creditBalance.value})
          .eq('profile_id', userId);

      await supabase.from('credit_transactions').insert({
        'id': transaction.id,
        'user_id': userId,
        'type': transaction.type,
        'credits_changed': transaction.creditsChanged,
        'description': transaction.description,
        'created_at': transaction.createdAt.toIso8601String(),
      });
    } catch (e) {
      debugPrint('⚠️ [CreditRepository] Sync bonus failed: $e');
    }
  }

  /// Get credit cost estimate for tokens
  static int estimateCreditCost({
    required int inputTokens,
    required int outputTokens,
  }) {
    const double inputPrice = 0.30 / 1_000_000 / 0.06;
    const double outputPrice = 2.50 / 1_000_000 / 0.06;
    return (inputTokens * inputPrice + outputTokens * outputPrice).ceil();
  }
}
