# 💳 Payment Gateway Routing - How It Works

## 🎯 Your Requirement

**Provider creates post:**
- If provider has **Razorpay** → Post must be in **INR**
- If provider has **Stripe** → Post can be in **USD/EUR/etc**

**Customer pays for booking:**
- Customer should use the **SAME gateway** as the provider's payout method
- This ensures the money goes to the correct payout account

---

## ✅ Current Implementation (Already Working!)

### 1️⃣ Post Creation - Currency Determination

**File:** `lib/screens/add_flow/create_post_screen.dart` (lines 310-335)

```dart
String _determineCurrencyType() {
  final currentUser = ProfileRepository.instance.profile.value;

  // Step 1: Check if user has bank currency set
  final bankCurrency = currentUser.bankCurrency;
  if (bankCurrency != null && bankCurrency.isNotEmpty) {
    return bankCurrency.toUpperCase();  // Use bank currency
  }

  // Step 2: Fallback to payment provider
  final paymentProvider = currentUser.paymentProvider;
  
  if (paymentProvider == 'razorpay') {
    return 'INR';  // Razorpay → INR
  } else if (paymentProvider == 'stripe') {
    return 'USD';  // Stripe → USD (default)
  }

  // Step 3: Default
  return 'INR';
}
```

**How it works:**
1. Provider selects **Razorpay** → Post currency = **INR** ✓
2. Provider selects **Stripe** → Post currency = **USD** ✓
3. Provider's `bankCurrency` is set when they connect their account

---

### 2️⃣ Bank Currency Setting

**When Provider Connects Payment Account:**

#### Razorpay Connection:
```dart
// File: lib/services/profile_repository.dart (line 663-666)
Future<void> updateRazorpayAccountId(String accountId) async {
  // Razorpay is India-only, always INR
  await saveProfile(
    p.copyWith(
      razorpayAccountId: accountId, 
      bankCurrency: 'INR'  // ← Automatically set to INR
    )
  );
}
```

#### Stripe Connection:
```dart
// File: lib/services/profile_repository.dart (line 647-656)
Future<void> updateStripeAccountId(String accountId, {String? currency}) async {
  final bankCurrency =
    currency ??
    (accountId.startsWith('acct_test_') ? 'USD' : null) ??  // ← Test accounts default to USD
    p.bankCurrency;

  await saveProfile(
    p.copyWith(
      stripeAccountId: accountId, 
      bankCurrency: bankCurrency  // ← Set based on Stripe account
    )
  );
}
```

**Result:**
- Provider connects **Razorpay** → `bankCurrency` = `INR` ✓
- Provider connects **Stripe** (test) → `bankCurrency` = `USD` ✓
- Provider connects **Stripe** (live) → `bankCurrency` = Stripe account currency ✓

---

### 3️⃣ Customer Payment Routing

**File:** `lib/services/payment_service.dart` (lines 180-224)

**Current logic:**
```dart
if (_isIndia(countryCode)) {
  // Route to Razorpay (India)
} else {
  // Route to Stripe (international)
}
```

**Problem:**  
Uses slot `countryCode` instead of provider's payment gateway! ❌

---

## ❌ The Issue

### Current Flow (WRONG):

```
Provider (Stripe, USD bank) creates post
  ↓
Post currency: USD ✓
Post location: India (countryCode = 'IN')
  ↓
Customer tries to book
  ↓
Payment routing checks countryCode = 'IN'
  ↓
Routes to Razorpay ❌ (WRONG! Provider has Stripe!)
  ↓
Payment goes to Razorpay
  ↓
Provider can't receive payout (money in wrong gateway!)
```

### Correct Flow (NEEDED):

```
Provider (Stripe, USD bank) creates post
  ↓
Post currency: USD ✓
Post payment_provider: 'stripe' ✓ (stored in database)
  ↓
Customer tries to book
  ↓
Payment routing checks post.payment_provider = 'stripe'
  ↓
Routes to Stripe ✓ (CORRECT!)
  ↓
Money goes to provider's Stripe account ✓
```

---

## ✅ Solution Needed

### Step 1: Store Provider's Payment Gateway in Post

**Database:** Add `payment_provider` column to `posts` table

```sql
ALTER TABLE posts 
ADD COLUMN payment_provider TEXT;  -- 'razorpay' or 'stripe'
```

### Step 2: Save Payment Provider When Creating Post

**File:** `lib/screens/add_flow/create_post_screen.dart`

```dart
// When creating slot
Slot(
  // ... existing fields
  currencyType: _determineCurrencyType(),
  paymentProvider: currentUser.paymentProvider,  // ← ADD THIS
)
```

### Step 3: Update Payment Routing to Use Provider's Gateway

**File:** `lib/services/payment_service.dart`

