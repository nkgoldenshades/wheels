-- ═══════════════════════════════════════════════════════════════════════════
-- EXPERT BADGE MANAGEMENT (Manual Approval System)
-- ═══════════════════════════════════════════════════════════════════════════
-- Expert badge is now subscription-based (not auto-earned)
-- You manually approve users and they must pay for expert status
-- ═══════════════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────────────────
-- 1. FIND CANDIDATES FOR EXPERT STATUS
-- ──────────────────────────────────────────────────────────────────────────
-- These users have good stats but need to be manually upgraded

SELECT 
  pub.id,
  pub.full_name,
  priv.subscription_plan,
  
  -- Provider stats
  pub.provider_total_trips,
  pub.provider_rating,
  
  -- Customer stats
  pub.customer_total_trips,
  pub.customer_rating,
  
  -- Current subscription status
  CASE 
    WHEN priv.subscription_plan = 'expert' AND priv.subscription_expires_at > NOW()
    THEN '✅ Already Expert'
    WHEN priv.subscription_plan = 'premium' AND priv.subscription_expires_at > NOW()
    THEN '⭐ Currently Premium'
    ELSE '👤 Basic User'
  END as current_status,
  
  -- Experience qualification
  CASE 
    WHEN (pub.provider_total_trips >= 50 AND pub.provider_rating >= 4.5)
         OR (pub.customer_total_trips >= 50 AND pub.customer_rating >= 4.5)
    THEN '✅ Has Experience'
    ELSE '❌ Needs More Experience'
  END as has_experience
  
FROM profiles_public pub
LEFT JOIN profiles_private priv ON pub.id = priv.profile_id

-- Filter: Show only users with expert-level experience
WHERE (pub.provider_total_trips >= 50 AND pub.provider_rating >= 4.5)
   OR (pub.customer_total_trips >= 50 AND pub.customer_rating >= 4.5)
   
-- And not already expert
AND (priv.subscription_plan != 'expert' 
     OR priv.subscription_expires_at < NOW()
     OR priv.subscription_plan IS NULL)

ORDER BY 
  pub.provider_total_trips + pub.customer_total_trips DESC;


-- ──────────────────────────────────────────────────────────────────────────
-- 2. GRANT EXPERT STATUS (After Payment Received)
-- ──────────────────────────────────────────────────────────────────────────
-- Use this after user pays for expert subscription

-- Replace 'USER_ID_HERE' and 'PAYMENT_ID_HERE' with actual values
UPDATE profiles_private
SET 
  subscription_plan = 'expert',
  subscription_expires_at = NOW() + INTERVAL '30 days', -- or '365 days' for yearly
  subscription_payment_id = 'PAYMENT_ID_HERE'
WHERE profile_id = 'USER_ID_HERE';

-- Example:
-- UPDATE profiles_private
-- SET 
--   subscription_plan = 'expert',
--   subscription_expires_at = NOW() + INTERVAL '365 days', -- Annual subscription
--   subscription_payment_id = 'pay_expert_abc123'
-- WHERE profile_id = 'user_xyz';


-- ──────────────────────────────────────────────────────────────────────────
-- 3. EXTEND EXPERT SUBSCRIPTION (Renewal)
-- ──────────────────────────────────────────────────────────────────────────
-- When existing expert renews their subscription

UPDATE profiles_private
SET 
  subscription_expires_at = subscription_expires_at + INTERVAL '365 days',
  subscription_payment_id = 'PAYMENT_ID_HERE'
WHERE profile_id = 'USER_ID_HERE'
  AND subscription_plan = 'expert';


-- ──────────────────────────────────────────────────────────────────────────
-- 4. REVOKE EXPERT STATUS (Manual)
-- ──────────────────────────────────────────────────────────────────────────
-- If you need to manually remove expert status (e.g., policy violation)

UPDATE profiles_private
SET 
  subscription_plan = 'basic',
  subscription_expires_at = NULL
WHERE profile_id = 'USER_ID_HERE';


-- ──────────────────────────────────────────────────────────────────────────
-- 5. VIEW ALL CURRENT EXPERT USERS
-- ──────────────────────────────────────────────────────────────────────────

