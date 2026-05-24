import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/supabase_config.dart';
import 'stripe_service.dart';
import 'razorpay_service.dart';
import 'auth_repository.dart';

/// Unified payment gateway router.
/// - India (countryCode == 'IN') → Razorpay
/// - All other countries → Stripe escrow
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  static const String _supabaseUrl = SupabaseConfig.url;
  static const String _supabaseAnonKey = SupabaseConfig.anonKey;

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

  /// Create a Razorpay order via the Supabase Edge Function.
  /// Returns a map with `id`, `amount`, `currency` matching Razorpay order shape.
  Future<Map<String, dynamic>> createOrder({
    required int amount,
    required String currency,
    Map<String, String>? notes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_supabaseUrl/functions/v1/create-razorpay-order'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': _supabaseAnonKey,
          'Authorization': 'Bearer $_supabaseAnonKey',
        },
        body: jsonEncode({
          'amount': amount, // already in paise
          'currency': currency.toUpperCase(),
          'receipt': 'rcpt_${DateTime.now().millisecondsSinceEpoch}',
          'notes': notes ?? {},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Edge function returns { orderId, amount, currency, receipt }
        return {
          'id': data['orderId'] as String,
          'amount': data['amount'],
          'currency': data['currency'],
        };
      } else {
        final err = jsonDecode(response.body);
        debugPrint('[PaymentService] createOrder error: ${err['error']}');
        return {'error': err['error'] ?? 'Failed to create order'};
      }
    } catch (e) {
      debugPrint('[PaymentService] createOrder exception: $e');
      return {'error': e.toString()};
    }
  }

  /// Verify Razorpay payment signature via the Supabase Edge Function (HMAC-SHA256).
  /// Returns `{ 'verified': true }` on valid signature, or `{ 'error': '...' }`.
  Future<Map<String, dynamic>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_supabaseUrl/functions/v1/verify-razorpay-payment'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': _supabaseAnonKey,
          'Authorization': 'Bearer $_supabaseAnonKey',
        },
        body: jsonEncode({
          'razorpay_order_id': razorpayOrderId,
          'razorpay_payment_id': razorpayPaymentId,
          'razorpay_signature': razorpaySignature,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['verified'] == true) {
        return {'verified': true, 'payment_id': razorpayPaymentId};
      } else {
        debugPrint('[PaymentService] verifyPayment failed: ${data['error']}');
        return {'verified': false, 'error': data['error'] ?? 'Signature verification failed'};
      }
    } catch (e) {
      debugPrint('[PaymentService] verifyPayment exception: $e');
      return {'verified': false, 'error': e.toString()};
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

    if (_isIndia(countryCode)) {
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
          return {'error': verification['error'] ?? 'Payment verification failed'};
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
          return {'error': verification['error'] ?? 'Payment verification failed'};
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

  /// Process subscription payment for Premium/Expert plans
  /// Routes to Razorpay (India) or Stripe (international)
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

    final amountInSmallestUnit = (amount * 100).toInt(); // Convert to paise/cents

    if (_isIndia(currency == 'INR' ? 'IN' : null) || currency == 'INR') {
      // ── Razorpay path for India ──
      debugPrint('[PaymentService] Processing subscription via Razorpay');

      // Create order first
      final orderResult = await createOrder(
        amount: amountInSmallestUnit,
        currency: 'INR',
        notes: {
          'plan': planName,
          'user_id': currentUser.id,
          'type': 'subscription',
        },
      );

      if (orderResult['error'] != null) return orderResult;

      final result = await RazorpayService.instance.processPayment(
        amountInPaise: amountInSmallestUnit,
        description: '$planName Plan Subscription',
        userEmail: userEmail,
        userPhone: userPhone,
        userName: userName,
        orderId: orderResult['id'] as String,
      );

      if (result['error'] != null) return result;

      // Verify signature
      final signature = result['signature'] as String?;
      if (signature != null && signature.isNotEmpty) {
        final verification = await verifyPayment(
          razorpayOrderId: orderResult['id'] as String,
          razorpayPaymentId: result['payment_id'] as String,
          razorpaySignature: signature,
        );
        if (verification['verified'] != true) {
          return {'error': verification['error'] ?? 'Payment verification failed'};
        }
      }

      return {
        ...result,
        'plan': planName,
        'gateway': 'razorpay',
      };
    } else {
      // ── Stripe path for international ──
      debugPrint('[PaymentService] Processing subscription via Stripe');
      await StripeService.instance.init();
      
      final result = await StripeService.instance.processPayment(
        amount: amountInSmallestUnit,
        currency: currency.toLowerCase(),
        providerId: '', // No provider for subscriptions
        userId: currentUser.id,
        applicationFee: 0, // No commission on subscriptions
        slotId: 'subscription_$planName',
      );

      if (result == null) return {'error': 'Payment cancelled'};
      
      return {
        ...result,
        'plan': planName,
        'gateway': 'stripe',
      };
    }
  }
}



