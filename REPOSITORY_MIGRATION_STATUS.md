# 📊 Repository Migration Status

## Current Status Overview

| Feature | Repository | Storage | Supabase Ready? | Action Needed |
|---------|------------|---------|-----------------|---------------|
| **Users** | `auth_repository.dart` | Supabase ✅ | ✅ Yes | None - Working! |
| **Vehicles** | `vehicle_repository.dart` | Local (SharedPreferences) | ⏳ Table exists | Migrate to Supabase |
| **Slots** | `slot_repository.dart` | Local (SharedPreferences) | ⏳ Table exists | Migrate to Supabase |
| **Events** | `event_repository.dart` | Memory only | ⏳ Table exists | Migrate to Supabase |
| **User Posts** | `user_post_repository.dart` | ✅ Supabase ready | ✅ Yes | Just integrate! |
| **Bookings** | `booking_repository.dart` | Local (SharedPreferences) | ⏳ Table exists | Migrate to Supabase |
| **Payments** | `payment_repository.dart` | Local (SharedPreferences) | ⏳ Table exists | Migrate to Supabase |
| **Passengers** | `passenger_repository.dart` | Local (SharedPreferences) | ⏳ Table exists | Migrate to Supabase |

## What This Means

### ✅ Working with Supabase Now
- **Users** - Already syncing to Supabase
- **User Posts** - Code ready, just needs integration

### ⏳ Need Migration
Everything else is storing data locally:
- **Vehicles** - Lost on app uninstall
- **Events** - Lost on app restart
- **Slots** - Lost on app uninstall
- **Bookings** - Lost on app uninstall
- **Payments** - Lost on app uninstall
- **Passengers** - Lost on app uninstall

### ✅ Good News
All Supabase tables already exist! Just need to update the repository code.

---

## Migration Priority

### Priority 1: Core Features (Do First)
1. **Vehicles** - Users need to create vehicles to offer slots
2. **Slots** - Core marketplace feature
3. **Events** - Core marketplace feature

### Priority 2: Transactions (Do Second)
4. **Bookings** - After vehicles/slots work
5. **Payments** - After bookings work

### Priority 3: Supporting Features (Do Last)
6. **User Posts** - Already done!
7. **Passengers** - Nice to have

---

## How to Migrate Each Repository

### Pattern (Same for All)

**Before (Local Storage):**
```dart
class VehicleRepository {
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('vehicles_data');
    // Parse and load...
  }
  
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vehicles_data', jsonEncode(vehicles));
  }
}
```

**After (Supabase):**
```dart
class VehicleRepository {
  final _supabase = Supabase.instance.client;
  
  Future<void> loadVehicles() async {
    final response = await _supabase
        .from('vehicles')
        .select()
        .eq('user_id', currentUser.id);
    
    vehicles.value = (response as List)
        .map((json) => Vehicle.fromJson(json))
        .toList();
  }
  
  Future<void> addVehicle(Vehicle vehicle) async {
    await _supabase.from('vehicles').insert(vehicle.toJson());
    vehicles.value = [...vehicles.value, vehicle];
  }
}
```

---

## Quick Migration Guide

### Step 1: Update Model (Add toJson/fromJson)

**Example for Vehicle:**
```dart
class Vehicle {
  // ... existing fields
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'type': type,
      'year': year,
      'capabilities': capabilities,
      'photos': photos,
    };
  }
  
  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      type: json['type'],
      year: json['year'],
      capabilities: List<String>.from(json['capabilities'] ?? []),
      photos: List<String>.from(json['photos'] ?? []),
    );
  }
}
```

### Step 2: Update Repository

