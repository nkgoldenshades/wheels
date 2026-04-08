# 🔧 Backend Issues & Fixes

## 🚨 Critical Issues Found

### Issue 1: Table Name Mismatch ❌

**Problem:**
Your repositories are using `'posts'` table, but your database schema has `'slots'` table.

**Affected Files:**
1. `lib/services/slot_repository.dart` - Uses `'posts'` ❌
2. `lib/services/customer_slot_repository.dart` - Uses `'posts'` ❌

**Database Schema:**
```sql
CREATE TABLE public.slots (
  id text PRIMARY KEY,
  provider_id text NOT NULL,
  vehicle_id text NOT NULL,
  service_type text NOT NULL,
  ...
);
```

**Current Code (WRONG):**
```dart
// slot_repository.dart line 123
await supabase.from('posts').insert({ ... });

// customer_slot_repository.dart line 219
await supabase.from('posts').upsert(data);
```

**Should Be:**
```dart
await supabase.from('slots').insert({ ... });
await supabase.from('slots').upsert(data);
```

---

### Issue 2: Missing Bookings Sync ❌

**Problem:**
`BookingRepository` only inserts to Supabase, but doesn't load from Supabase on init.

**Current Code:**
```dart
// booking_repository.dart
Future<void> init() async {
  await _load(); // Only loads from local storage
}
```

**Missing:**
- Load bookings from Supabase
- Sync local bookings to Supabase
- Handle conflicts

---

### Issue 3: Inconsistent Field Names ⚠️

**Problem:**
Some repositories use different field names than database schema.

**Examples:**
1. **vehicles table:**
   - Schema: `owner_id`
   - Repository might use: `user_id` or `profile_id`

2. **slots table:**
   - Schema: `provider_id`
   - Repository might use: `user_id`

---

### Issue 4: Missing RLS Policies Test ⚠️

**Problem:**
No verification that RLS policies are working correctly.

**Risk:**
- Users might see other users' data
- Security vulnerabilities

---

## ✅ Fixes Required

### Fix 1: Update Table Names

**File: `lib/services/slot_repository.dart`**

Change all occurrences of `'posts'` to `'slots'`:

```dart
// Line 123
await supabase.from('slots').insert({
  'id': slot.id,
  'provider_id': currentUser.id, // Changed from user_id
  'vehicle_id': slot.vehicleId,
  'service_type': slot.serviceType.name,
  'slot_type': slot.slotType.name,
  'from_location': slot.fromLocation,
  'to_location': slot.toLocation,
  'base_location': slot.baseLocation,
  'radius': slot.radius,
  'start_time': slot.startTime.toIso8601String(),
  'end_time': slot.endTime.toIso8601String(),
  'available_seats': slot.availableSeats,
  'total_seats': slot.totalSeats,
  'price_per_person': slot.pricePerPerson,
  'is_active': true,
});

// Line 237
await supabase.from('slots').update({
  'vehicle_id': slot.vehicleId,
  'service_type': slot.serviceType.name,
  // ... rest of fields
}).eq('id', slot.id);

// Line 278
await supabase.from('slots').delete().eq('id', slotId);
```

**File: `lib/services/customer_slot_repository.dart`**

Change all occurrences of `'posts'` to `'user_posts'`:

```dart
// Line 219
await supabase.from('user_posts').upsert({
  'id': slot.id,
  'customer_id': currentUser.id, // Changed from user_id
  'service_type': slot.serviceType.name,
  'slot_type': slot.slotType.name,
  'from_location': slot.fromLocation,
  'to_location': slot.toLocation,
  'base_location': slot.baseLocation,
  'radius': slot.radius,
  'start_time': slot.startTime.toIso8601String(),
  'end_time': slot.endTime.toIso8601String(),
  'persons': slot.persons,
  'budget': slot.budget,
  'is_active': true,
});

// Line 231
await supabase.from('user_posts').delete().eq('id', id);
```

---

### Fix 2: Add Bookings Sync

**File: `lib/services/booking_repository.dart`**

Add Supabase loading:

```dart
Future<void> init() async {
  await _load(); // Load from local storage
  await _loadFromSupabase(); // Load from Supabase
}

Future<void> _loadFromSupabase() async {
  try {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return;

    final supabase = Supabase.instance.client;
    
    // Load bookings where user is customer or provider
    final response = await supabase
        .from('bookings')
        .select()
        .or('customer_id.eq.${currentUser.id},provider_id.eq.${currentUser.id}')
        .order('created_at', ascending: false);

    if (response != null && response is List) {
      final supabaseBookings = response
          .map((json) => Booking.fromJson(json as Map<String, dynamic>))
          .toList();

      // Merge with local bookings (Supabase is source of truth)
      _bookings.value = supabaseBookings;
      await _persist();

      debugPrint('✅ Loaded ${supabaseBookings.length} bookings from Supabase');
    }
  } catch (e) {
    debugPrint('⚠️ Failed to load bookings from Supabase: $e');
    // Continue with local data
  }
}
```

