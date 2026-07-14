-- Fix bookings table RLS to allow INSERT

-- First, check current policies
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
WHERE tablename = 'bookings';

-- Drop existing policies if needed (uncomment if you want fresh start)
-- DROP POLICY IF EXISTS "Users can insert their own bookings" ON bookings;
-- DROP POLICY IF EXISTS "Users can view their own bookings" ON bookings;
-- DROP POLICY IF EXISTS "Users can update their own bookings" ON bookings;

-- CREATE INSERT POLICY: Allow users to create bookings as customer OR provider
CREATE POLICY "Users can insert bookings"
ON bookings
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = profile_customer_id  -- User booking as customer
    OR auth.uid() = profile_provider_id -- Provider accepting request
);

-- CREATE SELECT POLICY: Allow users to view bookings they're involved in
CREATE POLICY "Users can view their bookings"
ON bookings
FOR SELECT
TO authenticated
USING (
    auth.uid() = profile_customer_id 
    OR auth.uid() = profile_provider_id
);

-- CREATE UPDATE POLICY: Allow users to update bookings they're involved in
CREATE POLICY "Users can update their bookings"
ON bookings
FOR UPDATE
TO authenticated
USING (
    auth.uid() = profile_customer_id 
    OR auth.uid() = profile_provider_id
)
WITH CHECK (
    auth.uid() = profile_customer_id 
    OR auth.uid() = profile_provider_id
);

-- Verify policies were created
SELECT 
    policyname,
    cmd,
    CASE 
        WHEN cmd = 'INSERT' THEN '✅ Can create bookings'
        WHEN cmd = 'SELECT' THEN '✅ Can read bookings'
        WHEN cmd = 'UPDATE' THEN '✅ Can update bookings'
        ELSE cmd
    END as description
FROM pg_policies 
WHERE tablename = 'bookings'
ORDER BY cmd;
