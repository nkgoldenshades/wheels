-- ═══════════════════════════════════════════════════════════════════════
-- AUTO-DOWNGRADE EXPIRED SUBSCRIPTIONS
-- 
-- This function automatically resets expired Premium/Expert subscriptions
-- back to 'basic' plan. Runs daily via pg_cron scheduler.
-- 
-- Security: Server-side only, users cannot manipulate this logic
-- Performance: Indexed query on subscription_expires_at
-- ═══════════════════════════════════════════════════════════════════════

-- Step 1: Create the function that downgrades expired subscriptions
CREATE OR REPLACE FUNCTION auto_downgrade_expired_subscriptions()
RETURNS TABLE(downgraded_count INTEGER) AS $$
DECLARE
  affected_rows INTEGER;
BEGIN
  -- Update all expired subscriptions to 'basic'
  -- Only touches rows where:
  --   1. subscription_plan is NOT 'basic' (no need to update if already basic)
  --   2. subscription_expires_at has passed (expired)
  UPDATE profiles_private
  SET 
    subscription_plan = 'basic',
    subscription_expires_at = NULL  -- Clear expiry date for basic plan
  WHERE 
    subscription_plan != 'basic'
    AND subscription_expires_at IS NOT NULL
    AND subscription_expires_at < NOW();
  
  -- Get number of rows affected
  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  
  -- Log the operation
  RAISE NOTICE 'Auto-downgraded % expired subscriptions to basic', affected_rows;
  
  -- Return the count
  RETURN QUERY SELECT affected_rows;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 2: Add comment for documentation
COMMENT ON FUNCTION auto_downgrade_expired_subscriptions() IS 
'Automatically downgrades expired Premium/Expert subscriptions to basic plan. 
Should be called daily via pg_cron or similar scheduler.';

-- Step 3: Create index for performance (if not exists)
CREATE INDEX IF NOT EXISTS idx_profiles_private_subscription_expires 
ON profiles_private(subscription_expires_at) 
WHERE subscription_plan != 'basic';

-- ═══════════════════════════════════════════════════════════════════════
-- TESTING (Run this to test the function manually)
-- ═══════════════════════════════════════════════════════════════════════
-- SELECT * FROM auto_downgrade_expired_subscriptions();

-- ═══════════════════════════════════════════════════════════════════════
-- SCHEDULED EXECUTION (Option 1: pg_cron - Supabase Pro+ only)
-- ═══════════════════════════════════════════════════════════════════════
-- Uncomment this if you have Supabase Pro with pg_cron enabled:
/*
SELECT cron.schedule(
  'auto-downgrade-expired-subscriptions',  -- Job name
  '0 2 * * *',                              -- Run daily at 2 AM UTC
  'SELECT auto_downgrade_expired_subscriptions();'
);
*/

-- To unschedule (if needed):
-- SELECT cron.unschedule('auto-downgrade-expired-subscriptions');

-- ═══════════════════════════════════════════════════════════════════════
-- SCHEDULED EXECUTION (Option 2: Firebase Function - Works on all plans)
-- ═══════════════════════════════════════════════════════════════════════
-- Add this to your Firebase Functions (functions/index.js or similar):
/*
exports.autoDowngradeExpiredSubscriptions = functions.pubsub
  .schedule('0 2 * * *')  // Daily at 2 AM UTC
  .timeZone('UTC')
  .onRun(async (context) => {
    const { data, error } = await supabase
      .rpc('auto_downgrade_expired_subscriptions');
    
    if (error) {
      console.error('Error downgrading subscriptions:', error);
    } else {
      console.log(`Successfully downgraded ${data} expired subscriptions`);
    }
    
    return null;
  });
*/
