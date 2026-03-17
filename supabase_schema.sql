-- QuickOHunt Database Schema for Supabase
-- This schema integrates with Firebase Auth (Firebase UID as TEXT primary key)

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- USERS TABLE
-- =====================================================
-- Stores user profile information
-- Uses Firebase UID as primary key (TEXT type)
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY, -- Firebase UID
  email TEXT UNIQUE NOT NULL,
  profile_name TEXT NOT NULL,
  phone TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- =====================================================
-- VEHICLES TABLE
-- =====================================================
-- Stores vehicle information for both providers and users
CREATE TABLE IF NOT EXISTS vehicles (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL, -- Denormalized for performance
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  year INTEGER,
  capabilities TEXT[] NOT NULL, -- Array of service types: passenger, parcel, lease, working
  profile_image TEXT,
  gallery_images TEXT[] DEFAULT '{}',
  video_url TEXT,
  gps_mode TEXT DEFAULT 'deviceLive', -- deviceLive, externalLink, manual
  gps_external_link TEXT,
  manual_lat DOUBLE PRECISION,
  manual_lng DOUBLE PRECISION,
  last_known_lat DOUBLE PRECISION,
  last_known_lng DOUBLE PRECISION,
  average_rating DOUBLE PRECISION DEFAULT 0.0,
  total_ratings INTEGER DEFAULT 0,
  total_bookings INTEGER DEFAULT 0,
  active_posts_count INTEGER DEFAULT 0,
  is_online BOOLEAN DEFAULT true,
  is_user_vehicle BOOLEAN DEFAULT false, -- true for "My Posts" vehicles, false for provider vehicles
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_vehicles_user_id ON vehicles(user_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_is_online ON vehicles(is_online);
CREATE INDEX IF NOT EXISTS idx_vehicles_is_user_vehicle ON vehicles(is_user_vehicle);

-- =====================================================
-- SLOTS TABLE
-- =====================================================
-- Stores service posts/slots
CREATE TABLE IF NOT EXISTS slots (
  id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  service_type TEXT NOT NULL, -- passenger, parcel, lease, working
  slot_type TEXT NOT NULL, -- fromTo, fromRange, toRange, baseRadius
  from_location TEXT,
  to_location TEXT,
  base_location TEXT,
  radius DOUBLE PRECISION,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  price DOUBLE PRECISION NOT NULL,
  capacity INTEGER NOT NULL,
  notes TEXT,
  images TEXT[] DEFAULT '{}',
  pickup_option TEXT, -- customerPickup, providerPickup, both
  with_operator BOOLEAN,
  lease_duration_days INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_slots_vehicle_id ON slots(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_slots_service_type ON slots(service_type);
CREATE INDEX IF NOT EXISTS idx_slots_start_time ON slots(start_time);
CREATE INDEX IF NOT EXISTS idx_slots_created_at ON slots(created_at DESC);

-- =====================================================
-- BOOKINGS TABLE
-- =====================================================
-- Stores booking requests and confirmations
CREATE TABLE IF NOT EXISTS bookings (
  id TEXT PRIMARY KEY,
  slot_id TEXT NOT NULL REFERENCES slots(id) ON DELETE CASCADE,
  customer_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider_name TEXT NOT NULL,
  provider_phone TEXT NOT NULL,
  user_name TEXT NOT NULL,
  user_phone TEXT NOT NULL,
  user_email TEXT,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, accepted, completed, rejected
  seats_booked INTEGER DEFAULT 1,
  otp TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_bookings_slot_id ON bookings(slot_id);
CREATE INDEX IF NOT EXISTS idx_bookings_customer_id ON bookings(customer_id);
CREATE INDEX IF NOT EXISTS idx_bookings_provider_id ON bookings(provider_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);

-- =====================================================
-- REVIEWS TABLE
-- =====================================================
-- Stores reviews for vehicles and bookings
CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id TEXT REFERENCES vehicles(id) ON DELETE CASCADE,
  booking_id TEXT REFERENCES bookings(id) ON DELETE CASCADE,
  reviewer_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  review_type TEXT NOT NULL, -- vehicle, booking
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_reviews_vehicle_id ON reviews(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_reviews_booking_id ON reviews(booking_id);
CREATE INDEX IF NOT EXISTS idx_reviews_reviewer_id ON reviews(reviewer_id);

-- =====================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users can view all profiles" ON users FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid()::TEXT = id);
CREATE POLICY "Users can insert own profile" ON users FOR INSERT WITH CHECK (auth.uid()::TEXT = id);

-- Vehicles policies
CREATE POLICY "Anyone can view online vehicles" ON vehicles FOR SELECT USING (is_online = true);
CREATE POLICY "Users can view own vehicles" ON vehicles FOR SELECT USING (auth.uid()::TEXT = user_id);
CREATE POLICY "Users can insert own vehicles" ON vehicles FOR INSERT WITH CHECK (auth.uid()::TEXT = user_id);
CREATE POLICY "Users can update own vehicles" ON vehicles FOR UPDATE USING (auth.uid()::TEXT = user_id);
CREATE POLICY "Users can delete own vehicles" ON vehicles FOR DELETE USING (auth.uid()::TEXT = user_id);

-- Slots policies
CREATE POLICY "Anyone can view slots for online vehicles" ON slots FOR SELECT USING (
  EXISTS (SELECT 1 FROM vehicles WHERE vehicles.id = slots.vehicle_id AND vehicles.is_online = true)
);
CREATE POLICY "Vehicle owners can insert slots" ON slots FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM vehicles WHERE vehicles.id = vehicle_id AND vehicles.user_id = auth.uid()::TEXT)
);
CREATE POLICY "Vehicle owners can update own slots" ON slots FOR UPDATE USING (
  EXISTS (SELECT 1 FROM vehicles WHERE vehicles.id = vehicle_id AND vehicles.user_id = auth.uid()::TEXT)
);
CREATE POLICY "Vehicle owners can delete own slots" ON slots FOR DELETE USING (
  EXISTS (SELECT 1 FROM vehicles WHERE vehicles.id = vehicle_id AND vehicles.user_id = auth.uid()::TEXT)
);

-- Bookings policies
CREATE POLICY "Users can view own bookings as customer" ON bookings FOR SELECT USING (auth.uid()::TEXT = customer_id);
CREATE POLICY "Users can view own bookings as provider" ON bookings FOR SELECT USING (auth.uid()::TEXT = provider_id);
CREATE POLICY "Users can create bookings" ON bookings FOR INSERT WITH CHECK (auth.uid()::TEXT = customer_id);
CREATE POLICY "Providers can update bookings" ON bookings FOR UPDATE USING (auth.uid()::TEXT = provider_id);

-- Reviews policies
CREATE POLICY "Anyone can view reviews" ON reviews FOR SELECT USING (true);
CREATE POLICY "Users can create reviews" ON reviews FOR INSERT WITH CHECK (auth.uid()::TEXT = reviewer_id);
CREATE POLICY "Users can update own reviews" ON reviews FOR UPDATE USING (auth.uid()::TEXT = reviewer_id);
CREATE POLICY "Users can delete own reviews" ON reviews FOR DELETE USING (auth.uid()::TEXT = reviewer_id);

-- =====================================================
-- FUNCTIONS AND TRIGGERS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vehicles_updated_at BEFORE UPDATE ON vehicles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_slots_updated_at BEFORE UPDATE ON slots
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bookings_updated_at BEFORE UPDATE ON bookings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to update vehicle statistics when reviews are added
CREATE OR REPLACE FUNCTION update_vehicle_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE vehicles
  SET 
    average_rating = (
      SELECT AVG(rating)::DOUBLE PRECISION 
      FROM reviews 
      WHERE vehicle_id = NEW.vehicle_id AND review_type = 'vehicle'
    ),
    total_ratings = (
      SELECT COUNT(*)::INTEGER 
      FROM reviews 
      WHERE vehicle_id = NEW.vehicle_id AND review_type = 'vehicle'
    )
  WHERE id = NEW.vehicle_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update vehicle rating on review insert
CREATE TRIGGER update_vehicle_rating_on_review AFTER INSERT ON reviews
  FOR EACH ROW 
  WHEN (NEW.vehicle_id IS NOT NULL AND NEW.review_type = 'vehicle')
  EXECUTE FUNCTION update_vehicle_rating();

-- =====================================================
-- SAMPLE DATA (Optional - for testing)
-- =====================================================
-- Uncomment to insert sample data

-- INSERT INTO users (id, email, profile_name, phone) VALUES
-- ('test_user_1', 'user1@example.com', 'John Doe', '+91 98765 43210'),
-- ('test_user_2', 'user2@example.com', 'Jane Smith', '+91 98765 43211');
