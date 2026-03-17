import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class PaymentService {
  static final PaymentService instance = PaymentService._();
  PaymentService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Create Razorpay order (server-side)
  Future<Map<String, dynamic>> createOrder({
    required int amount,
    String currency = 'INR',
    String? receipt,
    Map<String, dynamic>? notes,
  }) async {
    try {
      final result = await _functions.httpsCallable('createRazorpayOrder').call({
        'amount': amount,
        'currency': currency,
        'receipt': receipt,
        'notes': notes,
      });

      return {
        'orderId': result.data['orderId'],
        'amount': result.data['amount'],
        'currency': result.data['currency'],
        'receipt': result.data['receipt'],
      };
    } catch (e) {
      debugPrint('Error creating order: $e');
      rethrow;
    }
  }

  /// Verify payment signature (server-side)
  Future<Map<String, dynamic>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    try {
      final result = await _functions.httpsCallable('verifyRazorpayPayment').call({
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
      });

      return {
        'verified': result.data['verified'],
        'payment_id': result.data['payment_id'],
        'order_id': result.data['order_id'],
        'amount': result.data['amount'],
        'status': result.data['status'],
        'method': result.data['method'],
        'email': result.data['email'],
        'contact': result.data['contact'],
      };
    } catch (e) {
      debugPrint('Error verifying payment: $e');
      rethrow;
    }
  }
}
