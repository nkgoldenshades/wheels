/// Stub for non-web platforms — never actually called since kIsWeb is false.
Future<Map<String, dynamic>> openRazorpayWeb({
  required String keyId,
  required int amountInPaise,
  required String description,
  required String userEmail,
  required String userPhone,
  required String userName,
  String? orderId,
}) async {
  return {'error': 'Not running on web'};
}



