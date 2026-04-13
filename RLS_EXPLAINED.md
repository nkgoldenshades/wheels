# RLS Policies Explained - Simple Guide

## What is RLS (Row Level Security)?

RLS is like a bouncer at a club - it checks WHO you are and decides WHAT data you can see/modify.

## Your App's Security Model

### 🌐 Guest Users (Not Logged In)
```
CAN:
✅ Browse posts (see available rides)
✅ See online vehicles
✅ Read reviews
✅ View provider names (but we hide them in app as "Unknown User")

CANNOT:
❌ Create posts
❌ Book rides
❌ See offline vehicles
❌ Modify anything
```

### 👤 Authenticated Users (Logged In)
```
CAN:
✅ Everything guests can do
✅ See their own vehicles (all of them, online + offline)
✅ See other users' online vehicles
✅ Create/edit/delete their own posts
✅ Create bookings
✅ See bookings they're involved in (as customer or provider)
✅ Write reviews

CANNOT:
❌ See other users' offline vehicles
❌ Modify other users' data
❌ See other users' bookings
```

## How RLS Works - Real Examples

### Example 1: Viewing Vehicles

**Scenario:** User A wants to see vehicles

```sql
-- What User A queries:
SELECT * FROM vehicles;

-- What RLS does behind the scenes:
SELECT * FROM vehicles 
WHERE (
  profile_id = 'user-a-id'  -- User A's own vehicles
  OR is_online = true       -- Other users' online vehicles
);

-- Result: User A sees:
✅ Their own vehicles (all)
✅ Other users' online vehicles
❌ Other users' offline vehicles (hidden by RLS)
```

### Example 2: Guest Browsing Posts

**Scenario:** Guest (not logged in) wants to browse posts

```sql
-- What guest queries:
SELECT * FROM posts;

-- What RLS does:
SELECT * FROM posts 
WHERE is_active = true AND is_deleted = false;

-- Result: Guest sees:
✅ All active posts
❌ Deleted posts (hidden by RLS)
❌ Inactive posts (hidden by RLS)
```

### Example 3: Creating a Post

**Scenario:** User A tries to create a post

```sql
-- What User A tries:
INSERT INTO posts (id, profile_id, vehicle_id, ...) 
VALUES ('post-1', 'user-a-id', 'vehicle-1', ...);

-- What RLS checks:
WITH CHECK (profile_id = auth.jwt()->>'sub')
-- Is 'user-a-id' == current user's ID?

-- Result:
✅ If User A is logged in and profile_id matches → SUCCESS
❌ If User A tries to set profile_id to someone else → BLOCKED
❌ If guest tries → BLOCKED (not authenticated)
```

### Example 4: Viewing Bookings

**Scenario:** User A wants to see bookings

```sql
-- What User A queries:
SELECT * FROM bookings;

-- What RLS does:
SELECT * FROM bookings 
WHERE (
  profile_customer_id = 'user-a-id' OR  -- Bookings where User A is customer
  profile_provider_id = 'user-a-id'     -- Bookings where User A is provider
);

-- Result: User A sees:
✅ Bookings where they are the customer
✅ Bookings where they are the provider
❌ Other users' bookings (hidden by RLS)
```

## The "My Vehicles" Issue You Found

### What Was Happening (Before Fix):

```
1. Database RLS: USING (true)  ← Allows reading ALL vehicles
2. VehicleRepository: Loads ALL vehicles from database
3. VehicleListScreen: Shows ALL vehicles (BUG!)

Result: Provider A sees Provider B's vehicles ❌
```

### What We Fixed:

**Option 1: App-Level Filtering (Current)**
```
1. Database RLS: USING (true)  ← Still allows reading all
2. VehicleRepository: Loads ALL vehicles
3. VehicleListScreen: Filters to show only current user's vehicles ✅

Result: Provider A sees only their vehicles ✅
```

**Option 2: Database-Level Security (Recommended)**
```
1. Database RLS: USING (profile_id = auth.jwt()->>'sub' OR is_online = true)
2. VehicleRepository: Loads vehicles (RLS filters automatically)
3. VehicleListScreen: Shows what database returned ✅

Result: Provider A sees only their vehicles ✅
Security: Can't bypass in app code ✅
```

## Which RLS Setup Should You Use?

### Current Setup (Permissive):
```sql
CREATE POLICY "public_read_vehicles" 
ON vehicles FOR SELECT USING (true);
```
- ✅ Simple
- ✅ Works for browsing
- ❌ App must filter correctly
- ❌ Can be bypassed if app has bugs

### Recommended Setup (Secure):
```sql
CREATE POLICY "users_view_vehicles"
ON vehicles FOR SELECT
USING (
  profile_id = auth.jwt()->>'sub' OR  -- Own vehicles
  is_online = true                    -- Others' online vehicles
);
```
- ✅ Secure by default
- ✅ Can't bypass in app
- ✅ Follows principle of least privilege
- ✅ Better for compliance

## How to Apply the Secure Setup

### Step 1: Run the SQL
```bash
# In Supabase SQL Editor, run:
COMPLETE_RLS_POLICIES.sql
```

### Step 2: No Dart Changes Needed!
The Dart code I already fixed will work perfectly because:
- When querying `vehicles` table, RLS automatically filters
- "My Vehicles" page gets only user's vehicles
- Posts page gets all online vehicles

### Step 3: Test
```
1. Login as Provider A
2. Go to "My Vehicles"
3. Should see ONLY Provider A's vehicles ✅
4. Go to "Posts" page
5. Should see posts from all providers ✅
```

## Common RLS Patterns

### Pattern 1: Owner-Only Access
```sql
-- Users can only see/modify their own data
USING (user_id = auth.jwt()->>'sub')
```
Use for: Personal settings, private documents

### Pattern 2: Public Read, Owner Write
```sql
-- Everyone can read, only owner can write
FOR SELECT USING (true)
FOR UPDATE USING (user_id = auth.jwt()->>'sub')
```
Use for: Posts, reviews, public profiles

### Pattern 3: Conditional Public Access
```sql
-- Public can see if condition met, owner sees all
USING (
  user_id = auth.jwt()->>'sub' OR  -- Owner sees all
  is_public = true                 -- Others see public only
)
```
Use for: Vehicles (online/offline), posts (active/inactive)

### Pattern 4: Multi-Party Access
```sql
-- Multiple users can access the same row
USING (
  customer_id = auth.jwt()->>'sub' OR
  provider_id = auth.jwt()->>'sub'
)
```
Use for: Bookings, conversations, shared documents

## Debugging RLS Issues

### Issue: "No data showing"
```sql
-- Check if RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'your_table';

-- Check policies
SELECT * FROM pg_policies WHERE tablename = 'your_table';
```

### Issue: "Can't insert data"
```sql
-- Check INSERT policy WITH CHECK clause
-- Make sure it allows your user to insert
```

### Issue: "Seeing other users' data"
```sql
-- Check SELECT policy USING clause
-- Make sure it filters by current user
```

## Summary

**RLS is your database bouncer:**
- ✅ Enforces security at database level
- ✅ Can't be bypassed by buggy app code
- ✅ Automatic filtering on every query
- ✅ Works with any client (web, mobile, API)

**For your ride-sharing app:**
1. Run `COMPLETE_RLS_POLICIES.sql` for secure setup
2. Dart code already handles filtering correctly
3. Test to verify users only see their own data
4. Sleep well knowing security is enforced at DB level 😴
