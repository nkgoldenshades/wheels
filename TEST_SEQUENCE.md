# 🧪 Complete Test Sequence

Follow these steps in exact order to verify your Firebase + Supabase integration.

## Pre-Test Setup (10 minutes)

### ✅ Step 1: Confirm Firebase Provider Config
1. Open Supabase Dashboard: https://uklltpopjovbhplbvltr.supabase.co
2. Go to **Authentication** → **Providers**
3. Scroll to **"Third-party Auth"** section
4. Find **"Firebase"**
5. Verify:
   - [ ] Firebase provider is **ENABLED** (toggle ON)
   - [ ] Project ID = `quickohunt-app` (exactly)
6. If not configured → Enable it and enter Project ID → Save

### ✅ Step 2: Deploy Firebase Cloud Function (CRITICAL!)
This sets the `role: authenticated` custom claim on new users.

**Quick Deploy:**
```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Login
firebase login

# Initialize (if first time)
firebase init functions
# Select: quickohunt-app, JavaScript, No ESLint, Yes install

# Copy function code
# Copy firebase_functions/index.js to functions/index.js
# Copy firebase_functions/package.json to functions/package.json

# Deploy
cd functions
npm install
cd ..
firebase deploy --only functions
```

**Verify:**
- Firebase Console → Functions → See `addRoleClaim` active

**Alternative (Manual for existing users):**
See `FIREBASE_FUNCTION_SETUP.md` Option B

### ✅ Step 3: Run Updated SQL Schema
1. Stay in Supabase Dashboard
2. Go to **SQL Editor**
3. Copy **ALL** content from `FRESH_PROJECT_SCHEMA.sql`
4. Paste into SQL Editor
5. Click **"Run"**
6. Wait for success messages
7. Verify no errors

**Expected output:**
```
✅ QuickOHunt database created successfully!
✅ 8 tables created with proper relationships
✅ All user_id columns are TEXT (Firebase UID compatible)
✅ RLS enabled with secure policies
```

### ✅ Step 3: Verify Schema
1. Go to **Table Editor**
2. Click on **"users"** table
3. Look at column definitions
4. Verify:
   - [ ] `id` column type = `text` (NOT `uuid`)
   - [ ] `email` column exists
   - [ ] `name` column exists

**If `id` shows `uuid`:**
- The SQL didn't run correctly
- Go back to Step 2 and run it again

### ✅ Step 4: Enable Firebase Email Auth
1. Open Firebase Console: https://console.firebase.google.com/
2. Select project: **quickohunt-app**
3. Go to **Authentication** → **Sign-in method**
4. Find **"Email/Password"**
5. Click to enable it
6. Save

---

## Test Execution (10 minutes)

### 🚀 Test 1: Full Signup Flow

#### Run the App
```bash
flutter run
```

#### Perform Signup
1. Navigate to signup screen
2. Enter test credentials:
   - Email: `test@example.com`
   - Password: `password123`
   - Name: `Test User`
3. Click "Sign Up"

#### Watch Console Output
Look for these debug messages in order:

```
🔑 No Firebase user - returning null token (before signup)
🔑 Firebase UID: abc123xyz...
🔑 Access token provided to Supabase: eyJhbGciOiJSUzI1NiIs...
🔄 Syncing Firebase user to Supabase: abc123xyz...
✅ User synced to Supabase: abc123xyz...
```

**If you see all ✅ messages → SUCCESS!**

**Note:** The `accessToken` callback in `main.dart` automatically passes the Firebase JWT on every Supabase request. No need for manual `signInWithIdToken` calls.

#### Verify in Firebase Console
1. Go to Firebase Console → Authentication → Users
2. Check:
   - [ ] New user appears in list
   - [ ] Email = `test@example.com`
   - [ ] UID is a long alphanumeric string (e.g., `abc123xyz...`)

#### Verify in Supabase Dashboard
1. Go to Supabase Dashboard → Table Editor → users
2. Check:
   - [ ] New row appears
   - [ ] `id` = same Firebase UID (TEXT)
   - [ ] `email` = `test@example.com`
   - [ ] `name` = `Test User`

**If row appears in Supabase → INTEGRATION WORKING! 🎉**

---

### 🔍 Test 2: SQL Verification

While app is still running and user is signed in:

1. Go to Supabase Dashboard → SQL Editor
2. Run this query:

```sql
SELECT auth.uid();
```

**Expected result:**
- Returns your Firebase UID as TEXT (e.g., `"abc123xyz..."`)
- NOT a UUID format
- NOT null

3. Run this query:

```sql
SELECT auth.role();
```

**Expected result:**
- Returns `"authenticated"` (from Firebase custom claim)
- NOT `"anon"`

4. Run this query:

```sql
SELECT auth.jwt() ->> 'sub';
```

**Expected result:**
- Same Firebase UID as above
- Confirms JWT is being passed correctly

4. Run this query:

```sql
SELECT * FROM users WHERE id = auth.uid()::text;
```

**Expected result:**
- Returns your user row
- Confirms RLS policy is working

---

### 🔒 Test 3: RLS Policy Verification

#### Test 3.1: User Can Insert Own Data
In Supabase SQL Editor, run:

```sql
-- This should SUCCEED (you're inserting your own vehicle)
INSERT INTO vehicles (user_id, name, type, capabilities)
VALUES (auth.uid()::text, 'Test Car', 'Car', ARRAY['passenger']);
```

**Expected:** Insert succeeds, no error

#### Test 3.2: User Cannot Insert for Others
```sql
-- This should FAIL (trying to insert for fake user)
INSERT INTO vehicles (user_id, name, type, capabilities)
VALUES ('fake_user_id', 'Fake Car', 'Car', ARRAY['passenger']);
```

