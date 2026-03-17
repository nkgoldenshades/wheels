# ✅ Integration Success Verification

Use this checklist to verify your Firebase + Supabase integration is working correctly.

## Pre-Check: Configuration Status

### Supabase Configuration
- [ ] SQL schema run successfully (`FRESH_PROJECT_SCHEMA.sql`)
- [ ] `users` table exists
- [ ] `users.id` column type = `text` (NOT `uuid`)
- [ ] Firebase provider enabled in Authentication → Providers
- [ ] Firebase Project ID = `quickohunt-app`

### Firebase Configuration
- [ ] Email/Password authentication enabled
- [ ] Project ID = `quickohunt-app`

### Code Configuration
- [ ] `lib/main.dart` has `accessToken` callback
- [ ] `lib/main.dart` does NOT have `authOptions` with `pkce`
- [ ] `lib/services/auth_repository.dart` has token refresh + delay

---

## Test 1: Signup Flow ✅

### Run the App
```bash
flutter run
```

### Perform Signup
1. Go to signup screen
2. Enter:
   - Email: `test1@example.com`
   - Password: `password123`
   - Name: `Test User 1`
3. Click "Sign Up"

### Check Console Output
Look for these messages in order:

```
✅ Expected:
🔑 Firebase UID: [some_uid]
🔑 Access token provided to Supabase: eyJhbGci...
🔄 Syncing Firebase user to Supabase: [some_uid]
🔑 Token refreshed, waiting for accessToken callback...
✅ Ready to sync to Supabase
🔑 Access token provided to Supabase: eyJhbGci...
✅ User synced to Supabase: [some_uid]
```

**Mark as pass if:**
- [ ] All messages appear in correct order
- [ ] No error messages
- [ ] UID is consistent across messages

---

## Test 2: Firebase Verification ✅

### Check Firebase Console
1. Go to: https://console.firebase.google.com/
2. Select project: `quickohunt-app`
3. Go to Authentication → Users

**Verify:**
- [ ] New user appears in list
- [ ] Email = `test1@example.com`
- [ ] UID is alphanumeric string (e.g., `abc123xyz...`)
- [ ] UID format is TEXT, not UUID (no dashes)
- [ ] Provider = "password"

**Copy the UID for next test:** `_________________`

---

## Test 3: Supabase Database Verification ✅

### Check Supabase Table Editor
1. Go to: https://uklltpopjovbhplbvltr.supabase.co
2. Go to Table Editor → `users` table

**Verify:**
- [ ] New row appears
- [ ] `id` = Firebase UID (matches UID from Test 2)
- [ ] `email` = `test1@example.com`
- [ ] `name` = `Test User 1`
- [ ] `created_at` has timestamp
- [ ] `updated_at` has timestamp

**Screenshot recommended for documentation**

---

## Test 4: SQL Auth Context ✅

### While App is Running (User Logged In)

Go to Supabase SQL Editor and run these queries:

#### Query 1: Check auth.uid()
```sql
SELECT auth.uid() AS firebase_uid;
```

**Expected Result:**
- Returns: `"abc123xyz..."` (your Firebase UID as TEXT)
- NOT: `00000000-0000-0000-0000-000000000000` (UUID)
- NOT: `null`

**Verify:**
- [ ] Returns TEXT value
- [ ] Matches Firebase UID from Test 2
- [ ] No dashes in format

#### Query 2: Check auth.role()
```sql
SELECT auth.role() AS user_role;
```

**Expected Result:**
- Returns: `"authenticated"` or `"anon"`
- Both are acceptable for now

**Verify:**
- [ ] Returns a role (not null)

#### Query 3: Check JWT Claims
```sql
SELECT 
  auth.jwt() ->> 'sub' AS firebase_uid_from_jwt,
  auth.jwt() ->> 'email' AS email_from_jwt,
  auth.jwt() ->> 'role' AS role_from_jwt;
```

**Expected Result:**
- `firebase_uid_from_jwt` = Firebase UID (TEXT)
- `email_from_jwt` = `test1@example.com`
- `role_from_jwt` = `"authenticated"` or null

**Verify:**
- [ ] UID matches Firebase UID
- [ ] Email matches test email

#### Query 4: Query Own User Row
```sql
SELECT * FROM users WHERE id = auth.uid()::text;
```

