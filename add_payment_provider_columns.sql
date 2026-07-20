-- ═══════════════════════════════════════════════════════════════════════════
-- 💳 Add Payment Provider Columns to profiles_private
-- ═══════════════════════════════════════════════════════════════════════════
-- 
-- PURPOSE: Store Razorpay and Stripe account IDs for payment processing
-- 
-- COMPLIANCE: These are SAFE identifiers (not actual bank details)
-- - razorpay_account_id: Razorpay linked account ID (e.g., "acc_xyz123")
-- - stripe_account_id: Stripe connected account ID (e.g., "acct_abc456")
-- - payment_provider: Which provider user selected ('razorpay' or 'stripe')
-- - bank_currency: Currency of the payment account
--   * Razorpay: INR (India only)
--   * Stripe: Multi-national currencies (INR, USD, EUR, GBP, AUD, CAD, etc.)
--
-- ═══════════════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────────────────
-- Step 1: Add payment provider columns (if they don't exist)
-- ──────────────────────────────────────────────────────────────────────────

-- Add payment_provider column
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles_private' 
        AND column_name = 'payment_provider'
    ) THEN
        ALTER TABLE profiles_private 
        ADD COLUMN payment_provider TEXT;
        
        COMMENT ON COLUMN profiles_private.payment_provider IS 
        'Payment gateway provider: ''razorpay'' (India/INR only) or ''stripe'' (Multi-national/Multi-currency). User can only have one active provider at a time.';
    END IF;
END $$;

-- Add razorpay_account_id column
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles_private' 
        AND column_name = 'razorpay_account_id'
    ) THEN
        ALTER TABLE profiles_private 
        ADD COLUMN razorpay_account_id TEXT;
        
        COMMENT ON COLUMN profiles_private.razorpay_account_id IS 
        'Razorpay linked account ID (e.g., acc_xyz123). Bank details are managed by Razorpay. This ID is safe to store and cannot be used to access bank accounts directly.';
    END IF;
END $$;

-- Add stripe_account_id column
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles_private' 
        AND column_name = 'stripe_account_id'
    ) THEN
        ALTER TABLE profiles_private 
        ADD COLUMN stripe_account_id TEXT;
        
        COMMENT ON COLUMN profiles_private.stripe_account_id IS 
        'Stripe connected account ID (e.g., acct_abc456). Bank details are managed by Stripe. This ID is safe to store and cannot be used to access bank accounts directly.';
    END IF;
END $$;

-- Add bank_currency column
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles_private' 
        AND column_name = 'bank_currency'
    ) THEN
        ALTER TABLE profiles_private 
        ADD COLUMN bank_currency TEXT;
        
        COMMENT ON COLUMN profiles_private.bank_currency IS 
        'Currency of the connected payment account (ISO 4217 code). Razorpay: INR only. Stripe: Supports 135+ currencies including INR, USD, EUR, GBP, AUD, CAD, SGD, etc. This determines the currency for all posts created by this user.';
    END IF;
END $$;

-- ──────────────────────────────────────────────────────────────────────────
-- Step 2: Add constraints for data integrity
-- ──────────────────────────────────────────────────────────────────────────

-- Ensure payment_provider is either 'razorpay' or 'stripe'
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'profiles_private_payment_provider_check'
    ) THEN
        ALTER TABLE profiles_private
        ADD CONSTRAINT profiles_private_payment_provider_check
        CHECK (payment_provider IN ('razorpay', 'stripe') OR payment_provider IS NULL);
    END IF;
END $$;

-- Ensure bank_currency is a valid 3-letter code
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'profiles_private_bank_currency_check'
    ) THEN
        ALTER TABLE profiles_private
        ADD CONSTRAINT profiles_private_bank_currency_check
        CHECK (bank_currency ~ '^[A-Z]{3}$' OR bank_currency IS NULL);
    END IF;
END $$;

-- ──────────────────────────────────────────────────────────────────────────
-- Step 3: Create indexes for faster queries
-- ──────────────────────────────────────────────────────────────────────────

-- Index on payment_provider (for filtering users by provider)
CREATE INDEX IF NOT EXISTS idx_profiles_private_payment_provider
ON profiles_private(payment_provider)
WHERE payment_provider IS NOT NULL;

