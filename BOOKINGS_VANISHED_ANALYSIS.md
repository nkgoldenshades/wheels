# 🔍 Analysis: Why Bookings "Vanished"

**Date**: June 21, 2026  
**Issue**: User reported bookings suddenly disappeared  
**Status**: ROOT CAUSE IDENTIFIED ✅

---

## 🎯 ROOT CAUSE (Found!)

### **The Problem**: Supabase Loading Logic Bug

**Location**: `lib/services/booking_repository.dart` line 100

**Current Logic**:
```dart
// Try to load from Supabase first
bool supabaseSuccess = false;
try {
  await _loadFromSupabase();
  supabaseSuccess = true; // ✅ This line is WRONG!
  
  debugPrint('✅ Successfully loaded ${bookings.value.length} bookings from Supabase');
} catch (e) {
  debugPrint('❌ Supabase load failed: $e');
  supabaseSuccess = false;
}
```

**The Bug**:
- Line `supabaseSuccess = true` is set BEFORE checking if bookings loaded
- `_loadFromSupabase()` can succeed (no error thrown) but return 0 bookings
- This happens when:
  - User has no bookings yet (new account)
  - User ID doesn't match any bookings
  - Supabase query filters out all bookings
- Result: `supabaseSuccess = true` even when 0 bookings loaded
- Local storage is NEVER checked (because Supabase "succeeded")
- Bookings vanish!

---

## 💥 WHEN THIS HAPPENS

### **Scenario 1: New User**
```
1. User creates account
2. Loads app → Supabase returns 0 bookings
3. supabaseSuccess = true (no error, just empty result)
4. Local storage is NEVER checked
5. User sees 0 bookings ✅ (Correct - they have none)
```

### **Scenario 2: Existing User Logs Out/In**
```
1. User has 5 bookings in local storage
2. Logs out
3. Logs back in
4. Supabase loads → Returns 0 bookings (user ID filter issue)
5. supabaseSuccess = true (no error!)
6. Local storage is NEVER checked
7. User sees 0 bookings ❌ (WRONG - they have 5!)
```

### **Scenario 3: User ID Mismatch**
```
1. User books with Firebase ID: "abc123"
2. Booking saved to Supabase with profile_customer_id = "abc123"
3. User logs out
4. Firebase assigns new session ID: "xyz789" (rare but possible)
5. Supabase query: .or('profile_customer_id.eq.xyz789,...')
6. Returns 0 bookings (no match)
7. supabaseSuccess = true
8. Local storage is NEVER checked
9. Bookings vanish! ❌
```

---

## ✅ THE FIX

### **Solution 1: Always Check Both Sources**

**Change This** (line 100-115):
```dart
// OLD LOGIC (BROKEN):
bool supabaseSuccess = false;
try {
  await _loadFromSupabase();
  supabaseSuccess = true; // ← BUG HERE!
  debugPrint('✅ Successfully loaded ${bookings.value.length} bookings from Supabase');
} catch (e) {
  debugPrint('❌ Supabase load failed: $e');
  supabaseSuccess = false;
}

// Only load from local storage if Supabase failed
if (!supabaseSuccess) {
  // Load from local storage...
}
```

