# 🔥 RUNTIME VERIFICATION TEST - CRITICAL

## ✅ What Was Fixed

### Supabase Flutter Version
**Version:** `supabase_flutter: ^2.5.0`

### Correct Implementation (Per Official Docs)
According to [Supabase Firebase Auth docs](https://supabase.com/docs/guides/auth/third-party/firebase-auth), the correct way to pass Firebase JWT is through the `accessToken` callback during client initialization.

**WRONG (what I had before):**
```dart
await Supabase.instance.client.auth.setSession(idToken); // ❌ This is for refresh tokens
```

**CORRECT (implemented now):**
```dart
await Supabase.initialize(
  url: SupabaseConfig.url,
  anonKey: SupabaseConfig.anonKey,
  accessToken: () async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken(false);
  },
);
```

This callback is called automatically by Supabase whenever it needs to make an authenticated request.

---

## 🚨 CRITICAL RUNTIME TEST

### Test 1: Verify Token is Being Passed

Add this test code temporarily in your app after login:

```dart
// After successful login
final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
print('🔥 Firebase User: ${firebaseUser?.uid}');
print('🔥 Firebase Email: ${firebaseUser?.email}');

// Get Firebase token
final idToken = await firebaseUser?.getIdToken(false);
print('🔥 Firebase Token: ${idToken?.substring(0, 50)}...');

// Check if Supabase can access it
try {
  final result = await Supabase.instance.client
    .from('users')
    .select()
    .limit(1);
  print('✅ Supabase query succeeded: $result');
} catch (e) {
  print('❌ Supabase query failed: $e');
}
```

**Expected Output:**
```
🔥 Firebase User: 3fGk92kdlA8sd9sKJd92Klsd
🔥 Firebase Email: test@example.com
🔥 Firebase Token: eyJhbGciOiJSUzI1NiIsImtpZCI6IjdmNGI5ZjBjMmFmNjM...
✅ Supabase query succeeded: []
```

**If you see:**
```
❌ Supabase query failed: JWT expired
```
→ Token is being passed but might be expired (call with `getIdToken(true)`)

**If you see:**
```
❌ Supabase query failed: Row Level Security policy violation
```
→ Token is being passed but RLS policy is blocking (check policies)

**If you see:**
```
❌ Supabase query failed: permission denied
```
→ Token might not be passed correctly

---

### Test 2: Insert User Row

This is the DEFINITIVE test. After signup/login, try to insert the user into the database:

```dart
Future<void> testUserInsert() async {
  final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) {
    print('❌ No Firebase user');
    return;
  }

  print('🔥 Testing user insert for UID: ${firebaseUser.uid}');

  try {
    // Insert user into Supabase
    final result = await Supabase.instance.client
      .from('users')
      .insert({
        'id': firebaseUser.uid,  // TEXT, not UUID
        'email': firebaseUser.email,
        'name': firebaseUser.displayName ?? 'Test User',
      })
      .select();

    print('✅ User insert succeeded: $result');
  } catch (e) {
    print('❌ User insert failed: $e');
  }
}
```

**Expected Output:**
```
🔥 Testing user insert for UID: 3fGk92kdlA8sd9sKJd92Klsd
✅ User insert succeeded: [{id: 3fGk92kdlA8sd9sKJd92Klsd, email: test@example.com, name: Test User, ...}]
```

**If you see:**
```
❌ User insert failed: new row violates row-level security policy for table "users"
```
→ RLS policy is blocking. Check that:
1. Firebase JWT is being passed (Test 1)
2. RLS policy allows insert: `WITH CHECK (auth.uid() = id)`
3. Firebase user has `role: 'authenticated'` custom claim

**If you see:**
```
❌ User insert failed: invalid input syntax for type uuid
```
→ You're using the old schema with UUID instead of TEXT. Run `supabase_schema_fixed.sql`

---

### Test 3: Verify Data Isolation

Create two test users and verify they can't see each other's data:

```dart
Future<void> testDataIsolation() async {
  // User A logs in
  await signInWithEmail(email: 'userA@test.com', password: 'password');
  
  // User A inserts a vehicle
  final userA = firebase_auth.FirebaseAuth.instance.currentUser!;
  await Supabase.instance.client.from('vehicles').insert({
    'user_id': userA.uid,
    'name': 'User A Car',
    'type': 'Car',
    'capabilities': ['passenger'],
  });
  
  // User A queries vehicles
  final vehiclesA = await Supabase.instance.client
    .from('vehicles')
    .select();
  print('User A sees: ${vehiclesA.length} vehicles');
  
  // User A logs out
  await firebase_auth.FirebaseAuth.instance.signOut();
  
  // User B logs in
  await signInWithEmail(email: 'userB@test.com', password: 'password');
  
  // User B queries vehicles
  final vehiclesB = await Supabase.instance.client
    .from('vehicles')
    .select();
  print('User B sees: ${vehiclesB.length} vehicles');
  
  // Expected: User B sees 0 vehicles (only their own)
  if (vehiclesB.length == 0) {
    print('✅ Data isolation working correctly');
  } else {
    print('❌ Data isolation FAILED - User B can see User A\'s data!');
  }
}
```

**Expected Output:**
```
User A sees: 1 vehicles
User B sees: 0 vehicles
✅ Data isolation working correctly
```

**If User B sees User A's vehicles:**
→ RLS is NOT working. Token is not being passed correctly.

---

## 📋 Implementation Checklist

### ✅ Code Changes Made

- [x] Updated `lib/main.dart` to pass `accessToken` callback to Supabase.initialize()
- [x] Removed manual `setSession()` calls from auth_repository (not needed)
- [x] Removed Supabase import from auth_repository (not needed)
- [x] Token is now automatically passed on every Supabase request
- [x] Schema uses TEXT for Firebase UID (not UUID)
- [x] RLS policies use `auth.uid()` for access control

### 🚀 Your Action Items

1. **Run the fixed schema:**
   - Open Supabase SQL Editor
   - Run `supabase_schema_fixed.sql`
   - Verify tables created with TEXT user_id

2. **Configure Firebase in Supabase:**
   - Dashboard → Authentication → Providers
   - Enable "Firebase" provider
   - Add Firebase Project ID: `quickohunt-app`

3. **Enable Email Auth in Firebase:**
   - Firebase Console → Authentication
   - Enable Email/Password sign-in

4. **Add role custom claim (CRITICAL):**
   - All Firebase users need `role: 'authenticated'` custom claim
   - See instructions below

5. **Run Test 1:** Verify token is being passed
6. **Run Test 2:** Insert user row
7. **Run Test 3:** Verify data isolation

---

## 🔐 Firebase Custom Claims (REQUIRED)

Firebase JWTs don't have a `role` claim by default. Supabase needs this to assign the `authenticated` Postgres role.

### Option A: Blocking Functions (Easiest - if you have Identity Platform)

```javascript
// functions/index.js
import { beforeUserCreated, beforeUserSignedIn } from 'firebase-functions/v2/identity'

export const beforecreated = beforeUserCreated((event) => {
  return {
    customClaims: {
      role: 'authenticated',
    },
  }
})

export const beforesignedin = beforeUserSignedIn((event) => {
  return {
    customClaims: {
      role: 'authenticated',
    },
  }
})
```

Deploy: `firebase deploy --only functions`

### Option B: Admin SDK Script (For existing users)

```javascript
// set-role-claim.js
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

initializeApp();

async function setRoleCustomClaim() {
  let nextPageToken = undefined;

  do {
    const listUsersResult = await getAuth().listUsers(1000, nextPageToken);
    nextPageToken = listUsersResult.pageToken;

    await Promise.all(listUsersResult.users.map(async (userRecord) => {
      try {
        await getAuth().setCustomUserClaims(userRecord.uid, {
          role: 'authenticated'
        });
        console.log(`✅ Set role for user: ${userRecord.uid}`);
      } catch (error) {
        console.error(`❌ Failed for user ${userRecord.uid}:`, error);
      }
    }));
  } while (nextPageToken);
}

setRoleCustomClaim().then(() => {
  console.log('✅ All users updated');
  process.exit(0);
});
```

Run: `node set-role-claim.js`

**After setting custom claims, users must sign out and sign in again to get new tokens.**

---

## 🎯 Success Criteria

Your integration is working correctly when:

✅ Test 1 passes: Token is being passed
✅ Test 2 passes: User insert succeeds
✅ Test 3 passes: Data isolation works
✅ No RLS policy violations
✅ Users can only see their own data
✅ Firebase UID stored as TEXT in database

---

## 🐛 Troubleshooting

### "JWT expired"
**Fix:** Call `getIdToken(true)` to force refresh

### "Row Level Security policy violation"
**Fix:** Check that:
1. Token is being passed (Test 1)
2. User has `role: 'authenticated'` custom claim
3. RLS policy is correct: `auth.uid() = user_id`

### "invalid input syntax for type uuid"
**Fix:** Run `supabase_schema_fixed.sql` (uses TEXT, not UUID)

### "permission denied"
**Fix:** Verify `accessToken` callback is in Supabase.initialize()

### Users can see each other's data
**Fix:** RLS is not working. Token not being passed correctly.

---

## 📝 Summary

**Supabase Flutter Version:** `2.5.0`

**Correct Method:** Pass `accessToken` callback to `Supabase.initialize()`

**NOT:** Manual `setSession()` calls (that's for refresh tokens)

**Token Flow:**
1. User logs in with Firebase
2. Supabase needs to make a request
3. Supabase calls `accessToken()` callback
4. Callback returns Firebase JWT
5. Supabase attaches JWT to request
6. Supabase verifies JWT and sets `auth.uid()`
7. RLS policies use `auth.uid()` for access control

**This is automatic. No manual token sync needed.**

---

**NOW RUN THE TESTS AND REPORT RESULTS!**
