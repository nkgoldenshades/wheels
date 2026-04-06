// Test script to verify payment provider setup
// Run this in your Flutter app to test the payment provider functionality

import 'package:flutter/foundation.dart';
import 'services/profile_repository.dart';

class PaymentProviderTest {
  static Future<void> runTests() async {
    if (kDebugMode) print('🧪 Testing Payment Provider Setup...');
    
    try {
      // Test 1: Check if profile loads with payment provider fields
      final profile = ProfileRepository.instance.profile.value;
      if (profile.id.isNotEmpty) {
        if (kDebugMode) {
          print('✅ Profile loaded:');
          print('  - Payment Provider: ${profile.paymentProvider}');
          print('  - Wallet Balance: ₹${profile.walletBalance}');
          print('  - Country: ${profile.country ?? 'Not set'}');
          print('  - Stripe Account: ${profile.stripeAccountId ?? 'Not set'}');
          print('  - Razorpay Account: ${profile.razorpayAccountId ?? 'Not set'}');
        }
      } else {
        if (kDebugMode) print('❌ No profile loaded');
        return;
      }
      
      // Test 2: Test country update (should auto-set payment provider)
      if (kDebugMode) print('🧪 Testing country update...');
      await ProfileRepository.instance.updateCountry('IN');
      
      final updatedProfile = ProfileRepository.instance.profile.value;
      if (updatedProfile.paymentProvider == 'razorpay') {
        if (kDebugMode) print('✅ Country update works - set to Razorpay for India');
      } else {
        if (kDebugMode) print('❌ Country update failed');
      }
      
      // Test 3: Test wallet balance update
      if (kDebugMode) print('🧪 Testing wallet balance update...');
      await ProfileRepository.instance.updateWalletBalance(100.0);
      
      final balanceProfile = ProfileRepository.instance.profile.value;
      if (balanceProfile.walletBalance == 100.0) {
        if (kDebugMode) print('✅ Wallet balance update works');
      } else {
        if (kDebugMode) print('❌ Wallet balance update failed');
      }
      
      // Test 4: Test payment provider routing logic
      if (kDebugMode) print('🧪 Testing payment provider routing...');
      final provider = balanceProfile.paymentProvider;
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
      print('  Provider: ${profile.paymentProvider}');
      print('  Country: ${profile.country ?? 'Not set'}');
      print('  Wallet: ₹${profile.walletBalance}');
      print('  Can withdraw: ${profile.walletBalance > 0 ? 'Yes' : 'No'}');
      
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

// Usage in your app:
// await PaymentProviderTest.runTests();
// PaymentProviderTest.printPaymentProviderInfo();