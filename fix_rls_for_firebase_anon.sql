-- Fix RLS policies to work with Firebase JWT (role: anon)
-- Firebase users come in as 'anon' role, not 'authenticated'

-- ============================================================================
-- 1. FIX AI_CONVERSATIONS POLICIES
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own conversations" ON public.ai_conversations;
DROP POLICY IF EXISTS "Users can create conversations for own bookings" ON public.ai_conversations;
DROP POLICY IF EXISTS "Users can insert own conversations" ON public.ai_conversations;
DROP POLICY IF EXISTS "Users can update own conversations" ON public.ai_conversations;
DROP POLICY IF EXISTS "Users can delete own conversations" ON public.ai_conversations;

-- Create new policies that work with anon role
CREATE POLICY "ai_conversations_select" ON public.ai_conversations
  FOR SELECT 
  TO anon, authenticated
  USING (profile_id = auth.jwt()->>'sub');

CREATE POLICY "ai_conversations_insert" ON public.ai_conversations
  FOR INSERT 
  TO anon, authenticated
  WITH CHECK (profile_id = auth.jwt()->>'sub');

CREATE POLICY "ai_conversations_update" ON public.ai_conversations
  FOR UPDATE 
  TO anon, authenticated
  USING (profile_id = auth.jwt()->>'sub')
  WITH CHECK (profile_id = auth.jwt()->>'sub');

CREATE POLICY "ai_conversations_delete" ON public.ai_conversations
  FOR DELETE 
  TO anon, authenticated
  USING (profile_id = auth.jwt()->>'sub');

-- ============================================================================
-- 2. FIX VEHICLES POLICIES
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Users can insert own vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Users can update own vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "Users can delete own vehicles" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_select_all" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_insert_self" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_update_self" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_delete_self" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_all" ON public.vehicles;

-- Create new policies that work with anon role
CREATE POLICY "vehicles_select" ON public.vehicles
  FOR SELECT 
  TO anon, authenticated
  USING (profile_id = auth.jwt()->>'sub');

CREATE POLICY "vehicles_insert" ON public.vehicles
  FOR INSERT 
  TO anon, authenticated
  WITH CHECK (profile_id = auth.jwt()->>'sub');

CREATE POLICY "vehicles_update" ON public.vehicles
  FOR UPDATE 
  TO anon, authenticated
  USING (profile_id = auth.jwt()->>'sub')
  WITH CHECK (profile_id = auth.jwt()->>'sub');

CREATE POLICY "vehicles_delete" ON public.vehicles
  FOR DELETE 
  TO anon, authenticated
  USING (profile_id = auth.jwt()->>'sub');

-- ============================================================================
-- 3. FIX PROFILES POLICIES
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update" ON public.profiles;

-- Create new policies that work with anon role
CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT 
  TO anon, authenticated
  USING (id = auth.jwt()->>'sub');

CREATE POLICY "profiles_insert" ON public.profiles
  FOR INSERT 
  TO anon, authenticated
  WITH CHECK (id = auth.jwt()->>'sub');

CREATE POLICY "profiles_update" ON public.profiles
  FOR UPDATE 
  TO anon, authenticated
  USING (id = auth.jwt()->>'sub')
  WITH CHECK (id = auth.jwt()->>'sub');

-- ============================================================================
-- 4. VERIFY POLICIES
-- ============================================================================

-- Check current JWT claims
SELECT 
  auth.jwt() ->> 'sub' as user_id,
  auth.jwt() ->> 'role' as role,
  auth.jwt() ->> 'email' as email;

-- List all policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename IN ('ai_conversations', 'vehicles', 'profiles')
ORDER BY tablename, policyname;

-- Test insert permissions
SELECT 
  'ai_conversations' as table_name,
  has_table_privilege('anon', 'public.ai_conversations', 'INSERT') as can_insert,
  has_table_privilege('anon', 'public.ai_conversations', 'SELECT') as can_select,
  has_table_privilege('anon', 'public.ai_conversations', 'UPDATE') as can_update;

SELECT 
  'vehicles' as table_name,
  has_table_privilege('anon', 'public.vehicles', 'INSERT') as can_insert,
  has_table_privilege('anon', 'public.vehicles', 'SELECT') as can_select,
  has_table_privilege('anon', 'public.vehicles', 'UPDATE') as can_update;
