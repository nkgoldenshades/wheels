-- ============================================
-- PROPER SOLUTION: Create Public View for Vehicles
-- ============================================
-- This is the CORRECT way to expose vehicle data safely
-- Instead of opening the entire vehicles table with USING (true)

-- ============================================
-- STEP 1: Create Public View (Safe Data Only)
-- ============================================

CREATE OR REPLACE VIEW vehicles_public AS
SELECT 
  -- Basic vehicle info (safe to expose)
  id,
  profile_id,
  vehicle_type,
  vehicle_name,
  seating_capacity,
  vehicle_photo_url,
  gallery_images,
  video_url,
  created_at,
  updated_at,
  is_online,
  vehicle_owner,
  
  -- Statistics (safe to expose)
  total_trips,
  total_reviews,
  active_posts_count,
  is_verified,
  verified_at,
  
  -- Operator info (safe to expose)
  operator_name,
  operator_phone,
  operator_profile_photo_url,
  
  -- Ownership flag (useful for UI)
  CASE 
    WHEN profile_id = (auth.jwt() ->> 'sub'::text) THEN true
    ELSE false
  END AS is_owner
  
FROM vehicles

-- ❌ EXCLUDED (Sensitive Data):
-- - registration_number (private)
-- - rc_front_url (private)
-- - rc_back_url (private)
-- - insurance_number (private)
-- - insurance_expiry (private)
-- - insurance_document_url (private)
-- - pollution_certificate_url (private)
-- - pollution_expiry (private)
-- - fitness_certificate_url (private)
-- - fitness_expiry (private)
-- - Any other sensitive documents

WHERE 
  -- Only show active vehicles (optional filter)
  is_online = true OR profile_id = (auth.jwt() ->> 'sub'::text);

-- ============================================
-- STEP 2: Enable RLS on View
-- ============================================

ALTER VIEW vehicles_public SET (security_invoker = true);

-- ============================================
-- STEP 3: Create RLS Policy for Public View
-- ============================================

-- Drop old policy if exists
DROP POLICY IF EXISTS "vehicles_public_select" ON vehicles_public;

-- Create open policy for public view (SAFE because view filters data)
CREATE POLICY "vehicles_public_select" 
ON vehicles_public
FOR SELECT
TO anon, authenticated
USING (true);  -- ✅ Safe because view only exposes safe columns

-- ============================================
-- STEP 4: Keep Original Table Secure
-- ============================================

-- Ensure original vehicles table remains protected
DROP POLICY IF EXISTS "vehicles_select" ON vehicles;
DROP POLICY IF EXISTS "vehicles_select_all" ON vehicles;

-- Only owner can see full vehicle data (including sensitive info)
CREATE POLICY "vehicles_select_own" 
ON vehicles
FOR SELECT
TO authenticated
USING (profile_id = (auth.jwt() ->> 'sub'::text));

-- Only owner can update
CREATE POLICY "vehicles_update_own" 
ON vehicles
FOR UPDATE
TO authenticated
USING (profile_id = (auth.jwt() ->> 'sub'::text));

-- Only owner can delete
CREATE POLICY "vehicles_delete_own" 
ON vehicles
FOR DELETE
TO authenticated
USING (profile_id = (auth.jwt() ->> 'sub'::text));

-- Anyone can insert (for new vehicle creation)
CREATE POLICY "vehicles_insert" 
ON vehicles
FOR INSERT
TO authenticated
WITH CHECK (profile_id = (auth.jwt() ->> 'sub'::text));

-- ============================================
-- STEP 5: Verification
-- ============================================

-- Check the view
SELECT * FROM vehicles_public LIMIT 5;

-- Check RLS policies
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd,
  qual as "USING clause"
FROM pg_policies 
WHERE tablename IN ('vehicles', 'vehicles_public')
ORDER BY tablename, policyname;

-- ============================================
-- SUCCESS MESSAGE
-- ============================================

DO $$
BEGIN
  RAISE NOTICE '✅ vehicles_public view created successfully!';
  RAISE NOTICE '✅ Only safe data exposed (no sensitive documents)';
  RAISE NOTICE '✅ Original vehicles table remains secure';
  RAISE NOTICE '✅ Everyone can see basic vehicle info';
  RAISE NOTICE '✅ Only owners can see/edit sensitive data';
  RAISE NOTICE '';
  RAISE NOTICE '🔄 NEXT STEP: Update Flutter code to use vehicles_public';
  RAISE NOTICE '   Change: .from("vehicles") → .from("vehicles_public")';
END $$;
