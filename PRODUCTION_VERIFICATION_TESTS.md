# 🔥 PRODUCTION-GRADE VERIFICATION TESTS

## ⚠️ CRITICAL: Run ALL 6 Tests Before Building Features

These tests verify your security foundation is production-ready, not just "working".

---

## ✅ Test 1: Firebase Authentication

```dart
Future<void> test1_FirebaseAuth() async {
  print('\n=== TEST 1: Firebase Authentication ===');
  
  final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
  
  if (firebaseUser == null) {
    print('❌ FAIL: No Firebase user logged in');
    return;
  }

  print('✅ Firebase User ID: ${firebaseUser.uid}');
  print('✅ Firebase Email: ${firebaseUser.email}');
  
  try {
    final token = await firebaseUser.getIdToken(false);
    print('✅ Firebase Token: ${token?.substring(0, 50)}...');
    print('✅ PASS: Firebase authentication working');
  } catch (e) {
    print('❌ FAIL: Cannot get Firebase token: $e');
  }
}
```

**Expected:** ✅ PASS
**If fails:** Firebase not initialized correctly

---

## ✅ Test 2: User Insert (Own Profile)

```dart
Future<void> test2_UserInsert() async {
  print('\n=== TEST 2: User Insert (Own Profile) ===');
  
  final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) {
    print('❌ FAIL: No Firebase user');
    return;
  }

  try {
    final result = await Supabase.instance.client
      .from('users')
      .insert({
        'id': firebaseUser.uid,
        'email': firebaseUser.email,
        'name': firebaseUser.displayName ?? 'Test User',
      })
      .select();
    
    print('✅ PASS: User inserted: $result');
  } catch (e) {
    if (e.toString().contains('duplicate key')) {
      print('✅ PASS: User already exists (expected on re-run)');
    } else {
      print('❌ FAIL: User insert failed: $e');
    }
  }
}
```

**Expected:** ✅ PASS
**If fails:** JWT not being passed or RLS blocking

---

## ✅ Test 3: User Query (Own Profile)

```dart
Future<void> test3_UserQuery() async {
  print('\n=== TEST 3: User Query (Own Profile) ===');
  
  final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) {
    print('❌ FAIL: No Firebase user');
    return;
  }

  try {
    final result = await Supabase.instance.client
      .from('users')
      .select()
      .eq('id', firebaseUser.uid);
    
    if (result.isEmpty) {
      print('❌ FAIL: Cannot query own profile');
    } else {
      print('✅ PASS: Own profile query succeeded: $result');
    }
  } catch (e) {
    print('❌ FAIL: Query failed: $e');
  }
}
```

**Expected:** ✅ PASS
**If fails:** RLS blocking own data access

---

## 🔥 Test 4: Cross-User Isolation (CRITICAL)

```dart
Future<void> test4_CrossUserIsolation() async {
  print('\n=== TEST 4: Cross-User Isolation (CRITICAL) ===');
  
  final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    print('❌ FAIL: No Firebase user');
    return;
  }

  // Get all users (should only see public data, not private)
  try {
    final allUsers = await Supabase.instance.client
      .from('users')
      .select();
    
    print('📊 Can see ${allUsers.length} user profiles (public data)');
    
    // Try to query a specific different user's vehicles
    // First, create a vehicle for current user
    await Supabase.instance.client
      .from('vehicles')
      .insert({
        'user_id': currentUser.uid,
        'name': 'My Test Car',
        'type': 'Car',
        'capabilities': ['passenger'],
      });
    
    // Query all vehicles
    final allVehicles = await Supabase.instance.client
      .from('vehicles')
      .select();
    
    // Check if we only see our own vehicles
    final otherUserVehicles = allVehicles.where(
      (v) => v['user_id'] != currentUser.uid
    ).toList();
    
    if (otherUserVehicles.isEmpty) {
      print('✅ PASS: Can only see own vehicles (RLS working)');
    } else {
      print('❌ FAIL: Can see other users\' vehicles! RLS BROKEN!');
      print('   Other vehicles: $otherUserVehicles');
    }
  } catch (e) {
    print('❌ FAIL: Cross-user test failed: $e');
  }
}
```

**Expected:** ✅ PASS (can only see own vehicles)
**If fails:** RLS is NOT working - CRITICAL SECURITY ISSUE

---

## 🔥 Test 5: Illegal Insert Attempt (CRITICAL)

```dart
Future<void> test5_IllegalInsert() async {
  print('\n=== TEST 5: Illegal Insert Attempt (CRITICAL) ===');
  
  final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    print('❌ FAIL: No Firebase user');
    return;
  }

  // Try to insert a user with a different UID (should fail)
  try {
    await Supabase.instance.client
      .from('users')
      .insert({
        'id': 'fake-uid-12345',  // Different from auth.uid()
        'email': 'hacker@example.com',
        'name': 'Hack Attempt',
      });
    
    print('❌ FAIL: Illegal insert succeeded! RLS BROKEN!');
  } catch (e) {
    if (e.toString().contains('row-level security') || 
        e.toString().contains('policy')) {
      print('✅ PASS: Illegal insert blocked by RLS');
    } else {
      print('⚠️  WARN: Insert failed but not due to RLS: $e');
    }
  }
}
```

**Expected:** ✅ PASS (RLS blocks the insert)
**If fails:** User can insert data for other users - CRITICAL SECURITY ISSUE

