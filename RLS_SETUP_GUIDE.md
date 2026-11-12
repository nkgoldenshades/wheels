# Supabase RLS Setup Guide

## Problem
You're getting this error when creating a booking:
```
new row violates row-level security policy for table "bookings"
code: 42501
```

This means Supabase's Row Level Security (RLS) is blocking the INSERT operation.

## Solution

### Quick Fix (Bookings Only)
If you only need to fix the bookings table:

1. Go to **Supabase Dashboard** → **SQL Editor**
2. Run the SQL from `supabase_rls_policies.sql`
3. Test your booking creation again

### Complete Fix (All Tables)
For a complete setup with all tables properly secured:

1. Go to **Supabase Dashboard** → **SQL Editor**
2. Run the SQL from `supabase_rls_complete.sql`
3. This will set up RLS policies for:
   - profiles
   - vehicles
   - posts
   - bookings
   - reviews
   - ai_conversations

## What the Policies Do

### Bookings Table
- **INSERT**: Users can create bookings where they are the customer
- **SELECT**: Users can view bookings where they are customer OR provider
- **UPDATE**: Both customer and provider can update bookings

### Posts Table
- **INSERT**: Users can create their own posts
- **SELECT**: Everyone can view active posts
- **UPDATE/DELETE**: Users can only modify their own posts

### Vehicles Table
- **INSERT**: Users can add their own vehicles
- **SELECT**: Everyone can view vehicles (needed for browsing)
- **UPDATE/DELETE**: Users can only modify their own vehicles

### Profiles Table
- **INSERT**: Users can create their own profile
- **SELECT**: Everyone can view profiles (needed for bookings)
- **UPDATE**: Users can only update their own profile

## Verify Policies

After running the SQL, verify the policies are active:

```sql
SELECT schemaname, tablename, policyname, cmd 
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

## Important Notes

1. **Same User Booking**: The current policy allows a user to book their own post (customer = provider). If you want to prevent this, modify the INSERT policy:

```sql
CREATE POLICY "Users can insert their bookings" 
ON bookings 
FOR INSERT 
WITH CHECK (
  auth.uid() = profile_customer_id 
  AND profile_customer_id IS NOT NULL
  AND profile_customer_id != profile_provider_id  -- Prevent self-booking
);
```

2. **Testing**: After applying policies, test:
   - Creating a post ✅
   - Viewing posts ✅
   - Creating a booking ✅
   - Viewing bookings ✅

3. **Security**: These policies ensure:
   - Users can only create/modify their own data
   - Users can view public data (posts, vehicles, profiles)
   - Users can view bookings they're involved in

## Troubleshooting

If you still get RLS errors:

1. Check if RLS is enabled:
```sql
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public';
```

2. Check existing policies:
```sql
SELECT * FROM pg_policies WHERE tablename = 'bookings';
```

3. Temporarily disable RLS for testing (NOT for production):
```sql
ALTER TABLE bookings DISABLE ROW LEVEL SECURITY;
```

4. Re-enable after testing:
```sql
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
```
