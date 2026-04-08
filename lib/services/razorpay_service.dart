import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Razorpay payment service for Indian transactions (INR).
/// Used instead of Stripe since Stripe escrow is not permitted in India.
class RazorpayService {
  RazorpayService._();
  static final RazorpayService instance = RazorpayService._();

  // Razorpay test key — replace with live key for production
  static const String _keyId = 'rzp_test_YourRazorpayKeyHere';

  Razorpay? _razorpay;

  // Callbacks set before each payment
  void Function(PaymentSuccessResponse)? _onSuccess;
  void Function(PaymentFailureResponse)? _onFailure;
  void Function(ExternalWalletResponse)? _onExternalWallet;

  void _init() {
    _razorpay?.clear();
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handleFailure);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handleSuccess(PaymentSuccessResponse response) {
    _onSuccess?.call(response);
    _cleanup();
  }

  void _handleFailure(PaymentFailureResponse response) {
    _onFailure?.call(response);
    _cleanup();
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _onExternalWallet?.call(response);
  }

  void _cleanup() {
    _onSuccess = null;
    _onFailure = null;
    _onExternalWallet = null;
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }

  /// Open Razorpay checkout.
  /// On mobile: opens native Razorpay SDK.
  /// On web: redirects to Razorpay hosted checkout page.
  /// [amountInPaise] — amount in paise (e.g. ₹100 = 10000 paise).
  /// Returns a map with `payment_id` on success, or `error` on failure.
  Future<Map<String, dynamic>> processPayment({
    required int amountInPaise,
    required String description,
    required String userEmail,
    required String userPhone,
    required String userName,
    String? orderId,
  }) async {
    // ── Dev mode: placeholder key → skip payment, confirm directly ─────────
    if (_keyId.contains('YourRazorpay') || _keyId.isEmpty) {
      debugPrint('[RazorpayService] ⚠️ Placeholder key detected — bypassing payment for dev/test');
      return {
        'payment_id': 'dev_${DateTime.now().millisecondsSinceEpoch}',
        'order_id': orderId ?? 'dev_order_${DateTime.now().millisecondsSinceEpoch}',
      };
    }
    // ── Web: redirect to Razorpay hosted checkout ──────────────────────────
    if (kIsWeb) {
      return _processWebPayment(
        amountInPaise: amountInPaise,
        description: description,
        userEmail: userEmail,
        userPhone: userPhone,
        userName: userName,
        orderId: orderId,
      );
    }

    // ── Native: use Razorpay Flutter SDK ───────────────────────────────────
    _init();

    final completer = _PaymentCompleter();

    _onSuccess = (res) => completer.complete({
          'payment_id': res.paymentId,
          'order_id': res.orderId,
          'signature': res.signature,
        });

    _onFailure = (res) => completer.complete({
          'error': res.message ?? 'Payment failed',
          'code': res.code,
        });

    final options = <String, dynamic>{
      'key': _keyId,
      'amount': amountInPaise,
      'currency': 'INR',
      'name': 'VaultWheels',
      'description': description,
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
        'name': userName,
      },
      'theme': {'color': '#1976D2'},
      'order_id': ?orderId,
    };

    try {
      _razorpay!.open(options);
    } catch (e) {
      _cleanup();
      return {'error': e.toString()};
    }

    return completer.future;
  }

  /// Web fallback: open Razorpay hosted checkout in browser tab.
  /// The user completes payment on Razorpay's page and returns.
  /// Since we can't capture the callback on web, we return a pending state
  /// and rely on the backend webhook to confirm payment.
  Future<Map<String, dynamic>> _processWebPayment({
    required int amountInPaise,
    required String description,
    required String userEmail,
    required String userPhone,
    required String userName,
    String? orderId,
  }) async {
    // Build Razorpay hosted checkout URL
    // In production, generate a proper payment link via Razorpay Payment Links API
    // For now, open the standard checkout page with prefilled params
    final params = Uri(
      scheme: 'https',
      host: 'rzp.io',
      path: '/l/quickohunt', // Replace with your Razorpay payment link slug
      queryParameters: {
        'amount': (amountInPaise / 100).toStringAsFixed(0),
        'currency': 'INR',
        'description': description,
        'prefill[name]': userName,
        'prefill[email]': userEmail,
        'prefill[contact]': userPhone,
      },
    );

    final launched = await launchUrl(params, mode: LaunchMode.externalApplication);
    if (!launched) {
      return {'error': 'Could not open Razorpay checkout. Please try on mobile.'};
    }

    // On web we can't capture the result synchronously.
    // Return a pending marker — the booking will be confirmed via webhook.
    return {
      'gateway': 'razorpay_web',
      'payment_id': 'web_pending_${DateTime.now().millisecondsSinceEpoch}',
      'web_redirect': true,
    };
  }
}

/// Simple completer wrapper to await Razorpay callback.
class _PaymentCompleter {
  final _completer = Completer<Map<String, dynamic>>();

  void complete(Map<String, dynamic> result) {
    if (_completer.isCompleted) return;
    _completer.complete(result);
  }

  Future<Map<String, dynamic>> get future => _completer.future;
}
