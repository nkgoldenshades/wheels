import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for OTP verification
class OtpService {
  final _supabase = Supabase.instance.client;

  /// Verify OTP for a booking
  /// 
  /// Returns:
  /// - 'success': OTP verified successfully
  /// - 'not_found': Booking doesn't exist
  /// - 'unauthorized': User doesn't own this booking
  /// - 'already_verified': OTP already verified
  /// - 'locked': Too many failed attempts (5+)
  /// - 'wrong_otp': Incorrect OTP (attempts incremented)
  Future<OtpVerificationResult> verifyOtp({
    required int bookingId,
    required String userId,
    required String enteredOtp,
  }) async {
    try {
      debugPrint('🔐 Verifying OTP for booking $bookingId');
      debugPrint('   User ID: $userId');
      debugPrint('   Entered OTP: $enteredOtp');

      final response = await _supabase.rpc(
        'verify_otp',
        params: {
          'p_booking_id': bookingId,
          'p_profile_customer_id': userId,
          'p_entered_otp': enteredOtp,
        },
      );

      final result = response as String;
      debugPrint('✅ OTP verification result: $result');

      return OtpVerificationResult.fromString(result);
    } catch (e) {
      debugPrint('❌ OTP verification error: $e');
      debugPrint('   Error type: ${e.runtimeType}');
      return OtpVerificationResult.error;
    }
  }
}

/// OTP verification result
enum OtpVerificationResult {
  success,
  notFound,
  unauthorized,
  alreadyVerified,
  locked,
  wrongOtp,
  error;

  factory OtpVerificationResult.fromString(String value) {
    switch (value) {
      case 'success':
        return OtpVerificationResult.success;
      case 'not_found':
        return OtpVerificationResult.notFound;
      case 'unauthorized':
        return OtpVerificationResult.unauthorized;
      case 'already_verified':
        return OtpVerificationResult.alreadyVerified;
      case 'locked':
        return OtpVerificationResult.locked;
      case 'wrong_otp':
        return OtpVerificationResult.wrongOtp;
      default:
        return OtpVerificationResult.error;
    }
  }

  String get message {
    switch (this) {
      case OtpVerificationResult.success:
        return 'OTP verified successfully!';
      case OtpVerificationResult.notFound:
        return 'Booking not found';
      case OtpVerificationResult.unauthorized:
        return 'You are not authorized to verify this booking';
      case OtpVerificationResult.alreadyVerified:
        return 'OTP already verified';
      case OtpVerificationResult.locked:
        return 'Too many failed attempts. Booking is locked.';
      case OtpVerificationResult.wrongOtp:
        return 'Incorrect OTP. Please try again.';
      case OtpVerificationResult.error:
        return 'An error occurred. Please try again.';
    }
  }

  bool get isSuccess => this == OtpVerificationResult.success;
  bool get isWrongOtp => this == OtpVerificationResult.wrongOtp;
  bool get isLocked => this == OtpVerificationResult.locked;
}
