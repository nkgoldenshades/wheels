# 💳 Payment Mode Configuration

## Current Status: TEST MODE 🧪

Your app is currently configured for **TEST MODE** which is perfect for development and testing.

---

## 🔄 How to Switch Between TEST and PRODUCTION Modes

### Quick Toggle (Same for Both Services)

**File:** `lib/services/razorpay_service.dart`
```dart
static const bool USE_TEST_MODE = true;  // ← Change to false for PRODUCTION
```

**File:** `lib/services/stripe_service.dart`
```dart
static const bool USE_TEST_MODE = true;  // ← Change to false for PRODUCTION
```

---

## 📝 Step-by-Step: Going to PRODUCTION

### 1️⃣ Get Your Production API Keys

#### **For Razorpay (India - INR):**
1. Visit: https://dashboard.razorpay.com
2. **Switch to LIVE MODE** (toggle at top-right)
3. Go to **Settings** → **API Keys**
4. Click **Generate Live API Key**
5. Copy your **Key ID** (starts with `rzp_live_`)
6. Save your **Key Secret** securely (for backend)

#### **For Stripe (International):**
1. Visit: https://dashboard.stripe.com
2. **Switch to LIVE MODE** (toggle at top-left)
3. Go to **Developers** → **API Keys**
4. Copy your **Publishable key** (starts with `pk_live_`)
5. Save your **Secret key** securely (for backend)

### 2️⃣ Update Your Flutter App

**File:** `lib/services/razorpay_service.dart`
```dart
// Replace this line:
static const String _liveKeyId = 'rzp_live_XXXXXXXXXXXX';

// With your actual live key:
static const String _liveKeyId = 'rzp_live_YourActualKey123';
```

**File:** `lib/services/stripe_service.dart`
```dart
// Replace this line:
static const String _livePublishableKey = 'pk_live_XXXXXXXXXXXX';

// With your actual live key:
static const String _livePublishableKey = 'pk_live_YourActualKey123';
```

### 3️⃣ Update Your Backend (Firebase Functions)

Your backend also needs the production keys. Update:

**Razorpay Secret:**
```bash
firebase functions:config:set razorpay.secret="YOUR_LIVE_KEY_SECRET"
```

**Stripe Secret:**
```bash
firebase functions:config:set stripe.secret="YOUR_LIVE_SECRET_KEY"
```

### 4️⃣ Switch to Production Mode

Change both files:
```dart
static const bool USE_TEST_MODE = false; // ✅ PRODUCTION MODE
```

### 5️⃣ Test Before Going Live

1. Run the app in production mode
2. Check console logs: Should show `🔑 Razorpay Mode: PRODUCTION 🚀`
3. Make a small real payment (₹1 or $0.50)
4. Verify payment appears in your live dashboard
5. Verify funds are received in your account

---

## 🧪 TEST MODE Details

### Razorpay Test Mode
- **Test Key:** `rzp_test_SvBetsinxdM1dN`
- **Test Cards:**
  - **Indian Card:** `5267 3181 8797 5449`
  - **International Card:** `4111 1111 1111 1111` (may fail if international disabled)
  - **CVV:** Any 3 digits
  - **Expiry:** Any future date

### Stripe Test Mode
- **Test Key:** `pk_test_51SvbBRPL6V2gHHHX...`
- **Test Cards:**
  - **Success:** `4242 4242 4242 4242`
  - **Requires Auth:** `4000 0025 0000 3155`
  - **Declined:** `4000 0000 0000 9995`
  - **CVV:** Any 3 digits
  - **Expiry:** Any future date

---

## 🚀 PRODUCTION MODE Details

### What Changes in Production:
- ✅ **Real payments** are processed
- ✅ **Real money** is transferred
- ✅ Test cards will be **rejected**
- ✅ Only valid credit/debit cards work
- ✅ Payments appear in live dashboard
- ✅ Settlement to bank account happens automatically

### Important Production Checklist:
- [ ] Production API keys added
- [ ] Backend updated with production secrets
- [ ] Test payment successful
- [ ] Bank account connected (Razorpay/Stripe)
- [ ] Webhooks configured (for payment confirmations)
- [ ] KYC completed (Razorpay required for India)
- [ ] Terms & Privacy Policy updated
- [ ] Refund policy clearly stated

---

## 🔍 How to Check Current Mode

When the app runs, check the console logs:

**TEST MODE:**
```
🔑 Razorpay Mode: TEST 🧪
🔑 Using Key: rzp_test_Svb...
```

**PRODUCTION MODE:**
```
🔑 Razorpay Mode: PRODUCTION 🚀
🔑 Using Key: rzp_live_abc...
```

---

## ⚠️ IMPORTANT WARNINGS

### ❌ DO NOT:
- Commit production keys to Git (keep them in environment variables)
- Share API keys publicly
- Use test mode in production app
- Use production mode during development

### ✅ DO:
- Keep test mode during development
- Test thoroughly before switching to production
- Complete KYC verification (especially Razorpay)
- Monitor payments in live dashboard
- Set up webhook notifications
- Have proper refund/cancellation policies

---

## 🆘 Troubleshooting

### "Payment failed" in Production
- ✓ Check if you switched `USE_TEST_MODE` to `false`
- ✓ Verify production keys are correct
- ✓ Check if KYC is completed (Razorpay)
- ✓ Ensure bank account is connected

### "Invalid API Key"
- ✓ Make sure you copied the full key
- ✓ Check for extra spaces
- ✓ Verify you're using the right key (live vs test)

### "Test card not working in Production"
- ✓ This is expected! Use real cards in production
- ✓ Test cards only work in TEST mode

---

## 📞 Support

**Razorpay Support:** support@razorpay.com
**Stripe Support:** https://support.stripe.com

**Your Dashboard Links:**
- Razorpay: https://dashboard.razorpay.com
- Stripe: https://dashboard.stripe.com
