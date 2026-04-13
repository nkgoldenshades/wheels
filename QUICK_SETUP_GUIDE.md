# Quick Setup Guide - Get Posts Showing

## Step 1: Run Database Triggers (One-Time Setup)

### Open Supabase SQL Editor
1. Go to Supabase Dashboard
2. Click "SQL Editor" in left sidebar
3. Click "New Query"

### Run This SQL (Copy & Paste All)
```sql
-- ============================================
-- STEP 1: Create Sync Trigger
-- ============================================
CREATE OR REPLACE FUNCTION sync_vehicle_status_to_posts()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
    UPDATE posts
    SET 
      is_active = NEW.is_active,
      updated_at = NOW()
    WHERE vehicle_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS vehicle_status_sync_trigger ON vehicles;

CREATE TRIGGER vehicle_status_sync_trigger
  AFTER UPDATE ON vehicles
  FOR EACH ROW
  WHEN (OLD.is_active IS DISTINCT FROM NEW.is_active)
  EXECUTE FUNCTION sync_vehicle_status_to_posts();

-- ============================================
-- STEP 2: Activate Your Vehicles & Posts
-- ============================================
-- Replace 'YOUR_USER_ID' with: GbsFkKmcHCQFJ0ceVoBWz2punch1

-- Activate all your vehicles
UPDATE vehicles 
SET is_active = true 
WHERE profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';

-- Sync all posts to match vehicle status
UPDATE posts p
SET 
  is_active = v.is_active,
  updated_at = NOW()
FROM vehicles v
WHERE p.vehicle_id = v.id
  AND p.profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';

-- ============================================
-- STEP 3: Verify Everything
-- ============================================
SELECT 
  v.registration_number,
  v.is_active as vehicle_active,
  COUNT(p.id) as total_posts,
  COUNT(CASE WHEN p.is_active THEN 1 END) as active_posts
FROM vehicles v
LEFT JOIN posts p ON p.vehicle_id = v.id
WHERE v.profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1'
GROUP BY v.id, v.registration_number, v.is_active;

-- Expected: All vehicles should show is_active = true
-- Expected: active_posts should equal total_posts
```

## Step 2: Run RLS Policies (If Not Already Done)

### Copy & Paste This SQL
```sql
-- ============================================
-- RLS POLICIES
-- ============================================

-- Profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view other profiles" ON profiles;
CREATE POLICY "Users can view other profiles" ON profiles FOR SELECT USING (true);

-- Vehicles
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view all vehicles" ON vehicles;
CREATE POLICY "Users can view all vehicles" ON vehicles FOR SELECT USING (true);

-- Posts
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view active posts" ON posts;
CREATE POLICY "Users can view active posts" ON posts 
FOR SELECT USING (is_active = true OR auth.uid() = profile_id);

-- Bookings
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can insert their bookings" ON bookings;
CREATE POLICY "Users can insert their bookings" ON bookings 
FOR INSERT WITH CHECK (auth.uid() = profile_customer_id AND profile_customer_id IS NOT NULL);

DROP POLICY IF EXISTS "Users can view their bookings" ON bookings;
CREATE POLICY "Users can view their bookings" ON bookings 
FOR SELECT USING (auth.uid() = profile_customer_id OR auth.uid() = profile_provider_id);
```

## Step 3: Restart Your App

1. **Close the app completely**
2. **Restart it**
3. **Check the debug console**

### Expected Logs
```
✅ Loaded 5 vehicles from Supabase
✅ Loaded 5 slots from Supabase (all users)
Total provider slots: 5
  - Slot post_1: vehicle=veh_1, userId=..., online=true
  - Slot post_2: vehicle=veh_2, userId=..., online=true
📊 Provider posts mapped: 5
📊 FINAL RESULT: 5 posts after all filters
```

## Step 4: Check Your Feed

1. Open app
2. Go to "Provider Posts" tab
3. **You should see your 5 posts!** 🎉

## Troubleshooting

### Still Seeing 0 Posts?

#### Check 1: Vehicles Loaded?
Look for: `✅ Loaded X vehicles from Supabase`
- If 0 → RLS issue, run RLS policies again
- If >0 → Continue to next check

#### Check 2: Posts Loaded?
Look for: `✅ Loaded X slots from Supabase`
- If 0 → RLS issue, run RLS policies again
- If >0 → Continue to next check

#### Check 3: Vehicles Online?
Look for: `online=true` in logs
- If false → Toggle vehicle online in app
- Go to Vehicles → Toggle switch

#### Check 4: Database Status
Run this in Supabase:
```sql
SELECT 
  v.registration_number,
  v.is_active as vehicle_active,
  p.id as post_id,
  p.is_active as post_active
FROM vehicles v
LEFT JOIN posts p ON p.vehicle_id = v.id
WHERE v.profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';
```

Expected: All should have `is_active = true`

## How It Works Now

### Creating Posts
1. User adds vehicle → `vehicle.is_active = true` (default)
2. User creates post → `post.is_active = true` (default)
3. Post shows in feed ✅

### Hiding Posts
1. User goes to vehicle details
2. User deactivates vehicle → `vehicle.is_active = false`
3. **Trigger automatically sets** `post.is_active = false`
4. Post hidden from feed ✅

### Showing Posts Again
1. User goes to vehicle details
2. User activates vehicle → `vehicle.is_active = true`
3. **Trigger automatically sets** `post.is_active = true`
4. Post shows in feed again ✅

## Summary

**What You Did:**
1. ✅ Created database trigger for auto-sync
2. ✅ Activated all vehicles
3. ✅ Synced all posts
4. ✅ Set up RLS policies

**What Happens Now:**
- Vehicle status controls post visibility
- Changes are automatic (no manual sync)
- App just queries `is_active = true`
- Everything stays in sync

**Result:**
Your 5 posts should now be visible in the feed! 🚀
