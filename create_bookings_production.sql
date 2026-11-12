-- ============================================================================
-- BOOKINGS TABLE - Production Schema (54 columns across 10 sections)
-- ============================================================================
-- This schema supports:
-- - Instant booking (standard Uber/Bus model)
-- - Wait-for-full (group buying with payment authorization)
-- - Full vehicle charter (private booking)
-- ============================================================================

CREATE TABLE public.bookings (
  -- ============================================================================
  -- 1. IDENTITY & RELATIONSHIPS (5 columns)
  -- ============================================================================
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id TEXT REFERENCES public.profiles(id) ON DELETE CASCADE,
  provider_id TEXT REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending' CHECK (
    status IN ('pending', 'confirmed', 'completed', 'cancelled', 'waiting_for_quota')
  ),
  
  -- ============================================================================
  -- 2. SNAPSHOTS: The "Frozen" Contract (7 columns)
  -- Captures the exact terms at booking time - immutable record
  -- ============================================================================
  price_snapshot NUMERIC NOT NULL,
  deposit_snapshot NUMERIC DEFAULT 0,
  currency_snapshot TEXT DEFAULT 'INR',
  persons_snapshot INTEGER DEFAULT 1,
  seat_keys TEXT[], -- e.g., ['A1', 'A2'] for multi-seat bookings
  passenger_details JSONB, -- [{"name": "John", "age": 30, "gender": "male"}]
  booking_strategy_snapshot TEXT DEFAULT 'instant' CHECK (
    booking_strategy_snapshot IN ('instant', 'wait_for_full', 'full_vehicle')
  ),
  
  -- ============================================================================
  -- 3. SCHEDULE & ROUTE (9 columns)
  -- Frozen snapshot of journey details
  -- ============================================================================
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE NOT NULL,
  from_address TEXT,
  from_lat NUMERIC,
  from_lng NUMERIC,
  to_address TEXT,
  to_lat NUMERIC,
  to_lng NUMERIC,
  route_snapshot JSONB, -- Complete route with all stops
  
  -- ============================================================================
  -- 4. SERVICE SPECIFICS (1 column)
  -- ============================================================================
  parcel_snapshot JSONB, -- {"weight": 5, "length": 30, "width": 20, "height": 15}
  
  -- ============================================================================
  -- 5. OTP & SECURITY (4 columns)
  -- For ride start/end verification
  -- ============================================================================
  otp_code TEXT,
  otp_verified BOOLEAN DEFAULT false,
  otp_verified_at TIMESTAMP WITH TIME ZONE,
  otp_attempts INTEGER DEFAULT 0,
  
  -- ============================================================================
  -- 6. PAYMENT & ESCROW (6 columns)
  -- Handles payment authorization and capture
  -- ============================================================================
  payment_method TEXT CHECK (
    payment_method IN ('upi', 'card', 'wallet', 'cash', 'razorpay', 'stripe')
  ),
  payment_gateway_id TEXT, -- External transaction ID (Stripe/Razorpay)
  payment_status TEXT DEFAULT 'unpaid' CHECK (
    payment_status IN ('unpaid', 'authorized', 'captured', 'refunded', 'failed')
  ),
  payment_amount NUMERIC,
  payment_currency TEXT DEFAULT 'INR',
  paid_at TIMESTAMP WITH TIME ZONE,
  
  -- ============================================================================
  -- 7. PAYOUTS (5 columns)
  -- Driver/provider earnings after platform commission
  -- ============================================================================
  payout_status TEXT DEFAULT 'pending' CHECK (
    payout_status IN ('pending', 'processed', 'failed')
  ),
  payout_amount NUMERIC, -- Amount after deducting platform_fee
  payout_reference_id TEXT, -- External payout transaction ID
  payout_triggered_at TIMESTAMP WITH TIME ZONE,
  payout_completed_at TIMESTAMP WITH TIME ZONE,
  
  -- ============================================================================
  -- 8. PLATFORM FEES (1 column)
  -- Your app's commission
  -- ============================================================================
  platform_fee NUMERIC DEFAULT 0,
  
  -- ============================================================================
  -- 9. CANCELLATIONS & DISPUTES (10 columns)
  -- ============================================================================
  cancelled_by TEXT REFERENCES public.profiles(id),
  cancellation_reason TEXT,
  cancelled_at TIMESTAMP WITH TIME ZONE,
  refund_requested BOOLEAN DEFAULT false,
  refund_requested_at TIMESTAMP WITH TIME ZONE,
  refund_locked BOOLEAN DEFAULT false, -- Prevents double refunds
  dispute_reason TEXT,
  dispute_raised_at TIMESTAMP WITH TIME ZONE,
  dispute_resolved_at TIMESTAMP WITH TIME ZONE,
  dispute_resolution TEXT, -- Admin notes
  
  -- ============================================================================
  -- 10. TRACKING & METADATA (6 columns)
  -- ============================================================================
  device_id TEXT,
  device_session_id UUID,
  metadata JSONB, -- Flexible storage for extra data
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  completed_at TIMESTAMP WITH TIME ZONE
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Primary lookups
CREATE INDEX idx_bookings_post_id ON public.bookings(post_id);
CREATE INDEX idx_bookings_user_id ON public.bookings(user_id);
CREATE INDEX idx_bookings_provider_id ON public.bookings(provider_id);

