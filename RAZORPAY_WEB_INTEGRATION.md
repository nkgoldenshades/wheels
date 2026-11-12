# Razorpay Web Integration Guide

## Problem
You're seeing a blank screen when trying to process Razorpay payments on Flutter Web. This happens because:

1. **Invalid Payment Link**: The code was using a placeholder URL (`/l/quickohunt`) that doesn't exist
2. **URL Launcher Limitation**: `url_launcher` can't properly handle Razorpay checkout flows on web
3. **Missing Web Integration**: Razorpay requires their Checkout.js script for web payments

## Current Status
✅ **Fixed**: Razorpay Checkout.js script added to `web/index.html`  
⚠️ **Partial**: Web payments now show a helpful error instead of blank screen  
❌ **Not Implemented**: Full JavaScript interop for web checkout

## Solutions (Choose One)

### Option 1: Use Mobile App (Recommended for Now)
The Razorpay Flutter SDK works perfectly on Android/iOS. Direct users to:
```bash
flutter run -d android
# or
flutter run -d ios
```

### Option 2: Implement Razorpay Web Checkout (Full Solution)

#### Step 1: Add JS Interop Package
```yaml
# pubspec.yaml
dependencies:
  js: ^0.6.7
```

#### Step 2: Create Razorpay Web Handler
Create `lib/services/razorpay_web_handler.dart`:

```dart
@JS()
library razorpay_web;

import 'package:js/js.dart';
import 'dart:html' as html;

@JS('Razorpay')
class RazorpayJS {
  external factory RazorpayJS(RazorpayOptions options);
  external void open();
}

@JS()
@anonymous
class RazorpayOptions {
  external factory RazorpayOptions({
    String key,
    int amount,
    String currency,
    String name,
    String description,
    dynamic prefill,
    dynamic theme,
    Function handler,
  });
}

void openRazorpayCheckout({
  required String keyId,
  required int amountInPaise,
  required String description,
  required String userEmail,
  required String userPhone,
  required String userName,
  required Function(String paymentId) onSuccess,
  required Function(String error) onFailure,
}) {
  final options = RazorpayOptions(
    key: keyId,
    amount: amountInPaise,
    currency: 'INR',
    name: 'VaultWheels',
    description: description,
    prefill: {
      'email': userEmail,
      'contact': userPhone,
      'name': userName,
    },
    theme: {'color': '#1976D2'},
    handler: allowInterop((response) {
      onSuccess(response['razorpay_payment_id']);
    }),
  );
  
  final rzp = RazorpayJS(options);
  rzp.open();
}
```

#### Step 3: Update RazorpayService
```dart
Future<Map<String, dynamic>> _processWebPayment({...}) async {
  if (kIsWeb) {
    final completer = Completer<Map<String, dynamic>>();
    
    openRazorpayCheckout(
      keyId: _keyId,
      amountInPaise: amountInPaise,
      description: description,
      userEmail: userEmail,
      userPhone: userPhone,
      userName: userName,
      onSuccess: (paymentId) {
        completer.complete({'payment_id': paymentId});
      },
      onFailure: (error) {
        completer.complete({'error': error});
      },
    );
    
    return completer.future;
  }
}
```

### Option 3: Use Stripe Instead (Easier for Web)
Stripe has better web support. Your app already has Stripe integration:

```dart
// In booking flow, use Stripe for web users
if (kIsWeb) {
  // Use StripeService
  final result = await StripeService.instance.createCheckoutSession(...);
} else {
  // Use RazorpayService for mobile
  final result = await RazorpayService.instance.processPayment(...);
}
```

### Option 4: Backend Payment Links (Simplest)
Generate payment links from your backend using Razorpay Payment Links API:

```dart
Future<Map<String, dynamic>> _processWebPayment({...}) async {
  // Call your backend to create a payment link
  final response = await http.post(
    Uri.parse('https://your-backend.com/api/create-payment-link'),
    body: json.encode({
      'amount': amountInPaise,
      'description': description,
      'customer': {
        'email': userEmail,
        'contact': userPhone,
        'name': userName,
      },
    }),
  );
  
  final data = json.decode(response.body);
  final paymentLink = data['short_url'];
  
  // Open the payment link
  await launchUrl(Uri.parse(paymentLink), mode: LaunchMode.externalApplication);
  
  return {'web_redirect': true, 'payment_link': paymentLink};
}
```

## Quick Fix for Testing
For development/testing, the service now returns a helpful error instead of showing a blank screen. Users will see:

```
Web payments require additional setup.

Options:
1. Use the mobile app for seamless payments
2. Contact support for web payment link
3. Switch to Stripe (supports web better)
```

## Testing
After implementing any solution:

```bash
# Test on web
flutter run -d chrome

# Test on mobile (where it already works)
flutter run -d android
```

## Recommended Approach
1. **Short term**: Direct web users to download the mobile app
2. **Medium term**: Implement Option 4 (Backend Payment Links) - easiest and most reliable
3. **Long term**: Implement Option 2 (Full JS Interop) for seamless web experience

## Additional Resources
- [Razorpay Web Integration Docs](https://razorpay.com/docs/payments/payment-gateway/web-integration/)
- [Razorpay Payment Links API](https://razorpay.com/docs/payments/payment-links/)
- [Flutter Web JS Interop](https://dart.dev/web/js-interop)
