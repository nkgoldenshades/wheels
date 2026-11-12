# 🚀 QuickOHunt Pre-Launch Checklist

## ⚠️ CRITICAL: Payment Configuration Required

Your app **CANNOT accept real payments** until all keys are configured. Currently, most keys are still placeholders.

---

## 📋 MANDATORY STEPS (MUST DO BEFORE LAUNCH)

### ✅ Step 1: Configure Stripe Keys

#### A. Get Stripe LIVE Keys

1. **Go to Stripe Dashboard**: https://dashboard.stripe.com/apikeys
2. **Toggle to LIVE mode** (top-left corner - should say "LIVE" not "TEST")
3. **Copy Two Keys**:
   - **Publishable key**: Starts with `pk_live_` (will be visible)
   - **Secret key**: Starts with `sk_live_` (click "Reveal live key" button)

#### B. Update Backend (Firebase Functions)

Edit: `e:\quickohunt\functions\.env`

```env
# Change this line:
USE_LIVE_KEYS=true

# Update these lines with your actual keys:
STRIPE_SECRET_KEY_LIVE=sk_live_YOUR_ACTUAL_KEY_HERE
STRIPE_WEBHOOK_SECRET_LIVE=whsec_YOUR_WEBHOOK_SECRET_HERE
```

#### C. Update Flutter App

Edit: `e:\quickohunt\lib\services\stripe_service.dart`

```dart
// Line 18: Change to false
static const bool useTestMode = false; // ← PRODUCTION MODE

// Line 25: Add your live publishable key
static const String _livePublishableKey = 'pk_live_YOUR_ACTUAL_KEY_HERE';
```

---

### ✅ Step 2: Configure Razorpay Keys

#### A. Get Razorpay LIVE Keys

1. **Go to Razorpay Dashboard**: https://dashboard.razorpay.com/app/keys
2. **Toggle to LIVE mode** (top-right corner)
3. **Generate Live Keys** (if not already done)
4. **Copy Both Keys**:
   - **Key ID**: Starts with `rzp_live_`
   - **Key Secret**: A long random string

#### B. Update Backend (Firebase Functions)

Edit: `e:\quickohunt\functions\.env`

```env
RAZORPAY_KEY_ID_LIVE=rzp_live_YOUR_ACTUAL_KEY_HERE
RAZORPAY_KEY_SECRET_LIVE=YOUR_ACTUAL_SECRET_HERE
RAZORPAY_WEBHOOK_SECRET_LIVE=YOUR_WEBHOOK_SECRET_HERE
```

#### C. Update Flutter App

Edit: `e:\quickohunt\lib\services\razorpay_service.dart`

```dart
// Line 18: Change to false
static const bool useTestMode = false; // ← PRODUCTION MODE

// Line 24: Add your live key
static const String _liveKeyId = 'rzp_live_YOUR_ACTUAL_KEY_HERE';
```

---

### ✅ Step 3: Configure Supabase Key

#### A. Get Supabase Anon Key

1. **Go to Supabase Dashboard**: https://supabase.com/dashboard
2. **Select Your Project**: `quickohunt-app` or similar
3. **Go to Settings → API**
4. **Copy "anon" public key**: Starts with `eyJ...`

#### B. Update Backend

Edit: `e:\quickohunt\functions\.env`

```env
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.YOUR_ACTUAL_KEY_HERE
```

---

### ✅ Step 4: Enable Stripe Connect (for Provider Payouts)

1. **Go to**: https://dashboard.stripe.com/settings/connect
2. **Enable Stripe Connect**
3. **Set up your platform profile**:
   - Business name: QuickOHunt
   - Business URL: https://vervestrideal.com (or your actual domain)
   - Support email: your@email.com
4. **Configure payout settings**

---

### ✅ Step 5: Deploy Updated Configuration

After updating all keys:

```bash
# 1. Deploy Firebase Functions
cd e:\quickohunt
firebase deploy --only functions

# 2. Wait for deployment to complete (2-3 minutes)

# 3. Verify deployment
firebase functions:list
```

