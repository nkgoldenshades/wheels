# 💵 Currency Issue - Why USD Posts Show as INR

## 🔍 The Problem

You're seeing this behavior:
1. ✅ Create post with Stripe → Shows **$ (USD)** in creation screen
2. ❌ Post appears in feed → Shows **₹ (INR)** instead!

## 🎯 Root Cause

Your user's `bank_currency` field is **not set to USD** in the database. Here's what happened:

### Timeline:
```
1. You connected Stripe account (test mode)
   ↓
2. At that time, bank_currency field wasn't auto-set
   ↓
3. Your profile has: bank_currency = NULL or 'INR'
   ↓
4. When creating post, app reads bank_currency
   ↓
5. Falls back to default: 'INR'
   ↓
6. Post is saved with currency_type = 'INR'
   ↓
7. Feed displays: ₹ instead of $
```

## ✅ Solutions (Choose One)

### Option 1: Quick Database Fix (Fastest)

Run this SQL in your Supabase SQL Editor:

```sql
-- Find your user ID (replace email)
SELECT id, email, bank_currency, payment_provider 
FROM profiles  -- or profiles_private
WHERE email = 'your_actual_email@example.com';

-- Update your bank_currency to USD
UPDATE profiles  -- or profiles_private
SET bank_currency = 'USD'
WHERE id = 'YOUR_USER_ID_HERE'
  AND payment_provider = 'stripe';

-- Update all your existing posts to USD
UPDATE posts
SET currency_type = 'USD'
WHERE profile_id = 'YOUR_USER_ID_HERE';
```

**Then restart your app!**

---

### Option 2: Reconnect Stripe Account (Clean)

1. Go to your app → Profile → Payment Settings
2. Disconnect Stripe account
3. Reconnect Stripe account
4. The new code will automatically set `bank_currency = 'USD'`
5. Create a new post → It will use USD ✓

---

### Option 3: Automated Fix for All Users

If you want to fix this for ALL Stripe users in your database:

```sql
-- Fix all Stripe users
UPDATE profiles  -- or profiles_private
SET bank_currency = 'USD'
WHERE payment_provider = 'stripe'
  AND (bank_currency IS NULL OR bank_currency = '' OR bank_currency = 'INR')
  AND stripe_account_id IS NOT NULL;

-- Fix all their posts
UPDATE posts p
SET currency_type = 'USD'
FROM profiles pr  -- or profiles_private
WHERE p.profile_id = pr.id
  AND pr.payment_provider = 'stripe'
  AND pr.bank_currency = 'USD'
  AND (p.currency_type IS NULL OR p.currency_type = 'INR');
```

---

## 🔍 Verify the Fix

After applying the fix, check:

```sql
-- Check your profile
SELECT id, payment_provider, bank_currency, stripe_account_id
FROM profiles  -- or profiles_private
WHERE id = 'YOUR_USER_ID';

-- Check your posts
SELECT id, currency_type, price, created_at
FROM posts
WHERE profile_id = 'YOUR_USER_ID'
ORDER BY created_at DESC
LIMIT 5;
```

You should see:
- `bank_currency` = `'USD'` ✓
- `currency_type` = `'USD'` ✓

---

## 📱 App Behavior After Fix

### Creating New Post:
```
1. App reads your bank_currency = 'USD'
   ↓
2. Post form shows: $ (dollar sign)
   ↓
3. You enter price: 5
   ↓
4. Post is saved with currency_type = 'USD'
   ↓
5. Feed displays: $5 ✓
```

### Viewing Post in Feed:
```
1. Post has currency_type = 'USD'
   ↓
2. Slot.currencySymbol getter returns '$'
   ↓
3. Feed displays: $5 ✓
```

---

## 🛠️ Technical Details

### How Currency is Determined (Post Creation):

**File:** `lib/screens/add_flow/create_post_screen.dart`

```dart
String _determineCurrencyType() {
  final currentUser = ProfileRepository.instance.profile.value;
  
  // Step 1: Use bank_currency if set
  final bankCurrency = currentUser.bankCurrency;
  if (bankCurrency != null && bankCurrency.isNotEmpty) {
    return bankCurrency.toUpperCase();  // ← Should be 'USD'
  }
  
  // Step 2: Fallback to payment provider
  final paymentProvider = currentUser.paymentProvider;
  if (paymentProvider == 'razorpay') return 'INR';
  if (paymentProvider == 'stripe') return 'USD';
  
  // Step 3: Default
  return 'INR';  // ← Your posts are hitting this default!
}
```

### How Bank Currency is Set (Stripe Connection):

**File:** `lib/services/profile_repository.dart`

```dart
Future<void> updateStripeAccountId(String accountId, {String? currency}) async {
  final bankCurrency =
    currency ??
    (accountId.startsWith('acct_test_') ? 'USD' : null) ??  // ← Test accounts get USD
    p.bankCurrency;

  await saveProfile(
    p.copyWith(
      stripeAccountId: accountId, 
      bankCurrency: bankCurrency  // ← This should set USD
    )
  );
}
```

**Issue:** If you connected Stripe BEFORE this code was added, your `bankCurrency` never got set!

---

## 🎯 Prevention for Future

The code is already fixed! For NEW users who connect Stripe:
1. ✅ Test Stripe accounts → Auto-set to USD
2. ✅ Live Stripe accounts → Use account's actual currency
3. ✅ Razorpay accounts → Auto-set to INR

So this issue won't affect new users. Only existing users who connected Stripe before the fix need to run the SQL update.

---

## 📊 Database Schema

### Profiles Table:
```sql
profiles (or profiles_private)
  id TEXT PRIMARY KEY
  payment_provider TEXT  -- 'razorpay' or 'stripe'
  bank_currency TEXT     -- 'INR', 'USD', 'EUR', 'GBP', etc.
  stripe_account_id TEXT
  razorpay_account_id TEXT
```

### Posts Table:
```sql
posts
  id UUID PRIMARY KEY
  profile_id TEXT REFERENCES profiles(id)
  currency_type TEXT     -- 'INR', 'USD', 'EUR', 'GBP', etc.
  price NUMERIC
```

### The Connection:
```
Provider's bank_currency → Post's currency_type → Feed display
      'USD'          →        'USD'         →      '$5'
```

---

## 🚀 Quick Action Items

**To fix YOUR issue right now:**

1. **Run this SQL** (replace email/ID):
   ```sql
   UPDATE profiles SET bank_currency = 'USD' WHERE id = 'YOUR_ID';
   UPDATE posts SET currency_type = 'USD' WHERE profile_id = 'YOUR_ID';
   ```

2. **Restart your app** (pull to refresh the feed)

3. **Create a test post** → Should show $ now!

4. **Check existing posts** → Should show $ now!

**That's it! Your currency issue will be fixed!** 💰✨
