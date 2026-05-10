// Test script to verify payment provider setup
import 'package:flutter/foundation.dart';
import 'services/profile_repository.dart';

class PaymentProviderTest {
  static Future<void> runTests() async {
    if (kDebugMode) print('🧪 Testing Payment Provider Setup...');

    try {
      final profile = ProfileRepository.instance.profile.value;
      if (profile.id.isNotEmpty) {
        if (kDebugMode) {
          print('✅ Profile loaded:');
          print('  - Payment Provider: ${profile.paymentProvider ?? 'Not set'}');
          print('  - Country: ${profile.country ?? 'Not set'}');
          print('  - Stripe Account: ${profile.stripeAccountId ?? 'Not set'}');
          print('  - Razorpay Account: ${profile.razorpayAccountId ?? 'Not set'}');
        }
      } else {
        if (kDebugMode) print('❌ No profile loaded');
        return;
      }

      // Test: country update (auto-sets payment provider)
      if (kDebugMode) print('🧪 Testing country update...');
      await ProfileRepository.instance.updateCountry('IN');

      final updatedProfile = ProfileRepository.instance.profile.value;
      if (updatedProfile.paymentProvider == 'razorpay') {
        if (kDebugMode) print('✅ Country update works - set to Razorpay for India');
      } else {
        if (kDebugMode) print('❌ Country update failed');
      }

      // Test: payment provider routing
      if (kDebugMode) print('🧪 Testing payment provider routing...');
      final provider = updatedProfile.paymentProvider;
      if (provider == 'razorpay' || provider == 'stripe') {
        if (kDebugMode) print('✅ Payment provider routing works: $provider');
      } else {
        if (kDebugMode) print('❌ Invalid payment provider: $provider');
      }

      if (kDebugMode) print('🎉 Payment Provider Tests Complete!');
    } catch (e) {
      if (kDebugMode) print('❌ Test failed: $e');
    }
  }

  static void printPaymentProviderInfo() {
    final profile = ProfileRepository.instance.profile.value;
    if (profile.id.isEmpty) {
      if (kDebugMode) print('❌ No profile loaded');
      return;
    }

    if (kDebugMode) {
      print('💳 Payment Provider Info:');
      print('  Provider: ${profile.paymentProvider ?? 'Not set'}');
      print('  Country: ${profile.country ?? 'Not set'}');

      if (profile.paymentProvider == 'razorpay') {
        print('  Razorpay Account: ${profile.razorpayAccountId ?? 'Not linked'}');
        print('  Setup needed: ${profile.razorpayAccountId == null ? 'Yes - Add bank details' : 'No'}');
      } else {
        print('  Stripe Account: ${profile.stripeAccountId ?? 'Not linked'}');
        print('  Setup needed: ${profile.stripeAccountId == null ? 'Yes - Complete Stripe onboarding' : 'No'}');
      }
    }
  }
}



