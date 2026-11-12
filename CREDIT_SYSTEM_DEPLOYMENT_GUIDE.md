# 🚀 Credit System Deployment Guide

Complete step-by-step guide to deploy the credit payment system to production.

---

## Phase 1: Pre-Deployment (Environment Setup)

### 1.1 Stripe Account Setup

**If you don't have a Stripe account:**
1. Go to https://stripe.com
2. Click "Start now" → Create account
3. Complete identity verification (5-10 min)
4. Verify bank account (2-3 days)

**Get API Keys:**
1. Login to Stripe Dashboard
2. Go to Developers → API keys
3. Copy:
   - Secret key: `sk_live_xxxxx...` (KEEP PRIVATE)
   - Publishable key: `pk_live_xxxxx...` (public)

**Setup Webhook:**
1. Go to Developers → Webhooks
2. Click "Add endpoint"
3. URL: `https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/stripeWebhook`
4. Events: `payment_intent.succeeded`, `payment_intent.payment_failed`
5. Copy signing secret: `whsec_xxxxx...`

### 1.2 Firebase Configuration

**Verify Firebase Setup:**
```bash
firebase projects:list
firebase apps:list
```

Expected: Your QuickOHunt Firebase project listed

**Set Environment Variables:**
```bash
# Option A: Via Firebase Console (recommended for production)
firebase functions:config:set \
  stripe.secret_key="sk_live_xxxxx" \
  stripe.publishable_key="pk_live_xxxxx" \
  stripe.webhook_secret="whsec_xxxxx" \
  supabase.url="https://xxxx.supabase.co" \
  supabase.service_role_key="eyJhbGc..."

# Option B: Via .env file
# Copy .env.credit-system.example to .env.local
# Fill in your credentials
```

### 1.3 Supabase Configuration

**Get Supabase Credentials:**
1. Login to Supabase: https://app.supabase.com
2. Select your project
3. Go to Settings → API
4. Copy:
   - Project URL: `https://xxxx.supabase.co`
   - Service role key (look for "service_role" JWT)

**Verify Database Connection:**
```bash
# Test connection
psql "postgresql://postgres:PASSWORD@xxxx.supabase.co:5432/postgres"
```

---

## Phase 2: Database Deployment

### 2.1 Run SQL Migration

**Step 1: Open Supabase SQL Editor**
1. Go to https://app.supabase.com → Your project
2. SQL Editor (left sidebar)
3. Click "New Query"

**Step 2: Copy SQL Script**
1. Open `setup_credit_system.sql`
2. Copy entire content

**Step 3: Paste and Run**
1. Paste into SQL Editor
2. Review changes
3. Click "Run" (or Ctrl+Enter)

**Step 4: Verify**
```sql
-- Run in SQL Editor to verify:

-- Check tables exist
SELECT tablename FROM pg_tables 
WHERE schemaname='public' 
AND tablename IN ('credit_transactions', 'credit_packages', 'stripe_payment_records');

-- Check functions exist
SELECT proname FROM pg_proc 
WHERE proname IN ('deduct_credits', 'add_bonus_credits', 'give_signup_bonus');

-- Check profiles_private has column
SELECT column_name FROM information_schema.columns 
WHERE table_name='profiles_private' AND column_name='ai_credits_available';

-- Sample query (should show all 4 packages)
SELECT * FROM credit_packages;
```

Expected output:
```
✅ All 3 tables exist
✅ All 3 functions exist
✅ Column exists in profiles_private
✅ 4 credit packages inserted
```

---

## Phase 3: Firebase Functions Deployment

### 3.1 Prepare Functions

**Step 1: Navigate to functions directory**
```bash
cd functions
```

**Step 2: Install dependencies**
```bash
npm install
```

**Step 3: Create .env.local** (if using Option B from 1.2)
```bash
# Copy and fill in your credentials
cp .env.credit-system.example .env.local
```

### 3.2 Test Locally (Optional)

**Start emulator:**
```bash
npm run dev
# Or: npm run serve
```

**Test payment intent creation:**
```bash
# In another terminal:
curl -X POST http://localhost:5001/quickohunt/us-central1/createStripePaymentIntent \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "amountCents": 499,
      "credits": 100,
      "packageId": "basic",
      "userEmail": "test@example.com"
    }
  }'
```

### 3.3 Deploy to Firebase

**Deploy all credit functions:**
```bash
firebase deploy --only functions:createStripePaymentIntent,functions:confirmStripePayment,functions:handleFailedStripePayment,functions:getStripePaymentStatus,functions:getCreditPackages,functions:getUserCreditTransactions,functions:stripeWebhook
```

Or deploy all functions:
```bash
firebase deploy --only functions
```

**Verify deployment:**
```bash
firebase functions:list
```

Expected: All 7 functions listed as "Deployed"

---

## Phase 4: Flutter App Updates

