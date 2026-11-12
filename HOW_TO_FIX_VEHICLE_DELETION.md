# 🔧 How to Fix Vehicle Deletion Error

## 🚨 The Problem

You're getting this error when trying to delete a vehicle:
```
PostgrestException: column bookings.slot_id does not exist
```

**Even though:**
- ✅ You deleted all posts
- ✅ The `bookings` table uses `post_id` column (not `slot_id`)
- ✅ The table is empty (no data)

## 🎯 Root Cause

The error is coming from **database-level code** (RLS policies, functions, or triggers) that still references `bookings.slot_id` instead of `bookings.post_id`.

When you try to delete a vehicle, PostgreSQL checks RLS policies and triggers, and one of them tries to access the non-existent `slot_id` column.

## ✅ The Solution

Run the SQL script to find and fix ALL `slot_id` references in your database.

### Step 1: Open Supabase SQL Editor

1. Go to your Supabase dashboard
2. Click **SQL Editor** in the left sidebar
3. Click **New Query**

### Step 2: Run the Fix Script

1. Open the file: `FIND_AND_FIX_SLOT_ID.sql`
2. Copy ALL the content
3. Paste it into the Supabase SQL Editor
4. Click **Run** (or press Ctrl+Enter)

### Step 3: Check the Output

The script will:
1. 🔍 **Find** all `slot_id` references in:
   - RLS policies
   - Functions
   - Triggers
   - Foreign keys
2. 🔧 **Fix** them by:
   - Dropping old policies with `slot_id`
   - Creating new policies with `post_id`
   - Updating foreign keys
   - Updating indexes
3. ✅ **Verify** that everything is fixed

Look for this message at the end:
```
🎉 SUCCESS! All slot_id references have been fixed!
🎉 You can now delete vehicles without errors!
```

### Step 4: Test Vehicle Deletion

1. Go back to your Flutter app
2. Try deleting a vehicle again
3. It should work now! 🎉

## 📋 What the Script Does

### 1. Diagnostic Phase
- Searches for `slot_id` in RLS policies, functions, triggers, and foreign keys
- Shows you exactly where the problem is

### 2. Fix Phase
- Drops ALL RLS policies that reference `slot_id`
- Creates new RLS policies using `post_id`:
  - `bookings_select_as_customer` - Customers can see their bookings
  - `bookings_select_as_provider` - Providers can see their bookings
  - `bookings_insert_as_customer` - Customers can create bookings
  - `bookings_update_by_owner` - Both can update their bookings
- Updates foreign key constraints
- Updates indexes

### 3. Verification Phase
- Checks that no `slot_id` references remain
- Shows current RLS policies for confirmation

## 🔍 If It Still Doesn't Work

If you still get errors after running the script:

1. **Check the script output** - Look for any warnings like:
   ```
   ⚠️  Still found X functions with slot_id
   ```

2. **Send me the output** - Copy the entire output from the SQL Editor and send it to me

3. **Check for custom functions** - If you have custom database functions, they might need manual updates

## 🎓 Why This Happened

Your Flutter code was already fixed to use `post_id`, but the database still had old RLS policies from when the column was called `slot_id`. These policies run automatically when you try to delete a vehicle, causing the error.

## 📝 Summary

| What | Status |
|------|--------|
| Flutter code | ✅ Already fixed (uses `post_id`) |
| Database table | ✅ Already correct (has `post_id` column) |
| RLS policies | ❌ Still using `slot_id` → **This is what we're fixing** |
| Foreign keys | ❌ Might still reference `slot_id` → **This is what we're fixing** |

After running the script, everything will be aligned and vehicle deletion will work! 🚀
