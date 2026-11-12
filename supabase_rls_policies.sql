-- ============================================
-- SUPABASE RLS POLICIES FOR BOOKINGS TABLE
-- ============================================
-- Run this in Supabase SQL Editor

-- First, enable RLS on bookings table (if not already enabled)
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Allow users to insert their bookings" ON bookings;
DROP POLICY IF EXISTS "Allow users to view their bookings" ON bookings;
DROP POLICY IF EXISTS "Allow users to update their bookings" ON bookings;

-- ============================================
-- INSERT POLICY
-- ============================================
-- Allow users to create bookings where they are the customer
CREATE POLICY "Allow users to insert their bookings" 
ON bookings 
FOR INSERT 
WITH CHECK (
  auth.uid() = profile_customer_id 
  AND profile_customer_id IS NOT NULL
);

-- ============================================
-- SELECT POLICY
-- ============================================
-- Allow users to view bookings where they are either customer OR provider
CREATE POLICY "Allow users to view their bookings" 
ON bookings 
FOR SELECT 
USING (
  auth.uid() = profile_customer_id 
  OR auth.uid() = profile_provider_id
);

-- ============================================
-- UPDATE POLICY
-- ============================================
-- Allow customers to update their own bookings (e.g., cancel)
-- Allow providers to update bookings for their posts (e.g., accept/reject)
CREATE POLICY "Allow users to update their bookings" 
ON bookings 
FOR UPDATE 
USING (
  auth.uid() = profile_customer_id 
  OR auth.uid() = profile_provider_id
)
WITH CHECK (
  auth.uid() = profile_customer_id 
  OR auth.uid() = profile_provider_id
);

-- ============================================
-- DELETE POLICY (Optional - usually bookings shouldn't be deleted)
-- ============================================
-- Uncomment if you want to allow deletion
-- CREATE POLICY "Allow users to delete their bookings" 
-- ON bookings 
-- FOR DELETE 
-- USING (
--   auth.uid() = profile_customer_id
-- );

-- ============================================
-- VERIFY POLICIES
-- ============================================
-- Run this to see all policies on bookings table:
-- SELECT * FROM pg_policies WHERE tablename = 'bookings';
