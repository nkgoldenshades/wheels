# 💳 Credit Payment System - Integration Guide

## Overview

Complete implementation of a pay-as-you-go credit system for AI message usage. Users purchase credit packages via Stripe, and credits are automatically deducted based on actual Gemini API token consumption.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Flutter App                            │
├─────────────────────────────────────────────────────────┤
│  BuyCreditsScreen                                        │
│  ├─ Select package → CreditPaymentService              │
│  └─ Show Stripe payment sheet                           │
└──────────────────────┬──────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
┌───────▼──────────────┐  ┌──────────▼────────────────┐
│  Stripe Payment Flow │  │  Firebase Cloud Functions │
├──────────────────────┤  ├───────────────────────────┤
│ 1. Create intent     │  │ • createPaymentIntent     │
│ 2. Present sheet     │  │ • confirmPayment          │
│ 3. Confirm payment   │  │ • getPaymentStatus        │
└──────────┬───────────┘  │ • handleFailedPayment     │
           │              │ • stripeWebhook           │
           └──────────────┤ • getCreditPackages       │
                          └───────────┬────────────────┘
                                      │
                          ┌───────────▼────────────┐
                          │   Supabase Database    │
                          ├────────────────────────┤
                          │ profiles_private       │
                          │ ├─ ai_credits_available
                          │                        │
                          │ credit_transactions    │
                          │ ├─ type (purchase/use) │
                          │ ├─ credits_changed     │
                          │ ├─ metadata            │
                          │                        │
                          │ stripe_payment_records │
                          │ ├─ status              │
                          │ └─ payment_intent_id   │
                          └────────────────────────┘
```

## Setup Steps

### 1. Database Setup

Run the SQL migration to create tables and functions:

```bash
# In Supabase SQL editor, run:
psql "postgresql://.../quickohunt" < setup_credit_system.sql
```

This creates:
- ✅ `ai_credits_available` column in `profiles_private`
- ✅ `credit_transactions` table (complete history)
- ✅ `credit_packages` table (predefined packages)
- ✅ `stripe_payment_records` table
- ✅ RLS policies for privacy
- ✅ `deduct_credits()` function (atomic, race-condition safe)
- ✅ `add_bonus_credits()` function
- ✅ Signup trigger (50 credits free)

### 2. Environment Variables

Set these in Firebase Functions and Flutter:

```bash
# Firebase Cloud Functions (.env)
STRIPE_SECRET_KEY=sk_live_...
STRIPE_PUBLISHABLE_KEY=pk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...

# Flutter (pubspec.yaml already has keys from main.dart initialization)
```

### 3. Deploy Cloud Functions

```bash
cd functions
npm install
firebase deploy --only functions:createStripePaymentIntent,functions:confirmStripePayment,functions:handleFailedStripePayment,functions:getStripePaymentStatus,functions:getCreditPackages,functions:getUserCreditTransactions,functions:stripeWebhook
```

### 4. Flutter Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter_stripe: ^11.0.0
  cloud_functions: ^5.0.0
```

### 5. Initialize Credit System in main.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ... existing Firebase/Supabase init ...
  
  // Initialize credit repository
  await CreditRepository.instance.init();
}
```

### 6. Wire Up AI Service to Deduct Credits

In your `voice_ai_service.dart` or `ai_service.dart`:

```dart
// Before sending message to Gemini
final hasCredits = CreditRepository.instance.hasEnoughCredits(
  inputTokens: estimatedInputTokens,
  outputTokens: estimatedOutputTokens,
);

if (!hasCredits) {
  throw Exception('Insufficient credits. Please purchase more.');
}

// After getting response from Gemini
final success = await CreditRepository.instance.deductCredits(
  inputTokens: response.usageMetadata.promptTokenCount,
  outputTokens: response.usageMetadata.candidatesTokenCount,
  relatedBookingId: bookingId, // optional
);

if (!success) {
  // Optionally refund if this was a retry
  debugPrint('Warning: Failed to record credit deduction');
}
```

## Usage

### Buy Credits Screen

```dart
// Navigate to buy credits
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const BuyCreditsScreen()),
);
```

Features:
- ✅ Display current balance
- ✅ Show all packages with pricing
- ✅ Highlight popular packages
- ✅ Show savings percentage
- ✅ Integrated Stripe payment sheet
- ✅ Transaction history

### Check Credit Balance

```dart
ValueListenableBuilder<int>(
  valueListenable: CreditRepository.instance.creditBalance,
  builder: (context, balance, _) {
    return Text('Credits: $balance');
  },
)
```

### Estimate Cost

```dart
final estimatedCost = CreditRepository.estimateCreditCost(
  inputTokens: 250,
  outputTokens: 500,
);
// Returns: 1 credit (costs < $0.06)
```

## Pricing Model

**Base Rate:** 1 credit = $0.06

**Gemini Pricing:**
- Input tokens: $0.30 per 1M tokens
- Output tokens: $2.50 per 1M tokens

**Calculation:**
```
credits_cost = (input_tokens × 0.000000005 + output_tokens × 0.000000417)
            = ⌈(input_tokens × 0.30 + output_tokens × 2.50) / 1_000_000 / 0.06⌉
