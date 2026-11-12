# Real-Time GPS Tracking Setup Guide

## Current Status

✅ **Map displays vehicle movement along route**  
✅ **Updates every 3 seconds**  
✅ **Shows visual tracking**  
⚠️ **Uses simulated movement by default**  
✅ **Now supports real GPS data from database!**

## How It Works Now

### Automatic Mode Detection

The system now intelligently chooses between real GPS and simulated movement:

```
1. Check if vehicle has deviceLive GPS mode
2. Try to fetch latest GPS from database
3. If successful → Use real GPS coordinates
4. If failed → Fall back to simulated movement
```

### What You See on the Map

**For Live GPS Vehicles:**
- 🟢 Green pulsing marker
- Real coordinates from database
- Updates every 3 seconds
- Actual vehicle position

**For Other Vehicles:**
- 🔵 Blue/Orange/Grey marker
- Simulated movement for demo
- Smooth animation along route
- Good for testing

## Setting Up Real GPS Tracking

### Step 1: Update Vehicle GPS Coordinates

You need a way to update the vehicle's GPS in the database. Here are your options:

#### Option A: Mobile App GPS Tracker (Recommended)

Create a simple GPS tracker app for drivers:

```dart
// Example: Driver GPS Tracker
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverGPSTracker {
  Timer? _timer;
  String? vehicleId;
  
  void startTracking(String vehicleId) {
    this.vehicleId = vehicleId;
    
    _timer = Timer.periodic(Duration(seconds: 5), (timer) async {
      try {
        // Get current location
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        
        // Update database
        await Supabase.instance.client
            .from('vehicles')
            .update({
              'last_known_lat': position.latitude,
              'last_known_lng': position.longitude,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', vehicleId);
            
        print('✅ GPS updated: ${position.latitude}, ${position.longitude}');
      } catch (e) {
        print('❌ GPS update failed: $e');
      }
    });
  }
  
  void stopTracking() {
    _timer?.cancel();
  }
}
```

#### Option B: Backend API Endpoint

Create an API endpoint that drivers can ping with GPS data:

```javascript
// Example: Node.js/Express endpoint
app.post('/api/vehicles/:id/gps', async (req, res) => {
  const { id } = req.params;
  const { latitude, longitude } = req.body;
  
  await supabase
    .from('vehicles')
    .update({
      last_known_lat: latitude,
      last_known_lng: longitude,
      updated_at: new Date().toISOString()
    })
    .eq('id', id);
    
  res.json({ success: true });
});
```

#### Option C: Hardware GPS Device

If you have GPS hardware devices:

1. Configure device to send data to your server
2. Server updates database with coordinates
3. App automatically picks up changes

### Step 2: Set Vehicle GPS Mode

In your app, set the vehicle's GPS mode to `deviceLive`:

```dart
// When creating/editing vehicle
final vehicle = Vehicle(
  // ... other fields
  gpsMode: VehicleGpsMode.deviceLive,
  lastKnownLat: 13.0827,  // Initial position
  lastKnownLng: 80.2707,
);
```

### Step 3: Test the Tracking

1. **Update GPS in database** (manually for testing):
```sql
UPDATE vehicles 
SET last_known_lat = 13.0827, 
    last_known_lng = 80.2707,
    updated_at = NOW()
WHERE id = 'your-vehicle-id';
```

2. **Open the map** in your app
3. **Watch the marker** - it should show the database coordinates
4. **Update GPS again** with different coordinates
5. **Wait 3 seconds** - marker should move to new position

## Database Schema

Ensure your `vehicles` table has these columns:

```sql
CREATE TABLE vehicles (
  id TEXT PRIMARY KEY,
  -- ... other columns
  gps_mode TEXT DEFAULT 'manual',
  last_known_lat DOUBLE PRECISION,
  last_known_lng DOUBLE PRECISION,
  manual_lat DOUBLE PRECISION,
  manual_lng DOUBLE PRECISION,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Add index for faster GPS queries
CREATE INDEX idx_vehicles_gps ON vehicles(last_known_lat, last_known_lng);
```

## Real-Time Updates with Supabase Realtime

For instant updates without polling, use Supabase Realtime:

```dart
// In booking_map_screen.dart
StreamSubscription? _gpsSubscription;

void _subscribeToGPSUpdates(String vehicleId) {
  _gpsSubscription = Supabase.instance.client
      .from('vehicles:id=eq.$vehicleId')
      .stream(primaryKey: ['id'])
      .listen((data) {
        if (data.isEmpty) return;
        
        final lat = data[0]['last_known_lat'] as double?;
        final lng = data[0]['last_known_lng'] as double?;
        
        if (lat != null && lng != null && mounted) {
          setState(() {
            _vehicleLocation = LatLng(lat, lng);
          });
        }
      });
}

@override
void dispose() {
  _gpsSubscription?.cancel();
  super.dispose();
}
```

