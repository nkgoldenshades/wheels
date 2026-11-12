# ⚡ Quick Launch Guide - 30 Minutes to Production

## 🎯 Goal: Get Your App Live FAST

If you want to launch **RIGHT NOW**, here's the absolute minimum you need to do. This takes about **30 minutes** if you have all your accounts ready.

---

## 🚨 REALITY CHECK

**Current Status**: Your app is in TEST mode with placeholder keys.

**What Works**:
- ✅ Razorpay Test payments (India)
- ✅ Firebase Functions deployed
- ✅ App structure complete

**What DOESN'T Work** (will cause failures):
- ❌ Stripe payments (test key missing)
- ❌ Live Razorpay payments (live keys missing)
- ❌ Database operations (Supabase key missing)
- ❌ Provider payouts (Stripe Connect not activated)

---

## ⏱️ MINIMUM VIABLE LAUNCH (30 minutes)

### ✅ OPTION 1: Launch with Razorpay Only (India Only)

If you want to launch **only in India** and can skip Stripe for now:

#### Step 1: Get Razorpay Live Keys (5 min)

```bash
1. Go to: https://dashboard.razorpay.com/app/keys
2. Toggle to "LIVE" mode (top-right)
3. If you see "Activate Account" - you need KYC first (STOP HERE)
4. If activated, copy:
   - Key ID: rzp_live_XXXXX
   - Key Secret: YYYYYYYY
```

#### Step 2: Update Backend (2 min)

Open `e:\quickohunt\functions\.env` and update:

```env
USE_LIVE_KEYS=true
RAZORPAY_KEY_ID_LIVE=rzp_live_YOUR_KEY_HERE
RAZORPAY_KEY_SECRET_LIVE=YOUR_SECRET_HERE
```

#### Step 3: Update Flutter App (2 min)

Open `e:\quickohunt\lib\services\razorpay_service.dart`:

```dart
// Line 18:
static const bool useTestMode = false;

// Line 24:
static const String _liveKeyId = 'rzp_live_YOUR_KEY_HERE';
```

#### Step 4: Deploy (5 min)

```bash
cd e:\quickohunt
firebase deploy --only functions
flutter build apk --release
```

#### Step 5: Test (5 min)

- Make a ₹10 booking with real card/UPI
- Verify payment in Razorpay dashboard
- Test refund

**⚠️ LIMITATIONS**: 
- India only (INR payments)
- No Stripe subscriptions
- Provider payouts via Razorpay Route (need to set up separately)

---

### ✅ OPTION 2: Launch with Both Gateways (Recommended)

For **global launch** with Stripe + Razorpay:

#### Step 1: Get ALL Live Keys (10 min)

**Stripe**:
```
Dashboard: https://dashboard.stripe.com/apikeys (LIVE mode)
- Publishable: pk_live_XXXXX
- Secret: sk_live_YYYYY
```

**Razorpay**:
```
Dashboard: https://dashboard.razorpay.com/app/keys (LIVE mode)
- Key ID: rzp_live_XXXXX
- Secret: YYYYYYYY
```

**Supabase**:
```
Dashboard: https://supabase.com/dashboard → Your Project → Settings → API
- Anon key: eyJhbGci...
```

#### Step 2: Update Backend .env (3 min)

```env
USE_LIVE_KEYS=true

SUPABASE_ANON_KEY=eyJhbGci...YOUR_ACTUAL_KEY

RAZORPAY_KEY_ID_LIVE=rzp_live_...
RAZORPAY_KEY_SECRET_LIVE=...

STRIPE_SECRET_KEY_LIVE=sk_live_...
```

#### Step 3: Update Flutter App (3 min)

**File 1**: `lib/services/stripe_service.dart`
```dart
static const bool useTestMode = false;
static const String _livePublishableKey = 'pk_live_YOUR_KEY';
```

**File 2**: `lib/services/razorpay_service.dart`
```dart
static const bool useTestMode = false;
static const String _liveKeyId = 'rzp_live_YOUR_KEY';
```

#### Step 4: Deploy Everything (5 min)

```bash
# Backend
firebase deploy --only functions

# Mobile app
flutter build apk --release

# Web (if needed)
flutter build web --release
```

#### Step 5: Quick Test (5 min)

Test with **real money** (use small amounts):

```
1. Stripe: $1 or €1 payment
2. Razorpay: ₹10 payment
3. Verify in dashboards
4. Test refund
```

---

## 🛑 BLOCKERS - You CANNOT Launch If...

### ❌ Razorpay Account Not Activated

**Error**: "Activate your account" message in dashboard

**Solution**: 
1. Go to Dashboard → Settings → Account & Settings
2. Submit KYC documents (PAN, bank details, business docs)
3. Wait 24-48 hours for approval
4. **YOU MUST WAIT** - no workaround

### ❌ Stripe Account Restricted

**Error**: "Your account is restricted" or "Additional information required"

**Solution**:
1. Go to Dashboard → Settings
2. Complete business verification
3. Submit requested documents
4. Wait for approval (can take 1-7 days)

### ❌ Supabase Key Invalid

**Error**: Database operations fail, "Invalid API key"

**Solution**:
1. Go to Supabase Dashboard
2. Settings → API
3. Copy the correct "anon" key (starts with eyJhbGci...)
4. Update .env file

---

## 🎯 FASTEST PATH TO LAUNCH

### If You Have Active Razorpay + Stripe Accounts:

```
Total Time: ~30 minutes

1. Copy all keys (10 min)
2. Update 3 files (5 min)
3. Deploy (5 min)
4. Test (10 min)
5. 🚀 LAUNCH!
```

