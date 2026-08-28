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

  // ✅ Pricing Configuration - TWO SEPARATE PRICES
  // Raw token calculation: What Gemini actually costs us
  static const double rawTokenCreditPrice =
      0.06; // $0.06 per credit = raw Gemini cost

  // Credit purchase price: What users pay
  static const double purchaseCreditPrice =
      0.10; // $0.10 per credit = purchase price (markup included)

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
        // Guest users get 0 credits - must login for AI access
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

      // Get transaction history from ai_conversations.aiinfra JSONB column
      // This replaces the old credit_transactions table approach
      final conversationsResponse = await supabase
          .from('ai_conversations')
          .select('aiinfra, created_at')
          .eq('user_id', authUser.id)
          .order('created_at', ascending: false)
          .limit(100);

      // Parse transactions from aiinfra JSONB
      final txnList = <CreditTransaction>[];
      for (final conv in (conversationsResponse as List)) {
        final aiinfra = conv['aiinfra'] as Map<String, dynamic>?;
        if (aiinfra != null && aiinfra['transactions'] is List) {
          for (final txn in aiinfra['transactions']) {
            try {
              txnList.add(
                CreditTransaction.fromJson(txn as Map<String, dynamic>),
              );
            } catch (e) {
              debugPrint('⚠️ Failed to parse transaction: $e');
            }
          }
        }
      }

      transactions.value = txnList;
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

      // Calculate cost in credits with sustainable pricing
      // Gemini pricing: $0.30 per 1M input tokens, $2.50 per 1M output tokens
      // Use rawTokenCreditPrice ($0.06) for actual cost calculation
      const double inputPrice = 0.30 / 1_000_000 / rawTokenCreditPrice;
      const double outputPrice = 2.50 / 1_000_000 / rawTokenCreditPrice;

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
          'conversation_id': ?conversationId,
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
    const double inputPrice = 0.30 / 1_000_000 / rawTokenCreditPrice;
    const double outputPrice = 2.50 / 1_000_000 / rawTokenCreditPrice;
    final creditsCost = (inputTokens * inputPrice + outputTokens * outputPrice)
        .ceil();
    return creditBalance.value >= creditsCost;
  }

  /// Check if user has sufficient credits before sending AI message
  /// Returns true if balance >= estimatedCredits
  Future<bool> hasEnoughCreditsForAI({required double estimatedCredits}) async {
    return creditBalance.value >= estimatedCredits;
  }

  /// Estimate credit cost based on message length (raw token pricing, no rounding)
  /// Returns estimated credits as raw decimal value
  /// Includes memory markup: Full=5x, Thread=3x, Chat=2x, None=1x
  static double estimateCreditCostForMessage(
    String message, {
    bool threadMemory = false,
    bool chatMemory = false,
  }) {
    // Estimate tokens: ~1.3 tokens per word
    // Plus ~100 tokens for AI response generation
    final estimatedInputTokens = (message.split(' ').length * 1.3);
    const estimatedOutputTokens = 100.0; // Conservative estimate for response

    // Step 1: Calculate raw API cost in USD
    // Gemini pricing: $0.30 per 1M input, $2.50 per 1M output
    const double inputPriceUSD = 0.30 / 1_000_000;
    const double outputPriceUSD = 2.50 / 1_000_000;
    double apiCostUSD =
        (estimatedInputTokens * inputPriceUSD) +
        (estimatedOutputTokens * outputPriceUSD);

    // Step 2: Apply memory-based markup to API cost (BEFORE converting to credits)
    // Full memory (Thread + Chat) = 5x
    // Thread only = 3x
    // Chat only = 2x
    // No memory = 1x (raw)
    final markupMultiplier = _getMemoryMarkupMultiplier(
      threadMemory,
      chatMemory,
    );
    final costWithMarkupUSD = apiCostUSD * markupMultiplier;

    // Step 3: Convert USD to credits (using purchaseCreditPrice for user payment)
    final estimatedCost = costWithMarkupUSD / purchaseCreditPrice;

    // Return raw decimal value (no rounding)
    return estimatedCost > 0 ? estimatedCost : 0.0;
  }

  /// Get cost estimate for specific token counts (raw decimal, no rounding)
  /// Used for displaying predicted cost to user
  /// Includes memory-based markup multiplier
  static double estimateCreditCostForTokens({
    required int inputTokens,
    required int outputTokens,
    bool threadMemory = false,
    bool chatMemory = false,
  }) {
    // Gemini pricing: $0.30 per 1M input, $2.50 per 1M output
    // Step 1: Calculate raw API cost in USD
    const double inputPriceUSD = 0.30 / 1_000_000;
    const double outputPriceUSD = 2.50 / 1_000_000;
    double apiCostUSD =
        (inputTokens * inputPriceUSD) + (outputTokens * outputPriceUSD);

    // Step 2: Apply memory-based markup to API cost (BEFORE converting to credits)
    final markupMultiplier = _getMemoryMarkupMultiplier(
      threadMemory,
      chatMemory,
    );
    final costWithMarkupUSD = apiCostUSD * markupMultiplier;

    // Step 3: Convert USD to credits (using purchaseCreditPrice for user payment)
    return costWithMarkupUSD / purchaseCreditPrice;
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

  /// Get credit cost estimate for tokens (raw decimal, no rounding)
  /// Get credit cost estimate for tokens
  /// Formula: (API Cost in USD × Markup) ÷ 0.10 = Credits
  /// Includes memory-based markup multiplier
  static double estimateCreditCost({
    required int inputTokens,
    required int outputTokens,
    bool threadMemory = false,
    bool chatMemory = false,
  }) {
    // Step 1: Calculate raw API cost in USD
    const double inputPriceUSD = 0.30 / 1_000_000;
    const double outputPriceUSD = 2.50 / 1_000_000;
    double apiCostUSD =
        (inputTokens * inputPriceUSD + outputTokens * outputPriceUSD);

    // Step 2: Apply memory-based markup to API cost (BEFORE converting to credits)
    final markupMultiplier = _getMemoryMarkupMultiplier(
      threadMemory,
      chatMemory,
    );
    final costWithMarkupUSD = apiCostUSD * markupMultiplier;

    // Step 3: Convert USD to credits (using purchaseCreditPrice for user payment)
    return costWithMarkupUSD / purchaseCreditPrice;
  }

  /// Helper: Calculate markup multiplier based on memory mode
  /// 🧠 Full (Thread + Chat) = 5x markup
  /// 🧵 Thread only = 3x markup
  /// 💬 Chat only = 2x markup
  /// 🆕 No memory = 1x (raw price)
  static double _getMemoryMarkupMultiplier(bool threadMemory, bool chatMemory) {
    if (threadMemory && chatMemory) {
      return 5.0; // 🧠 Full memory
    } else if (threadMemory) {
      return 3.0; // 🧵 Thread only
    } else if (chatMemory) {
      return 2.0; // 💬 Chat only
    } else {
      return 1.0; // 🆕 No memory (raw)
    }
  }
}