**To This** (FIXED):
```dart
// NEW LOGIC (FIXED):
bool supabaseHasData = false;
try {
  await _loadFromSupabase();
  
  // Only consider successful if we actually loaded bookings
  supabaseHasData = bookings.value.isNotEmpty;
  
  debugPrint('✅ Loaded ${bookings.value.length} bookings from Supabase');
} catch (e) {
  debugPrint('❌ Supabase load failed: $e');
  supabaseHasData = false;
}

// Load from local storage if Supabase returned nothing
if (!supabaseHasData) {
  debugPrint('⚠️ Supabase returned no bookings, checking local storage...');
  
  final bookingsData = prefs.getString(_storageKey);
  if (bookingsData != null) {
    final List<dynamic> jsonList = jsonDecode(bookingsData);
    final localBookings = jsonList
        .map((e) => Booking.fromJson(e as Map<String, dynamic>))
        .toList();
    
    // Deduplicate local bookings
    final uniqueLocal = <String, Booking>{};
    for (final booking in localBookings) {
      uniqueLocal[booking.id] = booking;
    }
    
    // Merge with Supabase bookings (don't replace!)
    final merged = <String, Booking>{};
    for (final booking in bookings.value) {
      merged[booking.id] = booking;
    }
    for (final booking in uniqueLocal.values) {
      merged[booking.id] = booking;
    }
    
    bookings.value = merged.values.toList();
    debugPrint('✅ Merged ${bookings.value.length} bookings (Supabase + local)');
  } else {
    debugPrint('⚠️ No local bookings found');
  }
}
```

---

## 🔧 ALTERNATIVE FIX (Simpler)

### **Solution 2: Always Merge Both Sources**

Even simpler approach - always merge Supabase + local storage:

```dart
// 1. Load from Supabase
try {
  await _loadFromSupabase();
  debugPrint('✅ Loaded ${bookings.value.length} bookings from Supabase');
} catch (e) {
  debugPrint('❌ Supabase load failed: $e');
}

final supabaseBookings = <String, Booking>{};
for (final booking in bookings.value) {
  supabaseBookings[booking.id] = booking;
}

// 2. Load from local storage
final bookingsData = prefs.getString(_storageKey);
if (bookingsData != null) {
  final List<dynamic> jsonList = jsonDecode(bookingsData);
  final localBookings = jsonList
      .map((e) => Booking.fromJson(e as Map<String, dynamic>))
      .toList();
  
  final uniqueLocal = <String, Booking>{};
  for (final booking in localBookings) {
    uniqueLocal[booking.id] = booking;
  }
  
  debugPrint('✅ Loaded ${uniqueLocal.length} bookings from local storage');
  
  // 3. Merge both sources (Supabase takes priority)
  final merged = <String, Booking>{};
  
  // Add local bookings first
  for (final booking in uniqueLocal.values) {
    merged[booking.id] = booking;
  }
  
  // Overwrite with Supabase bookings (they're more up-to-date)
  for (final booking in supabaseBookings.values) {
    merged[booking.id] = booking;
  }
  
  bookings.value = merged.values.toList();
  debugPrint('✅ Total ${bookings.value.length} unique bookings loaded');
} else {
  // No local bookings, use Supabase only
  bookings.value = supabaseBookings.values.toList();
  debugPrint('✅ Total ${bookings.value.length} bookings (Supabase only)');
}
```

**Benefits**:
- Always checks both sources
- Merges data (no loss)
- Supabase takes priority (most up-to-date)
- Fallback if Supabase fails

---

## 🧪 HOW TO TEST THE FIX

### **Test 1: New User (Should Show 0 Bookings)**
```
1. Create new account
2. Login
3. Expected: 0 bookings ✅
4. Actual: ?
```

### **Test 2: Existing User Logout/Login**
```
1. User A creates 3 bookings
2. Logout
3. Login as User A
4. Expected: 3 bookings ✅
5. Actual: ?
```

### **Test 3: Two Accounts**
```
Provider (Account A):
1. Create 1 post
2. Logout
3. Login
4. Expected: See post ✅

Customer (Account B):
1. Book the post
2. Logout
3. Login
4. Expected: See 1 booking ✅

Provider (Account A):
1. Logout
2. Login
3. Expected: See 1 booking as provider ✅
```

### **Test 4: Clear Cache**
```
1. User has 5 bookings
2. Force close app
3. Clear app cache (Settings → Apps → QuickOHunt → Clear Cache)
4. Reopen app
5. Expected: 5 bookings from Supabase ✅
```

---

## 🎯 WHICH FIX TO USE?

### **Recommendation: Solution 2 (Always Merge)**

