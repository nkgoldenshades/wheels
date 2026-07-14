-- Drop the old INSERT policy
DROP POLICY IF EXISTS "bookings_insert" ON bookings;

-- Create new INSERT policy that allows BOTH:
-- 1. Customers booking provider posts (profile_customer_id = current user)
-- 2. Providers accepting customer requests (profile_provider_id = current user)
CREATE POLICY "bookings_insert"
ON bookings
FOR INSERT
TO authenticated, anon
WITH CHECK (
    (auth.jwt() ->> 'sub') = profile_customer_id 
    OR (auth.jwt() ->> 'sub') = profile_provider_id
);

-- Verify the policy
SELECT 
    policyname,
    cmd,
    with_check
FROM pg_policies 
WHERE tablename = 'bookings' AND cmd = 'INSERT';