**Replace SharedPreferences with Supabase:**
```dart
// Remove
import 'package:shared_preferences/shared_preferences.dart';

// Add
import 'package:supabase_flutter/supabase_flutter.dart';

class VehicleRepository {
  final _supabase = Supabase.instance.client;
  
  // Replace _load() with loadVehicles()
  Future<void> loadVehicles() async {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return;
    
    final response = await _supabase
        .from('vehicles')
        .select()
        .eq('user_id', currentUser.id)
        .order('created_at', ascending: false);
    
    _vehicles.clear();
    _vehicles.addAll(
      (response as List).map((json) => Vehicle.fromJson(json))
    );
    _vehiclesNotifier.value = List.from(_vehicles);
  }
  
  // Replace _save() with individual operations
  Future<void> addVehicle(Vehicle vehicle) async {
    await _supabase.from('vehicles').insert(vehicle.toJson());
    _vehicles.add(vehicle);
    _vehiclesNotifier.value = List.from(_vehicles);
  }
  
  Future<void> updateVehicle(Vehicle vehicle) async {
    await _supabase
        .from('vehicles')
        .update(vehicle.toJson())
        .eq('id', vehicle.id);
    
    final index = _vehicles.indexWhere((v) => v.id == vehicle.id);
    if (index != -1) {
      _vehicles[index] = vehicle;
      _vehiclesNotifier.value = List.from(_vehicles);
    }
  }
  
  Future<void> deleteVehicle(String id) async {
    await _supabase.from('vehicles').delete().eq('id', id);
    _vehicles.removeWhere((v) => v.id == id);
    _vehiclesNotifier.value = List.from(_vehicles);
  }
}
```

### Step 3: Test

1. Create vehicle in app
2. Check Supabase Table Editor → `vehicles` table
3. Verify row appears
4. Close and reopen app
5. Verify vehicle still there

---

## Benefits After Migration

### Before (Local Storage)
- ❌ Data lost on app uninstall
- ❌ No sync across devices
- ❌ No backup
- ❌ Limited by device storage
- ❌ No real-time updates

### After (Supabase)
- ✅ Data persists forever
- ✅ Sync across devices
- ✅ Automatic backup
- ✅ Unlimited storage
- ✅ Real-time updates possible
- ✅ Secure with RLS
- ✅ Can query/filter efficiently

---

## Example: Vehicles Migration

I can create a complete Supabase-ready `VehicleRepository` similar to the `UserPostRepository` I created.

**Would you like me to:**
1. Create Supabase-ready `VehicleRepository`
2. Create Supabase-ready `EventRepository`
3. Create Supabase-ready `SlotRepository`
4. Create all three at once

**Time estimate per repository:**
- Create new repository: 10 minutes
- Test and verify: 5 minutes
- **Total: 15 minutes each**

---

## Quick Answer to Your Question

**Q: "Can I create vehicles, events, and posts like I do now?"**

**A: Yes! And they'll all work the same way:**

### Current Flow (After Migration)
1. **Create Vehicle** → Stored in Supabase `vehicles` table
2. **Create Event** → Stored in Supabase `events` table
3. **Create Slot** → Stored in Supabase `slots` table
4. **Create Post** → Stored in Supabase `user_posts` table

### All Features Work Identically
- Same UI
- Same user experience
- Just better persistence
- Automatic sync
- Secure with RLS

### Example User Flow
```
User logs in
  ↓
Creates vehicle → Supabase vehicles table
  ↓
Creates slot for vehicle → Supabase slots table
  ↓
Creates event → Supabase events table
  ↓
Creates user post → Supabase user_posts table
  ↓
All data persists forever ✅
```

---

## Next Steps

### Option 1: Migrate One by One
1. Start with Vehicles (most important)
2. Then Events
3. Then Slots
4. Then Bookings

### Option 2: Migrate All at Once
- I can create all Supabase repositories
- You integrate them one by one
- Test each feature

### Option 3: Use What You Have
- Keep local storage for now
- Migrate when needed
- Focus on other features first

**What would you like to do?**

---

## Summary

✅ **Yes, vehicles, events, slots, and posts all work the same way**
✅ **All Supabase tables already exist**
✅ **Just need to update repository code**
✅ **User Posts repository already done as example**
✅ **Can migrate others using same pattern**

**Ready to migrate? Let me know which repository to start with!** 🚀
