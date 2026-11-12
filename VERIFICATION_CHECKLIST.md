# ✅ Verification Checklist

Use this checklist to verify your setup is correct.

## Phase 1: Database Schema

### Step 1: Run STEP1_COMPLETE_WIPE.sql
- [ ] Opened Supabase Dashboard → SQL Editor
- [ ] Copied ALL content from `STEP1_COMPLETE_WIPE.sql`
- [ ] Pasted into SQL Editor
- [ ] Clicked "Run"
- [ ] Saw success message: "Public schema completely wiped"

### Step 2: Run STEP2_CLEAN_SCHEMA.sql
- [ ] Stayed in Supabase SQL Editor
- [ ] Copied ALL content from `STEP2_CLEAN_SCHEMA.sql`
- [ ] Pasted into SQL Editor
- [ ] Clicked "Run"
- [ ] Saw success message: "QuickOHunt database created successfully"

### Step 3: Verify Column Types
- [ ] Opened Supabase → Table Editor
- [ ] Clicked on `users` table
- [ ] Checked `id` column definition
- [ ] Confirmed type = `text` (NOT `uuid`)

**If type shows `uuid`, STOP and run STEP1 again.**

## Phase 2: Authentication Configuration

### Step 4: Configure Firebase Provider in Supabase
- [ ] Opened Supabase Dashboard → Authentication → Providers
- [ ] Scrolled to "Third-party Auth" section
- [ ] Found "Firebase" provider
- [ ] Enabled Firebase provider
- [ ] Entered Firebase Project ID: `quickohunt-app`
- [ ] Clicked Save

### Step 5: Enable Email Auth in Firebase
- [ ] Opened Firebase Console
- [ ] Selected project: `quickohunt-app`
- [ ] Went to Authentication → Sign-in method
- [ ] Enabled "Email/Password" provider
- [ ] Saved changes

## Phase 3: Runtime Testing

### Step 6: Test User Signup
- [ ] Ran `flutter run` in terminal
- [ ] App launched successfully
- [ ] Navigated to signup screen
- [ ] Entered test email: `test@example.com`
- [ ] Entered test password: `password123`
- [ ] Entered test name: `Test User`
- [ ] Clicked "Sign Up"
- [ ] No errors in Flutter console

### Step 7: Verify Firebase User
- [ ] Opened Firebase Console → Authentication
- [ ] Saw new user in list
- [ ] User email matches: `test@example.com`
- [ ] User has Firebase UID (e.g., `abc123xyz`)

### Step 8: Verify Supabase User
- [ ] Opened Supabase → Table Editor → `users`
- [ ] Saw new row in table
- [ ] Row `id` matches Firebase UID
- [ ] Row `email` matches: `test@example.com`
- [ ] Row `name` matches: `Test User`

### Step 9: Check Debug Logs
- [ ] Checked Flutter console output
- [ ] Saw message: `✅ User synced to Supabase: [uid]`
- [ ] No error messages about RLS or uuid=text

## Phase 4: Security Verification

### Step 10: Test RLS Policies
Run these tests in Supabase SQL Editor:

#### Test 1: User can read their own profile
```sql
-- Set auth context (replace with your Firebase UID)
SELECT set_config('request.jwt.claims', '{"sub":"YOUR_FIREBASE_UID"}', true);

-- Should return your user row
SELECT * FROM users WHERE id = 'YOUR_FIREBASE_UID';
```
- [ ] Query returned 1 row
- [ ] Row matches your user data

#### Test 2: User cannot read other profiles (should fail)
```sql
-- Try to read all users (should only see your own)
SELECT * FROM users;
```
- [ ] Query returned only 1 row (your own)
- [ ] Did NOT return all users

#### Test 3: User can insert vehicle
```sql
-- Should succeed
INSERT INTO vehicles (user_id, name, type, capabilities)
VALUES ('YOUR_FIREBASE_UID', 'Test Car', 'Car', ARRAY['passenger']);
```
- [ ] Insert succeeded
- [ ] No RLS policy violation error

#### Test 4: User cannot insert vehicle for another user
```sql
-- Should fail with RLS policy violation
INSERT INTO vehicles (user_id, name, type, capabilities)
VALUES ('fake_user_id', 'Fake Car', 'Car', ARRAY['passenger']);
```
- [ ] Insert failed
- [ ] Error message: "new row violates row-level security policy"

## Phase 5: Integration Verification

### Step 11: Test Complete Flow
- [ ] Logged out of app
- [ ] Signed up with new email
- [ ] User appeared in Firebase
- [ ] User appeared in Supabase
- [ ] Logged out
- [ ] Logged in with same email
- [ ] Login succeeded
- [ ] User data loaded correctly

### Step 12: Test Data Operations
- [ ] Created a vehicle in app
- [ ] Vehicle appeared in Supabase `vehicles` table
- [ ] Created a slot in app
- [ ] Slot appeared in Supabase `slots` table
- [ ] Created an event in app
- [ ] Event appeared in Supabase `events` table

## Success Criteria

### ✅ All checks passed if:
1. `users.id` column type = `text`
2. Firebase provider enabled in Supabase
3. User signup works without errors
4. User appears in both Firebase and Supabase
5. Debug log shows: "User synced to Supabase"
6. RLS policies allow own data, block other users
7. No `uuid = text` errors anywhere

### ❌ Something is wrong if:
1. `users.id` column type = `uuid` → Run STEP1 again
2. Error: "operator does not exist: uuid = text" → Run STEP1 again
3. Error: "new row violates row-level security policy" → Check Firebase provider
4. User in Firebase but not Supabase → Check Firebase provider
5. No debug log "User synced to Supabase" → Check `syncUserToSupabase()` method

## Troubleshooting

### Issue: users.id still shows uuid
**Solution:** 
1. Run STEP1_COMPLETE_WIPE.sql again
2. Make sure you copied the ENTIRE script
3. Wait for success message
4. Then run STEP2_CLEAN_SCHEMA.sql

### Issue: User not appearing in Supabase
**Solution:**
1. Check Firebase provider is enabled in Supabase
2. Check Firebase Project ID is correct: `quickohunt-app`
3. Check Flutter console for errors
4. Check `syncUserToSupabase()` is being called

### Issue: RLS policy violation
**Solution:**
1. Verify Firebase provider is enabled
2. Verify Firebase Project ID matches
3. Check `accessToken` callback in `main.dart`
4. Restart app to refresh token

## Final Confirmation

After completing ALL steps above:

- [ ] Database schema is correct (TEXT for Firebase UID)
- [ ] Firebase authentication is configured
- [ ] Supabase Firebase provider is enabled
- [ ] User signup/login works
- [ ] User data syncs to Supabase
- [ ] RLS policies enforce security
- [ ] No errors in console
- [ ] Ready to build features

**If all boxes are checked: ✅ Setup is complete and working!**

**If any box is unchecked: ⚠️ Review that section and fix the issue.**

---

## Next Steps After Verification

Once all checks pass, you can:
1. Start building features
2. Add more vehicles/slots/events
3. Test booking flow
4. Integrate Razorpay payments
5. Add real-time subscriptions
6. Deploy to production

## Time to Complete

- Phase 1: 3 minutes
- Phase 2: 4 minutes
- Phase 3: 5 minutes
- Phase 4: 3 minutes
- Phase 5: 5 minutes

**Total: ~20 minutes**

---

**Remember:** Don't skip verification steps. Each one confirms a critical part of the integration is working correctly.
