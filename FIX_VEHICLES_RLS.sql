-- ============================================
-- FIX: Vehicles RLS Policies
-- ============================================
-- Note: vehicles table uses is_online, NOT is_active

-- Enable RLS
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;

-- Allow everyone to view all vehicles (needed for public feed)
CREATE POLICY "public_read_vehicles" 
ON vehicles 
FOR SELECT 
USING (true);

-- Allow users to insert their own vehicles
CREATE POLICY "users_insert_own_vehicles" 
ON vehicles 
FOR INSERT 
WITH CHECK (auth.uid() = profile_id);

-- Allow users to update their own vehicles
CREATE POLICY "users_update_own_vehicles" 
ON vehicles 
FOR UPDATE 
USING (auth.uid() = profile_id)
WITH CHECK (auth.uid() = profile_id);

-- Allow users to delete their own vehicles
CREATE POLICY "users_delete_own_vehicles" 
ON vehicles 
FOR DELETE 
USING (auth.uid() = profile_id);

-- Verify policies
SELECT 
  policyname,
  cmd,
  CASE 
    WHEN qual = 'true' THEN 'Allow all'
    ELSE qual
  END as condition
FROM pg_policies 
WHERE tablename = 'vehicles';
