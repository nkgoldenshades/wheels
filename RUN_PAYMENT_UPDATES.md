# Quick Start: Payment System Updates

## 🚀 Run These Commands in Order

### 1. Add bank_currency Column to profiles_private Table (REQUIRED FIRST!)

```bash
# Option A: Using SQL file
psql -U postgres -d your_database_name -f add_bank_currency_to_profiles.sql

# Option B: Using Supabase SQL Editor
# Copy and paste the contents of add_bank_currency_to_profiles.sql
```

**What it does:**
- Adds `bank_currency` column to `profiles_private` table
- Stores currency of provider's bank account (INR/USD/GBP/EUR)
- Required before the next migration!

### 2. Add currency_type Column to Posts Table

```bash
# Option A: Using SQL file
psql -U postgres -d your_database_name -f add_currency_type_to_posts.sql

# Option B: Using Supabase SQL Editor
# Copy and paste the contents of add_currency_type_to_posts.sql
```

**What it does:**
- Adds `currency_type` column to `posts` table
- Auto-populated from `bank_currency` field
- Used for payment routing

### 2. Verify the Changes

```sql
-- Check if bank_currency column exists
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'profiles_private' 
AND column_name = 'bank_currency';

-- Check if currency_type column exists
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'posts' 
AND column_name = 'currency_type';

-- Check existing profiles
SELECT id, payment_provider, bank_currency, stripe_account_id, razorpay_account_id
FROM profiles_private 
WHERE payment_provider IS NOT NULL
LIMIT 10;

-- Check existing posts
SELECT id, profile_id, currency_type, price 
FROM posts 
LIMIT 10;
```

### 3. Test Provider Payment Validation

#### Test Case 1: Provider WITHOUT Payment Account
1. Open app
2. Try to create a post
3. **Expected:** Error dialog appears
4. **Message:** "Payment Account Required"
5. Click "Go to Settings"
6. Connect Razorpay or Stripe

#### Test Case 2: Provider WITH Payment Account
1. Open app
2. Navigate to Profile → Settings
3. Connect Razorpay (India) or Stripe (International)
4. Try to create a post
5. **Expected:** Post creation succeeds
6. Verify `currency_type` is set correctly

### 4. Test Currency Auto-Detection

```dart
// Debug output in create_post_screen.dart
debugPrint('Currency: ${_determineCurrencyType()}');
// Should show: 'INR', 'USD', 'GBP', or 'EUR'
```

---

## 🔍 What Changed?

### Database
- ✅ Added `currency_type` column to `posts` table
- ✅ Auto-updates from `bank_currency` field
- ✅ Fallback to `payment_provider` (Razorpay=INR, Stripe=USD)

### Frontend
- ✅ Added payment provider validation before post creation
- ✅ Shows error dialog if payment account not connected
- ✅ Currency auto-detected from bank account
- ✅ Currency stored in post on creation

### Payment Flow
- ✅ Already implemented in `payment_service.dart`
- ✅ Routes to Razorpay for INR
- ✅ Routes to Stripe for other currencies

---

## ✅ Verification Checklist

- [ ] SQL migration successful
- [ ] `currency_type` column exists
- [ ] Existing posts updated with currency
- [ ] Provider validation blocks post creation
- [ ] Error dialog shows for providers without payment account
- [ ] Navigation to settings works
- [ ] Currency auto-detected correctly
- [ ] Posts created with correct `currency_type`
- [ ] Payment flow routes correctly based on currency

---

## 🐛 Common Issues

### Issue: Column already exists
**Solution:** No problem! The `IF NOT EXISTS` clause prevents errors.

### Issue: Payment validation not working
**Check:**
```dart
// Profile must have:
paymentProvider: 'razorpay' or 'stripe'
stripeAccountId: 'acct_xxx...' OR razorpayAccountId: 'cont_xxx...'
```

### Issue: Wrong currency detected
**Check priority:**
1. `bank_currency` field (best)
2. `payment_provider` (Razorpay=INR, Stripe=USD)
3. Default 'INR'

---

## 📞 Support

If you encounter issues:
1. Check console logs for debug output
2. Verify database schema with queries above
3. Test with both Razorpay and Stripe
4. Check `PAYMENT_IMPLEMENTATION_GUIDE.md` for details

---

**Ready to test!** 🎉
