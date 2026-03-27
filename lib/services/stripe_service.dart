import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:url_launcher/url_launcher.dart';
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

  Future<Map<String, String>> _authorizedJsonHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return headers;
    final token = await user.getIdToken(true);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

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
    if (kIsWeb) {
      throw UnsupportedError(
        'Web checkout is not configured for Stripe PaymentSheet.',
      );
    }
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'VaultWheels',
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
  Future<Map<String, dynamic>?> processPayment({
    required int amount,
    required String currency,
    required String providerId,
    required String userId,
    required int applicationFee,
    String? postId,
    String? slotId,
  }) async {
    try {
      // On web: create a Stripe Checkout session and redirect to hosted page
      if (kIsWeb) {
        return await _processWebCheckout(
          amount: amount,
          currency: currency,
          providerId: providerId,
          userId: userId,
          applicationFee: applicationFee,
          slotId: slotId,
          postId: postId,
        );
      }

      final booking = await createBooking(
        userId: userId,
        providerId: providerId,
        postId: postId,
        slotId: slotId,
        amount: amount,
        currency: currency,
        commissionAmount: applicationFee,
        countdownHours: 1,
      );
      if (booking == null) {
        return {
          'error': 'Unable to create booking. Please check login and try again.',
        };
      }

      final clientSecret = booking['client_secret'] as String?;
      if (clientSecret == null || clientSecret.trim().isEmpty) {
        return {'error': 'Missing payment client secret from server.'};
      }

      final success = await presentPaymentSheet(clientSecret: clientSecret);
      if (!success) {
        return {'error': 'Payment was cancelled or could not be completed.'};
      }

      // Return booking details for local storage
      return booking;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Web: create a Stripe Checkout session via backend and redirect browser to it.
  Future<Map<String, dynamic>?> _processWebCheckout({
    required int amount,
    required String currency,
    required String providerId,
    required String userId,
    required int applicationFee,
    String? slotId,
    String? postId,
  }) async {
    try {
      final headers = await _authorizedJsonHeaders();
      final response = await http.post(
        Uri.parse('$backendUrl/createCheckoutSession'),
        headers: headers,
        body: json.encode({
          'user_id': userId,
          'provider_id': providerId,
          if (slotId != null) 'slot_id': slotId,
          if (postId != null) 'post_id': postId,
          'amount': amount,
          'currency': currency,
          'commission_amount': applicationFee,
          // Backend will add booking_id to these URLs automatically
        }),
      );

      if (response.statusCode != 200) {
        return {'error': 'Could not create checkout session. Try again.'};
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final checkoutUrl = data['url'] as String?;

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        return {'error': 'No checkout URL returned from server.'};
      }

      final launched = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        return {'error': 'Could not open Stripe checkout. Please try on mobile.'};
      }

      // Return pending — confirmed via Stripe webhook on backend
      return {
        'gateway': 'stripe_web',
        'payment_intent_id': data['payment_intent'] as String?,
        'client_secret': null,
        'web_redirect': true,
        'otp': data['otp'] as String?,
        'countdown_end_time': data['countdown_end_time'] as String?,
      };
    } catch (e) {
      return {'error': e.toString()};
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
      final headers = await _authorizedJsonHeaders();
      final response = await http.post(
        Uri.parse('$backendUrl/releaseFunds'),
        headers: headers,
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
      final headers = await _authorizedJsonHeaders();
      final response = await http.post(
        Uri.parse('$backendUrl/refundPayment'),
        headers: headers,
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
    String? postId,
    String? slotId,
    required int amount,
    required String currency,
    required int commissionAmount,
    required int countdownHours,
  }) async {
    try {
      final headers = await _authorizedJsonHeaders();
      final response = await http.post(
        Uri.parse('$backendUrl/createBooking'),
        headers: headers,
        body: json.encode({
          'user_id': userId,
          'provider_id': providerId,
          if (postId != null) 'post_id': postId,
          if (slotId != null) 'slot_id': slotId,
          'amount': amount,
          'currency': currency,
          'commission_amount': commissionAmount,
          'countdown_hours': countdownHours,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint(
          'createBooking failed: ${response.statusCode} ${response.body}',
        );
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
      final headers = await _authorizedJsonHeaders();
      final response = await http.post(
        Uri.parse('$backendUrl/verifyOtp'),
        headers: headers,
        body: json.encode({'booking_id': bookingId, 'otp': otp}),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
