# ✅ Credit System Setup Checklist

Complete this checklist to fully integrate the credit payment system.

## 🗄️ Database (Complete ✅)

- [x] Create `ai_credits_available` column in `profiles_private`
- [x] Create `credit_transactions` table with indexes
- [x] Create `credit_packages` table (reference data)
- [x] Create `stripe_payment_records` table
- [x] Add RLS policies for privacy
- [x] Create `deduct_credits()` function
- [x] Create `add_bonus_credits()` function
- [x] Add signup bonus trigger (50 credits)

**Action:** Run SQL migration:
```bash
# In Supabase SQL editor:
# Copy content from: e:\quickohunt\setup_credit_system.sql
# Paste and run
```

---

## 🔧 Firebase Cloud Functions (Complete ✅)

- [x] Create `credit-payment-functions.ts`
- [x] Implement `createStripePaymentIntent`
- [x] Implement `confirmStripePayment`
- [x] Implement `handleFailedStripePayment`
- [x] Implement `getStripePaymentStatus`
- [x] Implement `getCreditPackages`
- [x] Implement `getUserCreditTransactions`
- [x] Implement webhook handler `stripeWebhook`

**Action:** Deploy functions
```bash
cd functions
npm install
firebase deploy --only functions
```

---

## 📦 Flutter Dependencies

- [ ] Update `pubspec.yaml` with `flutter_stripe: ^11.0.0`
- [ ] Run `flutter pub get`

**Action:**
```bash
# Open pubspec.yaml and add:
dependencies:
  flutter_stripe: ^11.0.0
  
# Then run:
flutter pub get
```

---

## 📱 Flutter Code (Complete ✅)

- [x] Create `CreditPackage` model (`lib/models/credit_package.dart`)
- [x] Create `CreditTransaction` model (`lib/models/credit_transaction.dart`)
- [x] Create `CreditRepository` service (`lib/services/credit_repository.dart`)
- [x] Create `CreditPaymentService` (`lib/services/credit_payment_service.dart`)
- [x] Create `BuyCreditsScreen` UI (`lib/screens/credits/buy_credits_screen.dart`)
- [x] Create `CreditHistoryScreen` UI

**Action:** Files already created ✅

---

## 🌍 Environment Configuration

- [ ] Set Stripe API keys in Firebase Functions
- [ ] Set Supabase credentials in Firebase Functions
- [ ] Configure Stripe webhook endpoint
- [ ] Add Firebase Function URLs to Flutter app

**Actions:**

### 1. Firebase Functions Environment
```bash
# In Firebase Console → Functions → credit-payment-functions → Runtime settings:

STRIPE_SECRET_KEY=sk_live_xxxxxxxxxxxx
STRIPE_PUBLISHABLE_KEY=pk_live_xxxxxxxxxxxx
STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxxxxxx
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...
```

### 2. Stripe Webhook Setup
```
1. Go to Stripe Dashboard → Webhooks
2. Click "Add endpoint"
3. URL: https://us-central1-{project-id}.cloudfunctions.net/stripeWebhook
4. Events: payment_intent.succeeded, payment_intent.payment_failed
5. Copy signing secret → STRIPE_WEBHOOK_SECRET above
```

---

## 🔌 Integration Hooks

- [ ] Initialize `CreditRepository` in `main.dart`
- [ ] Hook AI service to deduct credits on message
- [ ] Add credit balance indicator to UI
- [ ] Add "Buy Credits" button to settings/profile

**Actions:**

### 1. Initialize in `main.dart`
```dart
void main() async {
  // ... existing code ...
  
  // Initialize repos
  await AuthRepository.instance.init();
  await ProfileRepository.instance.init();
  await CreditRepository.instance.init();  // ← Add this
  
  runApp(const MyApp());
}
```

### 2. Hook AI Service (in `voice_ai_service.dart` or `ai_service.dart`)
```dart
// Check credits before sending
final hasCredits = CreditRepository.instance.hasEnoughCredits(
  inputTokens: estimatedTokens,
  outputTokens: 0, // estimate 0 for now
);

if (!hasCredits) {
  throw 'Insufficient credits. Please purchase more.';
}

// After getting Gemini response
await CreditRepository.instance.deductCredits(
  inputTokens: response.usageMetadata.promptTokenCount,
  outputTokens: response.usageMetadata.candidatesTokenCount,
);
```

### 3. Add UI Components
```dart
// In settings/profile screen:
ListTile(
  title: Text('Buy Credits'),
  subtitle: ValueListenableBuilder<int>(
    valueListenable: CreditRepository.instance.creditBalance,
    builder: (context, balance, _) => Text('Balance: $balance'),
  ),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const BuyCreditsScreen()),
  ),
)
```

---

## ✅ Verification Steps

After deployment, verify each component:

