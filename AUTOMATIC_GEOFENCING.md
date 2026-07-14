# Automatic Geofencing Feature

## Overview
The app now automatically tracks GPS location and marks arrival when providers or customers reach the start or end locations of a trip.

## How It Works

### 1. **Automatic Monitoring**
- When the app starts, it automatically monitors all **active bookings** (accepted, confirmed, or in-progress)
- Location tracking starts in the background with high accuracy
- Updates every 10 meters to save battery

### 2. **Geofencing Zones**
- **Start Location**: 100 meter radius around pickup point
- **End Location**: 100 meter radius around dropoff point

### 3. **Automatic Arrival Detection**

#### **START Location**
- When provider/customer enters the 100m radius of pickup location
- GPS coordinates are **automatically captured** and saved
- No manual action required - happens in background
- Marks arrival timestamp automatically

#### **END Location**  
- Only monitored after START arrival is marked
- When provider/customer enters the 100m radius of dropoff location
- GPS coordinates are **automatically captured** and saved
- Automatically stops monitoring after END is reached

### 4. **Data Captured Automatically**
For each arrival (start/end), the system captures:
- ✅ GPS latitude and longitude
- ✅ Timestamp of arrival
- ✅ Stored in `trip_media` JSON structure
- ✅ Synced to Supabase database automatically

## Technical Details

### Files Created/Modified

1. **`lib/services/geofencing_service.dart`** (NEW)
   - Background location monitoring service
   - Automatic arrival detection
   - GPS capture and database updates

2. **`lib/main.dart`** (MODIFIED)
   - Imports geofencing service
   - Initializes service on app startup
   - Monitors active bookings automatically

### Database Structure
GPS data is stored in the existing `trip_media` JSON column:

```json
{
  "start": {
    "provider": {
      "gps_lat": 12.9716,
      "gps_lng": 77.5946,
      "gps_timestamp": "2026-06-19T10:30:00Z",
      "images": [...],
      "video_url": "..."
    },
    "customer": {
      "gps_lat": 12.9716,
      "gps_lng": 77.5946,
      "gps_timestamp": "2026-06-19T10:30:00Z",
      "images": [...],
      "video_url": "..."
    }
  },
  "end": { /* same structure */ }
}
```

## Permissions Required

### Android
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

### iOS
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to verify pickup and dropoff</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>We track your location in the background to automatically mark arrival</string>
```

## Benefits

### For Users
- ✅ **No manual action needed** - arrivals detected automatically
- ✅ **Hands-free operation** - focus on driving/riding
- ✅ **Proof of location** - GPS verification for disputes
- ✅ **Accurate timing** - exact arrival timestamps

### For Platform
- ✅ **Fraud prevention** - GPS verification of actual pickup/dropoff
- ✅ **Trust building** - both parties verified automatically
- ✅ **Dispute resolution** - GPS proof of location
- ✅ **Better UX** - seamless experience

## Battery Optimization

The geofencing service is optimized for battery life:
- Only monitors **active bookings**
- Stops monitoring once END is reached
- Uses **10 meter distance filter** (updates only when moved 10m)
- Stops completely when no active bookings

## How to Use

### As Provider/Customer
1. Accept/confirm a booking
2. **That's it!** The app automatically:
   - Monitors your location in background
   - Detects when you reach pickup point
   - Captures GPS coordinates
   - Detects when you reach dropoff point
   - Captures GPS coordinates
   - Stops monitoring

### Manual Override
Users can still manually submit photos through the trip media widget if needed.

## Testing

To test the feature:
1. Create a booking with GPS coordinates
2. Accept/confirm the booking
3. Physically move to within 100m of the pickup location
4. Check the booking - GPS should be captured automatically
5. Move to dropoff location
6. GPS should be captured automatically

## Future Enhancements

Possible improvements:
- [ ] Show notification when arrival is detected
- [ ] Show real-time distance to pickup/dropoff
- [ ] Adjust geofence radius based on location accuracy
- [ ] Add route tracking between start and end
- [ ] Send location updates to other party in real-time
- [ ] Add geofence arrival sounds/vibrations

## Troubleshooting

### Location not detected?
- Check location permissions are granted
- Ensure GPS is enabled on device
- Check if location services are turned on
- Move to within 100 meters of the location

### Battery drain?
- Service only runs for active bookings
- Automatically stops after trip ends
- Uses distance filter to minimize updates

### Data not saved?
- Check internet connection
- Verify Supabase permissions (RLS policies)
- Check console logs for errors