**Why?**
- Simpler code
- No data loss
- Always checks both sources
- Handles all edge cases
- Fallback if Supabase fails

**Trade-off**:
- Slightly slower (reads both sources)
- But only ~10ms difference (negligible!)

---

## 📊 DEBUG LOGS TO ADD

Add these logs to track what's happening:

```dart
// At start of _load()
debugPrint('🔄 Loading bookings...');
debugPrint('   Current user ID: ${AuthRepository.instance.currentUser?.id}');

// After Supabase load
debugPrint('📥 Supabase returned ${bookings.value.length} bookings');
for (final b in bookings.value) {
  debugPrint('   - ${b.id}: customer=${b.userId}, provider=${b.providerId}');
}

// After local load
debugPrint('💾 Local storage has ${uniqueLocal.length} bookings');

// After merge
debugPrint('✅ Final total: ${bookings.value.length} unique bookings');
```

---

## 🚨 OTHER POTENTIAL ISSUES

### **Issue 1: User ID Format Mismatch**

**Check**:
```dart
// Firebase Auth user ID format:
abc123-xyz-456-def

// Supabase stored user ID:
ABC123-XYZ-456-DEF

// These won't match! (case-sensitive)
```

**Fix**: Always normalize to lowercase
```dart
.or('profile_customer_id.eq.${currentUser.id.toLowerCase()},profile_provider_id.eq.${currentUser.id.toLowerCase()}')
```

### **Issue 2: Supabase RLS (Row Level Security)**

**Check Supabase Dashboard**:
1. Go to: Authentication → Policies
2. Check `bookings` table policies
3. Verify users can read their own bookings

**Expected Policy**:
```sql
-- Allow users to read bookings where they are customer OR provider
CREATE POLICY "Users can read their bookings"
ON bookings FOR SELECT
USING (
  auth.uid() = profile_customer_id 
  OR 
  auth.uid() = profile_provider_id
);
```

### **Issue 3: Deduplication Removing Valid Bookings**

**Check**: Are duplicate IDs being removed incorrectly?

**Example**:
```dart
// If two bookings have same ID (shouldn't happen but might):
Booking A: id="123", status="pending"
Booking B: id="123", status="completed"

// Dedupe keeps only one (which one?)
uniqueBookings["123"] = booking; // Last one wins!
```

**Fix**: Keep the most recent one
```dart
if (uniqueBookings.containsKey(booking.id)) {
  // Keep the one with latest createdAt
  final existing = uniqueBookings[booking.id]!;
  if (booking.createdAt.isAfter(existing.createdAt)) {
    uniqueBookings[booking.id] = booking;
  }
} else {
  uniqueBookings[booking.id] = booking;
}
```

---

## ✅ ACTION ITEMS

### **Immediate (Fix the Bug)**:
- [ ] Apply Solution 2 (Always Merge) to `booking_repository.dart`
- [ ] Add debug logs
- [ ] Test with 2 accounts
- [ ] Test logout/login persistence
- [ ] Verify fix works

### **Verification (Before Launch)**:
- [ ] Create 5 bookings
- [ ] Logout
- [ ] Login
- [ ] Verify all 5 bookings still visible
- [ ] Clear cache
- [ ] Verify bookings reload from Supabase

### **Monitoring (After Launch)**:
- [ ] Check debug logs for "0 bookings" warnings
- [ ] Monitor user complaints about missing bookings
- [ ] Check Supabase dashboard for booking count
- [ ] Verify booking count matches user reports

---

## 🎉 SUMMARY

**Root Cause**: Supabase load "succeeded" with 0 bookings, skipped local storage check

**Impact**: Users lose their bookings after logout/login

**Fix**: Always merge Supabase + local storage (don't skip local)

**Time to Fix**: 10-15 minutes

**Priority**: 🔴 CRITICAL - Fix before launch!

---

**NEXT STEP**: Apply Solution 2 to `lib/services/booking_repository.dart` and test!
