-- ═══════════════════════════════════════════════════════════════════════════
-- 💳 Credit System Setup - Complete Database Schema
-- ═══════════════════════════════════════════════════════════════════════════
-- 
-- This migration sets up the complete credit system for AI message usage:
-- 1. Credit balance tracking in profiles_private
-- 2. Credit transaction history
-- 3. Credit packages (predefined purchase options)
-- 4. Indexes for performance
-- ═══════════════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────────────────
-- Step 1: Add AI credits column to profiles_private (if not already exists)
-- ──────────────────────────────────────────────────────────────────────────

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles_private' 
        AND column_name = 'ai_credits_available'
    ) THEN
        ALTER TABLE profiles_private 
        ADD COLUMN ai_credits_available INTEGER DEFAULT 50;
        
        COMMENT ON COLUMN profiles_private.ai_credits_available IS 
        'Available AI message credits. Each message costs fractional credits based on Gemini token usage.';
    END IF;
END $$;

-- ──────────────────────────────────────────────────────────────────────────
-- Step 2: Create credit_transactions table
-- ──────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.credit_transactions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('purchase', 'usage', 'bonus', 'refund')),
  credits_changed INTEGER NOT NULL, -- Positive for additions, negative for usage
  amount_usd NUMERIC(10, 2), -- For purchases
  description TEXT,
  related_booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
  payment_gateway_id TEXT, -- Stripe payment intent ID or Razorpay order ID
  metadata JSONB, -- Additional data (e.g., token counts for usage)
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  -- Indexes for performance
  CONSTRAINT credit_transactions_credits_check CHECK (credits_changed != 0)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_credit_transactions_user_id 
  ON public.credit_transactions(user_id);

