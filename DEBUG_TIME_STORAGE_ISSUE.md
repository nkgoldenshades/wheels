# 🔍 Debug: Time Storage Issue

## The Problem

**You select:** 9:00 AM  
**App shows:** 14:30 (2:30 PM)

This suggests the time you choose is **not being stored correctly** in Supabase.

## Possible Causes

### 1. Wrong Column Type in Supabase
If the column is `timestamp` instead of `timestamptz`, it won't store timezone info correctly.

**Check this:**
Run `CHECK_SUPABASE_TIME_COLUMNS.sql` in Supabase SQL Editor

**Expected:**
```
column_name  | data_type
-------------|------------
start_time   | timestamptz  ← Should be this
end_time     | timestamptz  ← Should be this
```

**If you see:**
```
start_time   | timestamp  ← WRONG!
end_time     | timestamp  ← WRONG!
```

Then the column type needs to be changed.

### 2. Default Time Being Used
The time picker might not be updating the actual DateTime value.

### 3. Timezone Conversion Issue
The DateTime might be in wrong timezone when created.

## Debug Steps

### Step 1: Create a New Post

1. **Restart your app:**
   ```bash
   flutter run -d chrome
   ```

2. **Create a post and select time:** 9:00 AM

3. **Check console logs** for:
   ```
   ⏰ TIME DEBUG:
      slot.startTime (local): 2026-04-15 09:00:00.000
      slot.endTime (local): 2026-04-15 17:00:00.000
      startTime ISO: 2026-04-15T03:30:00.000Z
      endTime ISO: 2026-04-15T11:30:00.000Z
   ```

### Step 2: Check What's Stored in Supabase

1. Go to **Supabase Dashboard** → **Table Editor** → **posts**
2. Find your post
3. Check `start_time` and `end_time` columns

**Expected:**
```
start_time: 2026-04-15 03:30:00+00  (9 AM IST in UTC)
end_time: 2026-04-15 11:30:00+00  (5 PM IST in UTC)
```

**If you see:**
```
start_time: 2026-04-15 14:30:00+00  ← WRONG!
```

Then the problem is in how the time is created in Flutter.

### Step 3: Check Time Picker

If the console shows wrong time (like 14:30 instead of 9:00), then the time picker is not working correctly.

## Solutions

### Solution 1: Fix Column Type (If Wrong)

Run this SQL in Supabase:

```sql
-- Change column type to timestamptz
ALTER TABLE posts 
  ALTER COLUMN start_time TYPE timestamptz USING start_time AT TIME ZONE 'UTC';

ALTER TABLE posts 
  ALTER COLUMN end_time TYPE timestamptz USING end_time AT TIME ZONE 'UTC';

ALTER TABLE user_posts 
  ALTER COLUMN start_time TYPE timestamptz USING start_time AT TIME ZONE 'UTC';

ALTER TABLE user_posts 
  ALTER COLUMN end_time TYPE timestamptz USING end_time AT TIME ZONE 'UTC';
```

### Solution 2: Fix Time Picker (If Not Updating)

Check if the time picker is actually updating `_startTime` and `_endTime` variables.

### Solution 3: Remove .toLocal() (Already Done)

I already removed `.toLocal()` from the parsing code since `toIso8601String()` handles timezone conversion automatically.

## What to Share

After creating a post, share these from console:

1. **Time debug logs:**
   ```
   ⏰ TIME DEBUG:
      slot.startTime (local): ???
      startTime ISO: ???
   ```

2. **What you selected:** 9:00 AM

3. **What app shows:** 14:30

4. **What's in Supabase:** (from Table Editor)

This will help identify exactly where the problem is!

---

**Next Step:** Create a post and share the console logs!
