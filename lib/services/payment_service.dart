import 'package:flutter/foundation.dart';
import 'stripe_service.dart';
import 'razorpay_service.dart';
import 'auth_repository.dart';

/// Unified payment gateway router.
/// - India (countryCode == 'IN') → Razorpay
/// - All other countries → Stripe escrow
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

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

  /// Create a Razorpay order via backend (or mock locally for test key usage).
  /// Returns a map with `id`, `amount`, `currency` matching Razorpay order shape.
  Future<Map<String, dynamic>> createOrder({
    required int amount,
    required String currency,
    Map<String, String>? notes,
  }) async {
    // For now, create a mock order locally (replace with backend call when ready).
    // In production, call your server: POST /createRazorpayOrder { amount, currency, notes }
    final mockOrderId = 'order_${DateTime.now().millisecondsSinceEpoch}';
    return {
      'id': mockOrderId,
      'amount': amount * 100, // Razorpay expects paise
      'currency': currency,
    };
  }

  /// Verify Razorpay payment signature via backend.
  /// Returns `{ 'success': true }` on valid signature.
  Future<Map<String, dynamic>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    // For now, accept all payments locally (replace with backend HMAC verification).
    // In production, call your server: POST /verifyRazorpayPayment { orderId, paymentId, signature }
    debugPrint('[PaymentService] verifyPayment: $razorpayPaymentId');
    return {'success': true};
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
      final result = await RazorpayService.instance.processPayment(
        amountInPaise: amountInPaise,
        description: description,
        userEmail: userEmail,
        userPhone: userPhone,
        userName: userName,
      );

      if (result['error'] != null) return result;

      // For Razorpay, generate a local OTP (no server-side escrow)
      final otp = _generateOtp(amountInPaise);
      return {
        'payment_id': result['payment_id'],
        'order_id': result['order_id'],
        'gateway': 'razorpay',
        'otp': otp,
        'payment_intent_id': null, // no Stripe intent
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
      return RazorpayService.instance.processPayment(
        amountInPaise: 4900, // ₹49
        description: 'KYC Document Verification',
        userEmail: userEmail,
        userPhone: userPhone,
        userName: userName,
      );
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

  String _generateOtp(int seed) {
    final base = (seed % 900000) + 100000;
    return base.toString().padLeft(6, '0');
  }
}
