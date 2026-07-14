# 🧪 Test Mode Setup Guide

## Quick Test Mode for Development

The payment provider validation is now working! For testing without connecting real Stripe/Razorpay accounts, use these test mode helpers.

---

## ✅ Option 1: Use Test Mode Buttons (Fastest)

### For Stripe (International)
1. Go to **Settings → Payment Setup**
2. Select **Stripe (International)**
3. Scroll down
4. Click **"🧪 Use Test Account (Development)"** button
5. Done! Test Stripe account set with USD currency

### For Razorpay (India)
1. Go to **Settings → Payment Setup**
2. Select **Razorpay (Bank payout)**
3. Scroll down  
4. Click **"🧪 Fill Test Bank Details (Development)"** button
5. Done! Test bank details filled with INR currency

---

## ✅ Option 2: Manual Test Account Entry

### Stripe Test Account
1. Go to **Settings → Payment Setup**
2. Select **Stripe (International)**
3. In "Or enter Stripe Account ID manually" field, enter:
   ```
   acct_test_quickohunt_dev
   ```
4. Currency auto-set to **USD**

### Razorpay Test Account
1. Go to **Settings → Payment Setup**
2. Select **Razorpay (Bank payout)**
3. Fill in test bank details:
   - Account Holder: `Test User`
   - Account Number: `1234567890`
   - Bank Name: `Test Bank`
   - IFSC Code: `TEST0001234`
   - Account Type: `Savings`
4. Currency auto-set to **INR**

---

## 🎯 What Happens After Setup

### Provider Creates Post
```
1. Open app
2. Try to create post
3. ✅ Validation passes (has test payment account)
4. Currency auto-detected:
   - Stripe test → USD
   - Razorpay test → INR
5. Post created successfully!
```

### Verify in Database
```sql
-- Check profile
SELECT id, payment_provider, stripe_account_id, razorpay_account_id, bank_currency
FROM profiles_private
WHERE id = 'YOUR_USER_ID';

-- Expected for Stripe test:
-- payment_provider: 'stripe'
-- stripe_account_id: 'acct_test_quickohunt_dev'
-- bank_currency: 'USD'

-- Expected for Razorpay test:
-- payment_provider: 'razorpay'
-- razorpay_account_id: 'rzp_test_contact_id'
-- bank_currency: 'INR'
```

---

## 🔧 What Changed

### 1. Profile Repository Updates
**File:** `lib/services/profile_repository.dart`

```dart
// Now auto-sets currency for test accounts
Future<void> updateStripeAccount(String accountId, {String? currency}) async {
  final bankCurrency = currency ?? 
                      (accountId.startsWith('acct_test_') ? 'USD' : null);
  
  await saveProfile(p.copyWith(
    stripeAccountId: accountId,
    bankCurrency: bankCurrency, // ← Currency now saved!
  ));
}

// Razorpay always INR
Future<void> updateRazorpayAccount(String accountId) async {
  await saveProfile(p.copyWith(
    razorpayAccountId: accountId,
    bankCurrency: 'INR', // ← Always INR for Razorpay
  ));
}
```

### 2. UI Updates  
**File:** `lib/main.dart`

Added two test mode buttons:
- 🧪 **Use Test Account** (Stripe section)
- 🧪 **Fill Test Bank Details** (Razorpay section)

---

## 🐛 Troubleshooting

### Issue: Firebase Functions Error
```
Failed to connect to Stripe. ClientException: Failed to fetch...
```

**Solution:** Use test mode! The Firebase function connectivity issue is bypassed by manually setting test accounts.

### Issue: Validation Still Blocks Post Creation
**Check:**
```dart
// Both must be set:
paymentProvider: 'stripe' or 'razorpay'
stripeAccountId: 'acct_test_xxx...' OR razorpayAccountId: 'rzp_test_xxx...'
```

**Fix:** Click the test mode button again, or check database to verify values saved.

### Issue: Wrong Currency Detected
**Check database:**
```sql
SELECT bank_currency FROM profiles_private WHERE id = 'YOUR_USER_ID';
```

**Expected:**
- Stripe test → 'USD'
- Razorpay test → 'INR'

**Fix:** Click test mode button again to re-save with correct currency.

---

## ✅ Testing Checklist

### Test A: Provider Without Payment Account
- [ ] Try to create post
- [ ] ❌ Error dialog appears: "Payment Account Required"
- [ ] Click "Go to Settings"
- [ ] Navigate to profile settings ✓

### Test B: Setup Stripe Test Account
- [ ] Select Stripe
- [ ] Click "🧪 Use Test Account" button
- [ ] ✅ Success message: "Test Stripe account set! Currency: USD"
- [ ] Try to create post
- [ ] ✅ Post created successfully
- [ ] Check post in database
- [ ] `currency_type = 'USD'` ✓

### Test C: Setup Razorpay Test Account
- [ ] Select Razorpay
- [ ] Click "🧪 Fill Test Bank Details" button
- [ ] ✅ Success message: "Test Razorpay details filled! Currency: INR"
- [ ] Try to create post
- [ ] ✅ Post created successfully
- [ ] Check post in database
- [ ] `currency_type = 'INR'` ✓

---

## 📊 Database Verification

### Check Profile Setup
```sql
-- See all payment details
SELECT 
  id,
  full_name,
  payment_provider,
  stripe_account_id,
  razorpay_account_id,
  bank_currency,
  bank_account_number,
  bank_name
FROM profiles_private
WHERE id = 'YOUR_USER_ID';
```

### Check Post Currency
```sql
-- See posts with currency
SELECT 
  id,
  profile_id,
  price,
  currency_type,
  created_at
FROM posts
WHERE profile_id = 'YOUR_USER_ID'
ORDER BY created_at DESC
LIMIT 5;
```

---

## 🎉 Success!

You can now test the payment validation without connecting real Stripe/Razorpay accounts!

**Key Points:**
- ✅ Test mode buttons work instantly
- ✅ Currency auto-detected correctly
- ✅ Provider validation passes
- ✅ Posts created successfully
- ✅ No Firebase Functions needed for testing

---

## 🔗 Related Documentation

- **PAYMENT_IMPLEMENTATION_GUIDE.md** - Technical details
- **PAYMENT_TESTING_CHECKLIST.md** - Complete test suite
- **RUN_PAYMENT_UPDATES.md** - Deployment guide

---

**Last Updated:** July 7, 2026  
**Version:** 1.0  
**Status:** ✅ Test Mode Ready