**Expected Result:**
- Returns 1 row (your user)
- All fields populated correctly

**Verify:**
- [ ] Returns exactly 1 row
- [ ] Row data matches signup info

---

## Test 5: RLS Policy Verification ✅

### Test 5.1: Insert Own Vehicle (Should Succeed)
```sql
INSERT INTO vehicles (user_id, name, type, capabilities)
VALUES (auth.uid()::text, 'Test Car', 'Car', ARRAY['passenger'])
RETURNING *;
```

**Expected Result:**
- Insert succeeds
- Returns the inserted row
- `user_id` = your Firebase UID

**Verify:**
- [ ] No error
- [ ] Row inserted successfully
- [ ] `user_id` matches your UID

### Test 5.2: Insert for Fake User (Should Fail)
```sql
INSERT INTO vehicles (user_id, name, type, capabilities)
VALUES ('fake_user_id_12345', 'Fake Car', 'Car', ARRAY['passenger']);
```

**Expected Result:**
- Error: `new row violates row-level security policy for table "vehicles"`

**Verify:**
- [ ] Insert fails with RLS error
- [ ] No row inserted

### Test 5.3: Read All Vehicles (Should Succeed)
```sql
SELECT * FROM vehicles;
```

**Expected Result:**
- Returns all vehicles (marketplace requirement)
- Includes the vehicle you just inserted

**Verify:**
- [ ] Query succeeds
- [ ] Returns at least 1 row (your vehicle)

### Test 5.4: Update Own Vehicle (Should Succeed)
```sql
UPDATE vehicles 
SET name = 'Updated Test Car'
WHERE user_id = auth.uid()::text
RETURNING *;
```

**Expected Result:**
- Update succeeds
- Returns updated row

**Verify:**
- [ ] Update succeeds
- [ ] Name changed to 'Updated Test Car'

### Test 5.5: Update Other User's Vehicle (Should Fail)
```sql
UPDATE vehicles 
SET name = 'Hacked Car'
WHERE user_id = 'fake_user_id_12345';
```

**Expected Result:**
- Update affects 0 rows (RLS blocks it)
- No error, but no rows updated

**Verify:**
- [ ] 0 rows affected
- [ ] No vehicles updated

### Test 5.6: Delete Own Vehicle (Should Succeed)
```sql
DELETE FROM vehicles 
WHERE user_id = auth.uid()::text
RETURNING *;
```

**Expected Result:**
- Delete succeeds
- Returns deleted row

**Verify:**
- [ ] Delete succeeds
- [ ] Vehicle removed

---

## Test 6: Login Flow ✅

### Logout
1. In app, click logout button
2. Verify redirected to login screen

### Login
1. Enter credentials:
   - Email: `test1@example.com`
   - Password: `password123`
2. Click "Sign In"

### Check Console Output
```
✅ Expected:
🔑 Firebase UID: [same_uid_as_before]
🔑 Access token provided to Supabase: eyJhbGci...
🔄 Syncing Firebase user to Supabase: [same_uid]
🔑 Token refreshed, waiting for accessToken callback...
✅ Ready to sync to Supabase
✅ User already exists in Supabase
```

**Verify:**
- [ ] Login succeeds
- [ ] UID matches previous signup
- [ ] "User already exists" message appears
- [ ] No duplicate row created in Supabase

---

## Test 7: Multiple Users ✅

### Create Second User
1. Logout
2. Sign up with:
   - Email: `test2@example.com`
   - Password: `password123`
   - Name: `Test User 2`

### Verify Isolation
1. Go to Supabase Table Editor → `users`
2. Check:
   - [ ] 2 rows exist (test1 and test2)
   - [ ] Each has unique Firebase UID
   - [ ] Each has correct email

### Test Data Isolation
Login as test2, then run:
```sql
-- Should only see test2's data
SELECT * FROM users WHERE id = auth.uid()::text;
```

**Verify:**
- [ ] Returns only test2's row
- [ ] Does NOT return test1's row

---

## Test 8: Type Consistency ✅

### Verify No Type Errors
Run these queries (should all succeed):

