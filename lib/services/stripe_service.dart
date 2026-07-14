import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';

class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();

  // ═══════════════════════════════════════════════════════════
  // 🔑 PAYMENT MODE CONFIGURATION
  // ═══════════════════════════════════════════════════════════
  // Set to true for TEST mode, false for PRODUCTION mode
  static const bool useTestMode = true; // ← CHANGE THIS TO false FOR PRODUCTION

  // TEST MODE KEYS (for development/testing)
  static const String _testPublishableKey =
      'pk_test_51SvbBRPL6V2gHHHXPuLctk57x8CXjOHVkInRO4ZIxXezQQv6pnQYlgTbg4vcGd5yNh0tqfrZ2ntxq06EzGi2zJqP00w9c4rvqo';

  // PRODUCTION MODE KEYS (get from dashboard.stripe.com in LIVE mode)
  // ⚠️ IMPORTANT: Add your live keys before going to production!
  static const String _livePublishableKey =
      'pk_live_XXXXXXXXXXXX'; // ← Replace with your LIVE key

  // Active publishable key based on mode
  static String get publishableKey =>
      useTestMode ? _testPublishableKey : _livePublishableKey;

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

    debugPrint('🔑 Stripe Mode: ${useTestMode ? "TEST 🧪" : "PRODUCTION 🚀"}');
    debugPrint('🔑 Using Key: ${publishableKey.substring(0, 15)}...');

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
      // On web, payment is handled via Stripe Checkout redirect
      // This method should not be called directly on web
      debugPrint(
        '⚠️ presentPaymentSheet called on web - use processPayment instead',
      );
      return false;
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
          'error':
              'Unable to create booking. Please check login and try again.',
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
          'slot_id': ?slotId,
          'post_id': ?postId,
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
        return {
          'error': 'Could not open Stripe checkout. Please try on mobile.',
        };
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
  /// Returns the onboarding URL to open in browser
  Future<Map<String, dynamic>?> createConnectedAccount({
    required String email,
    required String country,
    required String userId,
    String? returnUrl,
    String? refreshUrl,
  }) async {
    try {
      debugPrint(
        '[StripeService] createConnectedAccount: email=$email, country=$country, userId=$userId',
      );

      final headers = await _authorizedJsonHeaders();
      debugPrint('[StripeService] Headers: ${headers.keys.join(", ")}');
      debugPrint('[StripeService] Calling: $backendUrl/createConnectedAccount');

      final response = await http.post(
        Uri.parse('$backendUrl/createConnectedAccount'),
        headers: headers,
        body: json.encode({
          'email': email,
          'country': country,
          'user_id': userId,
          'return_url': returnUrl ?? 'https://vervestrideal.com/stripe-return',
          'refresh_url':
              refreshUrl ?? 'https://vervestrideal.com/stripe-refresh',
        }),
      );

      debugPrint('[StripeService] Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('[StripeService] Response body: ${response.body}');
        debugPrint(
          'createConnectedAccount failed: ${response.statusCode} ${response.body}',
        );
        try {
          final data = json.decode(response.body);
          if (data is Map<String, dynamic>) {
            return {
              'error':
                  data['error']?.toString() ?? 'Stripe account setup failed.',
            };
          }
        } catch (_) {
          // Fall through to a generic message below.
        }
        return {
          'error': 'Stripe account setup failed (${response.statusCode}).',
        };
      }

      final result = json.decode(response.body) as Map<String, dynamic>;
      debugPrint('[StripeService] Account created: ${result['account_id']}');
      return result;
    } catch (e) {
      debugPrint('createConnectedAccount error: $e');
      return {'error': 'Failed to connect to Stripe: $e'};
    }
  }

  /// Create and open Stripe Checkout for subscription plans.
  Future<Map<String, dynamic>> processSubscriptionPayment({
    required int amount,
    required String currency,
    required String planName,
    required String userId,
  }) async {
    try {
      debugPrint('[StripeService] processSubscriptionPayment called');
      debugPrint(
        '[StripeService] Amount: $amount, Currency: $currency, Plan: $planName',
      );

      // Check internet connectivity first
      debugPrint('[StripeService] Getting auth headers...');
      final headers = await _authorizedJsonHeaders();
      debugPrint(
        '[StripeService] Headers obtained: ${headers.keys.join(", ")}',
      );

      final url = '$backendUrl/createSubscriptionCheckoutSession';
      debugPrint('[StripeService] Calling URL: $url');

      final body = json.encode({
        'user_id': userId,
        'plan_name': planName,
        'amount': amount,
        'currency': currency,
      });
      debugPrint('[StripeService] Request body: $body');

      final response = await http
          .post(Uri.parse(url), headers: headers, body: body)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint('[StripeService] Request timed out after 30 seconds');
              throw TimeoutException('Request timed out');
            },
          );

      debugPrint('[StripeService] Response status: ${response.statusCode}');
      debugPrint('[StripeService] Response body: ${response.body}');

      if (response.statusCode != 200) {
        try {
          final data = json.decode(response.body);
          if (data is Map<String, dynamic>) {
            final errorMsg =
                data['error']?.toString() ??
                'Could not create Stripe checkout.';
            debugPrint('[StripeService] Server error: $errorMsg');
            return {'error': errorMsg};
          }
        } catch (e) {
          debugPrint('[StripeService] Error parsing response: $e');
          // Fall through to generic message below.
        }
        return {
          'error': 'Could not create Stripe checkout (${response.statusCode}).',
        };
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final checkoutUrl = data['url'] as String?;
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        debugPrint('[StripeService] No checkout URL in response');
        return {'error': 'No checkout URL returned from server.'};
      }

      debugPrint('[StripeService] Opening checkout URL: $checkoutUrl');
      final launched = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        debugPrint('[StripeService] Failed to launch URL');
        return {'error': 'Could not open Stripe checkout.'};
      }

      debugPrint('[StripeService] Checkout opened successfully');
      return {...data, 'gateway': 'stripe', 'web_redirect': true};
    } on http.ClientException catch (e) {
      debugPrint(
        '[StripeService] ClientException - Network error: ${e.message}',
      );
      debugPrint('[StripeService] This usually means:');
      debugPrint('[StripeService]   1. No internet connection');
      debugPrint(
        '[StripeService]   2. Firebase Functions endpoint unreachable',
      );
      debugPrint('[StripeService]   3. DNS resolution failed');
      return {
        'error':
            'Network error: Unable to reach payment server. Please check your internet connection.',
      };
    } on TimeoutException catch (e) {
      debugPrint('[StripeService] TimeoutException: $e');
      return {'error': 'Request timed out. Please try again.'};
    } on SocketException catch (e) {
      debugPrint('[StripeService] SocketException: $e');
      return {
        'error': 'Connection failed. Please check your internet connection.',
      };
    } catch (e, stackTrace) {
      debugPrint('[StripeService] Unexpected error: $e');
      debugPrint('[StripeService] Stack trace: $stackTrace');
      return {'error': 'Payment error: ${e.toString()}'};
    }
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
          'post_id': ?postId,
          'slot_id': ?slotId,
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
