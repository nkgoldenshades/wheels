# 🚨 URGENT: Fix Vehicles RLS Policy

## The Problem

User 2 can't see User 1's posts because:

1. ✅ Supabase returns the post (RLS allows it)
2. ❌ But User 2 has **0 vehicles loaded**
3. ❌ Post can't find its vehicle → 0 slot entries built
4. ❌ Feed shows empty

**From your logs:**
```
User 2 logs in:
🔍 Supabase response: 1 posts found  ← Post is there!
📊 Built 0 slot entries from 1 slots  ← But no vehicle!
✅ Loaded 0 vehicles from Supabase  ← RLS blocking vehicles!
```

## Root Cause

The `vehicles` table has an RLS policy that filters by `profile_id`, so users only see their own vehicles.

**Current (wrong) policy:**
```sql
-- Users only see their own vehicles
USING (profile_id = current_user_id)
```

**What we need:**
```sql
-- All users see all vehicles (for common feed)
USING (true)
```

## The Fix

### Step 1: Run Diagnostic (30 seconds)

1. Open **Supabase Dashboard** → **SQL Editor**
2. Copy and run `DEBUG_WHY_NO_VEHICLES_FOR_USER2.sql`
3. Look at the diagnosis

**If you see:**
```
❌ PROBLEM: SELECT policy filters by profile_id - users only see own vehicles
```

Then proceed to Step 2.

### Step 2: Fix RLS Policy (1 minute)

1. In **Supabase Dashboard** → **SQL Editor**
2. Copy and paste **ALL** of `FIX_VEHICLES_SELECT_POLICY.sql`
3. Click **Run**
4. Wait for "Success"

**What this does:**
- ✅ Removes user-specific SELECT policy on vehicles
- ✅ Creates new policy: `public_select_all_vehicles` with `USING (true)`
- ✅ Allows ALL users to see ALL vehicles
- ✅ Keeps INSERT/UPDATE/DELETE restricted to vehicle owners

### Step 3: Restart Flutter App

```bash
flutter run -d chrome
```

### Step 4: Test

1. User 1 creates a post
2. User 2 logs in
3. User 2 should see User 1's post ✅

## Why This Is Needed

**For common feed to work:**
- ✅ Posts table: Allow all users to SELECT (already done)
- ✅ Vehicles table: Allow all users to SELECT (needs fixing)

**Without this fix:**
- User 2 queries posts → Gets User 1's post
- User 2 tries to build slot entry → Can't find vehicle
- Result: Empty feed

**With this fix:**
- User 2 queries posts → Gets User 1's post
- User 2 queries vehicles → Gets User 1's vehicle
- User 2 builds slot entry → Success!
- Result: Post appears in feed ✅

## Security

**Don't worry - security is maintained:**

### What Users CAN Do
- ✅ **SELECT:** See all vehicles (needed for feed)
- ✅ **INSERT:** Create their own vehicles
- ✅ **UPDATE:** Edit their own vehicles only
- ✅ **DELETE:** Delete their own vehicles only

### What Users CANNOT Do
- ❌ Edit other users' vehicles
- ❌ Delete other users' vehicles
- ❌ Create vehicles for other users

**The fix only changes SELECT (viewing), not write operations!**

## Expected Console Logs

### Before Fix
```
User 2:
✅ Loaded 0 vehicles from Supabase  ← RLS blocking
📊 Built 0 slot entries from 1 slots  ← No vehicles = no entries
```

### After Fix
```
User 2:
✅ Loaded 1 vehicles from Supabase  ← Can see User 1's vehicle!
📊 Built 1 slot entries from 1 slots  ← Entry created!
📊 FINAL RESULT: 1 posts after all filters  ← Post appears!
```

## Summary

**Problem:** Vehicles RLS filters by user → User 2 can't see User 1's vehicle → Can't build slot entry

**Solution:** Change vehicles SELECT policy to `USING (true)`

**Files to run:**
1. `DEBUG_WHY_NO_VEHICLES_FOR_USER2.sql` - Diagnose
2. `FIX_VEHICLES_SELECT_POLICY.sql` - Fix

**Time:** 2 minutes

**Result:** Common feed works! ✅

---

**Action Required:** Run `FIX_VEHICLES_SELECT_POLICY.sql` in Supabase SQL Editor NOW!