-- Index on razorpay_account_id (for lookups)
CREATE INDEX IF NOT EXISTS idx_profiles_private_razorpay_account_id
ON profiles_private(razorpay_account_id)
WHERE razorpay_account_id IS NOT NULL;

-- Index on stripe_account_id (for lookups)
CREATE INDEX IF NOT EXISTS idx_profiles_private_stripe_account_id
ON profiles_private(stripe_account_id)
WHERE stripe_account_id IS NOT NULL;

-- ──────────────────────────────────────────────────────────────────────────
-- Step 4: Verify the columns exist
-- ──────────────────────────────────────────────────────────────────────────

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'profiles_private'
AND column_name IN ('payment_provider', 'razorpay_account_id', 'stripe_account_id', 'bank_currency')
ORDER BY column_name;

-- Expected output:
-- bank_currency           | text | YES | NULL
-- payment_provider        | text | YES | NULL
-- razorpay_account_id     | text | YES | NULL
-- stripe_account_id       | text | YES | NULL

-- ──────────────────────────────────────────────────────────────────────────
-- USAGE EXAMPLES
-- ──────────────────────────────────────────────────────────────────────────

-- Example 1: User connects Razorpay account
/*
UPDATE profiles_private
SET 
    payment_provider = 'razorpay',
    razorpay_account_id = 'acc_xyz123',
    bank_currency = 'INR',
    stripe_account_id = NULL  -- Clear Stripe ID if switching
WHERE profile_id = 'user-firebase-uid';
*/

-- Example 2: User connects Stripe account (with different currencies)
/*
-- USD example:
UPDATE profiles_private
SET 
    payment_provider = 'stripe',
    stripe_account_id = 'acct_abc456',
    bank_currency = 'USD',
    razorpay_account_id = NULL
WHERE profile_id = 'user-firebase-uid';

-- EUR example:
UPDATE profiles_private
SET 
    payment_provider = 'stripe',
    stripe_account_id = 'acct_abc456',
    bank_currency = 'EUR',
    razorpay_account_id = NULL
WHERE profile_id = 'user-firebase-uid';

-- INR example (Stripe also supports INR now):
UPDATE profiles_private
SET 
    payment_provider = 'stripe',
    stripe_account_id = 'acct_abc456',
    bank_currency = 'INR',
    razorpay_account_id = NULL
WHERE profile_id = 'user-firebase-uid';
*/

-- Example 3: Query all Razorpay users
/*
SELECT 
    profile_id,
    payment_provider,
    razorpay_account_id,
    bank_currency
FROM profiles_private
WHERE payment_provider = 'razorpay'
AND razorpay_account_id IS NOT NULL;
*/

-- Example 4: Query all Stripe users
/*
SELECT 
    profile_id,
    payment_provider,
    stripe_account_id,
    bank_currency
FROM profiles_private
WHERE payment_provider = 'stripe'
AND stripe_account_id IS NOT NULL;
*/

-- ──────────────────────────────────────────────────────────────────────────
-- SECURITY NOTES
-- ──────────────────────────────────────────────────────────────────────────

-- ✅ SAFE to store:
-- - razorpay_account_id: Just an identifier, cannot access bank account
-- - stripe_account_id: Just an identifier, cannot access bank account
-- - payment_provider: Just a string ('razorpay' or 'stripe')
-- - bank_currency: Just a currency code (INR, USD, EUR)

-- ❌ NEVER store (already removed):
-- - bank_account_number
-- - bank_ifsc
-- - bank_name
-- - bank_account_holder
-- - credit card numbers
-- - CVV codes

-- ──────────────────────────────────────────────────────────────────────────
-- COMPLIANCE STATUS
-- ──────────────────────────────────────────────────────────────────────────

-- ✅ PCI-DSS Compliant: No payment card or bank account data stored
-- ✅ RBI Compliant: Not acting as payment aggregator
-- ✅ GDPR Compliant: Account IDs are not sensitive financial data
-- ✅ DPDP Compliant: No sensitive personal financial data stored

-- ═══════════════════════════════════════════════════════════════════════════

SELECT '✅ Payment provider columns added successfully!' AS status;
