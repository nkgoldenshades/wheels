-- Verification script for payment provider currency setup
-- Run this in Supabase SQL Editor to check if everything is ready

-- 1. Check if required columns exist
SELECT 
    'profiles_private.bank_currency' AS check_item,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'profiles_private' AND column_name = 'bank_currency'
        ) THEN '✅ EXISTS'
        ELSE '❌ MISSING - Run add_bank_currency_to_profiles.sql'
    END AS status
UNION ALL
SELECT 
    'posts.currency_type' AS check_item,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'posts' AND column_name = 'currency_type'
        ) THEN '✅ EXISTS'
        ELSE '❌ MISSING - Run add_currency_type_to_posts.sql'
    END AS status;

-- 2. Check current profile data
SELECT 
    'Current Profiles' AS section,
    COUNT(*) AS total,
    COUNT(payment_provider) AS with_payment_provider,
    COUNT(bank_currency) AS with_bank_currency,
    COUNT(CASE WHEN payment_provider = 'razorpay' THEN 1 END) AS razorpay_users,
    COUNT(CASE WHEN payment_provider = 'stripe' THEN 1 END) AS stripe_users
FROM profiles_private;

-- 3. Show sample profile data (if columns exist)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles_private' AND column_name = 'bank_currency'
    ) THEN
        RAISE NOTICE 'Sample profiles with payment data:';
        PERFORM * FROM profiles_private 
        WHERE payment_provider IS NOT NULL 
        LIMIT 5;
    END IF;
END $$;
