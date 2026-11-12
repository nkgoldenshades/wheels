-- ============================================================================
-- PROFILES TABLE SPLIT MIGRATION
-- ============================================================================
-- This migration splits the monolithic 'profiles' table into 3 tables:
-- 1. profiles - Public info (name, photo, rating, business type)
-- 2. profile_contact - Contact info (phone, email) - visible during active bookings
-- 3. profile_confidential - Sensitive data (documents, bank, verification, credits)
-- ============================================================================

-- STEP 1: Create new tables
-- ============================================================================

-- Table 1: profile_contact (visible to booking partners during active bookings)
CREATE TABLE IF NOT EXISTS public.profile_contact (
    id TEXT PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    phone_number TEXT,
    email TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table 2: profile_confidential (owner-only access)
CREATE TABLE IF NOT EXISTS public.profile_confidential (
    id TEXT PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    
    -- AI Credits (PRIVATE)
    ai_credits_available INTEGER DEFAULT 50,
    ai_credits_used INTEGER DEFAULT 0,
    ai_last_used_at TIMESTAMPTZ,
    ai_credit_reset_at TIMESTAMPTZ,
    
    -- Wallet/Balance (PRIVATE) - if exists in your schema
    wallet_balance DECIMAL(10,2) DEFAULT 0.0,
    
    -- Bank details (PRIVATE)
    bank_account_holder TEXT,
    bank_account_number TEXT,
    bank_account_type TEXT,
    bank_name TEXT,
    bank_ifsc TEXT,
    
    -- Payment provider accounts (PRIVATE)
    payment_provider TEXT DEFAULT 'razorpay',
    stripe_account_id TEXT,
    razorpay_account_id TEXT,
    
    -- ID Documents (PRIVATE - stored as Base64 or URLs)
    national_id_number TEXT,
    national_id_verified BOOLEAN DEFAULT FALSE,
    national_id_front_url TEXT,
    national_id_back_url TEXT,
    
    tax_id_number TEXT,
    tax_id_verified BOOLEAN DEFAULT FALSE,
    tax_id_front_url TEXT,
    
    driving_license_number TEXT,
    driving_license_verified BOOLEAN DEFAULT FALSE,
    driving_license_front_url TEXT,
    driving_license_back_url TEXT,
    
    business_id_number TEXT,
    business_id_verified BOOLEAN DEFAULT FALSE,
    business_id_front_url TEXT,
    business_id_back_url TEXT,
    
    -- Verification & fraud detection (PRIVATE)
    ai_verification_log JSONB,
    fraud_score DECIMAL(5,2),
    vetting_status TEXT,
    vetting_notes TEXT,
    device_ip TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- STEP 2: Migrate existing data from profiles table
-- ============================================================================

-- Migrate contact info to profile_contact
INSERT INTO public.profile_contact (id, phone_number, email, created_at, updated_at)
SELECT 
    id,
    phone_number,
    email,
    created_at,
    updated_at
FROM public.profiles
ON CONFLICT (id) DO NOTHING;

-- Migrate confidential data to profile_confidential
INSERT INTO public.profile_confidential (
    id,
    ai_credits_available,
    ai_credits_used,
    ai_last_used_at,
    ai_credit_reset_at,
    wallet_balance,
    bank_account_holder,
    bank_account_number,
    bank_account_type,
    bank_name,
    bank_ifsc,
    payment_provider,
    stripe_account_id,
    razorpay_account_id,
    national_id_number,
    national_id_verified,
    national_id_front_url,
    national_id_back_url,
    tax_id_number,
    tax_id_verified,
    tax_id_front_url,
    driving_license_number,
    driving_license_verified,
    driving_license_front_url,
    driving_license_back_url,
    business_id_number,
    business_id_verified,
    business_id_front_url,
    business_id_back_url,
    ai_verification_log,
    fraud_score,
    vetting_status,
    vetting_notes,
    device_ip,
    created_at,
    updated_at
)
SELECT 
    id,
    COALESCE(ai_credits_available, 50),
    COALESCE(ai_credits_used, 0),
    ai_last_used_at,
    ai_credit_reset_at,
    COALESCE(wallet_balance, 0.0),
    bank_account_holder,
    bank_account_number,
    bank_account_type,
    bank_name,
    bank_ifsc,
    COALESCE(payment_provider, 'razorpay'),
    stripe_account_id,
    razorpay_account_id,
    national_id_number,
    COALESCE(national_id_verified, FALSE),
    national_id_front_url,
    national_id_back_url,
    tax_id_number,
    COALESCE(tax_id_verified, FALSE),
    tax_id_front_url,
    driving_license_number,
    COALESCE(driving_license_verified, FALSE),
    driving_license_front_url,
    driving_license_back_url,
    business_id_number,
    COALESCE(business_id_verified, FALSE),
    business_id_front_url,
    business_id_back_url,
    ai_verification_log,
    fraud_score,
    vetting_status,
    vetting_notes,
    device_ip,
    created_at,
    updated_at
FROM public.profiles
ON CONFLICT (id) DO NOTHING;

-- STEP 3: Drop migrated columns from profiles table
-- ============================================================================
-- Keep only public info in profiles table

ALTER TABLE public.profiles 
    DROP COLUMN IF EXISTS phone_number,
    DROP COLUMN IF EXISTS email,
    DROP COLUMN IF EXISTS ai_credits_available,
    DROP COLUMN IF EXISTS ai_credits_used,
    DROP COLUMN IF EXISTS ai_last_used_at,
    DROP COLUMN IF EXISTS ai_credit_reset_at,
    DROP COLUMN IF EXISTS wallet_balance,
    DROP COLUMN IF EXISTS bank_account_holder,
    DROP COLUMN IF EXISTS bank_account_number,
    DROP COLUMN IF EXISTS bank_account_type,
    DROP COLUMN IF EXISTS bank_name,
    DROP COLUMN IF EXISTS bank_ifsc,
    DROP COLUMN IF EXISTS payment_provider,
    DROP COLUMN IF EXISTS stripe_account_id,
    DROP COLUMN IF EXISTS razorpay_account_id,
    DROP COLUMN IF EXISTS national_id_number,
    DROP COLUMN IF EXISTS national_id_verified,
    DROP COLUMN IF EXISTS national_id_front_url,
    DROP COLUMN IF EXISTS national_id_back_url,
    DROP COLUMN IF EXISTS tax_id_number,
    DROP COLUMN IF EXISTS tax_id_verified,
    DROP COLUMN IF EXISTS tax_id_front_url,
    DROP COLUMN IF EXISTS driving_license_number,
    DROP COLUMN IF EXISTS driving_license_verified,
    DROP COLUMN IF EXISTS driving_license_front_url,
    DROP COLUMN IF EXISTS driving_license_back_url,
    DROP COLUMN IF EXISTS business_id_number,
    DROP COLUMN IF EXISTS business_id_verified,
    DROP COLUMN IF EXISTS business_id_front_url,
    DROP COLUMN IF EXISTS business_id_back_url,
    DROP COLUMN IF EXISTS ai_verification_log,
    DROP COLUMN IF EXISTS fraud_score,
    DROP COLUMN IF EXISTS vetting_status,
    DROP COLUMN IF EXISTS vetting_notes,
    DROP COLUMN IF EXISTS device_ip;

-- STEP 4: Create RLS policies
-- ============================================================================

-- Enable RLS on new tables
ALTER TABLE public.profile_contact ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_confidential ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES FOR: profiles (public info)
-- ============================================================================

-- Drop existing policies if any
DROP POLICY IF EXISTS "profiles_select_authenticated" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;

-- Policy 1: All authenticated users can read public profiles
CREATE POLICY "profiles_select_authenticated"
ON public.profiles
FOR SELECT
TO authenticated
USING (true);

-- Policy 2: Users can insert their own profile
CREATE POLICY "profiles_insert_own"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (auth.uid()::text = id);

-- Policy 3: Users can update their own profile
CREATE POLICY "profiles_update_own"
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth.uid()::text = id)
WITH CHECK (auth.uid()::text = id);

-- ============================================================================
-- RLS POLICIES FOR: profile_contact (visible during active bookings)
-- ============================================================================

-- Policy 1: Owner can always read their own contact info
CREATE POLICY "contact_select_own"
ON public.profile_contact
FOR SELECT
TO authenticated
USING (auth.uid()::text = id);

-- Policy 2: Users can read contact info of their booking partners (active bookings only)
-- Active bookings = pending, accepted, confirmed, inProgress
CREATE POLICY "contact_select_booking_partner"
ON public.profile_contact
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.bookings
        WHERE 
            bookings.status IN ('pending', 'accepted', 'confirmed', 'in_progress')
            AND (
                -- User is the customer and can see provider's contact
                (bookings.user_id = auth.uid()::text AND profile_contact.id = bookings.provider_id)
                OR
                -- User is the provider and can see customer's contact
                (bookings.provider_id = auth.uid()::text AND profile_contact.id = bookings.user_id)
            )
    )
);

