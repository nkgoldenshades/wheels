# 🔧 Stripe Setup Guide - Fix Payment Failure

## ❌ Current Problem
**Subscription payment is failing** with error:
```
Payment failed: ClientException: Failed to fetch, 
uri=https://us-central1-quickohunt-app.cloudfunctions.net/createSubscriptionCheckoutSession
```

## 🔍 Root Cause
The Firebase Cloud Function `createSubscriptionCheckoutSession` is deployed and working, but the **Stripe secret key is not configured** in the environment variables. The `.env` file has a placeholder value `sk_test_your_key_here` instead of your actual Stripe key.

---

## ✅ Solution: Add Your Stripe Keys

### Step 1: Get Your Stripe Test Secret Key

1. **Go to Stripe Dashboard (TEST MODE)**
   - Visit: https://dashboard.stripe.com/test/apikeys
   - Make sure you're in **TEST mode** (toggle in top-left)

2. **Copy Your Secret Key**
   - Look for the section **"Secret key"**
   - Your key starts with: `sk_test_51...` (followed by random characters)
   - Click **"Reveal test key"** if it's hidden
   - Copy the entire key

### Step 2: Update the `.env` File

1. **Open the file**: `e:\quickohunt\functions\.env`

2. **Replace this line**:
   ```env
   STRIPE_SECRET_KEY_TEST=sk_test_your_key_here
   ```

3. **With your actual key**:
   ```env
   STRIPE_SECRET_KEY_TEST=sk_test_51SvbBRPL6V2gHHHXYourActualSecretKeyHere...
   ```

   ⚠️ **IMPORTANT**: 
   - Your secret key should start with `sk_test_51SvbBRPL6V2gHHHX` (same account as your publishable key)
   - The secret key is about 107 characters long
   - Never share this key publicly or commit it to Git

### Step 3: Deploy Updated Environment

After updating the `.env` file, redeploy your functions:

```bash
cd e:\quickohunt
firebase deploy --only functions
```

This will upload your new environment variables to Firebase Cloud Functions.

---

## 🧪 Testing After Setup

### Test 1: Check Function Logs
```bash
firebase functions:log
```
Look for any "Stripe is not configured" errors - they should be gone.

### Test 2: Try Subscription Payment Again
1. Open your app
2. Go to subscription payment screen
3. Try to create a checkout session
4. It should now redirect to Stripe checkout page

---

## 📋 Your Current Configuration Status

### ✅ Already Configured:
- **Flutter App Publishable Key**: `pk_test_51SvbBRPL6V2gHHHX...` ✓
- **Razorpay Test Keys**: Configured ✓
- **Firebase Functions**: Deployed ✓
- **Function Exports**: `createSubscriptionCheckoutSession` exported ✓

### ❌ Missing Configuration:
- **Stripe Secret Key**: Needs your actual key from dashboard
- **Supabase Anon Key**: Still has placeholder `your_anon_key_here`

---

## 🔒 Security Best Practices

### DO:
- ✅ Keep `.env` file in `.gitignore`
- ✅ Use test keys during development
- ✅ Store production keys in Firebase Secret Manager
- ✅ Use different keys for test and production

### DON'T:
- ❌ Commit `.env` file to Git
- ❌ Share secret keys publicly
- ❌ Use production keys in test mode
- ❌ Hardcode keys in source code

---

## 🚀 Going to Production Later

When ready to accept real payments:

1. **Switch to Live Keys**:
   ```env
   USE_LIVE_KEYS=true
   ```

2. **Get Live Stripe Keys**:
   - Go to https://dashboard.stripe.com/apikeys (LIVE mode)
   - Copy **live secret key** (starts with `sk_live_`)
   - Update `STRIPE_SECRET_KEY_LIVE` in `.env`

3. **Update Flutter App**:
   - In `lib/services/stripe_service.dart`
   - Change `useTestMode = false`
   - Add your live publishable key

4. **Redeploy Everything**:
   ```bash
   firebase deploy --only functions
   flutter build apk --release
   ```

---

## 📞 Need Help?

If you encounter any issues:

1. Check Firebase Functions logs: `firebase functions:log`
2. Verify your Stripe dashboard is in TEST mode
3. Ensure the secret key matches your publishable key (same account)
4. Make sure you redeployed after updating `.env`

---

## 🎯 Quick Checklist

- [ ] Logged into Stripe dashboard (test mode)
- [ ] Copied secret key starting with `sk_test_51SvbBRPL6V2gHHHX...`
- [ ] Updated `STRIPE_SECRET_KEY_TEST` in `functions/.env`
- [ ] Saved the `.env` file
- [ ] Ran `firebase deploy --only functions`
- [ ] Waited for deployment to complete
- [ ] Tested subscription payment in app
- [ ] Checked Firebase logs for errors

---

**Note**: The same process applies to Supabase. You'll also need to update `SUPABASE_ANON_KEY` with your actual Supabase anonymous key from the Supabase dashboard.