### 4.1 Add Dependencies

**Edit `pubspec.yaml`:**
```yaml
dependencies:
  flutter_stripe: ^11.0.0
  cloud_functions: ^5.0.0  # Already present
  # ... other dependencies
```

**Run:**
```bash
flutter pub get
```

### 4.2 Initialize in main.dart

**Find the main() function:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ... existing Firebase initialization ...
  
  // Add after Firebase/Supabase init:
  await CreditRepository.instance.init();
  
  runApp(const MyApp());
}
```

### 4.3 Integrate with AI Service

**In `voice_ai_service.dart` or wherever AI messages are sent:**

Before sending:
```dart
// Check if user has enough credits
final inputTokens = estimateInputTokens(userMessage); // Your estimation
final outputTokens = 0; // Estimate conservatively

if (!CreditRepository.instance.hasEnoughCredits(
  inputTokens: inputTokens,
  outputTokens: outputTokens,
)) {
  throw Exception('Insufficient credits. Please purchase more.');
}
```

After Gemini response:
```dart
// Deduct actual credits based on token usage
final success = await CreditRepository.instance.deductCredits(
  inputTokens: response.usageMetadata.promptTokenCount,
  outputTokens: response.usageMetadata.candidatesTokenCount,
);

if (!success) {
  // Log error but don't fail - transaction may sync later
  debugPrint('Warning: Failed to record credit deduction');
}
```

### 4.4 Add UI Components

**In settings/profile screen:**
```dart
ListTile(
  title: const Text('Buy Credits'),
  subtitle: ValueListenableBuilder<int>(
    valueListenable: CreditRepository.instance.creditBalance,
    builder: (context, balance, _) => Text('Balance: $balance'),
  ),
  trailing: const Icon(Icons.arrow_forward),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const BuyCreditsScreen()),
  ),
)
```

**In chat/message screen (show balance):**
```dart
ValueListenableBuilder<int>(
  valueListenable: CreditRepository.instance.creditBalance,
  builder: (context, balance, _) => Chip(
    label: Text('$balance credits'),
    backgroundColor: balance > 0 ? Colors.green : Colors.red,
  ),
)
```

---

## Phase 5: Testing & Verification

### 5.1 Local Testing

**Step 1: Start development server**
```bash
flutter run
```

**Step 2: Create test account**
- Sign up with test email
- Should automatically get 50 credits

**Step 3: Test purchasing**
1. Go to Settings → Buy Credits
2. Select "Basic" package
3. Click "Buy Credits"
4. Enter Stripe test card: `4242 4242 4242 4242`
5. Expiry: Future date (e.g., 12/25)
6. CVC: Any 3 digits (e.g., 123)
7. Verify:
   - ✅ Balance increased by 100
   - ✅ Transaction appears in history

**Step 4: Test credit deduction**
1. Send AI message
2. Verify:
   - ✅ Message sent successfully
   - ✅ Balance decreased by ~1 credit
   - ✅ Transaction recorded with type="usage"

### 5.2 Staging Testing

**Deploy to staging build:**
```bash
flutter build apk --release --flavor staging
# Or for iOS:
flutter build ipa --release --flavor staging
```

**Test full flow:**
1. Install staging build
2. Create account
3. Test purchasing (actual Stripe live keys)
4. Verify balance and transactions
5. Test message sending

### 5.3 Production Readiness Checklist

- [ ] SQL migration verified in Supabase
- [ ] All Cloud Functions deployed
- [ ] Environment variables set in Firebase Console
- [ ] Stripe webhook configured and tested
- [ ] Flutter app initialized with CreditRepository
- [ ] AI service wired to deduct credits
- [ ] Buy Credits UI integrated
- [ ] Test purchases work (Stripe test card)
- [ ] Test credit deduction works
- [ ] Balance persists across app restarts
- [ ] Transaction history visible
- [ ] Error messages clear and helpful

---

## Phase 6: Production Deployment

### 6.1 Final Checks

```bash
# Firebase
firebase functions:list
firebase functions:log

# Supabase - Run in SQL Editor
SELECT COUNT(*) FROM credit_packages;  -- Should be 4
SELECT COUNT(*) FROM credit_transactions;  -- Should be > 0 if tested

# Stripe
# Go to Dashboard → Payments
# Should see test transactions if tested
```

### 6.2 Deploy Flutter App

**Build for iOS:**
```bash
flutter build ipa --release
# Upload to App Store Connect
```

**Build for Android:**
```bash
flutter build appbundle --release
# Upload to Google Play Console
```

### 6.3 Enable Stripe Live Mode

**Update Firebase Functions with live keys:**
```bash
firebase functions:config:set \
  stripe.secret_key="sk_live_ACTUAL_KEY" \
  stripe.publishable_key="pk_live_ACTUAL_KEY" \
  stripe.webhook_secret="whsec_ACTUAL_SECRET"

