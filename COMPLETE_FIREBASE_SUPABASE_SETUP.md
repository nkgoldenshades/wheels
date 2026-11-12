# 🔥 Complete Firebase Auth + Supabase Database Setup

## Architecture Overview

**Firebase Auth** → Handles authentication (unlimited free emails)
**Supabase Database** → Stores all app data with RLS security
**Firebase UID** → TEXT format (e.g., `"abc123xyz"`)

## Critical Implementation Details

### 1. The Token Flow (MOST IMPORTANT!)

```dart
// After Firebase sign-in/sign-up:
final firebaseToken = await FirebaseAuth.instance.currentUser!.getIdToken();

// Sign in to Supabase with Firebase token
await Supabase.instance.client.auth.signInWithIdToken(
  provider: OAuthProvider.firebase,
  idToken: firebaseToken,
);
```

**Why this matters:**
- Without this, Supabase doesn't know who the Firebase user is
- `auth.uid()` will be NULL or fallback to UUID
- RLS policies will fail with `uuid = text` errors

### 2. The Complete Flow

```
User signs up
    ↓
Firebase creates user (UID = "abc123xyz" TEXT)
    ↓
App gets Firebase ID token
    ↓
App calls signInWithIdToken() → Supabase verifies token
    ↓
Supabase extracts sub claim from JWT
    ↓
auth.uid() now returns "abc123xyz" as TEXT
    ↓
App inserts row into users table with id = "abc123xyz"
    ↓
RLS policies work: auth.uid()::text = user_id (TEXT = TEXT ✅)
```

## Setup Steps

### Step 1: Run SQL Schema (2 minutes)

1. Open Supabase Dashboard → SQL Editor
2. Copy ALL content from `FRESH_PROJECT_SCHEMA.sql`
3. Run it
4. Verify: Table Editor → users → id column type = `text`

**Key features:**
- All `user_id` columns are TEXT
- All RLS policies use `auth.uid()::text` (defensive casting)
- Payments have NO UPDATE policy (webhook only)

### Step 2: Configure Firebase Provider in Supabase (2 minutes)

1. Supabase Dashboard → Authentication → Providers
2. Scroll to "Third-party Auth"
3. Enable "Firebase"
4. Enter Project ID: `quickohunt-app`
5. Save

**What this does:**
- Tells Supabase to accept Firebase JWT tokens
- Allows Supabase to verify Firebase signatures
- Makes `auth.uid()` return Firebase UID as TEXT

### Step 3: Enable Email Auth in Firebase (2 minutes)

1. Firebase Console → Authentication → Sign-in method
2. Enable "Email/Password"
3. Save

### Step 4: Test the Integration (5 minutes)

```bash
flutter run
```

1. Sign up with email/password
2. Check Flutter console for:
   - `✅ Signed in to Supabase with Firebase token`
   - `✅ User synced to Supabase: [uid]`
3. Check Firebase Console → Authentication (user should appear)
4. Check Supabase → Table Editor → users (row should appear)

## Code Implementation (Already Done!)

### auth_repository.dart

```dart
Future<void> _signInToSupabaseWithFirebaseToken() async {
  final firebaseUser = _firebaseAuth.currentUser;
  if (firebaseUser == null) return;

  // Get Firebase ID token
  final idToken = await firebaseUser.getIdToken();
  if (idToken == null) return;

  // CRITICAL: Sign in to Supabase with Firebase token
  await Supabase.instance.client.auth.signInWithIdToken(
    provider: OAuthProvider.firebase,
    idToken: idToken,
  );
}

Future<void> syncUserToSupabase() async {
  // STEP 1: Sign in to Supabase (makes auth.uid() work)
  await _signInToSupabaseWithFirebaseToken();
  
  // STEP 2: Insert user row
  await supabase.from('users').insert({
    'id': firebaseUser.uid,  // TEXT
    'email': firebaseUser.email,
    'name': firebaseUser.displayName ?? 'User',
  });
}
```

