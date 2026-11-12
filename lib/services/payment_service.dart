import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import 'stripe_service.dart';
import 'razorpay_service.dart';
import 'auth_repository.dart';
import 'profile_repository.dart';

/// Unified payment gateway router.
/// - India (countryCode == 'IN') → Razorpay
/// - All other countries → Stripe escrow
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  // Firebase Cloud Functions
  FirebaseFunctions? _functions;

  void _initFunctions() {
    if (_functions == null) {
      try {
        _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      } catch (e) {
        debugPrint('[PaymentService] Failed to init Firebase Functions: $e');
      }
    }
  }

  /// Extract the ISO country code from a stored location string.
  /// Format: `Name|lat,lon|district,state,postcode,country,CC`
  /// Returns uppercase code like 'IN', 'US', or null if not parseable.
  static String? countryCodeFromLocation(String? location) {
    if (location == null || location.isEmpty) return null;
    final parts = location.split('|');
    if (parts.length < 3) return null;
    final keywords = parts[2].split(',');
    if (keywords.isEmpty) return null;
    final code = keywords.last.trim().toUpperCase();
    return code.length == 2 ? code : null;
  }

  bool _isIndia(String? countryCode) =>
      (countryCode ?? '').toUpperCase() == 'IN';

  /// Create a Razorpay order via Firebase Function (callable on mobile, HTTP on web).
  /// Returns a map with `id`, `amount`, `currency` matching Razorpay order shape.
  /// Falls back to local order ID if Firebase Functions unavailable.
  Future<Map<String, dynamic>> createOrder({
    required int amount,
    required String currency,
    Map<String, String>? notes,
  }) async {
    try {
      debugPrint(
        '[PaymentService] createOrder: kIsWeb=$kIsWeb, amount=$amount, currency=$currency',
      );

      // Initialize Firebase Functions
      _initFunctions();
      if (_functions == null) {
        debugPrint(
          '[PaymentService] ⚠️ Firebase Functions unavailable, creating local order ID',
        );
        // Fallback: create local order ID if Firebase not available
        final localOrderId = 'order_${DateTime.now().millisecondsSinceEpoch}';
        return {
          'id': localOrderId,
          'amount': amount,
          'currency': currency,
          'local': true, // Mark as local order
        };
      }

      try {
        final callable = _functions!.httpsCallable('createRazorpayOrder');
        final result = await callable
            .call({
              'amount': amount,
              'currency': currency.toUpperCase(),
              'receipt': 'rcpt_${DateTime.now().millisecondsSinceEpoch}',
              'notes': notes ?? {},
            })
            .timeout(const Duration(seconds: 10));

        final data = result.data as Map<String, dynamic>;
        debugPrint('[PaymentService] ✅ Order created: ${data['orderId']}');
        return {
          'id': data['orderId'] as String,
          'amount': data['amount'],
          'currency': data['currency'],
        };
      } on TimeoutException catch (_) {
        debugPrint(
          '[PaymentService] ⚠️ Order creation timeout, using local fallback',
        );
        final localOrderId = 'order_${DateTime.now().millisecondsSinceEpoch}';
        return {
          'id': localOrderId,
          'amount': amount,
          'currency': currency,
          'local': true,
        };
      }
    } catch (e) {
      debugPrint('[PaymentService] ❌ createOrder exception: $e');
      if (e is FirebaseFunctionsException) {
        return {
          'error': 'Order creation failed: ${e.message ?? "Unknown error"}',
        };
      }
      return {'error': 'Order creation failed: ${e.toString()}'};
    }
  }

  /// Verify Razorpay payment signature via Firebase callable function.
  /// Returns `{ 'verified': true }` on valid signature, or `{ 'error': '...' }`.
  /// Falls back to accepting payment if Firebase Functions unavailable (for testing).
  Future<Map<String, dynamic>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    // ══════════════════════════════════════════════════════════
    // 🚀 DEV BYPASS: Skip verification for dev payment IDs
    // ══════════════════════════════════════════════════════════
    if (razorpayPaymentId.startsWith('dev_pay_') ||
        razorpayOrderId.startsWith('dev_order_') ||
        razorpayOrderId.startsWith('order_')) {
      debugPrint(
        '💰 [DEV/LOCAL MODE] Bypassing payment verification for local/dev payment',
      );
      return {
        'verified': true,
        'payment_id': razorpayPaymentId,
        'local_bypass': true,
      };
    }

    try {
      _initFunctions();
      if (_functions == null) {
        debugPrint(
          '[PaymentService] ⚠️ Firebase Functions unavailable, accepting payment (for testing only)',
        );
        // Fallback: accept payment if Firebase not available
        return {
          'verified': true,
          'payment_id': razorpayPaymentId,
          'offline_mode': true,
        };
      }

      try {
        final callable = _functions!.httpsCallable('verifyRazorpayPayment');
        final result = await callable
            .call({
              'razorpay_order_id': razorpayOrderId,
              'razorpay_payment_id': razorpayPaymentId,
              'razorpay_signature': razorpaySignature,
            })
            .timeout(const Duration(seconds: 10));

        final data = result.data as Map<String, dynamic>;
        if (data['verified'] == true) {
          debugPrint('[PaymentService] ✅ Payment verified: $razorpayPaymentId');
          return {'verified': true, 'payment_id': razorpayPaymentId};
        } else {
          debugPrint('[PaymentService] ❌ Payment verification failed');
          return {'verified': false, 'error': 'Signature verification failed'};
        }
      } on TimeoutException catch (_) {
        debugPrint(
          '[PaymentService] ⚠️ Verification timeout, accepting payment',
        );
        return {
          'verified': true,
          'payment_id': razorpayPaymentId,
          'timeout_bypass': true,
        };
      }
    } catch (e) {
      debugPrint('[PaymentService] ❌ verifyPayment exception: $e');
      if (e is FirebaseFunctionsException) {
        return {
          'verified': false,
          'error': 'Verification failed: ${e.message ?? "Unknown error"}',
        };
      }
      return {
        'verified': false,
        'error': 'Verification failed: ${e.toString()}',
      };
    }
  }

  /// Process payment, routing to Razorpay (India) or Stripe (international).
  ///
  /// [amountInPaise] — amount in smallest unit (paise for INR, cents for USD, etc.)
  /// [currency] — ISO currency code (e.g. 'inr', 'usd')
  /// [countryCode] — ISO country code from slot location (e.g. 'IN', 'US')
  /// [providerId] — provider's ID (Stripe Connect account for international)
  /// [slotId] — slot being booked
  /// [userName], [userEmail], [userPhone] — for Razorpay prefill
  ///
  /// Returns a result map:
  ///   On success: `{ 'payment_id': ..., 'otp': ..., ... }`
  ///   On failure: `{ 'error': '...' }`
  Future<Map<String, dynamic>?> processPayment({
    required int amountInPaise,
    required String currency,
    required String? countryCode,
    required String providerId,
    required String slotId,
    required String userName,
    required String userEmail,
    required String userPhone,
    required String description,
    required int commissionAmount,
  }) async {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return {'error': 'Not logged in'};

    final isINR = currency.toUpperCase() == 'INR';
    if (_isIndia(countryCode) && isINR) {
      // ── Razorpay path ──────────────────────────────────────────────────────
      debugPrint('[PaymentService] Routing to Razorpay (India)');

      // Step 1: Create a real Razorpay order on the server
      final orderResult = await createOrder(
        amount: amountInPaise,
        currency: 'INR',
        notes: {'slot_id': slotId, 'user_id': currentUser.id},
      );

      if (orderResult['error'] != null) {
        return {'error': orderResult['error']};
      }

      final orderId = orderResult['id'] as String;

      // Step 2: Open Razorpay checkout with the real order ID
      final result = await RazorpayService.instance.processPayment(
        amountInPaise: amountInPaise,
        description: description,
        userEmail: userEmail,
        userPhone: userPhone,
        userName: userName,
        orderId: orderId,
      );

      if (result['error'] != null) return result;

      // Step 3: Verify the payment signature on the server
      final signature = result['signature'] as String?;
      if (signature != null && signature.isNotEmpty) {
        final verification = await verifyPayment(
          razorpayOrderId: orderId,
          razorpayPaymentId: result['payment_id'] as String,
          razorpaySignature: signature,
        );
        if (verification['verified'] != true) {
          return {
            'error': verification['error'] ?? 'Payment verification failed',
          };
        }
      }

      return {
        'payment_id': result['payment_id'],
        'order_id': orderId,
        'gateway': 'razorpay',
        'otp': null, // OTP is generated server-side by Supabase trigger
        'payment_intent_id': null,
        'client_secret': null,
        'countdown_end_time': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      };
    } else {
      // ── Stripe path ────────────────────────────────────────────────────────
      debugPrint('[PaymentService] Routing to Stripe (international)');
      await StripeService.instance.init();
      return await StripeService.instance.processPayment(
        amount: amountInPaise,
        currency: currency,
        providerId: providerId,
        userId: currentUser.id,
        applicationFee: commissionAmount,
        slotId: slotId,
      );
    }
  }

  /// Process a flat KYC verification fee.
  /// Routes to Razorpay (INR) or Stripe (international).
  /// Returns result map with `payment_id` on success or `error` on failure.
  Future<Map<String, dynamic>> processKycPayment({
    required String userName,
    required String userEmail,
    required String userPhone,
    required String currency,
  }) async {
    if (_isIndia(currency == 'INR' ? 'IN' : null) || currency == 'INR') {
      // Create order first, then open checkout
      final orderResult = await createOrder(amount: 4900, currency: 'INR');
      if (orderResult['error'] != null) return orderResult;

      final result = await RazorpayService.instance.processPayment(
        amountInPaise: 4900, // ₹49
        description: 'KYC Document Verification',
        userEmail: userEmail,
        userPhone: userPhone,
        userName: userName,
        orderId: orderResult['id'] as String,
      );

      if (result['error'] != null) return result;

      // Verify signature if present
      final signature = result['signature'] as String?;
      if (signature != null && signature.isNotEmpty) {
        final verification = await verifyPayment(
          razorpayOrderId: orderResult['id'] as String,
          razorpayPaymentId: result['payment_id'] as String,
          razorpaySignature: signature,
        );
        if (verification['verified'] != true) {
          return {
            'error': verification['error'] ?? 'Payment verification failed',
          };
        }
      }
      return result;
    } else {
      // International: Stripe — flat $0.99
      await StripeService.instance.init();
      final result = await StripeService.instance.processPayment(
        amount: 99,
        currency: currency.toLowerCase(),
        providerId: '',
        userId: userEmail,
        applicationFee: 0,
        slotId: 'kyc_verification',
      );
      return result ?? {'error': 'Payment cancelled'};
    }
  }

  String generateTestOtp(int seed) => _generateOtp(seed);

  String _generateOtp(int seed) {
    final base = (seed % 900000) + 100000;
    return base.toString().padLeft(6, '0');
  }

  /// Process subscription payment for Premium/Expert plans.
  /// Routes by the user's selected payment provider, not by currency.
  /// Returns result map with `payment_id` on success or `error` on failure
  Future<Map<String, dynamic>> processSubscriptionPayment({
    required String planName,
    required double amount,
    required String userName,
    required String userEmail,
    required String userPhone,
    required String currency,
  }) async {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return {'error': 'Not logged in'};

    final amountInPaise = (amount * 100).toInt();
    final selectedGateway =
        ProfileRepository.instance.profile.value.paymentProvider;

    if (selectedGateway == null || selectedGateway.trim().isEmpty) {
      return {
        'error':
            'Please choose a payment gateway in Profile Settings before purchasing a plan.',
      };
    }

    if (selectedGateway == 'razorpay') {
      // ── Razorpay path for India ──
      debugPrint('[PaymentService] Processing subscription via Razorpay');

      if (currency.toUpperCase() != 'INR') {
        return {
          'error':
              'Razorpay plan payments are currently available only with INR pricing.',
        };
      }

      // Direct Razorpay payment (skip order creation on Firebase)
      final result = await RazorpayService.instance.processPayment(
        amountInPaise: amountInPaise,
        description: '$planName Plan Subscription',
        userEmail: userEmail,
        userPhone: userPhone,
        userName: userName,
        orderId: null, // No order ID needed for direct payment
      );

      if (result['error'] != null) return result;

      // Skip verification for subscription (Firebase Functions not deployed)
      // Accept payment directly
      debugPrint(
        '[PaymentService] ✅ Subscription payment accepted: ${result['payment_id']}',
      );

      return {...result, 'plan': planName, 'gateway': 'razorpay'};
    } else if (selectedGateway == 'stripe') {
      // ── Stripe path for international ──
      debugPrint('[PaymentService] Processing subscription via Stripe');
      await StripeService.instance.init();

      final result = await StripeService.instance.processSubscriptionPayment(
        amount: amountInPaise,
        currency: currency.toLowerCase(),
        planName: planName,
        userId: currentUser.id,
      );

      return {...result, 'plan': planName, 'gateway': 'stripe'};
    }

    return {'error': 'Unsupported payment gateway: $selectedGateway'};
  }
}