**Expected:** Error: `new row violates row-level security policy`

#### Test 3.3: User Can Read Own Data
```sql
SELECT * FROM vehicles WHERE user_id = auth.uid()::text;
```

**Expected:** Returns the vehicle you just inserted

#### Test 3.4: User Can View All Marketplace Data
```sql
SELECT * FROM vehicles;
```

**Expected:** Returns all vehicles (marketplace requirement)

---

### 🔄 Test 4: Login Flow

#### Logout
1. In app, click logout button
2. Verify you're back at login screen

#### Login
1. Enter same credentials:
   - Email: `test@example.com`
   - Password: `password123`
2. Click "Sign In"

#### Watch Console Output
```
🔑 Firebase UID: abc123xyz...
🔑 Firebase token (first 20 chars): eyJhbGciOiJSUzI1NiIs...
✅ Supabase session established
✅ Supabase user ID: abc123xyz...
✅ User already exists in Supabase
```

**Expected:** Login succeeds, user data loads

---

## Troubleshooting Guide

### ❌ Issue 1: No Debug Messages Appear

**Symptoms:**
- No `🔑` or `✅` messages in console
- Signup seems to work but nothing happens

**Diagnosis:**
- `_signInToSupabaseWithFirebaseToken()` not being called

**Fix:**
1. Check `lib/services/auth_repository.dart`
2. Verify `syncUserToSupabase()` calls `_signInToSupabaseWithFirebaseToken()`
3. Verify `signUpWithEmail()` calls `syncUserToSupabase()`

---

### ❌ Issue 2: User in Firebase but NOT in Supabase

**Symptoms:**
- User appears in Firebase Console
- No row in Supabase users table
- Console shows: `⚠️ Could not get Firebase ID token`

**Diagnosis:**
- Firebase provider not configured in Supabase
- OR Project ID mismatch

**Fix:**
1. Go to Supabase → Authentication → Providers
2. Verify Firebase is enabled
3. Verify Project ID = `quickohunt-app` (exactly)
4. Save and try again

---

### ❌ Issue 3: Error "operator does not exist: uuid = text"

**Symptoms:**
- Error when trying to insert data
- Console shows type mismatch error

**Diagnosis:**
- `signInWithIdToken()` not called successfully
- Supabase doesn't have valid Firebase session
- `auth.uid()` returning UUID instead of TEXT

**Fix:**
1. Check console for `✅ Supabase session established`
2. If missing → Check Firebase provider config
3. Run SQL: `SELECT auth.uid();` → Should return TEXT, not UUID
4. If returns UUID → Token not being passed

---

### ❌ Issue 4: Error "new row violates row-level security policy"

**Symptoms:**
- Insert fails with RLS error
- Even when inserting own data

**Diagnosis:**
- `auth.uid()` is NULL
- No valid session in Supabase

**Fix:**
1. Verify `signInWithIdToken()` was called
2. Check console for `✅ Supabase session established`
3. Run SQL: `SELECT auth.uid();` → Should NOT be null
4. If null → Firebase provider not configured

---

### ❌ Issue 5: users.id Column Type is UUID

**Symptoms:**
- Table Editor shows `id` type = `uuid`
- Should be `text`

**Diagnosis:**
- Wrong SQL schema was run
- OR old schema still exists

**Fix:**
1. Go to SQL Editor
2. Run: `DROP TABLE IF EXISTS users CASCADE;`
3. Re-run `FRESH_PROJECT_SCHEMA.sql`
4. Verify `id` type = `text`

---

## Success Criteria Checklist

Mark all items to confirm integration is working:

### Firebase
- [ ] User appears in Firebase Console → Authentication
- [ ] UID is alphanumeric string (not UUID format)
- [ ] Email matches test email

### Supabase Database
- [ ] Row appears in users table
- [ ] `id` column = Firebase UID (TEXT)
- [ ] `id` column type = `text` (not `uuid`)
- [ ] Email and name match

### Console Logs
- [ ] `🔑 Firebase UID: ...` appears
- [ ] `🔑 Firebase token (first 20 chars): ...` appears
- [ ] `✅ Supabase session established` appears
- [ ] `✅ User synced to Supabase: ...` appears

### SQL Verification
- [ ] `SELECT auth.uid();` returns Firebase UID as TEXT
- [ ] `SELECT auth.jwt() ->> 'sub';` returns same UID
- [ ] Can insert own vehicle (RLS allows)
- [ ] Cannot insert for fake user (RLS blocks)

### Login/Logout
- [ ] Logout works
- [ ] Login works
- [ ] User data persists

---

## Next Steps After Success

Once all tests pass:

1. **Build Features:**
   - Vehicle management
   - Slot creation
   - Event posting
   - Booking flow

2. **Add Razorpay:**
   - Payment integration
   - Escrow flow
   - Webhook handling

3. **Real-time Features:**
   - Supabase subscriptions
   - Live updates
   - Notifications

4. **Production Prep:**
   - Error handling
   - Loading states
   - Offline support

---

## Time Estimate

- Pre-test setup: 5 minutes
- Test 1 (Signup): 3 minutes
- Test 2 (SQL): 2 minutes
- Test 3 (RLS): 3 minutes
- Test 4 (Login): 2 minutes

**Total: ~15 minutes**

---

## Support

If you encounter issues not covered here:

1. Share the EXACT error message
2. Share console output (all debug messages)
3. Share result of `SELECT auth.uid();` in SQL Editor
4. Confirm Firebase provider is enabled with correct Project ID

**Remember:** The `signInWithIdToken()` call is the critical piece. If that works, everything else falls into place.