```

**Example:**
- Input: 250 tokens, Output: 500 tokens
- Cost: (250×0.30 + 500×2.50) / 1,000,000 / 0.06 = 0.0267 credits
- Rounded up: 1 credit

**Package Pricing:**

| Package | Credits | Price | $/Credit | Savings |
|---------|---------|-------|----------|---------|
| Starter | 50 | $2.99 | $0.06 | — |
| Basic | 100 | $4.99 | $0.0499 | 17% |
| Pro | 500 | $19.99 | $0.04 | 33% |
| Enterprise | 1000 | $34.99 | $0.035 | 42% |

## Data Flow Examples

### Purchase Flow

```
1. User selects "Basic" package (100 credits, $4.99)
   ↓
2. CreditPaymentService.createPaymentIntent()
   ├─ Calls Firebase Function
   ├─ Creates Stripe PaymentIntent
   ├─ Returns clientSecret + publishableKey
   ↓
3. Flutter Stripe shows payment sheet
   ├─ User enters card details
   ├─ Stripe processes payment
   ↓
4. User confirms on device
   ├─ Stripe returns success
   ↓
5. CreditPaymentService.confirmPayment()
   ├─ Verifies with Stripe
   ├─ Calls add_bonus_credits() RPC
   ├─ Updates profile: ai_credits_available += 100
   ├─ Records transaction
   ↓
6. CreditRepository.creditBalance updated (optimistic)
   ├─ App shows "100 credits added!"
   ├─ Syncs to local storage
```

### Usage Flow

```
1. User sends AI chat message
   ↓
2. CreditRepository.hasEnoughCredits()
   ├─ Estimates tokens from message
   ├─ Checks balance >= estimated_cost
   ├─ Returns true/false
   ↓
3. If insufficient:
   ├─ Show snackbar: "Need 5 more credits"
   ├─ Offer quick link to buy
   ↓
4. If sufficient:
   ├─ Send message to Gemini API
   ├─ Get response with usage metadata
   ↓
5. CreditRepository.deductCredits()
   ├─ Calculate actual cost from tokens
   ├─ Deduct from balance (optimistic)
   ├─ Record transaction
   ├─ Sync to Supabase (fire-and-forget)
   ↓
6. Show response to user
   ├─ Display new balance
```

## Webhook Setup

Configure Stripe webhook to your Firebase function:

1. Go to Stripe Dashboard → Webhooks
2. Add endpoint: `https://us-central1-{project-id}.cloudfunctions.net/stripeWebhook`
3. Events to listen for:
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`

## Error Handling

**Insufficient Credits:**
```
❌ Error: Insufficient credits (have 2, need 5)
→ Show dialog with option to buy credits
```

**Payment Failed:**
```
❌ Payment failed or cancelled
→ No credits deducted
→ User can retry
```

**Network Offline:**
```
→ Credits deducted locally (optimistic update)
→ Sync queued for when online
→ Worst case: Local balance ≠ server (reconciles on refresh)
```

## Security Considerations

✅ **PCI-DSS Compliant:**
- No payment details stored locally
- All card processing via Stripe
- Firebase Functions handle sensitive data

✅ **Rate Limiting:**
- Firebase Functions have built-in rate limits
- Implement client-side debouncing for deductions

✅ **RLS Policies:**
- Users can only see their own transactions
- Transactions are append-only (immutable)

✅ **Atomic Operations:**
- `deduct_credits()` uses database locks to prevent race conditions
- If payment fails, credits are never deducted

## Testing

### Test Stripe Payments

Use Stripe test cards:
- **Success:** `4242 4242 4242 4242`
- **Decline:** `4000 0000 0000 0002`

```dart
// Test purchasing credits
Future<void> _testPurchase() async {
  final result = await CreditPaymentService.instance.createPaymentIntent(
    amountCents: 499, // $4.99
    credits: 100,
    packageId: 'basic',
  );
  
  print('Payment Intent: ${result['clientSecret']}');
}
```

### Test Credit Deduction

```dart
// Verify credit deduction works
Future<void> _testDeduction() async {
  final success = await CreditRepository.instance.deductCredits(
    inputTokens: 250,
    outputTokens: 500,
  );
  
  print('Deducted: $success');
  print('New balance: ${CreditRepository.instance.creditBalance.value}');
}
```

## Monitoring

**Firebase Functions Console:**
- View logs: Functions → Select function → Logs
- Monitor errors: Functions → Select function → Error Reporting

**Stripe Dashboard:**
- View payments: Payments → Payment intents
- Monitor webhooks: Webhooks → Recent deliveries

**Supabase:**
- Monitor credit balance: SQL Editor → Query `profiles_private`
- View transactions: Query `credit_transactions` table

## Future Enhancements

- [ ] Daily bonus credits (e.g., 5 free credits per day)
- [ ] Referral rewards (get credits for inviting friends)
- [ ] Subscription plans (monthly credits)
- [ ] Credit expiration (e.g., 1 year expiry)
- [ ] Admin panel for credit audits
- [ ] A/B testing pricing tiers
- [ ] Monthly usage analytics/dashboard

## Support

For issues:
1. Check Firebase Functions logs
2. Verify Stripe API keys are correct
3. Ensure Supabase RLS policies allow operations
4. Check network requests in Flutter DevTools
