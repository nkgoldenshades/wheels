# ⚡ Quick Start - 3 Steps to Test

## 🔥 CRITICAL FIX APPLIED

**Issue:** `AuthFlowType.pkce` was breaking Firebase auth
**Fix:** Removed `authOptions` from `Supabase.initialize()`
**Status:** ✅ Code already fixed in `lib/main.dart`

---

## Step 1: Configure (2 minutes)

### Supabase Dashboard
1. Go to: https://uklltpopjovbhplbvltr.supabase.co
2. **SQL Editor** → Paste `FRESH_PROJECT_SCHEMA.sql` → Run
3. **Authentication** → **Providers** → Enable **Firebase** → Project ID: `quickohunt-app`

### Firebase Console
1. Go to: https://console.firebase.google.com/
2. Select: **quickohunt-app**
3. **Authentication** → **Sign-in method** → Enable **Email/Password**

## Step 2: Verify (1 minute)

### Check Schema
- Supabase → **Table Editor** → **users** table
- Verify: `id` column type = **text** ✅

## Step 3: Test (5 minutes)

### Run App
```bash
flutter run
```

### Sign Up
- Email: `test@example.com`
- Password: `password123`
- Name: `Test User`

### Check Console
Look for:
```
🔑 Firebase UID: abc123xyz...
✅ Supabase session established
✅ User synced to Supabase: abc123xyz...
```

### Verify Success
1. **Firebase Console** → User appears ✅
2. **Supabase Table Editor** → Row in users table ✅

## ✅ Success = User in Both Places

If you see the user in both Firebase and Supabase → **Integration working!**

## 📚 Full Details

- Complete guide: `COMPLETE_FIREBASE_SUPABASE_SETUP.md`
- Test sequence: `TEST_SEQUENCE.md`
- Troubleshooting: `TEST_SEQUENCE.md` (bottom section)

## 🆘 Quick Fixes

**User in Firebase but NOT Supabase?**
→ Check Firebase provider is enabled in Supabase

**Error: "uuid = text"?**
→ Check `users.id` column type = `text`

**Error: "RLS policy violation"?**
→ Check Firebase provider Project ID = `quickohunt-app`

---

**Total time: ~8 minutes**
