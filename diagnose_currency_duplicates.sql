-- 🔍 Diagnose Currency Duplicate Posts Issue

-- ===================================
-- STEP 1: Check Your Profile Settings
-- ===================================

-- Replace 'YOUR_USER_ID' with your actual Firebase user ID
-- (You can find this in the app or Firebase Console)

SELECT 
    id,
    profile_name,
    email,
    payment_provider,
    bank_currency,
    razorpay_account_id,
    stripe_account_id,
    bank_account_holder,
    created_at
FROM profiles
WHERE id = 'YOUR_USER_ID';

-- Expected result:
-- payment_provider: 'razorpay' (if using Indian bank)
-- bank_currency: 'INR' (should be set!)
-- razorpay_account_id: Should have a value if Razorpay connected

-- ===================================
-- STEP 2: Find All Your Posts
-- ===================================

SELECT 
    id,
    profile_id,
    vehicle_id,
    price,
    currency_type,
    from_location,
    to_location,
    service_type,
    is_active,
    created_at
FROM posts
WHERE profile_id = 'YOUR_USER_ID'
ORDER BY created_at DESC;

-- Check for duplicates:
-- - Same price but different currency_type
-- - Created at nearly the same time
-- - Same from_location and to_location

-- ===================================
-- STEP 3: Find Duplicate Posts (Same Price, Different Currency)
-- ===================================

SELECT 
    p1.id as post1_id,
    p1.price as price1,
    p1.currency_type as currency1,
    p1.created_at as created1,
    p2.id as post2_id,
    p2.price as price2,
    p2.currency_type as currency2,
    p2.created_at as created2,
    EXTRACT(EPOCH FROM (p2.created_at - p1.created_at)) as seconds_apart
FROM posts p1
JOIN posts p2 ON p1.profile_id = p2.profile_id
WHERE p1.profile_id = 'YOUR_USER_ID'
  AND p1.price = p2.price
  AND p1.currency_type != p2.currency_type
  AND p1.id != p2.id
ORDER BY p1.created_at DESC;

-- This finds posts with:
-- - Same price
-- - Different currency
-- - Same user
-- Shows how many seconds apart they were created

-- ===================================
-- STEP 4: Count Posts by Currency
-- ===================================

SELECT 
    currency_type,
    COUNT(*) as count,
    SUM(price) as total_value
FROM posts
WHERE profile_id = 'YOUR_USER_ID'
  AND is_active = true
GROUP BY currency_type
ORDER BY count DESC;

-- Shows how many posts you have in each currency

-- ===================================
-- STEP 5: Fix - Delete Wrong Currency Posts
-- ===================================

-- ⚠️ CAREFUL: Only run this after confirming which posts to delete!

-- Option 1: Delete all USD posts (if you only use INR)
/*
DELETE FROM posts
WHERE profile_id = 'YOUR_USER_ID'
  AND currency_type = 'USD';
*/

-- Option 2: Delete specific post by ID
/*
DELETE FROM posts
WHERE id = 'POST_ID_TO_DELETE';
*/

-- ===================================
-- STEP 6: Fix Profile Currency (if NULL)
-- ===================================

-- Set bank_currency to INR if it's not set
/*
UPDATE profiles
SET 
    bank_currency = 'INR',
    payment_provider = 'razorpay'
WHERE id = 'YOUR_USER_ID'
  AND (bank_currency IS NULL OR bank_currency = '');
*/

-- ===================================
-- STEP 7: Verify Fix
-- ===================================

-- Check profile is fixed
SELECT id, profile_name, bank_currency, payment_provider
FROM profiles
WHERE id = 'YOUR_USER_ID';

-- Check posts are correct
SELECT id, price, currency_type, from_location, created_at
FROM posts
WHERE profile_id = 'YOUR_USER_ID'
ORDER BY created_at DESC
LIMIT 10;

-- ===================================
-- TROUBLESHOOTING GUIDE
-- ===================================

/*
SCENARIO 1: bank_currency is NULL
---------------------------------
Problem: Your profile doesn't have bank_currency set
Fix: Run Step 6 to set it to 'INR'
Then restart app

SCENARIO 2: Duplicate posts exist
----------------------------------
Problem: Post created twice (once with USD, once with INR)
Fix: Run Step 5 to delete the USD posts
Keep only the INR posts

SCENARIO 3: payment_provider is NULL
-------------------------------------
Problem: App doesn't know which payment gateway you use
Fix: 
UPDATE profiles
SET payment_provider = 'razorpay'  -- or 'stripe'
WHERE id = 'YOUR_USER_ID';

SCENARIO 4: Posts created with wrong currency
----------------------------------------------
Problem: Old posts created before bank_currency was set
Fix: Either delete them or update currency:
UPDATE posts
SET currency_type = 'INR'
WHERE profile_id = 'YOUR_USER_ID'
  AND currency_type = 'USD'
  AND from_location LIKE '%India%';
*/

-- ===================================
-- PREVENTION: Ensure Future Posts Use Correct Currency
-- ===================================

-- Verify your current settings one more time:
SELECT 
    id,
    profile_name,
    payment_provider,
    bank_currency,
    CASE 
        WHEN bank_currency IS NULL THEN '❌ NOT SET - Will default!'
        WHEN bank_currency = 'INR' THEN '✅ Correct for India'
        WHEN bank_currency = 'USD' THEN '✅ Correct for US'
        ELSE '⚠️ Check if correct'
    END as currency_status
FROM profiles
WHERE id = 'YOUR_USER_ID';
