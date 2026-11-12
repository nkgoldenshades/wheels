# 🚨 URGENT: Fix RLS Policies for Common Feed

## The Problem

You're still seeing only your own posts because **Supabase RLS policies are filtering by user** at the database level.

The Flutter code is correct, but the database is blocking other users' posts!

---

## 🎯 Quick Fix (2 Minutes)

### Step 1: Run Diagnostic (30 seconds)

1. Open Supabase Dashboard → SQL Editor
2. Copy and run `CHECK_WHAT_USERS_SEE.sql`
3. Look at the diagnosis output

**If you see:**
```
❌ PROBLEM: SELECT policy filters by profile_id - users only see own posts
```

**Then you need to run the fix!**

---

### Step 2: Run Fix Script (1 minute)

1. Open Supabase Dashboard → SQL Editor
2. Copy **ALL** content from `FIX_RLS_COMMON_FEED.sql`
3. Paste and click "Run"
4. Wait for "Success" message

**What this does:**
- ✅ Removes user-specific SELECT policies
- ✅ Creates new policies that allow ALL users to see ALL posts
- ✅ Keeps INSERT/UPDATE/DELETE restricted to post owners
- ✅ Enables true common feed

---

### Step 3: Restart Flutter App (30 seconds)

1. Stop your Flutter app completely
2. Restart it
3. Test with multiple users

**Expected result:**
- ✅ All users see the same posts
- ✅ Common shared feed works

---

## 🔍 What's Happening

### Current (Wrong) RLS Policy

```sql
-- This filters posts by current user
CREATE POLICY "posts_select"
ON posts FOR SELECT
USING (profile_id = current_user_id);  -- ❌ WRONG!
```

**Result:** Each user only sees their own posts

### Fixed RLS Policy

```sql
-- This allows everyone to see all active posts
CREATE POLICY "public_select_all_active_posts"
ON posts FOR SELECT
TO public
USING (is_active = true);  -- ✅ CORRECT!
```

**Result:** All users see all posts

---

## 📊 Before vs After

### Before Fix (❌ User-Specific)

**Database query from User A:**
```sql
SELECT * FROM posts WHERE is_active = true;
-- RLS adds: AND profile_id = 'user_a_id'
-- Returns: Only User A's posts
```

**Database query from User B:**
```sql
SELECT * FROM posts WHERE is_active = true;
-- RLS adds: AND profile_id = 'user_b_id'
-- Returns: Only User B's posts
```

### After Fix (✅ Common Feed)

**Database query from User A:**
```sql
SELECT * FROM posts WHERE is_active = true;
-- RLS allows: All active posts
-- Returns: All users' posts
```

**Database query from User B:**
```sql
SELECT * FROM posts WHERE is_active = true;
-- RLS allows: All active posts
-- Returns: All users' posts (same as User A)
```

---

## 🛡️ Security

**Don't worry - security is maintained:**

### What Users CAN Do
- ✅ **SELECT:** See all active posts (common feed)
- ✅ **INSERT:** Create their own posts
- ✅ **UPDATE:** Edit their own posts only
- ✅ **DELETE:** Delete their own posts only

### What Users CANNOT Do
- ❌ Edit other users' posts
- ❌ Delete other users' posts
- ❌ See inactive/deleted posts

**The fix only changes SELECT (viewing), not write operations!**

---

## 🧪 Testing

### Test 1: Check Policies

Run in Supabase SQL Editor:
```sql
SELECT policyname, cmd, roles
FROM pg_policies 
WHERE tablename = 'posts' AND cmd = 'SELECT';
```

**Expected:**
```
policyname                        | cmd    | roles
----------------------------------|--------|--------
public_select_all_active_posts    | SELECT | {public}
```

### Test 2: Multiple Users

1. User A creates a post
2. User B opens app
3. User B should see User A's post

**Expected:** ✅ Both users see the same posts

### Test 3: Guest Access

1. Open app without logging in
2. Check posts feed

**Expected:** ✅ Guest sees all active posts

---

## 📝 Files to Run

**In Supabase SQL Editor:**

1. **`CHECK_WHAT_USERS_SEE.sql`** - Diagnose the problem
2. **`FIX_RLS_COMMON_FEED.sql`** - Fix the policies

**Run them in this order!**

---

## ⚠️ Common Mistakes

### Mistake 1: Not running the SQL script
**Problem:** Flutter code is correct, but database still filters by user  
**Fix:** Run `FIX_RLS_COMMON_FEED.sql` in Supabase

### Mistake 2: Running partial script
**Problem:** Some policies updated, others not  
**Fix:** Copy and run the ENTIRE script

### Mistake 3: Not restarting app
**Problem:** App still has cached data  
**Fix:** Completely restart Flutter app

### Mistake 4: Wrong table name
**Problem:** Script runs on wrong table  
**Fix:** Verify table names are `posts` and `user_posts`

---

## 🎯 Success Criteria

After running the fix:

- [ ] Diagnostic shows: "✅ OK: SELECT policy allows all users to see all posts"
- [ ] User A sees User B's posts
- [ ] User B sees User A's posts
- [ ] Guests see all posts
- [ ] All users see identical feeds

---

## 🆘 Still Not Working?

If you still see only your own posts after running the SQL:

### Check 1: Verify Policies Were Created
```sql
SELECT * FROM pg_policies WHERE tablename = 'posts';
```

### Check 2: Test as Anonymous User
```sql
SET ROLE anon;
SELECT COUNT(*) FROM posts WHERE is_active = true;
RESET ROLE;
```

### Check 3: Check Flutter Console
Look for:
```
🔍 Supabase response: X posts found
```

If X = 1 (only your post), the RLS policy is still filtering.

### Check 4: Verify Table Names
Make sure your tables are named:
- `posts` (not `post` or `provider_posts`)
- `user_posts` (not `customer_posts` or `requests`)

---

## 📞 Need Help?

Share these outputs:

1. **Diagnostic output:**
```sql
-- Run CHECK_WHAT_USERS_SEE.sql and share the diagnosis section
```

2. **Current policies:**
```sql
SELECT * FROM pg_policies WHERE tablename IN ('posts', 'user_posts');
```

3. **Flutter console logs:**
```
🔍 Loading posts from Supabase...
🔍 Supabase response: X posts found
```

---

**TL;DR:**
1. Run `FIX_RLS_COMMON_FEED.sql` in Supabase
2. Restart Flutter app
3. All users will see all posts ✅
