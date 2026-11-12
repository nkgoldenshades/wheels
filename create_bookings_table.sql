-- ============================================================================
-- BOOKINGS TABLE - Complete schema for ride/parcel/lease bookings
-- ============================================================================

CREATE TABLE public.bookings (
  -- Primary Key
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- ============================================================================
  -- RELATIONSHIPS
  -- ============================================================================
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  customer_id TEXT REFERENCES public.profiles(id) ON DELETE CASCADE,
  provider_id TEXT REFERENCES public.profiles(id) ON DELETE CASCADE,
  vehicle_id UUID REFERENCES public.vehicles(id),
  
  -- ============================================================================
  -- BOOKING TYPE & SERVICE
  -- ============================================================================
  service_type TEXT NOT NULL CHECK (
    service_type IN ('passenger', 'parcel', 'lease')
  ),
  
  -- For lease bookings
  lease_type TEXT CHECK (
    lease_type IN ('with_operator', 'without_operator')
  ),
  
  -- ============================================================================
  -- ROUTE & LOCATION
  -- ============================================================================
  route_type TEXT CHECK (
    route_type IN ('from_to', 'base_range')
  ),
  
  -- From → To route
  from_address TEXT,
  from_lat NUMERIC,
  from_lng NUMERIC,
  to_address TEXT,
  to_lat NUMERIC,
  to_lng NUMERIC,
  
  -- Base + Range route
  base_address TEXT,
  base_lat NUMERIC,
  base_lng NUMERIC,
  range_km NUMERIC,
  
  -- ============================================================================
  -- TIME & SCHEDULE
  -- ============================================================================
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE NOT NULL,
  
  -- Actual times (filled during trip)
  actual_start_time TIMESTAMP WITH TIME ZONE,
  actual_end_time TIMESTAMP WITH TIME ZONE,
  
  -- ============================================================================
  -- PRICING & PAYMENT
  -- ============================================================================
  base_price NUMERIC NOT NULL,
  currency_code TEXT DEFAULT 'INR',
  
  -- Additional charges
  extra_charges NUMERIC DEFAULT 0,
  extra_charges_reason TEXT,
  
  -- Discounts
  discount_amount NUMERIC DEFAULT 0,
  discount_code TEXT,
  
  -- Final amounts
  total_amount NUMERIC NOT NULL,
  platform_fee NUMERIC DEFAULT 0,
  provider_earnings NUMERIC,
  
  -- Payment status
  payment_status TEXT DEFAULT 'pending' CHECK (
    payment_status IN ('pending', 'paid', 'failed', 'refunded', 'partially_refunded')
  ),
  payment_method TEXT CHECK (
    payment_method IN ('wallet', 'razorpay', 'stripe', 'cash')
  ),
  payment_id TEXT, -- Transaction ID from payment gateway
  
  -- Refund info
  refund_amount NUMERIC DEFAULT 0,
  refund_reason TEXT,
  refunded_at TIMESTAMP WITH TIME ZONE,
  
  -- ============================================================================
  -- BOOKING STATUS
  -- ============================================================================
  status TEXT DEFAULT 'pending' CHECK (
    status IN (
      'pending',           -- Waiting for provider confirmation
      'confirmed',         -- Provider accepted
      'in_progress',       -- Trip started
      'completed',         -- Trip finished
      'cancelled',         -- Cancelled by customer/provider
      'cancelled_by_customer',
      'cancelled_by_provider',
      'no_show',          -- Customer didn't show up
      'disputed'          -- Issue raised
    )
  ),
  
  -- Cancellation info
  cancelled_by TEXT,
  cancellation_reason TEXT,
  cancelled_at TIMESTAMP WITH TIME ZONE,
  
  -- ============================================================================
  -- SLOT/SEAT SELECTION (for layout-based bookings)
  -- ============================================================================
  selected_seats JSONB, -- Array of seat IDs: ["A1", "A2"]
  seat_count INTEGER DEFAULT 1,
  
  -- ============================================================================
  -- PASSENGER/PARCEL DETAILS
  -- ============================================================================
  passenger_name TEXT,
  passenger_phone TEXT,
  passenger_count INTEGER DEFAULT 1,
  
  -- For parcel bookings
  parcel_description TEXT,
  parcel_weight NUMERIC,
  parcel_dimensions TEXT, -- "30x20x10 cm"
  
  -- ============================================================================
  -- SPECIAL REQUESTS & NOTES
  -- ============================================================================
  customer_notes TEXT,
  provider_notes TEXT,
  special_requests TEXT,
  
  -- ============================================================================
  -- TRACKING & LOCATION
  -- ============================================================================
  current_lat NUMERIC,
  current_lng NUMERIC,
  last_location_update TIMESTAMP WITH TIME ZONE,
  
  -- Trip tracking
  distance_travelled NUMERIC, -- in km
  route_polyline TEXT, -- Encoded polyline for map
  
  -- ============================================================================
  -- RATINGS & REVIEWS
  -- ============================================================================
  customer_rating INTEGER CHECK (customer_rating >= 1 AND customer_rating <= 5),
  customer_review TEXT,
  customer_reviewed_at TIMESTAMP WITH TIME ZONE,
  
  provider_rating INTEGER CHECK (provider_rating >= 1 AND provider_rating <= 5),
  provider_review TEXT,
  provider_reviewed_at TIMESTAMP WITH TIME ZONE,
  
  -- ============================================================================
  -- COMMUNICATION
  -- ============================================================================
  conversation_id TEXT, -- Link to messages/chat
  
  -- ============================================================================
  -- METADATA
  -- ============================================================================
  booking_reference TEXT UNIQUE, -- Human-readable ref like "BK-ABC123"
  
  -- Device & location where booking was created
  created_device_id TEXT,
  created_lat NUMERIC,
  created_lng NUMERIC,
  
  -- Flags
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  is_flagged BOOLEAN DEFAULT false, -- For suspicious bookings
  flag_reason TEXT,
  
  -- ============================================================================
  -- TIMESTAMPS
  -- ============================================================================
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  confirmed_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

CREATE INDEX idx_bookings_post_id ON public.bookings(post_id);
CREATE INDEX idx_bookings_customer_id ON public.bookings(customer_id);
CREATE INDEX idx_bookings_provider_id ON public.bookings(provider_id);
CREATE INDEX idx_bookings_vehicle_id ON public.bookings(vehicle_id);
CREATE INDEX idx_bookings_status ON public.bookings(status);
CREATE INDEX idx_bookings_payment_status ON public.bookings(payment_status);
CREATE INDEX idx_bookings_service_type ON public.bookings(service_type);
CREATE INDEX idx_bookings_start_time ON public.bookings(start_time);
CREATE INDEX idx_bookings_created_at ON public.bookings(created_at DESC);
CREATE INDEX idx_bookings_reference ON public.bookings(booking_reference);

-- Composite indexes for common queries
CREATE INDEX idx_bookings_customer_status ON public.bookings(customer_id, status);
CREATE INDEX idx_bookings_provider_status ON public.bookings(provider_id, status);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- Customers can view their own bookings
CREATE POLICY "bookings_select_customer" ON public.bookings
  FOR SELECT 
  TO anon, authenticated
  USING (customer_id = auth.jwt()->>'sub');

-- Providers can view bookings for their posts
CREATE POLICY "bookings_select_provider" ON public.bookings
  FOR SELECT 
  TO anon, authenticated
  USING (provider_id = auth.jwt()->>'sub');

-- Customers can create bookings
CREATE POLICY "bookings_insert" ON public.bookings
  FOR INSERT 
  TO anon, authenticated
  WITH CHECK (customer_id = auth.jwt()->>'sub');

-- Customers can update their own bookings (before confirmed)
CREATE POLICY "bookings_update_customer" ON public.bookings
  FOR UPDATE 
  TO anon, authenticated
  USING (customer_id = auth.jwt()->>'sub')
  WITH CHECK (customer_id = auth.jwt()->>'sub');

-- Providers can update bookings for their posts
CREATE POLICY "bookings_update_provider" ON public.bookings
  FOR UPDATE 
  TO anon, authenticated
  USING (provider_id = auth.jwt()->>'sub')
  WITH CHECK (provider_id = auth.jwt()->>'sub');

-- Only customers can delete their own pending bookings
CREATE POLICY "bookings_delete" ON public.bookings
  FOR DELETE 
  TO anon, authenticated
  USING (
    customer_id = auth.jwt()->>'sub' AND 
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

-- Auto-generate booking reference
CREATE OR REPLACE FUNCTION generate_booking_reference()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.booking_reference IS NULL THEN
    NEW.booking_reference := 'BK-' || UPPER(SUBSTRING(NEW.id::TEXT, 1, 8));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER bookings_generate_reference
  BEFORE INSERT ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION generate_booking_reference();

-- ============================================================================
-- VERIFY
-- ============================================================================

SELECT 
  tablename, 
  policyname, 
  roles, 
  cmd 
FROM pg_policies 
WHERE tablename = 'bookings' 
ORDER BY cmd, policyname;

-- Show table structure
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'bookings' 
ORDER BY ordinal_position;
