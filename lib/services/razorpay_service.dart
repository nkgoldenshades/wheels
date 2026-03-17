import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayService {
  static final RazorpayService instance = RazorpayService._();
  RazorpayService._();

  late Razorpay _razorpay;
  Function(PaymentSuccessResponse)? _onSuccess;
  Function(PaymentFailureResponse)? _onFailure;

  // Razorpay Test Keys (for testing with real Razorpay checkout)
  static const String keyId = 'rzp_test_SMpj1xxJxAcT6K';
  static const String keySecret = 'PZKW95oZEjcavJ5flTEZVjeU';
  
  // TEST MODE - Set to false to use real Razorpay checkout (with test keys)
  static const bool testMode = false;

  void initialize() {
    if (!testMode) {
      _razorpay = Razorpay();
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  void dispose() {
    if (!testMode) {
      _razorpay.clear();
    }
  }

  /// Open Razorpay checkout with escrow
  /// amount: in paise (e.g., 10000 = ₹100)
  void openCheckout({
    required int amount,
    required String orderId,
    required String name,
    required String description,
    required String email,
    required String contact,
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onFailure,
  }) {
    _onSuccess = onSuccess;
    _onFailure = onFailure;

    // TEST MODE - Simulate successful payment
    if (testMode) {
      debugPrint('🧪 TEST MODE: Simulating payment success');
      Future.delayed(const Duration(seconds: 1), () {
        final mockResponse = PaymentSuccessResponse(
          orderId,
          'test_payment_${DateTime.now().millisecondsSinceEpoch}',
          'test_signature',
          {},
        );
        _handlePaymentSuccess(mockResponse);
      });
      return;
    }

    final options = {
      'key': keyId,
      'amount': amount, // in paise
      'name': 'QuickOHunt',
      'order_id': orderId,
      'description': description,
      'prefill': {
        'contact': contact,
        'email': email,
        'name': name,
      },
      'theme': {
        'color': '#9C27B0',
      },
      // Escrow configuration
      'notes': {
        'escrow': 'true',
        'booking_id': orderId,
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay Error: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('Payment Success: ${response.paymentId}');
    _onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Payment Error: ${response.code} - ${response.message}');
    _onFailure?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External Wallet: ${response.walletName}');
  }
}
