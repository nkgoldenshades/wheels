-- ═══════════════════════════════════════════════════════════════════════════
-- DIAGNOSE CURRENCY ISSUE
-- Run this to understand why posts are showing wrong currency
-- ═══════════════════════════════════════════════════════════════════════════

-- Check 1: Does currency_type column exist in posts table?
SELECT 
  'posts.currency_type column' as check,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'posts' AND column_name = 'currency_type'
    ) THEN '✅ EXISTS'
    ELSE '❌ MISSING'
  END as status;

-- Check 2: What table stores profile data?
SELECT 
  table_name,
  column_name
FROM information_schema.columns
WHERE (table_name LIKE '%profile%' OR table_name = 'users')
  AND (column_name IN ('bank_currency', 'payment_provider', 'id'))
ORDER BY table_name, column_name;

-- Check 3: Show recent posts with their currency
SELECT 
  p.id,
  p.profile_id,
  p.price,
  p.currency_type,
  p.created_at,
  p.updated_at
FROM posts p
ORDER BY p.created_at DESC
LIMIT 5;

-- Check 4: Show profiles with payment info
-- Try profiles_private first
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles_private') THEN
    RAISE NOTICE '=== PROFILES_PRIVATE TABLE ===';
    PERFORM * FROM (
      SELECT 
        id,
        payment_provider,
        bank_currency,
        stripe_account_id,
        razorpay_account_id
      FROM profiles_private
      WHERE payment_provider IS NOT NULL
      LIMIT 5
    ) sub;
  ELSIF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles') THEN
    RAISE NOTICE '=== PROFILES TABLE ===';
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'profiles' AND column_name = 'bank_currency'
    ) THEN
      PERFORM * FROM (
        SELECT 
          id,
          payment_provider,
          bank_currency
        FROM profiles
        WHERE payment_provider IS NOT NULL
        LIMIT 5
      ) sub;
    END IF;
  END IF;
END $$;

-- Check 5: Find posts where currency doesn't match provider's bank_currency
-- This shows if there's a mismatch
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles_private') THEN
    RAISE NOTICE '=== CURRENCY MISMATCHES (profiles_private) ===';
    PERFORM * FROM (
      SELECT 
        p.id as post_id,
        p.currency_type as post_currency,
        pr.bank_currency as provider_bank_currency,
        pr.payment_provider,
        CASE 
          WHEN p.currency_type != pr.bank_currency THEN '❌ MISMATCH'
          ELSE '✅ MATCH'
        END as status
      FROM posts p
      JOIN profiles_private pr ON p.profile_id = pr.id
      WHERE pr.bank_currency IS NOT NULL
      LIMIT 10
    ) sub;
  ELSIF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles') THEN
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'profiles' AND column_name = 'bank_currency'
    ) THEN
      RAISE NOTICE '=== CURRENCY MISMATCHES (profiles) ===';
      PERFORM * FROM (
        SELECT 
          p.id as post_id,
          p.currency_type as post_currency,
          pr.bank_currency as provider_bank_currency,
          pr.payment_provider,
          CASE 
            WHEN p.currency_type != pr.bank_currency THEN '❌ MISMATCH'
            ELSE '✅ MATCH'
          END as status
        FROM posts p
        JOIN profiles pr ON p.profile_id = pr.id
        WHERE pr.bank_currency IS NOT NULL
        LIMIT 10
      ) sub;
    END IF;
  END IF;
END $$;

-- Check 6: Summary of all posts by currency
SELECT 
  COALESCE(currency_type, 'NULL') as currency,
  COUNT(*) as count,
  ROUND(AVG(price), 2) as avg_price
FROM posts
GROUP BY currency_type
ORDER BY count DESC;

-- ═══════════════════════════════════════════════════════════════════════════
-- INTERPRETATION:
-- ═══════════════════════════════════════════════════════════════════════════
-- If currency_type column is MISSING:
--   → Run: fix_post_currency_issue.sql
--
-- If posts show NULL or 'INR' but provider has bank_currency='USD':
--   → The issue is that new posts aren't saving currency correctly
--   → Check if _determineCurrencyType() is being called
--   → Check if provider's bank_currency is actually 'USD' in database
--
-- If posts show correct currency but feed shows wrong currency:
--   → The issue is in the Flutter app display logic
--   → Check if slot.currencySymbol getter is correct
--   → Check if feed is using slot.currencyType or user's preference
-- ═══════════════════════════════════════════════════════════════════════════
