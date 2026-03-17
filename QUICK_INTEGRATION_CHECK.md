# ⚡ Quick Integration Check (5 minutes)

## Minimal Verification - Fast Pass/Fail

### ✅ Step 1: Sign Up (2 minutes)
```bash
flutter run
```
- Sign up with: `test@example.com` / `password123`
- Watch console for: `✅ User synced to Supabase: [uid]`

**PASS if:** Message appears ✅
**FAIL if:** Error or no message ❌

---

### ✅ Step 2: Check Firebase (30 seconds)
- Firebase Console → Authentication → Users
- Look for: `test@example.com`

**PASS if:** User exists ✅
**FAIL if:** No user ❌

---

### ✅ Step 3: Check Supabase (30 seconds)
- Supabase Dashboard → Table Editor → users
- Look for row with email: `test@example.com`

**PASS if:** Row exists ✅
**FAIL if:** No row ❌

---

### ✅ Step 4: SQL Test (1 minute)
Supabase SQL Editor:
```sql
SELECT auth.uid();
```

**PASS if:** Returns TEXT like `"abc123xyz..."` ✅
**FAIL if:** Returns UUID or NULL ❌

---

### ✅ Step 5: RLS Test (1 minute)
```sql
INSERT INTO vehicles (user_id, name, type, capabilities)
VALUES (auth.uid()::text, 'Test', 'Car', ARRAY['passenger']);
```

**PASS if:** Insert succeeds ✅
**FAIL if:** RLS error ❌

---

## Result

### ✅ ALL PASS = Integration Working!
**You can now:**
- Build app features
- Add more tables
- Implement business logic

### ❌ ANY FAIL = Check Full Guide
See `INTEGRATION_SUCCESS_CHECK.md` for detailed troubleshooting

---

## Quick Fixes

**If Step 3 fails (no row in Supabase):**
- Check Firebase provider enabled
- Check Project ID = `quickohunt-app`

**If Step 4 fails (auth.uid() is UUID):**
- Check `lib/main.dart` has NO `authOptions`

**If Step 5 fails (RLS error):**
- Check `users.id` column type = `text`
- Run `FRESH_PROJECT_SCHEMA.sql` again

---

**Total time: 5 minutes**