### If Accounts Need Activation:

```
You need to WAIT for approval before launching

Razorpay KYC: 24-48 hours
Stripe Verification: 1-7 days

USE THIS TIME TO:
- Test thoroughly in test mode
- Get app store listings ready
- Create marketing materials
- Build user base
```

---

## 📋 ACTUAL FILES YOU NEED TO EDIT

Only **3 files** need changes:

### File 1: `functions/.env`
```env
USE_LIVE_KEYS=true
SUPABASE_ANON_KEY=<your_actual_key>
RAZORPAY_KEY_ID_LIVE=<your_key>
RAZORPAY_KEY_SECRET_LIVE=<your_secret>
STRIPE_SECRET_KEY_LIVE=<your_key>
```

### File 2: `lib/services/stripe_service.dart`
```dart
static const bool useTestMode = false;
static const String _livePublishableKey = '<your_key>';
```

### File 3: `lib/services/razorpay_service.dart`
```dart
static const bool useTestMode = false;
static const String _liveKeyId = '<your_key>';
```

---

## 🧪 MANDATORY TEST BEFORE LAUNCH

**Test with REAL MONEY** (you can refund it):

```bash
Test Case 1: Razorpay Payment (India)
- Amount: ₹10
- Method: UPI or Card
- Expected: Payment succeeds, shows in dashboard

Test Case 2: Stripe Payment (International)
- Amount: $1 or €1
- Method: Card
- Expected: Payment succeeds, shows in dashboard

Test Case 3: Refund
- Refund the test payments
- Expected: Money returns to card/account
```

**IF ANY TEST FAILS → DO NOT LAUNCH**

---

## 🚀 DEPLOY COMMANDS

Copy-paste these:

```bash
# Navigate to project
cd e:\quickohunt

# Deploy backend
firebase deploy --only functions

# Build Android APK
flutter clean
flutter pub get
flutter build apk --release

# Build for web (optional)
flutter build web --release

# Check build output
dir build\app\outputs\flutter-apk\
```

APK will be at: `build\app\outputs\flutter-apk\app-release.apk`

---

## ⚠️ LAUNCH DAY WARNINGS

### Things That WILL Go Wrong:
1. Some users will have payment failures
2. Refunds might be slow (24-48 hours)
3. You'll get support emails
4. Some edge cases you didn't test

### Things You MUST Monitor:
1. Firebase Functions logs: `firebase functions:log --follow`
2. Stripe dashboard: https://dashboard.stripe.com/payments
3. Razorpay dashboard: https://dashboard.razorpay.com/payments
4. App crash reports in Firebase Console

### Have Ready:
- [ ] Support email or phone number
- [ ] Access to all dashboards
- [ ] Ability to issue manual refunds
- [ ] Emergency rollback plan

---

## 🔥 EMERGENCY STOP BUTTON

If everything is on fire:

```bash
# Open functions/.env
USE_LIVE_KEYS=false  # Switch back to test mode

# Deploy immediately
firebase deploy --only functions

# This stops all live payments instantly
```

---

## ✅ LAUNCH CHECKLIST (Copy This)

```
BEFORE YOU HIT DEPLOY:

Account Status:
[ ] Razorpay account ACTIVATED (not "test mode")
[ ] Stripe account VERIFIED (not "restricted")
[ ] Supabase project accessible

Keys Configured:
[ ] Razorpay live keys in .env
[ ] Stripe live keys in .env
[ ] Supabase anon key in .env
[ ] Flutter app live keys updated

Testing:
[ ] Real ₹10 Razorpay payment tested
[ ] Real $1 Stripe payment tested
[ ] Refund tested successfully
[ ] Provider payout tested (if applicable)

Deployment:
[ ] Firebase functions deployed
[ ] APK built successfully
[ ] APK tested on real device

Monitoring:
[ ] Firebase Console open
[ ] Stripe Dashboard open
[ ] Razorpay Dashboard open
[ ] Phone nearby for support

Legal:
[ ] Privacy policy published
[ ] Terms of service published
[ ] Refund policy documented

Emergency:
[ ] Know how to switch back to test mode
[ ] Can issue manual refunds if needed
[ ] Have database backup

SIGN HERE: _________________ DATE: _______
```

---

## 🎉 READY TO LAUNCH?

### ✅ YES - If All These Are True:
- All payment accounts activated (no "test mode" warnings)
- All keys configured (no placeholders)
- Real money test passed
- Emergency plan ready
- Support plan ready

**GO FOR IT! 🚀**

### ❌ NO - If Any Of These Are True:
- "Activate account" message in dashboards
- Still have placeholder keys
- Haven't tested with real money
- Don't know how to issue refunds
- No support plan

**WAIT! Test more first! ⏸️**

---

## 💡 MY RECOMMENDATION

**Don't launch today.** Here's why:

1. Your Stripe test key isn't even configured yet
2. You haven't tested with real money
3. Provider payouts aren't set up
4. No monitoring in place

**Better Plan**:
1. **Today**: Configure all test keys, test thoroughly
2. **Tomorrow**: Get live keys, test with $1/$10
3. **Day 3**: Soft launch to 10-20 users
4. **Day 5**: If all good, full launch

**This gives you**:
- Confidence everything works
- Time to fix critical bugs
- Real user feedback
- Avoided disaster on launch day

---

## 🆘 NEED HELP?

If you're stuck:
1. Check Firebase Functions logs: `firebase functions:log`
2. Check Stripe docs: https://stripe.com/docs
3. Check Razorpay docs: https://razorpay.com/docs
4. Or hire a consultant for 1-2 hours to help you launch safely

**Good luck! 🍀**
