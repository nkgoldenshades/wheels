-- Fix permission issues and add missing columns

-- 1. Add missing columns to vehicles table
ALTER TABLE public.vehicles 
ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS is_user_vehicle BOOLEAN DEFAULT false;

-- 2. Fix users table RLS policies - allow authenticated users to insert
DROP POLICY IF EXISTS "users_insert_self" ON public.users;
CREATE POLICY "users_insert_self" ON public.users
  FOR INSERT 
  TO authenticated
  WITH CHECK (true);

-- Also allow anon users to insert (for guest mode)
CREATE POLICY "users_insert_anon" ON public.users
  FOR INSERT 
  TO anon
  WITH CHECK (true);

-- 3. Fix users update policy
DROP POLICY IF EXISTS "users_update_self" ON public.users;
CREATE POLICY "users_update_self" ON public.users
  FOR UPDATE 
  TO authenticated
  USING ((auth.uid())::text = id)
  WITH CHECK ((auth.uid())::text = id);

-- 4. Make sure vehicles policies work for authenticated users
DROP POLICY IF EXISTS "vehicles_insert_self" ON public.vehicles;
CREATE POLICY "vehicles_insert_self" ON public.vehicles
  FOR INSERT 
  TO authenticated
  WITH CHECK ((auth.uid())::text = user_id);

-- Also allow anon to insert vehicles (for guest mode)
CREATE POLICY "vehicles_insert_anon" ON public.vehicles
  FOR INSERT 
  TO anon
  WITH CHECK (true);

-- 5. Fix slots policies
DROP POLICY IF EXISTS "slots_insert_self" ON public.slots;
CREATE POLICY "slots_insert_self" ON public.slots
  FOR INSERT 
  TO authenticated
  WITH CHECK ((auth.uid())::text = user_id);

CREATE POLICY "slots_insert_anon" ON public.slots
  FOR INSERT 
  TO anon
  WITH CHECK (true);

-- 6. Fix bookings policies
DROP POLICY IF EXISTS "bookings_insert_self" ON public.bookings;
CREATE POLICY "bookings_insert_self" ON public.bookings
  FOR INSERT 
  TO authenticated
  WITH CHECK ((auth.uid())::text = user_id);

CREATE POLICY "bookings_insert_anon" ON public.bookings
  FOR INSERT 
  TO anon
  WITH CHECK (true);

COMMENT ON MIGRATION IS 'Fix RLS permissions and add missing vehicle columns';