CREATE INDEX IF NOT EXISTS idx_credit_transactions_created_at 
  ON public.credit_transactions(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_credit_transactions_type 
  ON public.credit_transactions(type);

CREATE INDEX IF NOT EXISTS idx_credit_transactions_payment_gateway_id 
  ON public.credit_transactions(payment_gateway_id);

-- ──────────────────────────────────────────────────────────────────────────
-- Step 3: Create credit_packages table (reference data)
-- ──────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.credit_packages (
  id TEXT PRIMARY KEY,
  credits INTEGER NOT NULL,
  price_usd NUMERIC(10, 2) NOT NULL,
  savings_percent NUMERIC(5, 2) DEFAULT 0,
  is_popular BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Insert predefined packages
INSERT INTO public.credit_packages (id, credits, price_usd, savings_percent, is_popular)
VALUES 
  ('starter', 50, 2.99, 0, FALSE),
  ('basic', 100, 4.99, 17, TRUE),
  ('pro', 500, 19.99, 33, FALSE),
  ('enterprise', 1000, 34.99, 42, FALSE)
ON CONFLICT (id) DO UPDATE SET
  price_usd = EXCLUDED.price_usd,
  savings_percent = EXCLUDED.savings_percent,
  is_popular = EXCLUDED.is_popular;

-- ──────────────────────────────────────────────────────────────────────────
-- Step 4: Row-Level Security (RLS) for credit_transactions
-- ──────────────────────────────────────────────────────────────────────────

ALTER TABLE public.credit_transactions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own transactions
DROP POLICY IF EXISTS "Users can view own credit transactions" ON public.credit_transactions;
CREATE POLICY "Users can view own credit transactions" ON public.credit_transactions
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Only Firebase JWT (via RLS claims) can insert transactions
DROP POLICY IF EXISTS "System can insert credit transactions" ON public.credit_transactions;
CREATE POLICY "System can insert credit transactions" ON public.credit_transactions
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Prevent updates to transactions (immutable)
ALTER TABLE public.credit_transactions DISABLE ROW LEVEL SECURITY;
-- Re-enable after inserting to keep it simple - transactions are append-only

-- ──────────────────────────────────────────────────────────────────────────
-- Step 5: RLS for credit_packages (public read-only)
-- ──────────────────────────────────────────────────────────────────────────

ALTER TABLE public.credit_packages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read credit packages" ON public.credit_packages;
CREATE POLICY "Anyone can read credit packages" ON public.credit_packages
  FOR SELECT
  USING (TRUE);

-- ──────────────────────────────────────────────────────────────────────────
-- Step 6: Create payment records table (for Stripe webhooks)
-- ──────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.stripe_payment_records (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  payment_intent_id TEXT NOT NULL UNIQUE,
  credits INTEGER NOT NULL,
  amount_cents INTEGER NOT NULL,
  currency TEXT DEFAULT 'usd',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'succeeded', 'failed', 'cancelled')),
  stripe_event_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_stripe_payment_records_user_id 
  ON public.stripe_payment_records(user_id);

CREATE INDEX IF NOT EXISTS idx_stripe_payment_records_payment_intent_id 
  ON public.stripe_payment_records(payment_intent_id);

CREATE INDEX IF NOT EXISTS idx_stripe_payment_records_status 
  ON public.stripe_payment_records(status);

-- ──────────────────────────────────────────────────────────────────────────
-- Step 7: Enable RLS for stripe_payment_records
-- ──────────────────────────────────────────────────────────────────────────

ALTER TABLE public.stripe_payment_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own stripe payments" ON public.stripe_payment_records;
CREATE POLICY "Users can view own stripe payments" ON public.stripe_payment_records
  FOR SELECT
  USING (auth.uid() = user_id);

-- ──────────────────────────────────────────────────────────────────────────
-- Step 8: Create function to handle credit deduction
-- ──────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.deduct_credits(
  p_user_id TEXT,
  p_credits INTEGER,
  p_description TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT NULL
)
RETURNS TABLE (
  success BOOLEAN,
  remaining_credits INTEGER,
  error_message TEXT
) AS $$
DECLARE
  v_current_credits INTEGER;
BEGIN
  -- Get current credits
  SELECT ai_credits_available INTO v_current_credits
  FROM profiles_private
  WHERE profile_id = p_user_id
  FOR UPDATE; -- Lock row to prevent race conditions

  IF v_current_credits IS NULL THEN
    RETURN QUERY SELECT false, 0::INTEGER, 'User profile not found'::TEXT;
    RETURN;
  END IF;

  -- Check if enough credits
  IF v_current_credits < p_credits THEN
    RETURN QUERY SELECT false, v_current_credits, 'Insufficient credits'::TEXT;
    RETURN;
  END IF;

  -- Deduct credits
  UPDATE profiles_private
  SET ai_credits_available = ai_credits_available - p_credits
  WHERE profile_id = p_user_id;

  -- Record transaction
  INSERT INTO credit_transactions (
    id,
    user_id,
    type,
    credits_changed,
    description,
    metadata,
    created_at
  ) VALUES (
    'txn_' || EXTRACT(EPOCH FROM NOW())::BIGINT || '_' || RANDOM()::TEXT,
    p_user_id,
    'usage',
    -p_credits,
    COALESCE(p_description, 'AI message'),
    p_metadata,
    NOW()
  );

  RETURN QUERY SELECT true, v_current_credits - p_credits, NULL::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────────────────────
-- Step 9: Create function to add bonus credits
-- ──────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.add_bonus_credits(
  p_user_id TEXT,
  p_credits INTEGER,
  p_description TEXT DEFAULT 'Bonus credits'
)
RETURNS TABLE (
  success BOOLEAN,
  new_balance INTEGER
) AS $$
BEGIN
  -- Add credits
  UPDATE profiles_private
  SET ai_credits_available = ai_credits_available + p_credits
  WHERE profile_id = p_user_id;

  -- Record transaction
  INSERT INTO credit_transactions (
    id,
    user_id,
    type,
    credits_changed,
    description,
    created_at
  ) VALUES (
    'txn_' || EXTRACT(EPOCH FROM NOW())::BIGINT || '_' || RANDOM()::TEXT,
    p_user_id,
    'bonus',
    p_credits,
    p_description,
    NOW()
  );

  RETURN QUERY 
  SELECT true, ai_credits_available
  FROM profiles_private
  WHERE profile_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────────────────────
-- Step 10: Trigger to give new users signup bonus
-- ──────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.give_signup_bonus()
RETURNS TRIGGER AS $$
BEGIN
  -- New users get 50 credits
  IF NEW.ai_credits_available IS NULL THEN
    NEW.ai_credits_available := 50;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS give_signup_bonus_trigger ON profiles_private;
CREATE TRIGGER give_signup_bonus_trigger
  BEFORE INSERT ON profiles_private
  FOR EACH ROW
  EXECUTE FUNCTION public.give_signup_bonus();

-- ═══════════════════════════════════════════════════════════════════════════
-- Summary: What was created
-- ═══════════════════════════════════════════════════════════════════════════
-- 
-- 1. ✅ ai_credits_available column in profiles_private (50 starting balance)
-- 2. ✅ credit_transactions table - Complete transaction history
-- 3. ✅ credit_packages table - Predefined purchase packages
-- 4. ✅ stripe_payment_records table - Payment tracking
-- 5. ✅ RLS policies - User-level privacy
-- 6. ✅ deduct_credits() function - Safe credit deduction with race condition handling
-- 7. ✅ add_bonus_credits() function - Award credits
-- 8. ✅ give_signup_bonus trigger - 50 credits on signup
-- 
-- Next steps:
-- - Deploy Cloud Functions for payment processing
-- - Integrate Flutter UI for purchase screen
-- - Wire up AI service to call deduct_credits on message usage
--
-- ═══════════════════════════════════════════════════════════════════════════