## Testing Without Real GPS

### Manual Testing
Update GPS coordinates manually in your database:

```sql
-- Simulate vehicle moving from Chennai to Bangalore
-- Update 1: Starting position
UPDATE vehicles SET last_known_lat = 13.0827, last_known_lng = 80.2707 WHERE id = 'test-vehicle';

-- Wait 10 seconds, then Update 2: Midway
UPDATE vehicles SET last_known_lat = 12.9716, last_known_lng = 79.5946 WHERE id = 'test-vehicle';

-- Wait 10 seconds, then Update 3: Destination
UPDATE vehicles SET last_known_lat = 12.9716, last_known_lng = 77.5946 WHERE id = 'test-vehicle';
```

### Automated Testing Script
Create a test script to simulate GPS movement:

```dart
// test_gps_simulator.dart
Future<void> simulateGPSMovement(String vehicleId) async {
  final route = [
    LatLng(13.0827, 80.2707), // Chennai
    LatLng(12.9716, 79.5946), // Midway
    LatLng(12.9716, 77.5946), // Bangalore
  ];
  
  for (final point in route) {
    await Supabase.instance.client
        .from('vehicles')
        .update({
          'last_known_lat': point.latitude,
          'last_known_lng': point.longitude,
        })
        .eq('id', vehicleId);
        
    print('📍 Updated GPS: ${point.latitude}, ${point.longitude}');
    await Future.delayed(Duration(seconds: 10));
  }
}
```

## Troubleshooting

### Vehicle Not Moving on Map

**Check 1: GPS Mode**
```dart
// Verify vehicle has deviceLive mode
print('GPS Mode: ${vehicle.gpsMode}');
// Should print: GPS Mode: VehicleGpsMode.deviceLive
```

**Check 2: Database Values**
```sql
SELECT id, last_known_lat, last_known_lng, updated_at 
FROM vehicles 
WHERE id = 'your-vehicle-id';
```

**Check 3: App Logs**
Look for these messages:
- ✅ `GPS updated: 13.0827, 80.2707` - Success
- ⚠️ `Failed to fetch vehicle GPS: ...` - Error

**Check 4: Network Connection**
Ensure device has internet connection

### Marker Shows Wrong Location

**Issue**: Old cached coordinates
**Solution**: Force refresh by closing and reopening map

**Issue**: Database not updating
**Solution**: Check your GPS update mechanism (app/API/device)

### Updates Too Slow

**Current**: 3-second polling interval
**To Change**: Modify the timer duration:

```dart
// In booking_map_screen.dart
_vehicleUpdateTimer = Timer.periodic(
  const Duration(seconds: 1), // Change from 3 to 1 for faster updates
  (timer) async {
    // ...
  }
);
```

**Warning**: Faster updates = more battery drain and data usage

## Performance Optimization

### Reduce Database Queries
Only fetch GPS when map is visible:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused) {
    _vehicleUpdateTimer?.cancel();
  } else if (state == AppLifecycleState.resumed) {
    _startVehicleUpdates(from, to);
  }
}
```

### Cache Recent Coordinates
Avoid redundant updates:

```dart
LatLng? _lastFetchedLocation;

// In _startVehicleUpdates
if (lat != null && lng != null) {
  final newLocation = LatLng(lat, lng);
  
  // Only update if location changed
  if (_lastFetchedLocation == null || 
      _lastFetchedLocation!.latitude != lat ||
      _lastFetchedLocation!.longitude != lng) {
    setState(() {
      _vehicleLocation = newLocation;
      _lastFetchedLocation = newLocation;
    });
  }
}
```

## Production Checklist

- [ ] GPS tracking app/device configured
- [ ] Database schema includes GPS columns
- [ ] Vehicles have `gpsMode` set to `deviceLive`
- [ ] Initial GPS coordinates populated
- [ ] Update mechanism tested (app/API/device)
- [ ] Map displays real GPS data
- [ ] Fallback to simulated movement works
- [ ] Performance acceptable (battery, data)
- [ ] Error handling in place
- [ ] Monitoring/logging configured

## Summary

**Current Implementation:**
- ✅ Map shows vehicle moving along route
- ✅ Updates every 3 seconds
- ✅ Fetches real GPS from database (if available)
- ✅ Falls back to simulated movement
- ✅ Works for testing and production

**To Get Real GPS:**
1. Set vehicle `gpsMode` to `deviceLive`
2. Update `last_known_lat/lng` in database
3. Use driver app, API, or GPS device
4. Map automatically shows real location

**You're all set! 🎉**
