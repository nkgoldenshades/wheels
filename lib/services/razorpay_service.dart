import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'razorpay_web_interop.dart' if (dart.library.io) 'razorpay_web_interop_stub.dart';

/// Razorpay payment service for Indian transactions (INR).
/// Uses native SDK on mobile, Checkout.js on web.
class RazorpayService {
  RazorpayService._();
  static final RazorpayService instance = RazorpayService._();

  // 🔑 Replace with YOUR key from dashboard.razorpay.com → Settings → API Keys
  static const String _keyId = 'rzp_test_SMpj1xxJxAcT6K'; // ← PUT YOUR KEY HERE
  static const String keyId = _keyId;

  Razorpay? _razorpay;

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

  /// Process payment.
  /// - Web  → Razorpay Checkout.js via JS interop
  /// - Mobile → Native Razorpay Flutter SDK
  Future<Map<String, dynamic>> processPayment({
    required int amountInPaise,
    required String description,
    required String userEmail,
    required String userPhone,
    required String userName,
    String? orderId,
  }) async {
    // Dev/placeholder key → skip payment
    if (_keyId.contains('YourRazorpay') || _keyId.isEmpty) {
      debugPrint('[RazorpayService] ⚠️ Placeholder key — bypassing payment');
      return {
        'payment_id': 'dev_${DateTime.now().millisecondsSinceEpoch}',
        'order_id': orderId ?? 'dev_order_${DateTime.now().millisecondsSinceEpoch}',
      };
    }

    // ── Web: use Checkout.js via JS interop ───────────────────────────────
    if (kIsWeb) {
      debugPrint('[RazorpayService] 🌐 Web payment via Checkout.js');
      return openRazorpayWeb(
        keyId: _keyId,
        amountInPaise: amountInPaise,
        description: description,
        userEmail: userEmail,
        userPhone: userPhone,
        userName: userName,
        orderId: orderId,
      );
    }

    // ── Native: Razorpay Flutter SDK ──────────────────────────────────────
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
}

class _PaymentCompleter {
  final _completer = Completer<Map<String, dynamic>>();

  void complete(Map<String, dynamic> result) {
    if (_completer.isCompleted) return;
    _completer.complete(result);
  }

  Future<Map<String, dynamic>> get future => _completer.future;
}

