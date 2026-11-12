-- ============================================
-- QUICKOHUNT PRODUCTION SCHEMA
-- For Fresh Supabase Project
-- Firebase UID = TEXT
-- ============================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ================= USERS =================

CREATE TABLE users (
  id TEXT PRIMARY KEY,  -- Firebase UID
  phone TEXT,
  name TEXT NOT NULL,
  email TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ================= VEHICLES =================

CREATE TABLE vehicles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  year INTEGER,
  capabilities TEXT[] NOT NULL,
  photos TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ================= SLOTS =================

CREATE TABLE slots (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  slot_type TEXT CHECK (slot_type IN ('from_to', 'base_radius')),
  from_location TEXT,
  to_location TEXT,
  base_location TEXT,
  radius NUMERIC,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  capacity INTEGER NOT NULL,
  price NUMERIC NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ================= EVENTS =================

CREATE TABLE events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  event_type TEXT NOT NULL,
  location TEXT NOT NULL,
  radius_km NUMERIC NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  description TEXT NOT NULL,
  price NUMERIC,
  images TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ================= BOOKINGS =================

CREATE TABLE bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  slot_id UUID REFERENCES slots(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider_name TEXT NOT NULL,
  provider_phone TEXT NOT NULL,
  provider_email TEXT,
  provider_avatar TEXT,
  user_name TEXT NOT NULL,
  user_age INTEGER NOT NULL,
  user_gender TEXT CHECK (user_gender IN ('any', 'male', 'female')),
  user_phone TEXT,
  user_email TEXT,
  seat_key TEXT,
  price NUMERIC NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (
    status IN ('pending','confirmed','rejected','completed','cancelled')
  ),
  otp TEXT,
  otp_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ================= PAYMENTS =================

CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (
    status IN ('pending','held','released','refunded','failed')
  ),
  razorpay_payment_id TEXT,
  razorpay_order_id TEXT,
  razorpay_signature TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  released_at TIMESTAMPTZ,
  refunded_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ================= USER POSTS =================

CREATE TABLE user_posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  service_type TEXT NOT NULL,
  slot_type TEXT CHECK (slot_type IN ('from_to', 'base_radius')),
  from_location TEXT,
  to_location TEXT,
  base_location TEXT,
  radius NUMERIC,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  budget NUMERIC NOT NULL,
  persons INTEGER NOT NULL,
  notes TEXT,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'archived')),
  is_online BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ================= SAVED PASSENGERS =================

CREATE TABLE saved_passengers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  age INTEGER NOT NULL,
  gender TEXT CHECK (gender IN ('any', 'male', 'female')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ================= INDEXES =================

CREATE INDEX idx_vehicles_user_id ON vehicles(user_id);
CREATE INDEX idx_slots_user_id ON slots(user_id);
CREATE INDEX idx_slots_start_time ON slots(start_time);
CREATE INDEX idx_events_user_id ON events(user_id);
CREATE INDEX idx_bookings_user_id ON bookings(user_id);
CREATE INDEX idx_bookings_provider_id ON bookings(provider_id);
CREATE INDEX idx_payments_booking_id ON payments(booking_id);
CREATE INDEX idx_user_posts_user_id ON user_posts(user_id);

-- ================= ENABLE RLS =================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_passengers ENABLE ROW LEVEL SECURITY;

-- ================= RLS POLICIES =================

-- Users: Everyone can view profiles (marketplace), but only update own
CREATE POLICY "users_select_all" ON users FOR SELECT USING (true);
CREATE POLICY "users_insert_self" ON users FOR INSERT WITH CHECK (auth.uid()::text = id);
CREATE POLICY "users_update_self" ON users FOR UPDATE USING (auth.uid()::text = id);

-- Vehicles: Everyone can view (marketplace), only owner can modify
CREATE POLICY "vehicles_select_all" ON vehicles FOR SELECT USING (true);
CREATE POLICY "vehicles_insert_self" ON vehicles FOR INSERT WITH CHECK (auth.uid()::text = user_id);
CREATE POLICY "vehicles_update_self" ON vehicles FOR UPDATE USING (auth.uid()::text = user_id);
CREATE POLICY "vehicles_delete_self" ON vehicles FOR DELETE USING (auth.uid()::text = user_id);

-- Slots: Everyone can view (marketplace), only owner can modify
CREATE POLICY "slots_select_all" ON slots FOR SELECT USING (true);
CREATE POLICY "slots_insert_self" ON slots FOR INSERT WITH CHECK (auth.uid()::text = user_id);
CREATE POLICY "slots_update_self" ON slots FOR UPDATE USING (auth.uid()::text = user_id);
CREATE POLICY "slots_delete_self" ON slots FOR DELETE USING (auth.uid()::text = user_id);

-- Events: Everyone can view (marketplace), only owner can modify
CREATE POLICY "events_select_all" ON events FOR SELECT USING (true);
CREATE POLICY "events_insert_self" ON events FOR INSERT WITH CHECK (auth.uid()::text = user_id);
CREATE POLICY "events_update_self" ON events FOR UPDATE USING (auth.uid()::text = user_id);
CREATE POLICY "events_delete_self" ON events FOR DELETE USING (auth.uid()::text = user_id);

-- Bookings: Only involved parties can view, user creates, provider updates
CREATE POLICY "bookings_select_own" ON bookings FOR SELECT USING (
  auth.uid()::text = user_id OR auth.uid()::text = provider_id
);
CREATE POLICY "bookings_insert_user" ON bookings FOR INSERT WITH CHECK (auth.uid()::text = user_id);
CREATE POLICY "bookings_update_provider" ON bookings FOR UPDATE USING (auth.uid()::text = provider_id);

-- Payments: Only involved parties can view, user creates, NO UPDATE (webhook only)
CREATE POLICY "payments_select_own" ON payments FOR SELECT USING (
  auth.uid()::text = user_id OR auth.uid()::text = provider_id
);
CREATE POLICY "payments_insert_user" ON payments FOR INSERT WITH CHECK (auth.uid()::text = user_id);
-- NO UPDATE POLICY: Payments can only be updated by Edge Functions with service role key

-- User Posts: Everyone can view active posts, only owner can modify
CREATE POLICY "posts_select_active" ON user_posts FOR SELECT USING (status = 'active');
CREATE POLICY "posts_select_own" ON user_posts FOR SELECT USING (auth.uid()::text = user_id);
CREATE POLICY "posts_insert_self" ON user_posts FOR INSERT WITH CHECK (auth.uid()::text = user_id);
CREATE POLICY "posts_update_self" ON user_posts FOR UPDATE USING (auth.uid()::text = user_id);
CREATE POLICY "posts_delete_self" ON user_posts FOR DELETE USING (auth.uid()::text = user_id);

-- Saved Passengers: Only owner can access
CREATE POLICY "passengers_select_own" ON saved_passengers FOR SELECT USING (auth.uid()::text = user_id);
CREATE POLICY "passengers_insert_self" ON saved_passengers FOR INSERT WITH CHECK (auth.uid()::text = user_id);
CREATE POLICY "passengers_update_self" ON saved_passengers FOR UPDATE USING (auth.uid()::text = user_id);
CREATE POLICY "passengers_delete_self" ON saved_passengers FOR DELETE USING (auth.uid()::text = user_id);

-- ================= TRIGGERS =================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_vehicles_updated_at BEFORE UPDATE ON vehicles 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_slots_updated_at BEFORE UPDATE ON slots 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON events 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_bookings_updated_at BEFORE UPDATE ON bookings 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON payments 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_posts_updated_at BEFORE UPDATE ON user_posts 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ================= SUCCESS =================

DO $$
BEGIN
    RAISE NOTICE '✅ QuickOHunt database created successfully!';
    RAISE NOTICE '✅ 8 tables created with proper relationships';
    RAISE NOTICE '✅ All user_id columns are TEXT (Firebase UID compatible)';
    RAISE NOTICE '✅ RLS enabled with secure policies';
    RAISE NOTICE '✅ Indexes created for performance';
    RAISE NOTICE '✅ Triggers set up for auto-updating timestamps';
    RAISE NOTICE '';
    RAISE NOTICE '🔥 CRITICAL NEXT STEPS:';
    RAISE NOTICE '';
    RAISE NOTICE '1. Configure Firebase Provider in Supabase:';
    RAISE NOTICE '   → Dashboard → Authentication → Providers → Firebase';
    RAISE NOTICE '   → Enable Firebase';
    RAISE NOTICE '   → Project ID: quickohunt-app';
    RAISE NOTICE '';
    RAISE NOTICE '2. Enable Email/Password in Firebase Console:';
    RAISE NOTICE '   → console.firebase.google.com';
    RAISE NOTICE '   → Authentication → Sign-in method';
    RAISE NOTICE '   → Enable Email/Password';
    RAISE NOTICE '';
    RAISE NOTICE '3. Verify Schema:';
    RAISE NOTICE '   → Table Editor → users → Check id column type = text';
    RAISE NOTICE '';
    RAISE NOTICE '4. Test in Flutter app:';
    RAISE NOTICE '   → flutter run';
    RAISE NOTICE '   → Sign up with email/password';
    RAISE NOTICE '   → Check if user appears in users table';
END $$;
