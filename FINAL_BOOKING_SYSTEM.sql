-- ============================================================================
-- FINAL BOOKING SYSTEM - Simple, Safe, Scalable
-- ============================================================================
-- This is the ONLY booking system you need to launch
-- No overthinking. No complexity. Just what works.
-- ============================================================================

-- ============================================================================
-- PART 1: USER TIER SYSTEM (Trust & Monetization)
-- ============================================================================

-- Add user tier to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS user_tier TEXT DEFAULT 'basic'
CHECK (user_tier IN ('basic', 'verified', 'expert'));

-- Create index for tier-based queries
CREATE INDEX IF NOT EXISTS idx_profiles_user_tier ON public.profiles(user_tier);

-- ============================================================================
-- PART 2: BOOKING MODE (Full vs Shared)
-- ============================================================================

-- Add booking mode to posts table
ALTER TABLE public.posts 
ADD COLUMN IF NOT EXISTS booking_mode TEXT DEFAULT 'shared'
CHECK (booking_mode IN ('full', 'shared'));

-- Add minimum customer tier requirement to posts
ALTER TABLE public.posts 
ADD COLUMN IF NOT EXISTS min_customer_tier TEXT DEFAULT 'basic'
CHECK (min_customer_tier IN ('basic', 'verified', 'expert'));

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_posts_booking_mode ON public.posts(booking_mode);
CREATE INDEX IF NOT EXISTS idx_posts_min_tier ON public.posts(min_customer_tier);

-- ============================================================================
-- PART 3: PROVIDER TIER RESTRICTIONS (Prevent Marketplace Blocking)
-- ============================================================================

-- Function to validate provider can set tier requirement
CREATE OR REPLACE FUNCTION validate_min_customer_tier()
RETURNS TRIGGER AS $$
DECLARE
  provider_tier TEXT;
BEGIN
  -- Get provider's tier
  SELECT user_tier INTO provider_tier
  FROM profiles
  WHERE id = NEW.user_id;
  
  -- Apply restrictions based on provider tier
  IF provider_tier = 'basic' AND NEW.min_customer_tier != 'basic' THEN
    RAISE EXCEPTION 'Basic providers can only accept basic customers. Upgrade to verified/expert to restrict.';
  END IF;
  
  IF provider_tier = 'verified' AND NEW.min_customer_tier = 'expert' THEN
    RAISE EXCEPTION 'Verified providers can only require basic or verified customers. Upgrade to expert to require expert customers.';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to posts table
DROP TRIGGER IF EXISTS check_min_customer_tier ON public.posts;
CREATE TRIGGER check_min_customer_tier
  BEFORE INSERT OR UPDATE ON public.posts
  FOR EACH ROW
  EXECUTE FUNCTION validate_min_customer_tier();

-- ============================================================================
-- PART 4: BOOKING VALIDATION (Check Customer Tier)
-- ============================================================================

-- Function to validate customer can book
CREATE OR REPLACE FUNCTION validate_customer_booking()
RETURNS TRIGGER AS $$
DECLARE
  customer_tier TEXT;
  required_tier TEXT;
  post_mode TEXT;
  existing_bookings INTEGER;
BEGIN
  -- Get customer tier
  SELECT user_tier INTO customer_tier
  FROM profiles
  WHERE id = NEW.user_id;
  
  -- Get post requirements
  SELECT min_customer_tier, booking_mode INTO required_tier, post_mode
  FROM posts
  WHERE id = NEW.post_id;
  
  -- Check tier requirement
  IF required_tier = 'verified' AND customer_tier = 'basic' THEN
    RAISE EXCEPTION 'This service requires verified customers. Please upgrade your account.';
  END IF;
  
  IF required_tier = 'expert' AND customer_tier IN ('basic', 'verified') THEN
    RAISE EXCEPTION 'This service requires expert customers. Please upgrade your account.';
  END IF;
  
  -- Check if post is full mode and already has a booking
  IF post_mode = 'full' THEN
    SELECT COUNT(*) INTO existing_bookings
    FROM bookings
    WHERE post_id = NEW.post_id
      AND status NOT IN ('cancelled', 'rejected', 'refunded');
    
    IF existing_bookings > 0 THEN
      RAISE EXCEPTION 'This vehicle is booked for full charter. Not available for additional bookings.';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to bookings table
DROP TRIGGER IF EXISTS check_customer_booking ON public.bookings;
CREATE TRIGGER check_customer_booking
  BEFORE INSERT ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION validate_customer_booking();

-- ============================================================================
-- PART 5: PRICING COLUMNS (Simple)
-- ============================================================================

-- Add full vehicle price to posts
ALTER TABLE public.posts 
ADD COLUMN IF NOT EXISTS full_vehicle_price NUMERIC DEFAULT NULL;

