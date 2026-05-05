// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Calls window.openRazorpay(options) defined in web/index.html
@JS('openRazorpay')
external JSPromise<JSString> _openRazorpay(JSObject options);

/// Opens Razorpay checkout on web using Checkout.js.
/// Returns a map with `payment_id` on success or `error` on failure.
Future<Map<String, dynamic>> openRazorpayWeb({
  required String keyId,
  required int amountInPaise,
  required String description,
  required String userEmail,
  required String userPhone,
  required String userName,
  String? orderId,
}) async {
  if (!kIsWeb) return {'error': 'Not running on web'};

  try {
    final opts = <String, dynamic>{
      'key': keyId,
      'amount': amountInPaise,
      'currency': 'INR',
      'name': 'VaultWheels',
      'description': description,
      // Only include order_id if it's actually set — empty string causes Razorpay to reject
      if (orderId != null && orderId.isNotEmpty) 'order_id': orderId,
      'prefill_name': userName,
      'prefill_email': userEmail,
      'prefill_contact': userPhone,
      'theme_color': '#1976D2',
    }.jsify() as JSObject;

    final resultStr = await _openRazorpay(opts).toDart;
    final decoded = jsonDecode(resultStr.toDart) as Map<String, dynamic>;
    return decoded;
  } catch (e) {
    debugPrint('[RazorpayWeb] Error: $e');
    return {'error': e.toString()};
  }
}