```sql
-- Test 1: TEXT = TEXT comparison
SELECT * FROM users WHERE id = auth.uid()::text;

-- Test 2: Foreign key relationship
INSERT INTO vehicles (user_id, name, type, capabilities)
VALUES (auth.uid()::text, 'Type Test Car', 'Car', ARRAY['passenger']);

-- Test 3: Join with TEXT foreign key
SELECT u.name, v.name AS vehicle_name
FROM users u
JOIN vehicles v ON u.id = v.user_id
WHERE u.id = auth.uid()::text;

-- Cleanup
DELETE FROM vehicles WHERE user_id = auth.uid()::text;
```

**Verify:**
- [ ] All queries succeed
- [ ] No "operator does not exist: uuid = text" errors
- [ ] No type mismatch errors

---

## Test 9: Token Refresh ✅

### Test Token Expiry Handling
1. Keep app running for 5 minutes
2. Perform an action (e.g., view profile)
3. Check console for token refresh

**Expected:**
```
🔑 Firebase UID: [uid]
🔑 Access token provided to Supabase: eyJhbGci...
```

**Verify:**
- [ ] Token automatically refreshes
- [ ] No errors
- [ ] Actions continue to work

---

## Test 10: Error Handling ✅

### Test Invalid Credentials
1. Logout
2. Try to login with:
   - Email: `test1@example.com`
   - Password: `wrongpassword`

**Expected:**
- Error message: "Wrong password" or similar
- No crash

**Verify:**
- [ ] Error message displayed
- [ ] App doesn't crash
- [ ] Can try again

### Test Network Error Handling
1. Turn off internet
2. Try to sign up
3. Turn on internet

**Expected:**
- Error message about network
- App recovers when internet returns

**Verify:**
- [ ] Error handled gracefully
- [ ] No crash

---

## Final Success Criteria

### All Tests Must Pass ✅

Mark each section:
- [ ] Test 1: Signup Flow
- [ ] Test 2: Firebase Verification
- [ ] Test 3: Supabase Database Verification
- [ ] Test 4: SQL Auth Context
- [ ] Test 5: RLS Policy Verification (all 6 sub-tests)
- [ ] Test 6: Login Flow
- [ ] Test 7: Multiple Users
- [ ] Test 8: Type Consistency
- [ ] Test 9: Token Refresh
- [ ] Test 10: Error Handling

### Key Metrics

| Metric | Expected | Actual | Pass? |
|--------|----------|--------|-------|
| Users in Firebase | 2 | ___ | [ ] |
| Rows in Supabase users | 2 | ___ | [ ] |
| auth.uid() type | TEXT | ___ | [ ] |
| RLS policies working | Yes | ___ | [ ] |
| Type errors | 0 | ___ | [ ] |
| Console errors | 0 | ___ | [ ] |

---

## Integration Status

### ✅ PASS - Integration Successful
If all tests pass, your integration is production-ready!

**Next steps:**
1. Build app features (vehicles, slots, events, bookings)
2. Add Razorpay payment integration
3. Deploy Cloud Function for role claims (optional)
4. Add real-time subscriptions
5. Implement push notifications

### ❌ FAIL - Issues Found
If any test fails, check:

1. **Console Output** - Look for error messages
2. **Supabase Logs** - Check for RLS violations
3. **Firebase Console** - Verify user exists
4. **Schema** - Verify `users.id` type = `text`
5. **Provider Config** - Verify Firebase provider enabled

**Common issues:**
- Missing Firebase provider config → Test 4 fails
- Wrong schema (UUID) → Test 8 fails
- Missing token delay → Test 3 fails (no row in Supabase)
- authOptions still has pkce → Test 4 fails (auth.uid() returns UUID)

---

## Documentation

### Save These for Reference
1. Screenshot of Firebase Console (users list)
2. Screenshot of Supabase Table Editor (users table)
3. Console output from successful signup
4. Results of SQL queries from Test 4

### Share Results
If reporting success or issues:
- [ ] All test results (pass/fail)
- [ ] Console output
- [ ] Error messages (if any)
- [ ] Screenshots

---

## Production Checklist

Before deploying to production:
- [ ] All tests pass
- [ ] Error handling tested
- [ ] Multiple users tested
- [ ] Token refresh tested
- [ ] RLS policies verified
- [ ] Type consistency verified
- [ ] Deploy Cloud Function for role claims
- [ ] Set up monitoring/logging
- [ ] Test on real devices
- [ ] Load testing completed

---

**Time to complete all tests: ~30 minutes**

**Good luck! 🚀**