```dart
Future<Map<String, dynamic>?> processPayment({
  required String providerId,
  required String slotId,
  String? providerPaymentGateway,  // ← ADD THIS parameter
  // ... other params
}) async {
  
  // NEW LOGIC: Use provider's payment gateway
  if (providerPaymentGateway == 'razorpay') {
    // Route to Razorpay (provider uses Razorpay)
    debugPrint('[PaymentService] Routing to Razorpay (provider preference)');
    // ... Razorpay flow
  } else {
    // Route to Stripe (provider uses Stripe)
    debugPrint('[PaymentService] Routing to Stripe (provider preference)');
    // ... Stripe flow
  }
}
```

---

## 🔄 Complete Flow (After Fix)

### Scenario 1: Provider with Razorpay

```
1. Provider connects Razorpay account
   ↓
2. bankCurrency = 'INR' (auto-set)
   ↓
3. Provider creates post
   ↓
4. Post currency: INR ✓
   Post payment_provider: 'razorpay' ✓
   ↓
5. Post appears in feed showing ₹ prices
   ↓
6. Customer (from anywhere) books the post
   ↓
7. Payment routing: providerPaymentGateway = 'razorpay'
   ↓
8. Routes to Razorpay ✓
   ↓
9. Money goes to provider's Razorpay account ✓
   ↓
10. Provider receives payout in INR ✓
```

### Scenario 2: Provider with Stripe

```
1. Provider connects Stripe account
   ↓
2. bankCurrency = 'USD' (or EUR, GBP, etc.)
   ↓
3. Provider creates post
   ↓
4. Post currency: USD ✓
   Post payment_provider: 'stripe' ✓
   ↓
5. Post appears in feed showing $ prices
   ↓
6. Customer (from anywhere) books the post
   ↓
7. Payment routing: providerPaymentGateway = 'stripe'
   ↓
8. Routes to Stripe ✓
   ↓
9. Money goes to provider's Stripe Connect account ✓
   ↓
10. Provider receives payout in USD ✓
```

---

## 🌍 Multi-Currency Support

Your app supports providers in different countries:

| Provider Location | Payment Gateway | Post Currency | Customer Pays With |
|-------------------|-----------------|---------------|-------------------|
| India | Razorpay | INR (₹) | Razorpay (INR) |
| USA | Stripe | USD ($) | Stripe (USD) |
| UK | Stripe | GBP (£) | Stripe (GBP) |
| UAE | Stripe | AED (د.إ) | Stripe (AED) |
| India | Stripe | INR (₹) | Stripe (INR) |

**Key Point:** Customer always pays in the **same currency** and **same gateway** as provider's payout method!

---

## 💡 Why This Matters

### Without Gateway Matching:
```
Provider (Stripe, USD) creates post
Customer pays via Razorpay (INR)
❌ Money goes to wrong gateway
❌ Provider can't receive payout
❌ Manual intervention needed
```

### With Gateway Matching:
```
Provider (Stripe, USD) creates post
Customer pays via Stripe (USD)
✓ Money goes to provider's Stripe account
✓ Provider receives automatic payout
✓ No manual work needed
```

---

## 📊 Database Schema

### Current `posts` table:
```sql
posts (
  id UUID PRIMARY KEY,
  provider_id UUID,
  currency_type TEXT,  -- 'INR', 'USD', 'EUR', etc.
  price NUMERIC,
  -- ... other fields
)
```

### Needed addition:
```sql
ALTER TABLE posts 
ADD COLUMN payment_provider TEXT;  -- 'razorpay' or 'stripe'

-- Set default for existing posts based on currency
UPDATE posts 
SET payment_provider = CASE 
  WHEN currency_type = 'INR' THEN 'razorpay'
  ELSE 'stripe'
END;
```

---

## ✅ Implementation Checklist

- [ ] Add `payment_provider` column to `posts` table in Supabase
- [ ] Update Slot model to include `paymentProvider` field
- [ ] Save provider's payment gateway when creating post
- [ ] Update `processPayment()` to accept `providerPaymentGateway` parameter
- [ ] Change routing logic from `countryCode` to `providerPaymentGateway`
- [ ] Test Razorpay provider → Razorpay customer payment
- [ ] Test Stripe provider → Stripe customer payment
- [ ] Verify payouts work correctly

---

## 🎯 Summary

**Your system already has most pieces in place:**
- ✅ Currency determination works
- ✅ Bank currency setting works
- ✅ Post creation works

**What needs to be fixed:**
- ❌ Payment routing uses `countryCode` (location-based)
- ✅ Should use `payment_provider` (gateway-based)

**Once fixed:**
- Provider's payout gateway → Determines post currency
- Customer payment → Uses same gateway as provider
- Money flows correctly → Provider gets paid automatically!

**This ensures the payment goes to the RIGHT payout account! 💰**