-- Auto-calculate full vehicle price (15% discount)
UPDATE public.posts
SET full_vehicle_price = ROUND(price * capacity * 0.85, 2)
WHERE full_vehicle_price IS NULL 
  AND price IS NOT NULL 
  AND capacity IS NOT NULL
  AND capacity > 0;

-- ============================================================================
-- PART 6: CURRENCY (Simple)
-- ============================================================================

-- Add currency to vehicles table
ALTER TABLE public.vehicles 
ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'INR'
CHECK (currency IN ('INR', 'USD', 'EUR', 'GBP', 'AED', 'SGD', 'MYR', 'THB', 'IDR', 'PHP'));

-- ============================================================================
-- PART 7: HELPER VIEWS
-- ============================================================================

-- View for available posts with tier info
CREATE OR REPLACE VIEW posts_available AS
SELECT 
  p.*,
  v.currency,
  prof.user_tier as provider_tier,
  prof.display_name as provider_name,
  CASE 
    WHEN p.booking_mode = 'full' THEN p.full_vehicle_price
    ELSE p.price
  END as display_price,
  CASE 
    WHEN p.booking_mode = 'full' THEN 'Full Vehicle'
    ELSE 'Per Seat'
  END as price_type
FROM posts p
JOIN vehicles v ON p.vehicle_id = v.id
JOIN profiles prof ON p.user_id = prof.id
WHERE p.is_available = true;

-- ============================================================================
-- PART 8: VERIFICATION QUERIES
-- ============================================================================

-- Check profiles table
SELECT 
  column_name, 
  data_type, 
  column_default
FROM information_schema.columns 
WHERE table_name = 'profiles' 
  AND column_name = 'user_tier';

-- Check posts table
SELECT 
  column_name, 
  data_type, 
  column_default
FROM information_schema.columns 
WHERE table_name = 'posts' 
  AND column_name IN ('booking_mode', 'min_customer_tier', 'full_vehicle_price');

-- Check vehicles table
SELECT 
  column_name, 
  data_type, 
  column_default
FROM information_schema.columns 
WHERE table_name = 'vehicles' 
  AND column_name = 'currency';

-- ============================================================================
-- PART 9: EXAMPLE DATA
-- ============================================================================

-- Example: Basic provider creates shared ride (default)
/*
INSERT INTO posts (user_id, vehicle_id, price, capacity, booking_mode, min_customer_tier)
VALUES ('basic_provider_id', 'vehicle_id', 100, 40, 'shared', 'basic');
-- ✅ Works - basic provider can only accept basic customers
*/

-- Example: Verified provider restricts to verified customers
/*
INSERT INTO posts (user_id, vehicle_id, price, capacity, booking_mode, min_customer_tier)
VALUES ('verified_provider_id', 'vehicle_id', 150, 40, 'shared', 'verified');
-- ✅ Works - verified provider can require verified customers
*/

-- Example: Expert provider offers full vehicle charter
/*
INSERT INTO posts (user_id, vehicle_id, price, capacity, booking_mode, min_customer_tier, full_vehicle_price)
VALUES ('expert_provider_id', 'vehicle_id', 200, 40, 'full', 'expert', 6800);
-- ✅ Works - expert provider can require expert customers and offer full charter
*/

-- Example: Basic provider tries to restrict (FAILS)
/*
INSERT INTO posts (user_id, vehicle_id, price, capacity, booking_mode, min_customer_tier)
VALUES ('basic_provider_id', 'vehicle_id', 100, 40, 'shared', 'verified');
-- ❌ FAILS - "Basic providers can only accept basic customers. Upgrade to verified/expert to restrict."
*/

-- ============================================================================
-- PART 10: TIER UPGRADE PATH (Monetization)
-- ============================================================================

-- Update user tier (manual approval or payment gateway)
/*
UPDATE profiles 
SET user_tier = 'verified',
    updated_at = NOW()
WHERE id = 'user_id';
*/

-- ============================================================================
-- SUMMARY
-- ============================================================================
/*
✅ WHAT YOU GET:

1. BOOKING MODES:
   - 'shared' → Multiple customers (default)
   - 'full' → One customer takes all

2. USER TIERS:
   - 'basic' → Free, everyone starts here
   - 'verified' → Paid upgrade, more trust
   - 'expert' → Premium, highest trust

3. PROVIDER RESTRICTIONS:
   - basic → can ONLY accept basic
   - verified → can accept basic or verified
   - expert → can accept all

4. AUTOMATIC PROTECTION:
   - Prevents marketplace blocking
   - Forces upgrades naturally
   - Creates revenue path

5. SIMPLE PRICING:
   - price → per seat
   - full_vehicle_price → full charter
   - currency → from vehicle

🚀 READY TO LAUNCH
*/
