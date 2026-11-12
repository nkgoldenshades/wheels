# QuickOHunt Database Setup Guide

## Overview
This app uses **Firebase Authentication** for user auth and **Supabase** for database storage. The integration passes Firebase JWT tokens to Supabase, making `auth.uid()` return the Firebase UID.

## Prerequisites
- Firebase project already set up ✅
- Supabase project created at: https://uklltpopjovbhplbvltr.supabase.co ✅

## Step 1: Run the SQL Schema

1. Go to your Supabase Dashboard: https://supabase.com/dashboard/project/uklltpopjovbhplbvltr
2. Click on **SQL Editor** in the left sidebar
3. Click **New Query**
4. Copy the entire contents of `supabase_schema.sql`
5. Paste into the SQL editor
6. Click **Run** (or press Ctrl+Enter)

This will create:
- `users` table - User profiles
- `vehicles` table - Vehicle information
- `slots` table - Service posts/slots
- `bookings` table - Booking requests
- `reviews` table - Reviews and ratings
- Row Level Security (RLS) policies
- Triggers for auto-updating timestamps and ratings

## Step 2: Verify Tables Created

In the Supabase Dashboard:
1. Click **Table Editor** in the left sidebar
2. You should see all 5 tables: users, vehicles, slots, bookings, reviews

## Step 3: Test Firebase-Supabase Integration

The integration is already configured in `lib/main.dart`:
```dart
await Supabase.initialize(
  url: SupabaseConfig.url,
  anonKey: SupabaseConfig.anonKey,
  accessToken: () async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    return await user?.getIdToken(false);
  },
);
```

This passes the Firebase JWT to Supabase on every request, making `auth.uid()` return the Firebase UID as TEXT.

## Step 4: Update Repositories to Use Supabase

Currently, your repositories use `SharedPreferences` for local storage. You'll need to update them to use Supabase. Here's the pattern:

### Example: VehicleRepository with Supabase

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class VehicleRepository {
  final _supabase = Supabase.instance.client;
  
  // Load vehicles from Supabase
  Future<void> _loadVehicles() async {
    try {
      final response = await _supabase
          .from('vehicles')
          .select()
          .eq('is_user_vehicle', false) // Provider vehicles only
          .order('created_at', ascending: false);
      
      _vehicles.value = (response as List)
          .map((json) => Vehicle.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to load vehicles: $e');
    }
  }
  
  // Add vehicle to Supabase
  Future<void> addVehicle(Vehicle vehicle) async {
    try {
      await _supabase.from('vehicles').insert(vehicle.toJson());
      _vehicles.value = [vehicle, ..._vehicles.value];
    } catch (e) {
      debugPrint('❌ Failed to create vehicle: $e');
      rethrow;
    }
  }
  
  // Update vehicle in Supabase
  Future<void> updateVehicle(Vehicle vehicle) async {
    try {
      await _supabase
          .from('vehicles')
          .update(vehicle.toJson())
          .eq('id', vehicle.id);
      
      final index = _vehicles.value.indexWhere((v) => v.id == vehicle.id);
      if (index != -1) {
        final updated = List<Vehicle>.from(_vehicles.value);
        updated[index] = vehicle;
        _vehicles.value = updated;
      }
    } catch (e) {
      debugPrint('❌ Failed to update vehicle: $e');
      rethrow;
    }
  }
}
```

## Step 5: Update Model toJson/fromJson Methods

Make sure your models match the database schema. Key points:

### Vehicle Model
- `userId` → `user_id` (snake_case for database)
- `userName` → `user_name`
- `createdAt` → `created_at`
- Arrays: `capabilities`, `galleryImages` → `gallery_images`

### Slot Model
- `vehicleId` → `vehicle_id`
- `serviceType` → `service_type`
- `fromLocation` → `from_location`
- etc.

Example:
```dart
Map<String, dynamic> toJson() {
  return {
    'id': id,
    'user_id': userId,
    'user_name': userName,
    'name': name,
    'type': type,
    'year': year,
    'capabilities': capabilities.map((e) => e.name).toList(),
    'profile_image': profileImage,
    'gallery_images': galleryImages,
    'created_at': createdAt.toIso8601String(),
    // ... rest of fields
  };
}
```

## Step 6: Real-time Subscriptions (Optional)

Enable real-time updates for live data:

```dart
void _subscribeToVehicles() {
  _supabase
      .from('vehicles')
      .stream(primaryKey: ['id'])
      .eq('is_online', true)
      .listen((data) {
        _vehicles.value = data.map((json) => Vehicle.fromJson(json)).toList();
      });
}
```

## Security Notes

1. **Row Level Security (RLS)** is enabled on all tables
2. Users can only modify their own data
3. Everyone can view online vehicles and slots
4. Firebase JWT is validated by Supabase on every request
5. The `auth.uid()` function returns Firebase UID as TEXT

## Testing

1. Sign up a new user in the app
2. Check Supabase Dashboard → Table Editor → users table
3. You should see the user created with Firebase UID
4. Create a vehicle in the app
5. Check vehicles table - should see the vehicle with correct user_id

## Migration Strategy

To migrate from SharedPreferences to Supabase:

1. **Phase 1**: Keep both systems running (write to both)
2. **Phase 2**: Read from Supabase, fallback to SharedPreferences
3. **Phase 3**: Remove SharedPreferences code

Or do a clean migration:
1. Run the SQL schema
2. Update all repositories to use Supabase
3. Test thoroughly
4. Remove SharedPreferences code

## Common Issues

### Issue: "auth.uid() returns null"
**Solution**: Make sure Firebase user is signed in and accessToken callback is working

### Issue: "Row Level Security policy violation"
**Solution**: Check that Firebase UID matches the user_id in the table

### Issue: "Column does not exist"
**Solution**: Make sure your toJson() uses snake_case (user_id, not userId)

## Next Steps

1. ✅ Run `supabase_schema.sql` in Supabase Dashboard
2. ⏳ Update VehicleRepository to use Supabase
3. ⏳ Update SlotRepository to use Supabase
4. ⏳ Update BookingRepository to use Supabase
5. ⏳ Update other repositories
6. ⏳ Test end-to-end flow
7. ⏳ Remove SharedPreferences code

Need help with any step? Let me know!
