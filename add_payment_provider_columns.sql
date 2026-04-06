-- Add payment provider columns to profiles table
-- Run this in your Supabase SQL editor

-- Add payment provider columns
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS
  payment_provider TEXT DEFAULT 'razorpay' CHECK (
    payment_provider IN ('stripe', 'razorpay')
  );

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS
  stripe_account_id TEXT;

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS
  razorpay_account_id TEXT;

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS
  wallet_balance DECIMAL(10,2) DEFAULT 0.00;

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS
  country TEXT;

-- Update existing profiles to set payment provider based on country
-- (You can customize this logic based on your needs)
UPDATE profiles 
SET payment_provider = CASE 
  WHEN country = 'IN' OR country = 'India' THEN 'razorpay'
  ELSE 'stripe'
END
WHERE payment_provider IS NULL;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_profiles_payment_provider ON profiles(payment_provider);
CREATE INDEX IF NOT EXISTS idx_profiles_country ON profiles(country);

-- Verify the changes
SELECT 
  payment_provider,
  COUNT(*) as user_count
FROM profiles 
GROUP BY payment_provider;