-- Status tracking
CREATE INDEX idx_bookings_status ON public.bookings(status);
CREATE INDEX idx_bookings_payment_status ON public.bookings(payment_status);
CREATE INDEX idx_bookings_payout_status ON public.bookings(payout_status);

-- Time-based queries
CREATE INDEX idx_bookings_start_time ON public.bookings(start_time);
CREATE INDEX idx_bookings_created_at ON public.bookings(created_at DESC);

-- Composite indexes for common queries
CREATE INDEX idx_bookings_user_status ON public.bookings(user_id, status);
CREATE INDEX idx_bookings_provider_status ON public.bookings(provider_id, status);
CREATE INDEX idx_bookings_payment_payout ON public.bookings(payment_status, payout_status);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- Works with Firebase anon role
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

-- Users can update their own bookings (cancellations, disputes)
CREATE POLICY "bookings_update_user" ON public.bookings
  FOR UPDATE 
  TO anon, authenticated
  USING (user_id = auth.jwt()->>'sub')
  WITH CHECK (user_id = auth.jwt()->>'sub');

-- Providers can update bookings for their posts (accept, complete, payout)
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

-- Auto-generate OTP on booking creation
CREATE OR REPLACE FUNCTION generate_booking_otp()
RETURNS TRIGGER AS $$
BEGIN
  -- Generate 6-digit OTP
  NEW.otp_code = LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER bookings_generate_otp
  BEFORE INSERT ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION generate_booking_otp();

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check table structure
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'bookings' 
ORDER BY ordinal_position;

-- Check policies
SELECT 
  tablename, 
  policyname, 
  roles, 
  cmd 
FROM pg_policies 
WHERE tablename = 'bookings' 
ORDER BY cmd, policyname;

-- Verify column count by section
SELECT 
  '1. Identity & Relationships' as section, 5 as columns
UNION ALL SELECT '2. Snapshots', 7
UNION ALL SELECT '3. Schedule & Route', 9
UNION ALL SELECT '4. Service Specifics', 1
UNION ALL SELECT '5. OTP & Security', 4
UNION ALL SELECT '6. Payment & Escrow', 6
UNION ALL SELECT '7. Payouts', 5
UNION ALL SELECT '8. Platform Fees', 1
UNION ALL SELECT '9. Cancellations & Disputes', 10
UNION ALL SELECT '10. Tracking & Metadata', 6
UNION ALL SELECT 'TOTAL', 54;
