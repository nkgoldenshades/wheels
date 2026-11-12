-- ═══════════════════════════════════════════════════════════════════════════
-- FIX POST CURRENCY ISSUE
-- Problem: Posts created with USD are showing as INR in feed
-- Solution: Ensure currency_type column exists and has correct values
-- ═══════════════════════════════════════════════════════════════════════════

-- Step 1: Add currency_type column if it doesn't exist
ALTER TABLE posts 
ADD COLUMN IF NOT EXISTS currency_type TEXT DEFAULT 'INR';

-- Step 2: Add index for faster currency filtering
CREATE INDEX IF NOT EXISTS idx_posts_currency_type ON posts(currency_type);

-- Step 3: Update existing posts to have correct currency_type
-- Try multiple table name variations (profiles, profiles_private, users)

-- First, try profiles_private table
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles_private') THEN
    UPDATE posts p
    SET currency_type = COALESCE(
      (SELECT bank_currency FROM profiles_private WHERE id = p.profile_id),
      'INR'
    )
    WHERE p.currency_type IS NULL OR p.currency_type = '' OR p.currency_type = 'INR';
    
    RAISE NOTICE 'Updated posts currency from profiles_private.bank_currency';
  END IF;
END $$;

-- If profiles_private doesn't exist, try regular profiles table
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles_private') 
     AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles') THEN
    
    -- Check if profiles table has bank_currency column
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'profiles' AND column_name = 'bank_currency'
    ) THEN
      UPDATE posts p
      SET currency_type = COALESCE(
        (SELECT bank_currency FROM profiles WHERE id = p.profile_id),
        'INR'
      )
      WHERE p.currency_type IS NULL OR p.currency_type = '' OR p.currency_type = 'INR';
      
      RAISE NOTICE 'Updated posts currency from profiles.bank_currency';
    END IF;
  END IF;
END $$;

-- Step 4: For posts where bank_currency is not set, use payment_provider as fallback
DO $$
BEGIN
  -- Try profiles_private first
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles_private') THEN
    UPDATE posts p
    SET currency_type = CASE 
      WHEN (SELECT payment_provider FROM profiles_private WHERE id = p.profile_id) = 'razorpay' THEN 'INR'
      WHEN (SELECT payment_provider FROM profiles_private WHERE id = p.profile_id) = 'stripe' THEN 'USD'
      ELSE 'INR'
    END
    WHERE (p.currency_type IS NULL OR p.currency_type = '' OR p.currency_type = 'INR')
      AND EXISTS (
        SELECT 1 FROM profiles_private pr 
        WHERE pr.id = p.profile_id 
        AND pr.payment_provider IS NOT NULL
      );
    
    RAISE NOTICE 'Applied fallback currency based on payment_provider (profiles_private)';
  
  -- Try regular profiles table
  ELSIF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles') THEN
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'profiles' AND column_name = 'payment_provider'
    ) THEN
      UPDATE posts p
      SET currency_type = CASE 
        WHEN (SELECT payment_provider FROM profiles WHERE id = p.profile_id) = 'razorpay' THEN 'INR'
        WHEN (SELECT payment_provider FROM profiles WHERE id = p.profile_id) = 'stripe' THEN 'USD'
        ELSE 'INR'
      END
      WHERE (p.currency_type IS NULL OR p.currency_type = '' OR p.currency_type = 'INR')
        AND EXISTS (
          SELECT 1 FROM profiles pr 
          WHERE pr.id = p.profile_id 
          AND pr.payment_provider IS NOT NULL
        );
      
      RAISE NOTICE 'Applied fallback currency based on payment_provider (profiles)';
    END IF;
  END IF;
END $$;

-- Step 5: Verification - Show posts with their currency
SELECT 
  p.id,
  p.profile_id,
  p.currency_type,
  p.price,
  CASE 
    WHEN p.currency_type = 'INR' THEN '₹'
    WHEN p.currency_type = 'USD' THEN '$'
    WHEN p.currency_type = 'EUR' THEN '€'
    WHEN p.currency_type = 'GBP' THEN '£'
    ELSE p.currency_type
  END as symbol,
  p.created_at
FROM posts p
ORDER BY p.created_at DESC
LIMIT 10;

-- Step 6: Show summary
SELECT 
  currency_type,
  COUNT(*) as post_count,
  CASE 
    WHEN currency_type = 'INR' THEN '₹'
    WHEN currency_type = 'USD' THEN '$'
    WHEN currency_type = 'EUR' THEN '€'
    WHEN currency_type = 'GBP' THEN '£'
    ELSE currency_type
  END as symbol
FROM posts
GROUP BY currency_type
ORDER BY post_count DESC;

-- ═══════════════════════════════════════════════════════════════════════════
-- NEXT STEPS FOR NEW POSTS:
-- ═══════════════════════════════════════════════════════════════════════════
-- The Flutter app already saves currency_type correctly when creating posts.
-- This script only fixes EXISTING posts that were created before the 
-- currency_type column was added.
-- 
-- For new posts, the currency is automatically determined by:
-- 1. Provider's bank_currency (set when connecting Razorpay/Stripe)
-- 2. Fallback to payment_provider (Razorpay=INR, Stripe=USD)
-- 3. Default to INR if neither is set
-- ═══════════════════════════════════════════════════════════════════════════