### 1. Database
```sql
-- In Supabase SQL Editor:

-- Check profiles_private has ai_credits_available
SELECT column_name FROM information_schema.columns 
WHERE table_name='profiles_private' AND column_name='ai_credits_available';

-- Check tables exist
SELECT tablename FROM pg_tables WHERE schemaname='public' 
AND tablename IN ('credit_transactions', 'credit_packages', 'stripe_payment_records');

-- Check new user gets 50 credits
SELECT id, ai_credits_available FROM profiles_private LIMIT 1;
```

Expected: 
✅ Column exists
✅ All tables exist  
✅ New user has 50 credits

### 2. Firebase Functions
```bash
# Check deployment
firebase functions:list

# View logs
firebase functions:log --only createStripePaymentIntent
```

Expected:
✅ All functions listed
✅ No errors in logs

### 3. Flutter App
```dart
// In main.dart debug section:
print('Credit balance: ${CreditRepository.instance.creditBalance.value}');
print('Transactions: ${CreditRepository.instance.transactions.value.length}');
```

Expected:
✅ Balance is 50 for new user
✅ Can navigate to BuyCreditsScreen without errors

### 4. Test Payment (using Stripe test card)
1. Open app → Go to Settings/Profile
2. Tap "Buy Credits"
3. Select "Basic" package (100 credits, $4.99)
4. Click "Buy Credits"
5. Enter test card: `4242 4242 4242 4242`, future expiry, any CVC
6. Complete payment

Expected:
✅ Payment sheet opens
✅ Card accepted
✅ Redirect to success screen
✅ Balance increases by 100
✅ Transaction recorded in history

---

## 📊 Monitoring & Debugging

### Common Issues

**"Firebase Functions not available"**
- [ ] Verify functions are deployed: `firebase functions:list`
- [ ] Check function regions match in code and Firebase

**"Payment intent creation failed"**
- [ ] Verify Stripe API keys are set in Functions
- [ ] Check Stripe webhook is configured
- [ ] View logs: `firebase functions:log`

**"Insufficient credits" after purchase**
- [ ] Check `stripe_payment_records.status` is 'succeeded'
- [ ] Verify webhook was received: Stripe Dashboard → Webhooks
- [ ] Check `profiles_private.ai_credits_available` updated

**Credits not deducted**
- [ ] Verify `deduct_credits()` RPC exists: Check Supabase functions list
- [ ] Check user has sufficient balance before deduction
- [ ] View logs in Firebase Functions

### Debug Commands

```bash
# View Firebase logs
firebase functions:log

# Query credit balance in Supabase
# In SQL Editor:
SELECT id, ai_credits_available FROM profiles_private WHERE id = 'USER_ID';

# Check transactions
SELECT * FROM credit_transactions WHERE user_id = 'USER_ID' ORDER BY created_at DESC;

# Check payment records
SELECT * FROM stripe_payment_records WHERE user_id = 'USER_ID';
```

---

## 🎯 Final Verification

- [ ] New users get 50 credits on signup
- [ ] Buy credits screen loads and displays packages
- [ ] Test card payment succeeds
- [ ] Credits appear in balance after purchase
- [ ] Transaction appears in history
- [ ] Credits deduct when sending AI message
- [ ] Error shown when insufficient credits

---

## 📚 Documentation Files

All implementation files are ready:

| File | Purpose |
|------|---------|
| `setup_credit_system.sql` | Database schema + functions |
| `lib/models/credit_package.dart` | Credit package model |
| `lib/models/credit_transaction.dart` | Transaction history |
| `lib/services/credit_repository.dart` | Credit state management |
| `lib/services/credit_payment_service.dart` | Stripe integration |
| `lib/screens/credits/buy_credits_screen.dart` | Purchase & history UI |
| `functions/src/credit-payment-functions.ts` | Cloud functions |
| `CREDIT_SYSTEM_INTEGRATION_GUIDE.md` | Complete guide |
| `CREDIT_SYSTEM_SETUP_CHECKLIST.md` | This file |

---

## 🚀 Quick Start Summary

```
1. Run SQL migration in Supabase
2. Deploy Firebase Functions (5 functions)
3. Add flutter_stripe to pubspec.yaml
4. Initialize CreditRepository in main.dart
5. Hook AI service to deductCredits()
6. Add UI for BuyCreditsScreen
7. Test with Stripe test card
8. Deploy to production
```

**Estimated time:** 30 minutes for full setup

---

## ❓ Support

Refer to:
1. **Integration Guide:** `CREDIT_SYSTEM_INTEGRATION_GUIDE.md`
2. **Database Schema:** Comments in `setup_credit_system.sql`
3. **Code Comments:** In-line in service files
4. **Stripe Docs:** https://stripe.com/docs/stripe-js
5. **Firebase Functions Docs:** https://firebase.google.com/docs/functions
