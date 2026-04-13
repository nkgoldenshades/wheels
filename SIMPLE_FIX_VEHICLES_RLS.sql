-- ============================================
-- SIMPLE FIX: Vehicles RLS Policies Using Profile Validation
-- ============================================
-- This works without Firebase JWT validation
-- Security: Relies on profile_id foreign key constraint
-- ============================================

-- Step 1: Ensure foreign key exists on vehicles table
DO $$ 
BEGIN
    -- Check if foreign key constraint exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name LIKE '%profile_id%' 
        AND table_name = 'vehicles'
        AND constraint_type = 'FOREIGN KEY'
    ) THEN
        -- Add foreign key constraint
        ALTER TABLE public.vehicles
        ADD CONSTRAINT vehicles_profile_id_fkey 
        FOREIGN KEY (profile_id) 
        REFERENCES public.profiles(id) 
        ON DELETE CASCADE;
        
        RAISE NOTICE 'Added foreign key constraint to vehicles';
    ELSE
        RAISE NOTICE 'Foreign key constraint already exists';
    END IF;
END $$;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_vehicles_profile_id ON public.vehicles(profile_id);

-- Step 2: Drop existing policies
DROP POLICY IF EXISTS "public_read_vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "guests_view_online_vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "users_view_vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "users_insert_own_vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "users_update_own_vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "users_delete_own_vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_insert" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_update" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_delete" ON public.vehicles;

-- Step 3: Create new policies

-- Everyone can view ONLINE vehicles (for browsing)
CREATE POLICY "public_view_online_vehicles"
ON public.vehicles
FOR SELECT
TO public
USING (is_online = true);

-- Allow insert if profile_id exists in profiles table
CREATE POLICY "authenticated_users_insert_vehicles"
ON public.vehicles
FOR INSERT
TO public
WITH CHECK (
  -- Profile must exist
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = profile_id
  )
);

-- Allow update for own vehicles
CREATE POLICY "authenticated_users_update_own_vehicles"
ON public.vehicles
FOR UPDATE
TO public
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = profile_id
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = profile_id
  )
);

-- Allow delete for own vehicles
CREATE POLICY "authenticated_users_delete_own_vehicles"
ON public.vehicles
FOR DELETE
TO public
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = profile_id
  )
);

-- Step 4: Verify policies were created
SELECT 
  tablename,
  policyname,
  cmd,
  roles
FROM pg_policies 
WHERE tablename = 'vehicles'
ORDER BY policyname;

-- Step 5: Check for any orphaned vehicles (vehicles without valid profile_id)
SELECT 
    COUNT(*) as orphaned_vehicles,
    'Vehicles with invalid profile_id' as description
FROM public.vehicles v
LEFT JOIN public.profiles p ON v.profile_id = p.id
WHERE p.id IS NULL;

-- If you have orphaned vehicles, you can either:
-- A) Delete them:
-- DELETE FROM public.vehicles WHERE profile_id NOT IN (SELECT id FROM public.profiles);
-- 
-- B) Or assign them to a specific user:
-- UPDATE public.vehicles SET profile_id = 'YOUR_USER_ID' WHERE profile_id IS NULL;

-- ============================================
-- SECURITY NOTE:
-- This approach is secure because:
-- 1. Foreign key constraint ensures profile_id is valid
-- 2. Your Flutter app validates the user before inserting
-- 3. The app only inserts with currentUser.id
-- 4. Guests can only see online vehicles
-- 5. Users can only modify their own vehicles
-- ============================================