-- Policy 3: Users can insert their own contact info
CREATE POLICY "contact_insert_own"
ON public.profile_contact
FOR INSERT
TO authenticated
WITH CHECK (auth.uid()::text = id);

-- Policy 4: Users can update their own contact info
CREATE POLICY "contact_update_own"
ON public.profile_contact
FOR UPDATE
TO authenticated
USING (auth.uid()::text = id)
WITH CHECK (auth.uid()::text = id);

-- ============================================================================
-- RLS POLICIES FOR: profile_confidential (owner-only)
-- ============================================================================

-- Policy 1: Users can only read their own confidential data
CREATE POLICY "confidential_select_own"
ON public.profile_confidential
FOR SELECT
TO authenticated
USING (auth.uid()::text = id);

-- Policy 2: Users can insert their own confidential data
CREATE POLICY "confidential_insert_own"
ON public.profile_confidential
FOR INSERT
TO authenticated
WITH CHECK (auth.uid()::text = id);

-- Policy 3: Users can update their own confidential data
CREATE POLICY "confidential_update_own"
ON public.profile_confidential
FOR UPDATE
TO authenticated
USING (auth.uid()::text = id)
WITH CHECK (auth.uid()::text = id);

-- STEP 5: Create indexes for performance
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_profile_contact_id ON public.profile_contact(id);
CREATE INDEX IF NOT EXISTS idx_profile_confidential_id ON public.profile_confidential(id);

-- Index for booking partner lookup (used in RLS policy)
CREATE INDEX IF NOT EXISTS idx_bookings_user_status ON public.bookings(user_id, status);
CREATE INDEX IF NOT EXISTS idx_bookings_provider_status ON public.bookings(provider_id, status);

-- STEP 6: Create updated_at triggers
-- ============================================================================

-- Trigger function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to profile_contact
DROP TRIGGER IF EXISTS update_profile_contact_updated_at ON public.profile_contact;
CREATE TRIGGER update_profile_contact_updated_at
    BEFORE UPDATE ON public.profile_contact
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Apply trigger to profile_confidential
DROP TRIGGER IF EXISTS update_profile_confidential_updated_at ON public.profile_confidential;
CREATE TRIGGER update_profile_confidential_updated_at
    BEFORE UPDATE ON public.profile_confidential
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
-- Next steps:
-- 1. Run this SQL in Supabase SQL Editor
-- 2. Update Flutter code to query from 3 tables instead of 1
-- 3. Test profile creation, updates, and booking contact visibility
-- ============================================================================
