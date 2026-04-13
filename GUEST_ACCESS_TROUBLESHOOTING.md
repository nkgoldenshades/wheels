# Guest Access Troubleshooting Guide

## Problem
Guest users (not logged in) cannot see posts/vehicles in the app.

## Root Cause
RLS (Row Level Security) policies in Supabase are blocking unauthenticated users from reading data.

## Quick Fix

### Step 1: Run SQL in Supabase
1. Go to Supabase Dashboard
2. Click "SQL Editor"
3. Copy and paste contents of `QUICK_FIX_GUEST_ACCESS.sql`
4. Click "Run"

### Step 2: Verify Policies
Check that policies were created:
```sql
SELECT tablename, policyname, cmd, roles
FROM pg_policies
WHERE tablename IN ('posts', 'vehicles', 'profiles')
AND cmd = 'SELECT';
```

You should see:
- `Allow public read access to active posts` on `posts`
- `Allow public read access to online vehicles` on `vehicles`
- `Allow public read access to profile names` on `profiles`

### Step 3: Test in App
1. Logout (or use guest mode)
2. Open app
3. Go to Posts tab
4. Should see posts now ✅

## Understanding RLS Policies

### What is RLS?
Row Level Security controls who can read/write specific rows in a table.

### Policy Roles:
- `authenticated` - Logged-in users only
- `anon` - Anonymous/guest users only
- `public` - BOTH authenticated AND anonymous users

### Our Policies:

#### Posts Table:
```sql
-- Allow ANYONE to read active posts
CREATE POLICY "Allow public read access to active posts"
ON posts FOR SELECT
TO public  -- ← This is the key!
USING (is_active = true);
```

#### Vehicles Table:
```sql
-- Allow ANYONE to read online vehicles
CREATE POLICY "Allow public read access to online vehicles"
ON vehicles FOR SELECT
TO public
USING (is_online = true);
```

#### Profiles Table:
```sql
-- Allow ANYONE to read profile names
CREATE POLICY "Allow public read access to profile names"
ON profiles FOR SELECT
TO public
USING (true);
```

## Common Issues

### Issue 1: "new row violates row-level security policy"
**Cause:** Trying to INSERT/UPDATE without proper policy  
**Fix:** Check INSERT/UPDATE policies exist for authenticated users

### Issue 2: "permission denied for table"
**Cause:** RLS is enabled but no policies exist  
**Fix:** Create SELECT policy with `TO public`

### Issue 3: Posts show for logged-in but not guests
**Cause:** Policy uses `TO authenticated` instead of `TO public`  
**Fix:** Change policy to `TO public`

### Issue 4: Empty result set for guests
**Cause:** No SELECT policy for public role  
**Fix:** Add SELECT policy with `TO public`

## Security Considerations

### What's Safe to Make Public?
✅ **Posts** - Active posts (is_active = true)  
✅ **Vehicles** - Online vehicles (is_online = true)  
✅ **Profile Names** - Provider names for display  

### What Should Stay Private?
❌ **Bookings** - Only customer and provider  
❌ **AI Conversations** - Only owner  
❌ **Sensitive Profile Data** - Phone, documents, etc.  

### How We Protect Private Data:

1. **Bookings:**
```sql
USING (
  profile_customer_id = (auth.jwt() ->> 'sub')
  OR
  profile_provider_id = (auth.jwt() ->> 'sub')
)
```
Only customer or provider can see booking.

2. **AI Conversations:**
```sql
USING (profile_id = (auth.jwt() ->> 'sub'))
```
Only owner can see their conversations.

3. **Profile Updates:**
```sql
USING (id = (auth.jwt() ->> 'sub'))
WITH CHECK (id = (auth.jwt() ->> 'sub'))
```
Users can only update their own profile.

## Testing Checklist

### As Guest User:
- [ ] Can see posts in feed
- [ ] Can see vehicle details
- [ ] Can see provider names
- [ ] Cannot create posts
- [ ] Cannot create bookings
- [ ] Cannot see other users' bookings
- [ ] Cannot see other users' AI chats

### As Logged-In User:
- [ ] Can see all posts (same as guest)
- [ ] Can create posts
- [ ] Can update own posts
- [ ] Can delete own posts
- [ ] Can create bookings
- [ ] Can see own bookings
- [ ] Can see AI chat history

## Debugging Steps

### 1. Check if RLS is enabled:
```sql
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('posts', 'vehicles', 'profiles');
```
Should show `rowsecurity = true`

### 2. Check existing policies:
```sql
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE tablename IN ('posts', 'vehicles', 'profiles')
ORDER BY tablename, cmd;
```

### 3. Test query as guest:
```sql
-- This should return posts (not error)
SELECT id, service_type, price
FROM posts
WHERE is_active = true
LIMIT 5;
```

### 4. Check app logs:
Look for errors like:
- `new row violates row-level security policy`
- `permission denied for table`
- `insufficient privilege`

### 5. Verify Supabase connection:
```dart
// In app code
final response = await Supabase.instance.client
    .from('posts')
    .select()
    .eq('is_active', true);
    
print('Posts loaded: ${response.length}');
```

## Quick Reference

### Enable RLS:
```sql
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
```

### Disable RLS (NOT RECOMMENDED):
```sql
ALTER TABLE posts DISABLE ROW LEVEL SECURITY;
```

### Drop Policy:
```sql
DROP POLICY IF EXISTS "policy_name" ON table_name;
```

### Create Public Read Policy:
```sql
CREATE POLICY "policy_name"
ON table_name
FOR SELECT
TO public
USING (condition);
```

### Create Authenticated Write Policy:
```sql
CREATE POLICY "policy_name"
ON table_name
FOR INSERT
TO authenticated
WITH CHECK (profile_id = (auth.jwt() ->> 'sub'));
```

## Support

If issues persist:
1. Check Supabase logs (Dashboard → Logs)
2. Verify Firebase JWT is being sent
3. Check network requests in browser DevTools
4. Test with Supabase SQL Editor directly
5. Contact Supabase support if needed

## Summary

The fix is simple:
1. Run `QUICK_FIX_GUEST_ACCESS.sql` in Supabase
2. Restart app
3. Guest users can now browse posts ✅

The key is using `TO public` instead of `TO authenticated` for SELECT policies on public data.
