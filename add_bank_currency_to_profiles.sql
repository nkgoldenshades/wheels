-- Add bank_currency column to profiles_private table
-- This column stores the currency of the provider's connected bank account
-- Used for auto-detecting post currency (INR/USD/GBP/EUR)

-- Add the column
ALTER TABLE profiles_private 
ADD COLUMN IF NOT EXISTS bank_currency TEXT;

-- Add comment
COMMENT ON COLUMN profiles_private.bank_currency IS 'Currency of the connected bank account (INR/USD/GBP/EUR) - auto-detected from Stripe/Razorpay';

-- Update existing profiles based on payment_provider
-- Razorpay → INR (India only)
UPDATE profiles_private
SET bank_currency = 'INR'
WHERE payment_provider = 'razorpay' 
  AND (bank_currency IS NULL OR bank_currency = '');

-- Stripe → USD (default, can be changed later)
UPDATE profiles_private
SET bank_currency = 'USD'
WHERE payment_provider = 'stripe' 
  AND (bank_currency IS NULL OR bank_currency = '');

-- Verify the changes
SELECT 
    COUNT(*) as total_profiles,
    COUNT(bank_currency) as profiles_with_currency,
    COUNT(CASE WHEN bank_currency = 'INR' THEN 1 END) as inr_profiles,
    COUNT(CASE WHEN bank_currency = 'USD' THEN 1 END) as usd_profiles,
    COUNT(CASE WHEN bank_currency IS NULL THEN 1 END) as null_currency
FROM profiles_private;

-- Show sample data
SELECT 
    id,
    payment_provider,
    stripe_account_id,
    razorpay_account_id,
    bank_currency
FROM profiles_private
WHERE payment_provider IS NOT NULL
LIMIT 10;
