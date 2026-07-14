-- Create user_post_acceptances table
-- This table tracks when providers accept user posts (ride/delivery requests)

CREATE TABLE IF NOT EXISTS public.user_post_acceptances (
    id TEXT PRIMARY KEY,
    post_id TEXT NOT NULL,
    provider_id TEXT NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    amount DECIMAL(10, 2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    otp TEXT,
    otp_expires_at TIMESTAMPTZ,
    razorpay_order_id TEXT,
    razorpay_payment_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    paid_at TIMESTAMPTZ,
    
    -- Constraints
    CONSTRAINT valid_status CHECK (status IN ('pending', 'otpVerified', 'paid', 'cancelled')),
    CONSTRAINT positive_amount CHECK (amount > 0)
);

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_user_post_acceptances_post_id ON public.user_post_acceptances(post_id);
CREATE INDEX IF NOT EXISTS idx_user_post_acceptances_provider_id ON public.user_post_acceptances(provider_id);
CREATE INDEX IF NOT EXISTS idx_user_post_acceptances_user_id ON public.user_post_acceptances(user_id);
CREATE INDEX IF NOT EXISTS idx_user_post_acceptances_status ON public.user_post_acceptances(status);
CREATE INDEX IF NOT EXISTS idx_user_post_acceptances_created_at ON public.user_post_acceptances(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.user_post_acceptances ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view acceptances where they are either the provider or the user
CREATE POLICY "Users can view their own acceptances"
    ON public.user_post_acceptances
    FOR SELECT
    USING (
        auth.uid() = provider_id OR 
        auth.uid() = user_id
    );

-- Providers can create acceptances
CREATE POLICY "Providers can create acceptances"
    ON public.user_post_acceptances
    FOR INSERT
    WITH CHECK (auth.uid() = provider_id);

-- Providers and users can update their own acceptances
CREATE POLICY "Users can update their acceptances"
    ON public.user_post_acceptances
    FOR UPDATE
    USING (
        auth.uid() = provider_id OR 
        auth.uid() = user_id
    )
    WITH CHECK (
        auth.uid() = provider_id OR 
        auth.uid() = user_id
    );

-- Providers and users can cancel their acceptances
CREATE POLICY "Users can delete their acceptances"
    ON public.user_post_acceptances
    FOR DELETE
    USING (
        auth.uid() = provider_id OR 
        auth.uid() = user_id
    );

-- Add comment
COMMENT ON TABLE public.user_post_acceptances IS 'Tracks provider acceptances of user posts with OTP verification and payment tracking';