SELECT 
  pub.id,
  pub.full_name,
  pub.profile_photo_url,
  priv.subscription_plan,
  priv.subscription_expires_at,
  
  -- Days remaining
  CASE 
    WHEN priv.subscription_expires_at > NOW()
    THEN EXTRACT(DAY FROM (priv.subscription_expires_at - NOW()))
    ELSE 0
  END as days_remaining,
  
  -- Status
  CASE 
    WHEN priv.subscription_expires_at > NOW() + INTERVAL '7 days'
    THEN '✅ Active'
    WHEN priv.subscription_expires_at > NOW()
    THEN '⚠️ Expiring Soon'
    ELSE '❌ Expired'
  END as status,
  
  -- Stats
  pub.provider_total_trips,
  pub.provider_rating,
  pub.customer_total_trips,
  pub.customer_rating,
  
  priv.subscription_payment_id

FROM profiles_public pub
JOIN profiles_private priv ON pub.id = priv.profile_id

WHERE priv.subscription_plan = 'expert'

ORDER BY priv.subscription_expires_at DESC;


-- ──────────────────────────────────────────────────────────────────────────
-- 6. VIEW EXPERT USERS EXPIRING SOON (Next 7 Days)
-- ──────────────────────────────────────────────────────────────────────────
-- Send them renewal reminders!

SELECT 
  pub.id,
  pub.full_name,
  priv.subscription_expires_at,
  EXTRACT(DAY FROM (priv.subscription_expires_at - NOW())) as days_remaining,
  pub.provider_total_trips + pub.customer_total_trips as total_trips

FROM profiles_public pub
JOIN profiles_private priv ON pub.id = priv.profile_id

WHERE priv.subscription_plan = 'expert'
  AND priv.subscription_expires_at > NOW()
  AND priv.subscription_expires_at < NOW() + INTERVAL '7 days'

ORDER BY priv.subscription_expires_at ASC;


-- ──────────────────────────────────────────────────────────────────────────
-- 7. PRICING SUGGESTIONS
-- ──────────────────────────────────────────────────────────────────────────

/*
RECOMMENDED PRICING:

Basic Plan:
  • Free
  • All basic features

Premium Plan:
  • India: ₹999/month or ₹9,999/year
  • International: $12.99/month or $129/year
  • Features: Priority support, premium badge, etc.

Expert Plan (MANUAL APPROVAL):
  • India: ₹4,999/month or ₹49,999/year (5x premium price)
  • International: $49.99/month or $499/year (4x premium price)
  • Requirements:
    - 50+ trips with 4.5+ rating OR
    - Special expertise/credentials verified by admin
  • Features:
    - Expert badge (💎)
    - Top priority in listings
    - Verified expert status
    - Premium features included
    - Featured profile
*/


-- ──────────────────────────────────────────────────────────────────────────
-- 8. BULK OPERATIONS
-- ──────────────────────────────────────────────────────────────────────────

-- Downgrade all expired expert users to basic (manual trigger)
UPDATE profiles_private
SET subscription_plan = 'basic'
WHERE subscription_plan = 'expert'
  AND subscription_expires_at < NOW();


-- Count users by subscription plan
SELECT 
  subscription_plan,
  COUNT(*) as user_count,
  COUNT(CASE WHEN subscription_expires_at > NOW() THEN 1 END) as active_count,
  COUNT(CASE WHEN subscription_expires_at < NOW() THEN 1 END) as expired_count
FROM profiles_private
GROUP BY subscription_plan
ORDER BY 
  CASE subscription_plan
    WHEN 'expert' THEN 1
    WHEN 'premium' THEN 2
    WHEN 'basic' THEN 3
    ELSE 4
  END;


-- ══════════════════════════════════════════════════════════════════════════
-- NOTES:
-- ══════════════════════════════════════════════════════════════════════════
-- 
-- 1. Expert badge is NO LONGER automatic
--    - Users can have 1000+ trips but won't get expert badge automatically
--    - You must manually upgrade them after payment
--
-- 2. hasExpertLevelExperience (in code) helps you find qualified candidates
--    - Use query #1 above to see who qualifies based on experience
--    - You can offer them expert upgrade at discounted rate
--
-- 3. Auto-downgrade still works
--    - Daily function at 2 AM UTC resets expired experts to 'basic'
--    - File: auto_downgrade_expired_subscriptions.sql
--
-- 4. Payment handling
--    - Create "Expert Plan" in your subscription UI
--    - Higher price (5x premium recommended)
--    - After payment success, run UPDATE query from section #2
--
-- ══════════════════════════════════════════════════════════════════════════
