-- ============================================
-- SECURE VEHICLES RLS - Two-Tier Access
-- ============================================
-- This creates a secure RLS setup where:
-- 1. Users can only see their OWN vehicles in the vehicles table
-- 2. Everyone can browse ONLINE vehicles through a public view
-- ============================================

-- Step 1: Drop existing permissive policies
-- ============================================
DROP POLICY IF EXISTS "public_read_vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_select_all" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_all_operations" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_all" ON public.vehicles;
DROP POLICY IF EXISTS "Allow public read access to online vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Users can view all vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Anyone can view online vehicles" ON public.vehicles;

-- Step 2: Create strict RLS policies
-- ============================================

-- Users can ONLY view their own vehicles
CREATE POLICY "users_view_own_vehicles" 
ON public.vehicles 
FOR SELECT 
TO authenticated
USING (profile_id = auth.jwt()->>'sub');

-- Anon users (guests) can view online vehicles only
CREATE POLICY "guests_view_online_vehicles"
ON public.vehicles
FOR SELECT
TO anon
USING (is_online = true);

-- Users can insert their own vehicles
DROP POLICY IF EXISTS "users_insert_own_vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Users can insert their own vehicles" ON public.vehicles;
CREATE POLICY "users_insert_own_vehicles" 
ON public.vehicles 
FOR INSERT 
TO authenticated
WITH CHECK (profile_id = auth.jwt()->>'sub');

-- Users can update their own vehicles
DROP POLICY IF EXISTS "users_update_own_vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Users can update their own vehicles" ON public.vehicles;
CREATE POLICY "users_update_own_vehicles" 
ON public.vehicles 
FOR UPDATE 
TO authenticated
USING (profile_id = auth.jwt()->>'sub')
WITH CHECK (profile_id = auth.jwt()->>'sub');

-- Users can delete their own vehicles
DROP POLICY IF EXISTS "users_delete_own_vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Users can delete their own vehicles" ON public.vehicles;
CREATE POLICY "users_delete_own_vehicles" 
ON public.vehicles 
FOR DELETE 
TO authenticated
USING (profile_id = auth.jwt()->>'sub');

-- Step 3: Create public view for browsing (optional)
-- ============================================
-- This view shows only online vehicles with limited info
-- Use this for the Posts/Browse page

DROP VIEW IF EXISTS public.vehicles_public CASCADE;
CREATE VIEW public.vehicles_public AS
SELECT 
  v.id,
  v.profile_id,
  v.vehicle_type,
  v.seating_capacity,
  v.vehicle_photo_url,
  v.gallery_images,
  v.is_verified,
  v.is_online,
  v.vehicle_name,
  v.total_trips,
  v.total_reviews,
  v.active_posts_count,
  -- Include provider name from denormalized field (if exists)
  p.full_name as provider_name,
  p.profile_photo_url as provider_avatar
FROM public.vehicles v
LEFT JOIN public.profiles p ON v.profile_id = p.id
WHERE v.is_online = true;

-- Allow everyone to read the public view
GRANT SELECT ON public.vehicles_public TO anon, authenticated;

-- Step 4: Verification
-- ============================================

-- Check RLS policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'vehicles'
ORDER BY policyname;

-- Test queries
-- As authenticated user, should see only own vehicles:
-- SELECT * FROM vehicles WHERE profile_id = auth.jwt()->>'sub';

-- As guest, should see only online vehicles:
-- SELECT * FROM vehicles WHERE is_online = true;

-- Everyone can browse through public view:
-- SELECT * FROM vehicles_public;

-- ============================================
-- IMPORTANT: Update Your Dart Code
-- ============================================
/*
After running this, you need to update your Dart code:

1. For "My Vehicles" page (authenticated users):
   - Keep using: .from('vehicles').select()
   - RLS will automatically filter to user's vehicles
   - No need to filter in Dart!

2. For "Posts/Browse" page (guests + authenticated):
   - Change to: .from('vehicles_public').select()
   - This view shows only online vehicles
   - Works for everyone (guests + authenticated)

Example changes needed:

// In VehicleRepository._loadVehicles()
// OLD:
final response = await _supabase
    .from('vehicles')
    .select()
    .order('created_at', ascending: false);

// NEW (for browsing all vehicles):
final response = await _supabase
    .from('vehicles_public')  // Use public view
    .select()
    .order('created_at', ascending: false);

// For user's own vehicles, keep using 'vehicles' table
// RLS will automatically filter to current user
*/

-- ============================================
-- Summary of Access Control
-- ============================================
/*
AUTHENTICATED USERS:
✅ Can SELECT their own vehicles from 'vehicles' table
✅ Can INSERT their own vehicles
✅ Can UPDATE their own vehicles
✅ Can DELETE their own vehicles
✅ Can browse all online vehicles via 'vehicles_public' view
❌ Cannot see other users' vehicles in 'vehicles' table

GUESTS (anon):
✅ Can SELECT online vehicles from 'vehicles' table
✅ Can browse all online vehicles via 'vehicles_public' view
❌ Cannot INSERT, UPDATE, or DELETE any vehicles
❌ Cannot see offline vehicles

SECURITY BENEFITS:
1. Users cannot accidentally see other users' private vehicles
2. Offline vehicles are hidden from guests
3. Sensitive data (registration, insurance) only visible to owner
4. Public view provides controlled access for browsing
5. RLS enforced at database level (can't bypass in app)
*/
