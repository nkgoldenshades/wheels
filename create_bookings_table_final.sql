-- ============================================================================
-- BOOKINGS TABLE - Production-ready schema with snapshots and escrow
-- ============================================================================

CREATE TABLE public.bookings (
  -- ============================================================================
  -- 1. IDENTITY & RELATIONSHIPS (5)
  -- ============================================================================
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id TEXT REFERENCES public.profiles(id) ON DELETE CASCADE,
  provider_id TEXT REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending' CHECK (
    status IN ('pending', 'confirmed', 'completed', 'cancelled', 'waiting_for_quota')
  ),
  
  -- ============================================================================
  -- 2. SNAPSHOTS: The "Frozen" Contract (7)
  -- ============================================================================
  price_snapshot NUMERIC NOT NULL,
  deposit_snapshot NUMERIC DEFAULT 0,
  currency_snapshot TEXT DEFAULT 'INR',
  persons_snapshot INTEGER DEFAULT 1,
  seat_keys TEXT[], -- e.g., ['A1', 'A2']
  passenger_details JSONB, -- List of names, ages, genders
  booking_strategy_snapshot TEXT CHECK (
    booking_strategy_snapshot IN ('instant', 'wait_for_full', 'full_vehicle')
  ),
  
  -- ============================================================================
  -- 3. SCHEDULE & ROUTE (9)
  -- ============================================================================
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE NOT NULL,
  from_address TEXT,
  from_lat NUMERIC,
  from_lng NUMERIC,
  to_address TEXT,
  to_lat NUMERIC,
  to_lng NUMERIC,
  route_snapshot JSONB, -- The exact stops agreed upon
  
  -- ============================================================================
  -- 4. SERVICE SPECIFICS (1)
  -- ============================================================================
  parcel_snapshot JSONB, -- Dimensions/weight (if it's a delivery)
  
  -- ============================================================================
  -- 5. OTP & SECURITY (4)
  -- ============================================================================
  otp_code TEXT,
  otp_verified BOOLEAN DEFAULT false,
  otp_verified_at TIMESTAMP WITH TIME ZONE,
  otp_attempts INTEGER DEFAULT 0,
  
  -- ============================================================================
  -- 6. PAYMENT & ESCROW (6)
  -- ============================================================================
  payment_method TEXT CHECK (
    payment_method IN ('upi', 'card', 'wallet', 'cash', 'razorpay', 'stripe')
  ),
  payment_gateway_id TEXT, -- External transaction reference
  payment_status TEXT DEFAULT 'unpaid' CHECK (
    payment_status IN ('unpaid', 'authorized', 'captured', 'refunded', 'failed')
  ),
  payment_amount NUMERIC,
  payment_currency TEXT DEFAULT 'INR',
  paid_at TIMESTAMP WITH TIME ZONE,
  
  -- ============================================================================
  -- 7. PAYOUTS (Driver's Money) (5)
  -- ============================================================================
  payout_status TEXT DEFAULT 'pending' CHECK (
    payout_status IN ('pending', 'processed', 'failed')
  ),
  payout_amount NUMERIC, -- Final amount minus commission
  payout_reference_id TEXT,
  payout_triggered_at TIMESTAMP WITH TIME ZONE,
  payout_completed_at TIMESTAMP WITH TIME ZONE,
  
  -- ============================================================================
  -- 8. PLATFORM FEES (1)
  -- ============================================================================
  platform_fee NUMERIC DEFAULT 0, -- Your app's cut/commission
  
  -- ============================================================================
  -- 9. CANCELLATIONS & DISPUTES (10)
  -- ============================================================================
  cancelled_by TEXT REFERENCES public.profiles(id),
  cancellation_reason TEXT,
  cancelled_at TIMESTAMP WITH TIME ZONE,
  refund_requested BOOLEAN DEFAULT false,
  refund_requested_at TIMESTAMP WITH TIME ZONE,
  refund_locked BOOLEAN DEFAULT false, -- Safety lock to prevent double refunds
  dispute_reason TEXT,
  dispute_raised_at TIMESTAMP WITH TIME ZONE,
  dispute_resolved_at TIMESTAMP WITH TIME ZONE,
  dispute_resolution TEXT, -- Admin's final decision notes
  
  -- ============================================================================
  -- 10. TRACKING & METADATA (6)
  -- ============================================================================
  device_id TEXT,
  device_session_id UUID,
  metadata JSONB, -- Extra flexible data
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  completed_at TIMESTAMP WITH TIME ZONE
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

CREATE INDEX idx_bookings_post_id ON public.bookings(post_id);
CREATE INDEX idx_bookings_user_id ON public.bookings(user_id);
CREATE INDEX idx_bookings_provider_id ON public.bookings(provider_id);
CREATE INDEX idx_bookings_status ON public.bookings(status);
CREATE INDEX idx_bookings_payment_status ON public.bookings(payment_status);
CREATE INDEX idx_bookings_payout_status ON public.bookings(payout_status);
CREATE INDEX idx_bookings_start_time ON public.bookings(start_time);
CREATE INDEX idx_bookings_created_at ON public.bookings(created_at DESC);

-- Composite indexes for common queries
CREATE INDEX idx_bookings_user_status ON public.bookings(user_id, status);
CREATE INDEX idx_bookings_provider_status ON public.bookings(provider_id, status);
CREATE INDEX idx_bookings_payment_payout ON public.bookings(payment_status, payout_status);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- Users can view their own bookings
CREATE POLICY "bookings_select_user" ON public.bookings
  FOR SELECT 
  TO anon, authenticated
  USING (user_id = auth.jwt()->>'sub');

-- Providers can view bookings for their posts
CREATE POLICY "bookings_select_provider" ON public.bookings
  FOR SELECT 
  TO anon, authenticated
  USING (provider_id = auth.jwt()->>'sub');

-- Users can create bookings
CREATE POLICY "bookings_insert" ON public.bookings
  FOR INSERT 
  TO anon, authenticated
  WITH CHECK (user_id = auth.jwt()->>'sub');

-- Users can update their own bookings (before confirmed)
CREATE POLICY "bookings_update_user" ON public.bookings
  FOR UPDATE 
  TO anon, authenticated
  USING (user_id = auth.jwt()->>'sub')
  WITH CHECK (user_id = auth.jwt()->>'sub');

-- Providers can update bookings for their posts
CREATE POLICY "bookings_update_provider" ON public.bookings
  FOR UPDATE 
  TO anon, authenticated
  USING (provider_id = auth.jwt()->>'sub')
  WITH CHECK (provider_id = auth.jwt()->>'sub');

-- Only users can delete their own pending bookings
CREATE POLICY "bookings_delete" ON public.bookings
  FOR DELETE 
  TO anon, authenticated
  USING (
    user_id = auth.jwt()->>'sub' AND 
    status = 'pending'
  );

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_bookings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER bookings_updated_at
  BEFORE UPDATE ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION update_bookings_updated_at();

-- ============================================================================
-- VERIFY
-- ============================================================================

-- Check policies
SELECT 
  tablename, 
  policyname, 
  roles, 
  cmd 
FROM pg_policies 
WHERE tablename = 'bookings' 
ORDER BY cmd, policyname;

-- Check table structure
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'bookings' 
ORDER BY ordinal_position;

-- Count columns by category
SELECT 
  '1. Identity & Relationships' as category, 5 as expected_columns
UNION ALL SELECT '2. Snapshots', 7
UNION ALL SELECT '3. Schedule & Route', 9
UNION ALL SELECT '4. Service Specifics', 1
UNION ALL SELECT '5. OTP & Security', 4
UNION ALL SELECT '6. Payment & Escrow', 6
UNION ALL SELECT '7. Payouts', 5
UNION ALL SELECT '8. Platform Fees', 1
UNION ALL SELECT '9. Cancellations & Disputes', 10
UNION ALL SELECT '10. Tracking & Metadata', 6;
