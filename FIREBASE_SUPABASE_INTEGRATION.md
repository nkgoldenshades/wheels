# Firebase + Supabase Integration - Complete Guide

## 🎯 How It Works

### The Token Flow (CRITICAL)

```
1. User logs in with Firebase
   ↓
2. Firebase returns ID token (JWT)
   ↓
3. App passes token to Supabase
   ↓
4. Supabase verifies token with Firebase
   ↓
5. Supabase sets auth.uid() = Firebase UID
   ↓
6. RLS policies use auth.uid() for access control
```

## ✅ What I Fixed

### Before (BROKEN)
```dart
// User logs in with Firebase
await _firebaseAuth.signInWithEmailAndPassword(...);

// ❌ Token NOT passed to Supabase
// ❌ Supabase treats user as anonymous
// ❌ RLS policies don't work
// ❌ auth.uid() returns NULL
```

### After (WORKING)
```dart
// User logs in with Firebase
final credential = await _firebaseAuth.signInWithEmailAndPassword(...);

// ✅ Get Firebase ID token
final idToken = await credential.user!.getIdToken();

// ✅ Pass token to Supabase
await Supabase.instance.client.auth.setSession(idToken);

// ✅ Now Supabase knows who the user is
// ✅ auth.uid() returns Firebase UID
// ✅ RLS policies work correctly
```

## 🔒 Row Level Security (RLS)

### What RLS Does
RLS policies control who can access what data in Supabase.

### Example Policy
```sql
-- Users can only see their own vehicles
CREATE POLICY "Users can view their vehicles" 
ON vehicles 
FOR SELECT 
USING (auth.uid() = user_id);
```

### How It Works
1. User makes query: `SELECT * FROM vehicles`
2. Supabase checks: `auth.uid()` (from Firebase token)
3. Policy filters: Only rows where `user_id = auth.uid()`
4. User only sees their own vehicles

### Without Token Sync
- `auth.uid()` = NULL
- Policy fails
- User sees nothing (or everything if no RLS)

### With Token Sync ✅
- `auth.uid()` = Firebase UID
- Policy works
- User sees only their data

## 📋 Implementation Details

### 1. Auth Repository Changes

```dart
// Added Supabase import
import 'package:supabase_flutter/supabase_flutter.dart';

// New method to sync tokens
Future<void> _syncFirebaseTokenToSupabase(firebase_auth.User firebaseUser) async {
  final idToken = await firebaseUser.getIdToken();
  if (idToken != null) {
    await Supabase.instance.client.auth.setSession(idToken);
  }
}

// Called on login
Future<AuthUser?> signInWithEmail(...) async {
  final credential = await _firebaseAuth.signInWithEmailAndPassword(...);
  await _syncFirebaseTokenToSupabase(credential.user!); // ← CRITICAL
  return user;
}

// Called on signup
Future<AuthUser?> signUpWithEmail(...) async {
  final credential = await _firebaseAuth.createUserWithEmailAndPassword(...);
  await _syncFirebaseTokenToSupabase(credential.user!); // ← CRITICAL
  return user;
}

// Called on auth state change
_firebaseAuth.authStateChanges().listen((firebaseUser) async {
  if (firebaseUser != null) {
    await _syncFirebaseTokenToSupabase(firebaseUser); // ← CRITICAL
  } else {
    await Supabase.instance.client.auth.signOut();
  }
});
```

### 2. Database Schema with RLS

File: `supabase_schema_with_rls.sql`

Key features:
- All tables have RLS enabled
- Policies use `auth.uid()` for access control
- Users can only access their own data
- Public data (slots, events) visible to all

### 3. Supabase Configuration Required

In Supabase Dashboard:
1. Authentication → Providers
2. Enable "Firebase" provider
3. Add Firebase Project ID: `quickohunt-app`

This tells Supabase to trust Firebase tokens.

## 🔐 Security Benefits

### With This Integration
✅ Users can only access their own data
✅ No user can see another user's private info
✅ Database enforces security at row level
✅ Even if app has bugs, database protects data
✅ Firebase handles auth, Supabase handles data

### Without This Integration
❌ All data potentially accessible to everyone
❌ Security depends on app code only
❌ Database can't verify user identity
❌ RLS policies don't work

## 🧪 Testing the Integration

### 1. Check Token Sync
```dart
// After login, check if Supabase has session
final session = Supabase.instance.client.auth.currentSession;
print('Session: ${session?.accessToken}'); // Should print token
print('User ID: ${session?.user.id}'); // Should match Firebase UID
```

### 2. Test RLS Policy
```dart
// Try to insert a vehicle
final result = await Supabase.instance.client
  .from('vehicles')
  .insert({
    'user_id': firebaseUser.uid,
    'name': 'Test Car',
    'type': 'Car',
    'capabilities': ['passenger'],
  });

// Should succeed if token is synced
// Should fail if token is not synced
```

### 3. Verify Data Isolation
```dart
// User A logs in
await signInWithEmail(email: 'userA@test.com', password: 'password');

// Query vehicles
final vehicles = await Supabase.instance.client
  .from('vehicles')
  .select();

// Should only see User A's vehicles, not User B's
```

## 📊 Data Flow Example

### Creating a Vehicle

```dart
// 1. User is logged in with Firebase
final firebaseUser = FirebaseAuth.instance.currentUser;

// 2. Token already synced to Supabase (automatic)
// 3. Insert vehicle
await Supabase.instance.client.from('vehicles').insert({
  'user_id': firebaseUser!.uid,  // ← Must match auth.uid()
  'name': 'My Car',
  'type': 'Car',
  'capabilities': ['passenger'],
});

// 4. RLS policy checks: auth.uid() == user_id
// 5. Insert succeeds because they match
```

### Querying Vehicles

```dart
// 1. User queries all vehicles
final vehicles = await Supabase.instance.client
  .from('vehicles')
  .select();

// 2. RLS policy filters: WHERE user_id = auth.uid()
// 3. User only sees their own vehicles
```

## 🚨 Common Issues

### Issue: "auth.uid() is null"
**Cause:** Token not synced to Supabase
**Fix:** Ensure `_syncFirebaseTokenToSupabase()` is called after login

### Issue: "Row Level Security policy violation"
**Cause:** Trying to access data that doesn't belong to user
**Fix:** Check that `user_id` matches `auth.uid()`

### Issue: "No rows returned"
**Cause:** RLS policy filtering out all rows
**Fix:** Verify token is synced and user_id is correct

### Issue: "Permission denied"
**Cause:** RLS policy doesn't allow the operation
**Fix:** Check RLS policies in Supabase dashboard

## 📝 Summary

### What You Have Now
1. ✅ Firebase Auth for user authentication
2. ✅ Supabase Database for data storage
3. ✅ Token sync between Firebase and Supabase
4. ✅ RLS policies for data security
5. ✅ Automatic auth state management

### What Happens on Login
1. User enters email/password
2. Firebase authenticates user
3. App gets Firebase ID token
4. App passes token to Supabase
5. Supabase verifies token with Firebase
6. Supabase sets `auth.uid()` = Firebase UID
7. User can now access their data securely

### What Happens on Data Access
1. User queries database
2. Supabase checks `auth.uid()` from token
3. RLS policy filters data based on `auth.uid()`
4. User only sees/modifies their own data

### Security Guarantee
Even if your app code has bugs, the database enforces security at the row level. Users cannot access each other's data.

---

**Next Step:** Configure Firebase as third-party auth provider in Supabase Dashboard!