---

## 🔥 Test 6: Illegal Update Attempt (CRITICAL)

```dart
Future<void> test6_IllegalUpdate() async {
  print('\n=== TEST 6: Illegal Update Attempt (CRITICAL) ===');
  
  final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    print('❌ FAIL: No Firebase user');
    return;
  }

  // Try to update another user's profile (should fail)
  try {
    await Supabase.instance.client
      .from('users')
      .update({'name': 'Hacked Name'})
      .eq('id', 'some-other-user-uid');  // Different UID
    
    print('❌ FAIL: Illegal update succeeded! RLS BROKEN!');
  } catch (e) {
    if (e.toString().contains('row-level security') || 
        e.toString().contains('policy') ||
        e.toString().contains('0 rows')) {
      print('✅ PASS: Illegal update blocked by RLS');
    } else {
      print('⚠️  WARN: Update failed but not due to RLS: $e');
    }
  }
}
```

**Expected:** ✅ PASS (RLS blocks the update)
**If fails:** User can update other users' data - CRITICAL SECURITY ISSUE

---

## 🎯 Complete Test Suite

```dart
Future<void> runAllProductionTests() async {
  print('\n╔════════════════════════════════════════╗');
  print('║  PRODUCTION VERIFICATION TEST SUITE   ║');
  print('╚════════════════════════════════════════╝');
  
  await test1_FirebaseAuth();
  await test2_UserInsert();
  await test3_UserQuery();
  await test4_CrossUserIsolation();
  await test5_IllegalInsert();
  await test6_IllegalUpdate();
  
  print('\n╔════════════════════════════════════════╗');
  print('║         TEST SUITE COMPLETE            ║');
  print('╚════════════════════════════════════════╝');
  print('\n⚠️  Review results above. ALL tests must PASS.');
  print('⚠️  If any CRITICAL test fails, DO NOT proceed to features.');
}
```

---

## 📊 Expected Results Summary

| Test | Expected | Critical |
|------|----------|----------|
| 1. Firebase Auth | ✅ PASS | Yes |
| 2. User Insert | ✅ PASS | Yes |
| 3. User Query | ✅ PASS | Yes |
| 4. Cross-User Isolation | ✅ PASS | **CRITICAL** |
| 5. Illegal Insert | ✅ PASS (blocked) | **CRITICAL** |
| 6. Illegal Update | ✅ PASS (blocked) | **CRITICAL** |

**ALL 6 MUST PASS before building features.**

---

## 🚨 About "Users can view all profiles" Policy

Your current schema has:
```sql
CREATE POLICY "Users can view all profiles" ON users FOR SELECT USING (true);
```

This means **any logged-in user can see ALL user profiles**.

### Is This Intentional?

**For a ride marketplace:** Probably YES
- Users need to see driver profiles
- Users need to see rider profiles
- Public profile data is expected

**But consider:**
- What data is in the users table?
- Phone numbers? (should be private)
- Email addresses? (should be private)
- Avatar URLs? (can be public)
- Names? (can be public)

### Recommendation:

**Option A: Keep current policy BUT:**
- Only store public data in `users` table
- Store private data (phone, address) in separate `user_private` table
- `user_private` has strict RLS: `USING (auth.uid() = id)`

**Option B: Restrict user profile visibility:**
```sql
-- Only see users you've interacted with
CREATE POLICY "Users can view profiles they interact with" 
ON users 
FOR SELECT 
USING (
  id = auth.uid()  -- Own profile
  OR
  EXISTS (  -- Or users you've booked with
    SELECT 1 FROM bookings 
    WHERE (user_id = auth.uid() AND provider_id = users.id)
       OR (provider_id = auth.uid() AND user_id = users.id)
  )
);
```

**For now:** Keep current policy (view all profiles) since it's a marketplace.
**Later:** Review what data is exposed and add privacy controls.

---

## 🎯 After All Tests Pass

### DO NOT:
- ❌ Redesign auth
- ❌ Switch providers
- ❌ Refactor schema
- ❌ Add more security layers

### DO:
- ✅ Lock auth layer (don't touch it)
- ✅ Move to booking flow immediately
- ✅ Build end-to-end: Create Ride → Book → Confirm → Complete
- ✅ Validate marketplace mechanics work

---

## 📝 Test Execution Checklist

Before running tests:
- [ ] `supabase_schema_fixed.sql` run in Supabase
- [ ] Firebase enabled in Supabase (Authentication → Providers)
- [ ] Email/Password enabled in Firebase Console
- [ ] App running without errors
- [ ] Test user signed up and logged in

Run tests:
- [ ] Test 1: Firebase Auth
- [ ] Test 2: User Insert
- [ ] Test 3: User Query
- [ ] Test 4: Cross-User Isolation
- [ ] Test 5: Illegal Insert
- [ ] Test 6: Illegal Update

After tests:
- [ ] All 6 tests PASS
- [ ] No security warnings
- [ ] Ready to build booking flow

---

## 🚀 Next Step After Verification

**Booking Flow Implementation:**

1. User creates ride post (slot)
2. Another user books the ride
3. Provider confirms booking
4. OTP verification
5. Ride completion

This validates your entire data model and marketplace logic.

**Payment comes AFTER booking flow works.**

---

**NOW: Run the complete test suite and report results.**
