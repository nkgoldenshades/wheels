import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'credit_repository.dart';
import 'auth_repository.dart';

/// Handles credit purchase payments via Stripe.
/// Uses Firebase Cloud Functions for PCI-DSS compliance.
class CreditPaymentService {
  CreditPaymentService._();
  static final CreditPaymentService instance = CreditPaymentService._();

  FirebaseFunctions? _functions;

  void _initFunctions() {
    if (_functions == null) {
      try {
        _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      } catch (e) {
        debugPrint(
          '[CreditPaymentService] Failed to init Firebase Functions: $e',
        );
      }
    }
  }

  /// Create a Stripe payment intent for credit purchase.
  /// Returns a map with 'clientSecret' for use with Stripe Flutter SDK.
  ///
  /// Arguments:
  /// - amountCents: Amount in cents (e.g., 499 for $4.99)
  /// - credits: Number of credits to award
  /// - packageId: ID of the credit package purchased
  Future<Map<String, dynamic>> createPaymentIntent({
    required int amountCents,
    required int credits,
    required String packageId,
  }) async {
    try {
      debugPrint(
        '[CreditPaymentService] Creating payment intent: \$${amountCents / 100}, $credits credits',
      );

      final authUser = AuthRepository.instance.currentUser;
      if (authUser == null) {
        return {'error': 'No authenticated user'};
      }

      _initFunctions();
      if (_functions == null) {
        return {'error': 'Firebase Functions not available'};
      }

      final callable = _functions!.httpsCallable('createStripePaymentIntent');
      final result = await callable.call({
        'amountCents': amountCents,
        'credits': credits,
        'packageId': packageId,
        'userEmail': authUser.email,
        'userId': authUser.id,
      });

      final data = result.data as Map<String, dynamic>;
      debugPrint(
        '[CreditPaymentService] Payment intent created: ${data['clientSecret']?.substring(0, 20)}...',
      );

      return {
        'clientSecret': data['clientSecret'] as String,
        'publishableKey': data['publishableKey'] as String,
        'paymentIntentId': data['paymentIntentId'] as String,
      };
    } catch (e) {
      debugPrint('[CreditPaymentService] createPaymentIntent error: $e');
      if (e is FirebaseFunctionsException) {
        return {'error': e.message ?? 'Failed to create payment intent'};
      }
      return {'error': e.toString()};
    }
  }

  /// Confirm payment and award credits to user.
  /// This is typically called after client-side Stripe payment succeeds.
  Future<Map<String, dynamic>> confirmPayment({
    required String paymentIntentId,
    required int credits,
    required double amountUSD,
  }) async {
    try {
      debugPrint('[CreditPaymentService] Confirming payment: $paymentIntentId');

      _initFunctions();
      if (_functions == null) {
        return {'error': 'Firebase Functions not available'};
      }

      final callable = _functions!.httpsCallable('confirmStripePayment');
      final result = await callable.call({
        'paymentIntentId': paymentIntentId,
        'credits': credits,
        'amountUSD': amountUSD,
      });

      final data = result.data as Map<String, dynamic>;

      // Record purchase in credit repository
      await CreditRepository.instance.recordPurchase(
        credits: credits,
        amountUSD: amountUSD,
        paymentGatewayId: paymentIntentId,
      );

      debugPrint(
        '[CreditPaymentService] Payment confirmed, credits awarded: $credits',
      );

      return {
        'success': true,
        'transactionId': data['transactionId'] as String,
        'creditsAwarded': credits,
      };
    } catch (e) {
      debugPrint('[CreditPaymentService] confirmPayment error: $e');
      if (e is FirebaseFunctionsException) {
        return {'error': e.message ?? 'Failed to confirm payment'};
      }
      return {'error': e.toString()};
    }
  }

  /// Handle payment failure and potentially refund credits if they were awarded early
  Future<void> handlePaymentFailure({
    required String paymentIntentId,
    String? reason,
  }) async {
    try {
      debugPrint(
        '[CreditPaymentService] Handling payment failure: $paymentIntentId, reason: $reason',
      );

      _initFunctions();
      if (_functions == null) return;

      final callable = _functions!.httpsCallable('handleFailedStripePayment');
      await callable.call({
        'paymentIntentId': paymentIntentId,
        'reason': reason ?? 'User cancelled',
      });
    } catch (e) {
      debugPrint(
        '⚠️ [CreditPaymentService] Failed to handle payment failure: $e',
      );
      // Non-critical, don't throw
    }
  }

  /// Check payment status (useful for polling or error recovery)
  Future<Map<String, dynamic>> getPaymentStatus({
    required String paymentIntentId,
  }) async {
    try {
      _initFunctions();
      if (_functions == null) {
        return {'error': 'Firebase Functions not available'};
      }

      final callable = _functions!.httpsCallable('getStripePaymentStatus');
      final result = await callable.call({'paymentIntentId': paymentIntentId});

      final data = result.data as Map<String, dynamic>;
      return {
        'status':
            data['status']
                as String, // 'succeeded', 'processing', 'requires_action', 'canceled', 'failed'
        'amount': data['amount'] as int,
        'currency': data['currency'] as String,
      };
    } catch (e) {
      debugPrint('[CreditPaymentService] getPaymentStatus error: $e');
      return {'error': e.toString()};
    }
  }
}
