import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();

  // Stripe test keys
  static const String publishableKey =
      'pk_test_51SvDRRPLeVZgzHHXPxLctk57aECXjdtVKTn5047FXXeXQQv6npQYjgThQAvcGdKyHmATqfr7ZWExj0MrEi0ZzJujMNaOCdYvqD';

  // Firebase Cloud Functions base URL
  static const String backendUrl =
      'https://us-central1-quickohunt-app.cloudfunctions.net';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    Stripe.publishableKey = publishableKey;
    await Stripe.instance.applySettings();
    _initialized = true;
  }

  /// Create a payment with escrow (money held until trip completes)
  /// [amount] - Amount in smallest currency unit (e.g., cents for USD, paise for INR)
  /// [currency] - Currency code (usd, inr, eur, etc.)
  /// [providerId] - Provider's Stripe Connect account ID
  /// [applicationFee] - Your commission amount
  Future<Map<String, dynamic>> createPaymentWithEscrow({
    required int amount,
    required String currency,
    required String providerId,
    required int applicationFee,
  }) async {
    throw UnsupportedError(
      'Direct payment intent creation is not supported. Use createBooking() instead.',
    );
  }

  /// Present payment sheet to user
  Future<bool> presentPaymentSheet({required String clientSecret}) async {
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Quickohunt',
          style: ThemeMode.system,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Complete payment flow
  Future<bool> processPayment({
    required int amount,
    required String currency,
    required String providerId,
    required int applicationFee,
  }) async {
    try {
      final booking = await createBooking(
        userId: 'unknown',
        providerId: providerId,
        postId: 'unknown',
        amount: amount,
        currency: currency,
        commissionAmount: applicationFee,
        countdownHours: 1,
      );
      if (booking == null) return false;

      final clientSecret = booking['client_secret'] as String?;
      if (clientSecret == null || clientSecret.trim().isEmpty) return false;

      return await presentPaymentSheet(clientSecret: clientSecret);
    } catch (e) {
      return false;
    }
  }

  /// Create Stripe Connect account for provider (onboarding)
  Future<String?> createConnectedAccount({
    required String email,
    required String country,
  }) async {
    return null;
  }

  /// Release escrowed funds to provider after OTP verification
  Future<bool> releaseFunds({
    required String paymentIntentId,
    required String providerId,
    required int amount,
    required int commissionAmount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/releaseFunds'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'payment_intent_id': paymentIntentId,
          'provider_id': providerId,
          'amount': amount,
          'commission_amount': commissionAmount,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Refund payment to user (when timer expires)
  Future<bool> refundPayment({
    required String paymentIntentId,
    required int amount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/refundPayment'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'payment_intent_id': paymentIntentId,
          'amount': amount,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Create booking with escrow payment
  Future<Map<String, dynamic>?> createBooking({
    required String userId,
    required String providerId,
    required String postId,
    required int amount,
    required String currency,
    required int commissionAmount,
    required int countdownHours,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/createBooking'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'provider_id': providerId,
          'post_id': postId,
          'amount': amount,
          'currency': currency,
          'commission_amount': commissionAmount,
          'countdown_hours': countdownHours,
        }),
      );

      if (response.statusCode != 200) {
        return null;
      }

      return json.decode(response.body);
    } catch (e) {
      return null;
    }
  }

  /// Verify OTP and release funds
  Future<bool> verifyOtpAndRelease({
    required String bookingId,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/verifyOtp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'booking_id': bookingId, 'otp': otp}),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
