-- =====================================================
-- Change Signup Credits from 50 to 0.2
-- =====================================================
-- Run this in Supabase SQL Editor to update credit system
-- =====================================================

-- Step 1: Change default for new users to 0.2 credits
ALTER TABLE profiles_private 
  ALTER COLUMN ai_credits_available SET DEFAULT 0.2;

-- Step 2: Update the signup bonus trigger to give 0.2 credits
CREATE OR REPLACE FUNCTION give_new_user_signup_credits()
RETURNS TRIGGER AS $$
BEGIN
  -- New users get 0.2 credits (instead of 50)
  IF NEW.ai_credits_available IS NULL THEN
    NEW.ai_credits_available := 0.2;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Recreate trigger (in case it doesn't exist)
DROP TRIGGER IF EXISTS tr_new_user_signup_credits ON profiles_private;

CREATE TRIGGER tr_new_user_signup_credits
  BEFORE INSERT ON profiles_private
  FOR EACH ROW
  EXECUTE FUNCTION give_new_user_signup_credits();

-- Step 4: (OPTIONAL) Reset existing users to 0.2 credits
-- ⚠️ ONLY RUN THIS IF YOU WANT TO RESET ALL EXISTING USERS
-- ⚠️ Comment out the lines below if you want to keep existing user credits

-- UPDATE profiles_private 
--   SET ai_credits_available = 0.2
--   WHERE ai_credits_available >= 50;

-- =====================================================
-- Verification Query - Run this to confirm changes
-- =====================================================

SELECT 
  column_default 
FROM information_schema.columns 
WHERE table_name = 'profiles_private' 
  AND column_name = 'ai_credits_available';

-- Expected result: 0.2

-- =====================================================
-- Summary
-- =====================================================
-- ✅ New users will get 0.2 credits on signup
-- ✅ Default column value changed to 0.2
-- ✅ Trigger updated to match
-- ℹ️ Existing users keep their current credits (unless you ran Step 4)
-- =====================================================
