-- Fix RLS policies to use auth.jwt()->>'sub' instead of auth.uid()
-- auth.uid() returns UUID type which fails with Firebase string UIDs
-- auth.jwt()->>'sub' returns TEXT which works with Firebase UIDs

-- ============================================================
-- profiles_public
-- ============================================================
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles_public;
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles_public;
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles_public;
DROP POLICY IF EXISTS "profiles_delete_own" ON public.profiles_public;
DROP POLICY IF EXISTS "profiles_select_during_active_booking" ON public.profiles_public;

-- All authenticated users can read public profiles
CREATE POLICY "profiles_select_authenticated"
ON public.profiles_public FOR SELECT TO authenticated
USING (true);

-- Owner can insert their own profile
CREATE POLICY "profiles_insert_own"
ON public.profiles_public FOR INSERT TO authenticated
WITH CHECK (id = auth.jwt()->>'sub');

-- Owner can update their own profile
CREATE POLICY "profiles_update_own"
ON public.profiles_public FOR UPDATE TO authenticated
USING (id = auth.jwt()->>'sub')
WITH CHECK (id = auth.jwt()->>'sub');

-- Owner can delete their own profile
CREATE POLICY "profiles_delete_own"
ON public.profiles_public FOR DELETE TO authenticated
USING (id = auth.jwt()->>'sub');

-- ============================================================
-- profiles_contact
-- ============================================================
DROP POLICY IF EXISTS "profiles_contact_owner_read" ON public.profiles_contact;
DROP POLICY IF EXISTS "profiles_contact_active_booking_read" ON public.profiles_contact;
DROP POLICY IF EXISTS "profiles_contact_insert_own" ON public.profiles_contact;
DROP POLICY IF EXISTS "profiles_contact_update_own" ON public.profiles_contact;

-- Owner can always read their own contact info
CREATE POLICY "profiles_contact_owner_read"
ON public.profiles_contact FOR SELECT TO authenticated
USING (profile_id = auth.jwt()->>'sub');

-- Booking partners can read contact during active bookings
CREATE POLICY "profiles_contact_active_booking_read"
ON public.profiles_contact FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.bookings
    WHERE
      bookings.status IN ('pending', 'accepted', 'confirmed', 'in_progress')
      AND (
        (bookings.profile_customer_id = auth.jwt()->>'sub' AND profiles_contact.profile_id = bookings.profile_provider_id)
        OR
        (bookings.profile_provider_id = auth.jwt()->>'sub' AND profiles_contact.profile_id = bookings.profile_customer_id)
      )
  )
);

-- Owner can insert their own contact info
CREATE POLICY "profiles_contact_insert_own"
ON public.profiles_contact FOR INSERT TO authenticated
WITH CHECK (profile_id = auth.jwt()->>'sub');

-- Owner can update their own contact info
CREATE POLICY "profiles_contact_update_own"
ON public.profiles_contact FOR UPDATE TO authenticated
USING (profile_id = auth.jwt()->>'sub')
WITH CHECK (profile_id = auth.jwt()->>'sub');

-- ============================================================
-- profiles_private
-- ============================================================
DROP POLICY IF EXISTS "profiles_private_owner_read" ON public.profiles_private;
DROP POLICY IF EXISTS "profiles_private_insert_own" ON public.profiles_private;
DROP POLICY IF EXISTS "profiles_private_update_own" ON public.profiles_private;

-- Owner can only read their own private data
CREATE POLICY "profiles_private_owner_read"
ON public.profiles_private FOR SELECT TO authenticated
USING (profile_id = auth.jwt()->>'sub');

-- Owner can insert their own private data
CREATE POLICY "profiles_private_insert_own"
ON public.profiles_private FOR INSERT TO authenticated
WITH CHECK (profile_id = auth.jwt()->>'sub');

-- Owner can update their own private data
CREATE POLICY "profiles_private_update_own"
ON public.profiles_private FOR UPDATE TO authenticated
USING (profile_id = auth.jwt()->>'sub')
WITH CHECK (profile_id = auth.jwt()->>'sub');