---

### ✅ Step 6: Build Production App

```bash
# For Android
flutter build apk --release

# For iOS (if applicable)
flutter build ipa --release

# For Web
flutter build web --release
```

---

## 🧪 TESTING BEFORE LAUNCH

### Test 1: Stripe Payment (Small Amount)

1. Use a **real card** (not test card)
2. Make a booking for ₹10 or $1
3. Complete the payment
4. Verify money appears in your Stripe dashboard
5. Cancel the booking and verify refund

### Test 2: Razorpay Payment (India)

1. Use a **real card** or UPI
2. Make a booking for ₹10
3. Complete the payment
4. Verify money appears in Razorpay dashboard
5. Test refund

### Test 3: Provider Onboarding

1. Create a provider account
2. Complete Stripe Connect onboarding
3. Verify provider can receive payouts

### Test 4: Full Booking Flow

1. Customer books a ride
2. Payment held in escrow
3. Provider enters OTP after ride
4. Money transferred to provider
5. Platform commission deducted correctly

---

## 🔒 SECURITY CHECKLIST

### Files to Protect

- [ ] **`.env` file MUST be in `.gitignore`** (verify it's not in Git)
- [ ] **Never commit live keys** to version control
- [ ] **Use Firebase Secret Manager** for production secrets
- [ ] **Enable 2FA** on Stripe and Razorpay accounts

### Check `.gitignore`

```bash
# Verify .env is ignored
cat .gitignore | grep ".env"

# If not, add it:
echo "functions/.env" >> .gitignore
```

---

## 💰 PAYMENT GATEWAY ACTIVATION

### Stripe Activation

- [ ] **Complete business verification** on Stripe
- [ ] **Activate your account** (may require documents)
- [ ] **Set up bank account** for payouts
- [ ] **Configure webhook endpoints**

### Razorpay Activation

- [ ] **Submit KYC documents** (PAN, business registration)
- [ ] **Get approval** (usually 24-48 hours)
- [ ] **Activate live mode**
- [ ] **Set up settlement account**

---

## 🌐 DOMAIN & URLS

### Update Return URLs

Edit: `e:\quickohunt\lib\services\stripe_service.dart`

```dart
// Update these URLs to your actual domain:
'return_url': returnUrl ?? 'https://YOUR-DOMAIN.com/stripe-return',
'refresh_url': refreshUrl ?? 'https://YOUR-DOMAIN.com/stripe-refresh',
```

### Update Webhook URLs

1. **Stripe Webhooks**: https://dashboard.stripe.com/webhooks
   - Add endpoint: `https://us-central1-quickohunt-app.cloudfunctions.net/stripeWebhook`
   - Select events: `payment_intent.succeeded`, `checkout.session.completed`

2. **Razorpay Webhooks**: https://dashboard.razorpay.com/app/webhooks
   - Add endpoint: `https://us-central1-quickohunt-app.cloudfunctions.net/razorpayWebhook`
   - Select events: `payment.captured`, `payment.failed`, `refund.created`

---

## 📱 GOOGLE PLAY / APP STORE

### Android (Google Play Console)

- [ ] **App signing enabled**
- [ ] **Privacy policy added**
- [ ] **Payment methods declared**
- [ ] **Age rating completed**
- [ ] **Content rating completed**

### iOS (App Store Connect)

- [ ] **App Review information complete**
- [ ] **Payment processing declared**
- [ ] **Privacy details filled**
- [ ] **In-App Purchase setup** (if applicable)

---

## 🎯 FINAL PRE-LAUNCH CHECKS

### Backend

- [ ] All Firebase Functions deployed
- [ ] All environment variables set
- [ ] Webhooks configured and tested
- [ ] Database indexes created
- [ ] Security rules tested

### Mobile App

- [ ] All payment modes tested with real money (small amounts)
- [ ] Refund flow tested
- [ ] Provider payout tested
- [ ] Error handling tested (network failures, etc.)
- [ ] Crash reporting enabled (Firebase Crashlytics)

### Legal & Compliance

- [ ] **Privacy Policy** published and linked in app
- [ ] **Terms of Service** published
- [ ] **Refund Policy** defined
- [ ] **Data encryption** enabled
- [ ] **GDPR compliance** (if serving EU)
- [ ] **PCI DSS compliance** (handled by Stripe/Razorpay)

---

## 🚨 EMERGENCY ROLLBACK PLAN

If something goes wrong after launch:

### Quick Disable Payments

```env
# In functions/.env:
USE_LIVE_KEYS=false  # Switch back to test mode
```

```bash
firebase deploy --only functions  # Redeploy immediately
```

### App-Level Kill Switch

In `lib/services/payment_service.dart`, you can add:

```dart
// Emergency maintenance mode
static const bool maintenanceMode = false;

if (maintenanceMode) {
  return {'error': 'Payment system under maintenance. Please try again later.'};
}
```

---

## 📊 MONITORING

### Must Monitor After Launch

1. **Firebase Functions Logs**:
   ```bash
   firebase functions:log --follow
   ```

2. **Stripe Dashboard**: https://dashboard.stripe.com/payments
3. **Razorpay Dashboard**: https://dashboard.razorpay.com/payments
4. **Supabase Logs**: Check database queries and errors
5. **App Crash Reports**: Firebase Crashlytics

---

## 💡 SOFT LAUNCH STRATEGY (RECOMMENDED)

Instead of full launch, consider:

### Phase 1: Internal Testing (1-2 days)
- You + 2-3 trusted friends
- Real payments (small amounts)
- Test all flows thoroughly

### Phase 2: Beta Launch (3-5 days)
- Invite 20-30 users
- Monitor closely
- Fix critical issues quickly

### Phase 3: Soft Launch (1-2 weeks)
- Limited marketing
- Gradual user growth
- Validate payment volumes
- Ensure payout system works

### Phase 4: Full Launch
- Once you're confident everything works
- Ramp up marketing
- Scale infrastructure as needed

---

## 🎬 LAUNCH DAY TASKS

### Morning of Launch

1. ☕ **Get coffee**
2. 🔍 **Final review** of all dashboards
3. 📊 **Check all monitors** are running
4. 🔔 **Enable alerts** for critical errors
5. 📱 **Have phone ready** for support calls

### During Launch

1. 👀 **Watch Firebase logs** in real-time
2. 💳 **Monitor first few payments** closely
3. 🐛 **Fix critical bugs** immediately
4. 📞 **Be available** for user support
5. 📝 **Document issues** as they arise

### End of Day

1. 📊 **Review metrics**: Payments, errors, crashes
2. 📧 **Check user feedback**
3. 🔧 **Plan hotfixes** for tomorrow
4. 💤 **Get rest** - you'll need it!

---

## ❓ STILL HAVE QUESTIONS?

Contact your payment providers:
- **Stripe Support**: https://support.stripe.com/
- **Razorpay Support**: https://razorpay.com/support/

---

## ✅ SIGN-OFF CHECKLIST

Before launching, ALL team members should verify:

**Developer**: __________  
- [ ] All keys configured  
- [ ] All tests passing  
- [ ] Monitoring enabled  

**QA Tester**: __________  
- [ ] Real payment tested  
- [ ] Refund flow verified  
- [ ] Error scenarios tested  

**Business Owner**: __________  
- [ ] Payment gateways activated  
- [ ] Legal documents ready  
- [ ] Support plan in place  

---

## 🎉 YOU'RE READY TO LAUNCH WHEN...

✅ All keys are configured (no placeholders)  
✅ Real payments tested successfully  
✅ Provider payouts verified  
✅ Refunds working correctly  
✅ Webhooks receiving events  
✅ Monitoring dashboards active  
✅ Support team briefed  
✅ Legal documents published  
✅ Emergency rollback plan ready  

**Good luck with your launch! 🚀**
