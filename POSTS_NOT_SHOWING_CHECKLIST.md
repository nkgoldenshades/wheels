# 🔍 Posts Not Showing - Troubleshooting Checklist

## Quick Diagnosis (Do These in Order)

### Step 1: Check if Posts Exist in Database (30 seconds)

**Run this in Supabase SQL Editor:**
```sql
SELECT COUNT(*) as total, 
       COUNT(*) FILTER (WHERE is_active = true) as active
FROM posts;
```

**Results:**
- `total = 0` → **No posts exist** → Go to Step 2
- `active = 0` → **Posts exist but not active** → Go to Step 3
- `active > 0` → **Posts exist and active** → Go to Step 4

---

### Step 2: No Posts Exist - Create Test Post

**Option A: Create via Flutter App**
1. Log in to your app
2. Go to "My Vehicles" → Add a vehicle
3. Go to "Create Post" → Fill form → Submit
4. Check if post appears in feed

**Option B: Create via SQL**
```sql
-- First, get your profile_id and vehicle_id
SELECT id, full_name FROM profiles LIMIT 1;
SELECT id, vehicle_name FROM vehicles LIMIT 1;

-- Then create a test post (replace IDs below)
INSERT INTO posts (
  id, profile_id, vehicle_id, service_type, slot_type,
  from_location, to_location, start_time, end_time,
  price, capacity, is_active, created_at
) VALUES (
  gen_random_uuid(),
  'YOUR_PROFILE_ID_HERE',  -- Replace with actual profile ID
  'YOUR_VEHICLE_ID_HERE',  -- Replace with actual vehicle ID
  'ride',
  'from_to',
  'Chennai Central',
  'Bangalore City',
  NOW() + INTERVAL '1 hour',
  NOW() + INTERVAL '5 hours',
  500,
  4,
  true,
  NOW()
);
```

**After creating:** Restart Flutter app and check feed.

---

### Step 3: Posts Exist But Not Active - Activate Them

**Run this in Supabase SQL Editor:**
```sql
-- Activate all posts
UPDATE posts SET is_active = true WHERE is_active = false;

-- Verify
SELECT COUNT(*) FROM posts WHERE is_active = true;
```

**After activating:** Restart Flutter app and check feed.

---

### Step 4: Posts Exist and Active - Check RLS Policies

**Run this in Supabase SQL Editor:**
```sql
-- Check if public can SELECT posts
SELECT policyname, roles, cmd
FROM pg_policies 
WHERE tablename = 'posts' AND cmd = 'SELECT';
```

**Expected Result:**
- Should see a policy with `roles = {public}` or `roles = {anon, authenticated}`

**If no SELECT policy exists:**
→ **Run `COMPLETE_RLS_FIX_FOR_FIREBASE.sql`** (this is the main fix)

---

### Step 5: RLS Policies Exist - Test as Guest

**Run this in Supabase SQL Editor:**
```sql
-- Simulate guest user
SET ROLE anon;
SELECT * FROM posts WHERE is_active = true LIMIT 5;
RESET ROLE;
```

**Results:**
- **Rows returned** → RLS is working, problem is in Flutter app
- **No rows / Error** → RLS is blocking guests → Run `COMPLETE_RLS_FIX_FOR_FIREBASE.sql`

---

### Step 6: Check Flutter App Logs

**Look for these messages in your Flutter console:**

**Good signs:**
```
🔍 Loading posts from Supabase...
🔍 Firebase user: GUEST (or a UID)
🔍 Supabase response: 5 posts found
✅ Loaded 5 slots from Supabase
```

**Bad signs:**
```
❌ Failed to load from Supabase: PostgrestException(message: Empty JWT...)
⚠️ Failed to load slots from Supabase, trying local: ...
```

**If you see "Empty JWT" error:**
→ **Run `COMPLETE_RLS_FIX_FOR_FIREBASE.sql`**

**If you see "0 posts found":**
→ Go back to Step 1 (no posts in database)

---

## 🎯 Most Common Issues & Fixes

### Issue 1: "Empty JWT is sent in Authorization header"
**Cause:** RLS policies require `authenticated` role, but guests are `anon`

**Fix:** Run `COMPLETE_RLS_FIX_FOR_FIREBASE.sql` in Supabase SQL Editor

**Time:** 2 minutes

---

### Issue 2: Posts exist but `is_active = false`
**Cause:** Posts were created but not activated

**Fix:**
```sql
UPDATE posts SET is_active = true;
```

**Time:** 10 seconds

---

### Issue 3: No posts in database at all
**Cause:** No one has created posts yet

**Fix:** Create posts via Flutter app or SQL (see Step 2)

**Time:** 2 minutes

---

### Issue 4: Blocking trigger prevents post creation
**Cause:** `validate_posts_profile_matches_vehicle` trigger blocks inserts

**Fix:** Run `COMPLETE_RLS_FIX_FOR_FIREBASE.sql` (drops the trigger)

**Time:** 2 minutes

---

### Issue 5: Posts have missing vehicles
**Cause:** `vehicle_id` in posts doesn't match any vehicle in `vehicles` table

**Fix:**
```sql
-- Find posts with missing vehicles
SELECT p.id, p.vehicle_id 
FROM posts p 
LEFT JOIN vehicles v ON v.id = p.vehicle_id 
WHERE v.id IS NULL;

-- Delete posts with missing vehicles (or fix vehicle_id)
DELETE FROM posts 
WHERE vehicle_id NOT IN (SELECT id FROM vehicles);
```

**Time:** 1 minute

---

## 🚀 The One-Command Fix (Most Cases)

**If you haven't run this yet, do it now:**

1. Open `COMPLETE_RLS_FIX_FOR_FIREBASE.sql`
2. Copy all content
3. Open Supabase Dashboard → SQL Editor
4. Paste and click "Run"
5. Restart Flutter app

**This fixes:**
- ✅ RLS policies (allows guests to browse)
- ✅ Drops blocking trigger
- ✅ Adds Firebase JWT validation
- ✅ Enables proper authentication

---

## 🔍 Advanced Diagnostics

**Run the complete diagnostic:**
1. Open `WHY_POSTS_NOT_SHOWING.sql`
2. Copy all content
3. Run in Supabase SQL Editor
4. Read the diagnosis messages

**This checks:**
- Do posts exist?
- Are posts active?
- Do RLS policies allow SELECT?
- Do vehicles exist for posts?
- Do profiles exist for posts?
- Is there a blocking trigger?
- What would guests see?

---

## ✅ Success Checklist

After fixing, you should have:

- [ ] Posts exist in database (`SELECT COUNT(*) FROM posts WHERE is_active = true` > 0)
- [ ] RLS SELECT policy exists for public/anon
- [ ] No "Empty JWT" errors in Flutter console
- [ ] Flutter logs show "X posts found"
- [ ] Posts appear in app feed
- [ ] Guests can browse without logging in

---

## 📞 Still Not Working?

**Share these details:**

1. **Database check:**
```sql
SELECT COUNT(*) as total, 
       COUNT(*) FILTER (WHERE is_active = true) as active
FROM posts;
```

2. **RLS check:**
```sql
SELECT policyname, roles 
FROM pg_policies 
WHERE tablename = 'posts' AND cmd = 'SELECT';
```

3. **Flutter console logs** (copy the relevant error messages)

4. **Did you run `COMPLETE_RLS_FIX_FOR_FIREBASE.sql`?** (Yes/No)
