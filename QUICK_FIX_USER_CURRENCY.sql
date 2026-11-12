-- ═══════════════════════════════════════════════════════════════════════════
-- QUICK FIX: Update User's Bank Currency
-- Use this to fix a specific user whose currency is wrong
-- ═══════════════════════════════════════════════════════════════════════════

-- STEP 1: Find your user ID
-- Replace 'your_email@example.com' with the actual email
-- SELECT id, email, payment_provider, bank_currency, stripe_account_id
-- FROM profiles  -- or profiles_private
-- WHERE email = 'your_email@example.com';

-- STEP 2: Update the user's bank_currency
-- Replace 'USER_ID_HERE' with the actual user ID from Step 1

-- For profiles_private table:
UPDATE profiles_private
SET bank_currency = 'USD'  -- Change to 'EUR', 'GBP', etc. as needed
WHERE id = 'USER_ID_HERE'
  AND payment_provider = 'stripe';

-- For regular profiles table (if using that instead):
-- UPDATE profiles
-- SET bank_currency = 'USD'
-- WHERE id = 'USER_ID_HERE'
--   AND payment_provider = 'stripe';

-- STEP 3: Update all existing posts by this user to use the correct currency
UPDATE posts
SET currency_type = 'USD'  -- Match the bank_currency above
WHERE profile_id = 'USER_ID_HERE'
  AND (currency_type IS NULL OR currency_type = 'INR' OR currency_type = '');

-- STEP 4: Verify the changes
SELECT 
  'User Profile' as type,
  id,
  payment_provider,
  bank_currency,
  stripe_account_id
FROM profiles_private  -- or profiles
WHERE id = 'USER_ID_HERE';

SELECT 
  'User Posts' as type,
  id,
  price,
  currency_type,
  created_at
FROM posts
WHERE profile_id = 'USER_ID_HERE'
ORDER BY created_at DESC
LIMIT 5;

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTOMATED VERSION: Fix all Stripe users
-- ═══════════════════════════════════════════════════════════════════════════
-- This updates ALL users with Stripe accounts to have USD currency
-- (unless they already have a different currency set)

-- Update profiles
UPDATE profiles_private
SET bank_currency = 'USD'
WHERE payment_provider = 'stripe'
  AND (bank_currency IS NULL OR bank_currency = '' OR bank_currency = 'INR')
  AND stripe_account_id IS NOT NULL;

-- Or for regular profiles table:
-- UPDATE profiles
-- SET bank_currency = 'USD'
-- WHERE payment_provider = 'stripe'
--   AND (bank_currency IS NULL OR bank_currency = '' OR bank_currency = 'INR');

-- Update their posts
UPDATE posts p
SET currency_type = 'USD'
FROM profiles_private pr  -- or profiles
WHERE p.profile_id = pr.id
  AND pr.payment_provider = 'stripe'
  AND pr.bank_currency = 'USD'
  AND (p.currency_type IS NULL OR p.currency_type = 'INR' OR p.currency_type = '');

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPLANATION:
-- ═══════════════════════════════════════════════════════════════════════════
-- When you created your Stripe account, the bank_currency field wasn't set.
-- So your posts defaulted to INR.
-- 
-- This script:
-- 1. Sets your bank_currency to USD
-- 2. Updates all your existing posts to show USD
-- 3. Future posts will automatically use USD
--
-- After running this, restart your app to see the changes!
-- ═══════════════════════════════════════════════════════════════════════════