### RLS Policies (Defensive Style)

```sql
-- Explicit ::text casting prevents type errors
CREATE POLICY "users_insert_self" ON users 
  FOR INSERT 
  WITH CHECK (auth.uid()::text = id);

CREATE POLICY "vehicles_insert_self" ON vehicles 
  FOR INSERT 
  WITH CHECK (auth.uid()::text = user_id);
```

## Diagnostic Checklist

### ✅ Success Indicators

1. **Firebase Console:**
   - User appears in Authentication → Users
   - UID is a string like `abc123xyz`

2. **Supabase Table Editor:**
   - Row appears in `users` table
   - `id` column = same Firebase UID (TEXT)
   - `id` column type = `text` (not `uuid`)

3. **Flutter Console:**
   ```
   ✅ Signed in to Supabase with Firebase token
   ✅ User synced to Supabase: abc123xyz
   ```

4. **SQL Test:**
   ```sql
   -- Run in Supabase SQL Editor (while logged in via app)
   SELECT auth.uid();
   -- Should return: "abc123xyz" (TEXT, not UUID)
   ```

### ❌ Common Issues

#### Issue 1: `operator does not exist: uuid = text`
**Cause:** `signInWithIdToken()` not called
**Fix:** Check `_signInToSupabaseWithFirebaseToken()` is being called

#### Issue 2: User in Firebase but not Supabase
**Cause:** Firebase provider not configured in Supabase
**Fix:** Step 2 above (enable Firebase provider)

#### Issue 3: `new row violates row-level security policy`
**Cause:** `auth.uid()` is NULL (token not passed)
**Fix:** Verify `signInWithIdToken()` is called before insert

#### Issue 4: `users.id` column type is `uuid`
**Cause:** Wrong schema was run
**Fix:** Run `FRESH_PROJECT_SCHEMA.sql` again

## Security Notes

### What's Protected

✅ Users can only insert/update their own data
✅ Everyone can view marketplace data (vehicles, slots, events)
✅ Bookings visible only to involved parties
✅ Payments cannot be updated from client (webhook only)

### What's NOT Protected (By Design)

- Profile viewing (marketplace requirement)
- Vehicle/slot/event viewing (marketplace requirement)

### Payment Security

```sql
-- NO UPDATE POLICY on payments table
-- Only Edge Functions with service_role key can update
CREATE POLICY "payments_insert_user" ON payments 
  FOR INSERT 
  WITH CHECK (auth.uid()::text = user_id);
-- No UPDATE policy = client cannot modify payment status
```

## Production Checklist

- [ ] SQL schema run successfully
- [ ] `users.id` column type = `text` verified
- [ ] Firebase provider enabled in Supabase
- [ ] Firebase Project ID = `quickohunt-app` configured
- [ ] Email/Password enabled in Firebase Console
- [ ] Test signup works
- [ ] User appears in both Firebase and Supabase
- [ ] Debug logs show token sign-in success
- [ ] RLS policies tested (user can insert own data)
- [ ] RLS policies tested (user cannot insert for others)

## Files Reference

| File | Purpose |
|------|---------|
| `FRESH_PROJECT_SCHEMA.sql` | Production schema with TEXT IDs and ::text casts |
| `lib/services/auth_repository.dart` | Updated with signInWithIdToken() |
| `lib/config/supabase_config.dart` | Supabase credentials |
| `lib/firebase_options.dart` | Firebase platform configs |

## Time Estimate

- SQL schema: 2 minutes
- Firebase provider config: 2 minutes
- Firebase email auth: 2 minutes
- Testing: 5 minutes

**Total: ~11 minutes**

## Next Steps After Setup

Once verified working:
1. Build vehicle/slot/event features
2. Implement booking flow
3. Add Razorpay payment integration
4. Set up payment webhooks (Edge Functions)
5. Add real-time subscriptions

---

**Remember:** The `signInWithIdToken()` call is THE critical piece. Without it, Supabase doesn't know about your Firebase user and everything breaks.