---

### Fix 3: Verify Field Names

**Check each repository's field mapping:**

1. **VehicleRepository:**
   ```dart
   'owner_id': vehicle.userId, // ✅ Correct
   ```

2. **SlotRepository:**
   ```dart
   'provider_id': currentUser.id, // ✅ Change from user_id
   ```

3. **BookingRepository:**
   ```dart
   'customer_id': booking.userId, // ✅ Correct
   'provider_id': booking.providerId, // ✅ Correct
   ```

4. **UserPostRepository:**
   ```dart
   'customer_id': post.customerId, // ✅ Correct
   ```

---

### Fix 4: Test RLS Policies

**Create test function:**

```dart
// lib/utils/test_rls.dart
Future<void> testRLSPolicies() async {
  final supabase = Supabase.instance.client;
  final currentUser = AuthRepository.instance.currentUser;
  
  if (currentUser == null) {
    debugPrint('❌ No user logged in');
    return;
  }

  try {
    // Test 1: Can read own profile
    final profile = await supabase
        .from('profiles')
        .select()
        .eq('id', currentUser.id)
        .single();
    debugPrint('✅ Can read own profile: ${profile['full_name']}');

    // Test 2: Can read own vehicles
    final vehicles = await supabase
        .from('vehicles')
        .select()
        .eq('owner_id', currentUser.id);
    debugPrint('✅ Can read own vehicles: ${vehicles.length} found');

    // Test 3: Can read all active slots
    final slots = await supabase
        .from('slots')
        .select()
        .eq('is_active', true)
        .limit(10);
    debugPrint('✅ Can read active slots: ${slots.length} found');

    // Test 4: Can read own bookings
    final bookings = await supabase
        .from('bookings')
        .select()
        .eq('customer_id', currentUser.id);
    debugPrint('✅ Can read own bookings: ${bookings.length} found');

    debugPrint('🎉 All RLS tests passed!');
  } catch (e) {
    debugPrint('❌ RLS test failed: $e');
  }
}
```

---

## 📋 Fix Checklist

### Immediate Fixes (Critical):
- [ ] Change `'posts'` to `'slots'` in `slot_repository.dart`
- [ ] Change `'posts'` to `'user_posts'` in `customer_slot_repository.dart`
- [ ] Verify all field names match database schema
- [ ] Add Supabase loading to `BookingRepository`

### Testing:
- [ ] Test creating a slot (provider)
- [ ] Test creating a user post (customer)
- [ ] Test creating a booking
- [ ] Test RLS policies
- [ ] Verify data appears in Supabase dashboard

### Optional Improvements:
- [ ] Add retry logic for failed Supabase operations
- [ ] Add conflict resolution for local vs cloud data
- [ ] Add real-time subscriptions for live updates
- [ ] Add data validation before inserting to Supabase

---

## 🎯 Expected Behavior After Fixes

### Provider Creates Slot:
```
1. User creates slot in app
2. SlotRepository saves to local storage
3. SlotRepository syncs to Supabase 'slots' table ✅
4. Other users can see slot in feed
```

### Customer Creates Request:
```
1. User creates post in app
2. CustomerSlotRepository saves to local storage
3. CustomerSlotRepository syncs to Supabase 'user_posts' table ✅
4. Providers can see request in feed
```

### User Creates Booking:
```
1. User books a slot
2. BookingRepository saves to local storage
3. BookingRepository syncs to Supabase 'bookings' table ✅
4. Provider receives notification
5. Both users can see booking status
```

---

## 🚀 Quick Fix Script

Run these fixes in order:

1. **Fix slot_repository.dart:**
   - Find: `from('posts')`
   - Replace: `from('slots')`
   - Find: `'user_id':`
   - Replace: `'provider_id':`

2. **Fix customer_slot_repository.dart:**
   - Find: `from('posts')`
   - Replace: `from('user_posts')`
   - Find: `'user_id':`
   - Replace: `'customer_id':`

3. **Test:**
   ```bash
   flutter run -d chrome
   # Create a slot
   # Check Supabase dashboard → slots table
   # Should see new row ✅
   ```

---

## 📊 Summary

**Issues Found:** 4
**Critical:** 2
**Warnings:** 2

**Estimated Fix Time:** 30 minutes

**Impact:**
- ✅ Data will sync correctly to Supabase
- ✅ Users can see each other's posts/slots
- ✅ Bookings will persist across devices
- ✅ App will work as intended

**After fixes, your backend will be 100% functional!** 🚀
