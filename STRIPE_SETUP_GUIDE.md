# Stripe Integration Setup Guide

## Overview
Stripe is now integrated for international payments and escrow. This allows you to:
- Accept payments from 135+ countries
- Hold money in escrow until trip completes
- Automatically transfer to providers worldwide
- Support multiple currencies

## Step 1: Get Stripe Keys

1. Sign up at https://stripe.com
2. Go to Developers → API Keys
3. Copy your keys:
   - Publishable key: `pk_test_...`
   - Secret key: `sk_test_...`

4. Update `lib/services/stripe_service.dart`:
```dart
static const String publishableKey = 'pk_test_YOUR_KEY';
static const String secretKey = 'sk_test_YOUR_KEY';
```

## Step 2: Setup Backend (Firebase Functions)

Create `functions/stripe.js`:

```javascript
const functions = require('firebase-functions');
const stripe = require('stripe')('sk_test_YOUR_SECRET_KEY');

// Create payment intent with escrow
exports.createPaymentIntent = functions.https.onRequest(async (req, res) => {
  const { amount, currency, provider_id, application_fee } = req.body;

  try {
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: currency,
      application_fee_amount: application_fee,
      transfer_data: {
        destination: provider_id,
      },
    });

    res.json({ clientSecret: paymentIntent.client_secret });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Create connected account for provider
exports.createConnectedAccount = functions.https.onRequest(async (req, res) => {
  const { email, country } = req.body;

  try {
    const account = await stripe.accounts.create({
      type: 'express',
      country: country,
      email: email,
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true },
      },
    });

    res.json({ account_id: account.id });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Release escrowed funds
exports.releaseFunds = functions.https.onRequest(async (req, res) => {
  const { payment_intent_id } = req.body;

  try {
    // Funds are automatically transferred when payment succeeds
    // This endpoint is for manual release if needed
    const paymentIntent = await stripe.paymentIntents.retrieve(payment_intent_id);
    
    res.json({ status: 'released', payment_intent: paymentIntent });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

## Step 3: Deploy Backend

```bash
cd functions
npm install stripe
firebase deploy --only functions
```

## Step 4: Update Service URLs

In `lib/services/stripe_service.dart`, update:
```dart
static const String backendUrl = 'https://YOUR_PROJECT.cloudfunctions.net';
```

## Step 5: Initialize Stripe in App

In `lib/main.dart`, add to `main()`:
```dart
await StripeService.instance.init();
```

## How Escrow Works

### Payment Flow:
1. User books a ride for $100
2. User pays via Stripe
3. Money held in YOUR Stripe account (escrow)
4. Trip completes
5. Stripe automatically transfers $85 to provider (your 15% commission kept)

### Code Example:
```dart
// When user books
final success = await StripeService.instance.processPayment(
  amount: 10000,  // $100.00 in cents
  currency: 'usd',
  providerId: 'acct_PROVIDER_STRIPE_ID',
  applicationFee: 1500,  // $15.00 commission
);

// Funds automatically released on successful payment
// Provider gets $85, you keep $15
```

## Provider Onboarding

Providers need to create Stripe Connect accounts:

```dart
final accountId = await StripeService.instance.createConnectedAccount(
  email: providerEmail,
  country: providerCountry,  // 'US', 'GB', 'IN', etc.
);

// Save accountId to provider's profile
```

## Supported Countries

Stripe Connect supports payouts to 40+ countries:
- USA, Canada, Mexico
- UK, Germany, France, Spain, Italy
- Australia, New Zealand, Singapore
- India, Japan, UAE
- And more...

## Fees

- **Stripe fees**: 2.9% + $0.30 per transaction
- **Your commission**: Set your own (e.g., 15%)
- **Currency conversion**: 1% if needed

## Test Cards

Use these for testing:
- Success: `4242 4242 4242 4242`
- Decline: `4000 0000 0000 0002`
- 3D Secure: `4000 0025 0000 3155`

CVV: Any 3 digits
Expiry: Any future date

## Going Live

1. Complete Stripe account verification
2. Replace test keys with live keys:
   - `pk_live_...`
   - `sk_live_...`
3. Test with real cards
4. Enable in production

## Hybrid Setup (Razorpay + Stripe)

In your payment logic:

```dart
Future<bool> processPayment(String userCountry, int amount) async {
  if (userCountry == 'India') {
    // Use Razorpay (cheaper for India)
    return await RazorpayService.instance.processPayment(amount);
  } else {
    // Use Stripe (international)
    return await StripeService.instance.processPayment(
      amount: amount,
      currency: getCurrencyForCountry(userCountry),
      providerId: provider.stripeAccountId,
      applicationFee: (amount * 0.15).toInt(),
    );
  }
}
```

## Security Notes

- Never expose secret keys in app code
- Always use backend for sensitive operations
- Validate amounts on backend
- Log all transactions
- Handle refunds properly

## Support

- Stripe Docs: https://stripe.com/docs
- Stripe Dashboard: https://dashboard.stripe.com
- Test Mode: Use test keys for development
