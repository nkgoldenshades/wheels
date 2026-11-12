# ⚡ QUICK FIX - Run This NOW!

## 🔴 Error You're Seeing:
```
Could not find the 'bank_currency' column of 'profiles_private'
```

---

## ✅ Solution (2 Steps, 3 Minutes)

### Step 1: Add bank_currency Column (Required!)

**Copy and run this SQL:**

```sql
-- Add bank_currency column to profiles_private
ALTER TABLE profiles_private 
ADD COLUMN IF NOT EXISTS bank_currency TEXT;

-- Set INR for Razorpay users
UPDATE profiles_private
SET bank_currency = 'INR'
WHERE payment_provider = 'razorpay' 
  AND (bank_currency IS NULL OR bank_currency = '');

-- Set USD for Stripe users  
UPDATE profiles_private
SET bank_currency = 'USD'
WHERE payment_provider = 'stripe' 
  AND (bank_currency IS NULL OR bank_currency = '');
```

**Where to run:**
- Supabase Dashboard → SQL Editor → Paste → Run
- Or: `psql -U postgres -d your_db -f add_bank_currency_to_profiles.sql`

---

### Step 2: Restart Your App

1. **Hot restart** (not hot reload) your Flutter app
2. Or wait 2-5 minutes for schema cache refresh

---

### Step 3: Test Again

1. Go to **Settings → Payment Setup**
2. Click **"🧪 Use Test Account"** button
3. ✅ Should work now!

---

## 🎯 What This Does

Adds the missing `bank_currency` column that stores:
- **Razorpay** → `'INR'`
- **Stripe** → `'USD'` (or GBP/EUR based on bank)

This column is used to auto-detect currency when creating posts.

---

## ✅ Verify It Worked

```sql
-- Check column exists
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'profiles_private' AND column_name = 'bank_currency';

-- Should return 1 row
```

---

## 🚀 Then Run Second Migration (Optional, for posts)

After fixing `bank_currency`, also run:

```sql
-- Add currency_type to posts table
ALTER TABLE posts 
ADD COLUMN IF NOT EXISTS currency_type TEXT DEFAULT 'INR';
```

---

**That's it! Problem solved.** ✅

**File to run:** `add_bank_currency_to_profiles.sql`  
**Time:** 1 minute  
**Effect:** Immediate (after schema refresh)
