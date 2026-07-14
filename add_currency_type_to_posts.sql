-- Add currency_type column to posts table
-- This column stores the currency code based on provider's connected bank account
-- Values: 'INR', 'USD', 'GBP', 'EUR', etc.
-- Currency is auto-detected from the user's Stripe/Razorpay account bank_currency field

ALTER TABLE posts 
ADD COLUMN IF NOT EXISTS currency_type TEXT DEFAULT 'INR';

COMMENT ON COLUMN posts.currency_type IS 'Currency code for this post, auto-detected from provider''s bank account (e.g., INR for Razorpay India, USD/GBP/EUR for Stripe)';

-- Update existing posts to have currency_type based on their provider's bank currency
-- This is a best-effort update for existing data
UPDATE posts p
SET currency_type = COALESCE(
    (SELECT bank_currency FROM profiles_private WHERE id = p.profile_id),
    'INR'
)
WHERE p.currency_type IS NULL OR p.currency_type = '';

-- For posts where provider hasn't set bank_currency, use their payment_provider as fallback
UPDATE posts p
SET currency_type = CASE 
    WHEN (SELECT payment_provider FROM profiles_private WHERE id = p.profile_id) = 'razorpay' THEN 'INR'
    WHEN (SELECT payment_provider FROM profiles_private WHERE id = p.profile_id) = 'stripe' THEN 'USD'
    ELSE 'INR'
END
WHERE p.currency_type IS NULL OR p.currency_type = '';
