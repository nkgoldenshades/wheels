# 🔧 Fix: bank_currency Column Missing

## ❌ Error
```
PostgrestException: Could not find the 'bank_currency' column of 'profiles_private' 
in the schema cache, code: PGRST204
```

---

## ✅ Quick Fix (5 minutes)

### Step 1: Run SQL Migration

**Option A: Using psql command line**
```bash
psql -U postgres -d your_database_name -f add_bank_currency_to_profiles.sql
```

**Option B: Using Supabase SQL Editor**
1. Go to Supabase Dashboard
2. Click **SQL Editor**
3. Copy contents of `add_bank_currency_to_profiles.sql`
4. Paste and click **Run**

**Option C: Run SQL Directly**
```sql
-- Add the column
ALTER TABLE profiles_private 
ADD COLUMN IF NOT EXISTS bank_currency TEXT;

-- Update existing profiles
UPDATE profiles_private
SET bank_currency = 'INR'
WHERE payment_provider = 'razorpay' 
  AND (bank_currency IS NULL OR bank_currency = '');

UPDATE profiles_private
SET bank_currency = 'USD'
WHERE payment_provider = 'stripe' 
  AND (bank_currency IS NULL OR bank_currency = '');
```

---

### Step 2: Refresh Schema Cache (If using Supabase)

Supabase caches the schema. You need to refresh it:

**Method 1: Wait (Automatic)**
- Supabase refreshes schema cache every few minutes
- Wait 2-5 minutes and try again

**Method 2: Restart Supabase (Instant)**
1. Go to Supabase Dashboard
2. Project Settings → Database
3. Click **"Restart Database"** (if available)
4. Or just wait for auto-refresh

**Method 3: Restart Your App (Instant)**
1. Hot reload your Flutter app
2. Schema cache will refresh on reconnect

---

### Step 3: Test Again

1. **Reload your app** (hot restart)
2. Go to **Settings → Payment Setup**
3. Click **"🧪 Use Test Account"** button
4. ✅ Should work now!

---

## 🔍 Verify Migration Worked

### Check Column Exists
```sql
-- Check if column was added
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'profiles_private' 
  AND column_name = 'bank_currency';

-- Expected: One row showing 'bank_currency' column
```

### Check Data
```sql
-- See bank_currency values
SELECT 
    id,
    payment_provider,
    bank_currency,
    stripe_account_id,
    razorpay_account_id
FROM profiles_private
WHERE payment_provider IS NOT NULL
LIMIT 10;
```

---

## 🎯 What This Column Does

The `bank_currency` column stores the **currency of the provider's bank account**:

- **Razorpay** → Always `'INR'` (India only)
- **Stripe** → `'USD'`, `'GBP'`, `'EUR'`, etc. (detected from bank)
- **Used for:** Auto-detecting `currency_type` in posts

### Flow:
```
Provider connects bank
  → bank_currency saved (INR/USD/GBP/EUR)
  → Creates post
  → Post currency_type auto-set from bank_currency
```

---

## 🐛 Troubleshooting

### Issue: Still getting the same error after migration

**Cause:** Supabase schema cache not refreshed

**Fix:**
1. Wait 5 minutes for auto-refresh
2. Or restart your app (hot restart, not hot reload)
3. Or restart Supabase database

### Issue: Column exists but values are NULL

**Fix:** Run update queries:
```sql
-- Set INR for Razorpay users
UPDATE profiles_private
SET bank_currency = 'INR'
WHERE payment_provider = 'razorpay' 
  AND bank_currency IS NULL;

-- Set USD for Stripe users
UPDATE profiles_private
SET bank_currency = 'USD'
WHERE payment_provider = 'stripe' 
  AND bank_currency IS NULL;
```

### Issue: Migration fails with "column already exists"

**Cause:** Column was already added

**Check:**
```sql
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'profiles_private' 
  AND column_name = 'bank_currency';
```

**Fix:** If it exists, just run the UPDATE queries to populate data.

---

## 📋 Complete Migration Checklist

- [ ] Run `add_bank_currency_to_profiles.sql`
- [ ] Verify column exists (SQL query)
- [ ] Verify data populated (SQL query)
- [ ] Wait 5 min or restart app
- [ ] Test "🧪 Use Test Account" button
- [ ] ✅ Should work without errors!

---

## 🚀 After Migration

Once migration is complete:

1. **Test Mode Works** ✅
   - Click test account buttons
   - bank_currency auto-set
   - Post creation works

2. **Production Ready** ✅
   - New users who connect Stripe/Razorpay
   - bank_currency auto-saved
   - Currency detection accurate

---

## 📊 Migration Order (Important!)

You need to run **TWO** migrations in this order:

### 1. **profiles_private** table (THIS ONE - Do First!)
```bash
psql -U postgres -d your_db -f add_bank_currency_to_profiles.sql
```
Adds `bank_currency` column to store provider's bank currency.

### 2. **posts** table (Already created earlier)
```bash
psql -U postgres -d your_db -f add_currency_type_to_posts.sql
```
Adds `currency_type` column that uses `bank_currency` for auto-detection.

---

## ✅ Success Indicators

After successful migration, you should see:

### In Database
```sql
-- profiles_private has bank_currency
SELECT bank_currency FROM profiles_private LIMIT 1;
-- Returns: 'INR', 'USD', 'GBP', etc.

-- posts has currency_type
SELECT currency_type FROM posts LIMIT 1;
-- Returns: 'INR', 'USD', 'GBP', etc.
```

### In App
- ✅ Test account buttons work
- ✅ No PostgrestException errors
- ✅ Success message appears
- ✅ Can create posts

---

**Run this migration NOW to fix the error!** ⚡

---

**File:** `add_bank_currency_to_profiles.sql`  
**Status:** Ready to run  
**Time:** ~1 minute  
**Risk:** Low (safe to run multiple times)
