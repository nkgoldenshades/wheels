# ⚡ Quick Fix Checklist

## 🚨 THE ONE THING YOU MUST DO

### Run This SQL Script in Supabase:
**File:** `COMPLETE_RLS_FIX_FOR_FIREBASE.sql`

**Steps:**
1. Open Supabase Dashboard
2. Click "SQL Editor" in left sidebar
3. Open `COMPLETE_RLS_FIX_FOR_FIREBASE.sql` in your code editor
4. Copy ALL the content (Ctrl+A, Ctrl+C)
5. Paste into Supabase SQL Editor
6. Click "Run" button
7. Wait for success message

**Time:** 2 minutes

---

## ✅ Verification (After Running SQL)

### Quick Test 1: Check Policies
Run this in Supabase SQL Editor:
```sql
SELECT tablename, policyname, roles
FROM pg_policies 
WHERE tablename IN ('posts', 'vehicles')
ORDER BY tablename, policyname;
```

**Expected:** All policies should show `{public}` in roles column

### Quick Test 2: Test Guest Access
1. Close your Flutter app
2. Reopen WITHOUT logging in
3. Check if posts appear in feed

**Expected:** Posts visible, no "Empty JWT" errors

### Quick Test 3: Test Authenticated Access
1. Log in with Firebase
2. Create a vehicle
3. Create a post with that vehicle

**Expected:** Both created successfully

---

## 🐛 If It Still Doesn't Work

### Run Diagnostic Script
**File:** `DIAGNOSE_RLS_ISSUES.sql`

Copy and run in Supabase SQL Editor. It will tell you exactly what's wrong.

### Common Issues

**"Empty JWT" error still appears**
→ Restart Flutter app completely

**Posts not showing**
→ Check if posts exist: `SELECT COUNT(*) FROM posts WHERE is_active = true;`

**Cannot create posts**
→ Check if profile exists: `SELECT * FROM profiles WHERE id = 'YOUR_FIREBASE_UID';`

---

## 📞 Need More Help?

Read these files in order:
1. `URGENT_FIX_STEPS.md` - Detailed fix guide
2. `CURRENT_STATUS_AND_NEXT_STEPS.md` - Complete status report
3. `DIAGNOSE_RLS_ISSUES.sql` - Automated diagnostics

---

## 🎯 Success = No More Errors

After the fix:
- ✅ No "Empty JWT" errors
- ✅ Guests can browse posts
- ✅ Logged-in users can create posts
- ✅ Everything just works™
