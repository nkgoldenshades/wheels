-- Check what payment-related columns are missing from profiles table
-- Run this in Supabase SQL Editor to see what you need to add

-- Check current columns
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'profiles' 
  AND table_schema = 'public'
  AND column_name IN (
    'payment_provider', 
    'stripe_account_id', 
    'razorpay_account_id', 
    'wallet_balance', 
    'country'
  )
ORDER BY column_name;

-- Check if wallet_balance and country columns exist
DO $$
BEGIN
  -- Add wallet_balance if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' 
      AND table_schema = 'public' 
      AND column_name = 'wallet_balance'
  ) THEN
    ALTER TABLE profiles ADD COLUMN wallet_balance DECIMAL(10,2) DEFAULT 0.00;
    RAISE NOTICE 'Added wallet_balance column';
  ELSE
    RAISE NOTICE 'wallet_balance column already exists';
  END IF;

  -- Add country if missing (you already have it in schema)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' 
      AND table_schema = 'public' 
      AND column_name = 'country'
  ) THEN
    ALTER TABLE profiles ADD COLUMN country TEXT;
    RAISE NOTICE 'Added country column';
  ELSE
    RAISE NOTICE 'country column already exists';
  END IF;
END $$;

-- Set default payment provider for existing users
UPDATE profiles 
SET payment_provider = CASE 
  WHEN country = 'IN' OR country = 'India' THEN 'razorpay'
  ELSE 'razorpay'  -- Default to razorpay for now
END
WHERE payment_provider IS NULL;

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_profiles_payment_provider ON profiles(payment_provider);
CREATE INDEX IF NOT EXISTS idx_profiles_country ON profiles(country);

-- Final verification
SELECT 
  'payment_provider' as column_name,
  COUNT(*) as total_users,
  COUNT(CASE WHEN payment_provider = 'razorpay' THEN 1 END) as razorpay_users,
  COUNT(CASE WHEN payment_provider = 'stripe' THEN 1 END) as stripe_users
FROM profiles
UNION ALL
SELECT 
  'wallet_balance' as column_name,
  COUNT(*) as total_users,
  COUNT(CASE WHEN wallet_balance > 0 THEN 1 END) as users_with_balance,
  ROUND(AVG(wallet_balance), 2) as avg_balance
FROM profiles;