firebase deploy --only functions
```

**Update Flutter with live Stripe publishable key** (if hardcoded):
```dart
// In main.dart or payment_service.dart:
Stripe.publishableKey = 'pk_live_ACTUAL_KEY'; // Update this
```

### 6.4 Verify Live Payments

**Test with real card:**
1. Create account in production
2. Receive 50 free credits
3. Purchase credits with real payment method
4. Verify charge appears in Stripe Dashboard
5. Verify credits appear in user account

---

## Phase 7: Post-Deployment Monitoring

### 7.1 Monitor Firebase Functions

```bash
# View logs
firebase functions:log --only createStripePaymentIntent
firebase functions:log --only confirmStripePayment
firebase functions:log --only stripeWebhook

# Or in Firebase Console:
# Console → Functions → Select function → Logs tab
```

### 7.2 Monitor Stripe

**Payments Dashboard:**
- Dashboard → Payments
- Should see real transactions coming in
- Status should be "succeeded"

**Webhook Deliveries:**
- Developers → Webhooks → View endpoint
- Recent deliveries should show all events
- Status should be green (successful)

### 7.3 Monitor Supabase

**Credit transactions:**
```sql
-- In SQL Editor:
SELECT * FROM credit_transactions 
ORDER BY created_at DESC 
LIMIT 10;
```

**User balances:**
```sql
SELECT id, ai_credits_available FROM profiles_private LIMIT 10;
```

**Payment records:**
```sql
SELECT * FROM stripe_payment_records 
WHERE status != 'succeeded' 
ORDER BY created_at DESC;
```

### 7.4 Set Up Alerts

**Firebase Cloud Function errors:**
- Console → Error Reporting
- Create alert threshold: > 5 errors in 5 min

**Stripe failed payments:**
- Dashboard → Settings → Email notifications
- Enable: Payment failed notifications

---

## Troubleshooting

### Issue: "Functions not deployed"

**Solution:**
```bash
cd functions
npm install
firebase deploy --only functions
```

### Issue: "Payment intent fails with auth error"

**Solution:**
- Check Firebase Function environment variables
- Verify Stripe API keys are correct
- Check Firebase Auth context exists

### Issue: "Webhook not triggering"

**Solution:**
1. Go to Stripe Dashboard → Webhooks
2. Click endpoint
3. Check "Recent deliveries" tab
4. If errors, check Firebase Function logs
5. Verify webhook URL is correct: `https://us-central1-PROJECT_ID.cloudfunctions.net/stripeWebhook`

### Issue: "Credits not deducting"

**Solution:**
1. Verify `deduct_credits` RPC exists: `SELECT * FROM pg_proc WHERE proname='deduct_credits'`
2. Check user has sufficient balance
3. Verify AI service is calling `deductCredits()`
4. Check Firebase Function logs for errors

---

## Rollback Procedure

If issues occur in production:

### Quick Rollback (Minutes)

**Disable credit deduction:**
1. In AI service, comment out `deductCredits()` call
2. Deploy app update
3. Users can still message without deduction

**Disable credit purchases:**
1. Hide "Buy Credits" button in UI
2. Deploy app update
3. Existing users keep their balance

### Full Rollback (if critical bug)

```bash
# Remove Cloud Functions
firebase functions:delete stripeWebhook --force

# Disable database functions
# In Supabase SQL Editor:
DROP FUNCTION IF EXISTS deduct_credits;
DROP TRIGGER IF EXISTS give_signup_bonus_trigger ON profiles_private;

# Revert database (if using git)
git revert <migration-commit>
```

---

## Success Metrics

Monitor these after launch:

| Metric | Target |
|--------|--------|
| Payment success rate | > 95% |
| Webhook delivery rate | > 99% |
| Credit deduction accuracy | 100% |
| User satisfaction | > 4.5/5 |
| Support tickets (credit issues) | < 5/week |

---

## Performance Baseline

After deployment, these are expected:

| Operation | Time |
|-----------|------|
| Create payment intent | 200-500ms |
| Confirm payment | 300-800ms |
| Deduct credits (DB) | < 50ms |
| UI response | < 100ms |
| Webhook processing | < 1s |

---

## Next Steps

After successful deployment:

1. **Monitor:** Check logs daily for first week
2. **Communicate:** Announce feature to users
3. **Support:** Prepare support team for questions
4. **Analytics:** Track conversion, ARPU, retention
5. **Iterate:** A/B test pricing, enhance UX

---

## Support Resources

- **Stripe Support:** https://support.stripe.com
- **Firebase Support:** https://firebase.google.com/support
- **Supabase Support:** https://supabase.com/support
- **Flutter Stripe Plugin:** https://github.com/flutter-stripe/flutter_stripe

---

**Congratulations! 🎉 Your credit payment system is live!**
