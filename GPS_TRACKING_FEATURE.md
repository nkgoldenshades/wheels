# GPS Tracking Feature

## Overview
The booking map now displays real-time vehicle GPS location with visual indicators showing the tracking status.

## Features Added

### 1. Vehicle GPS Marker
- **Live GPS (Green)**: Vehicle with active GPS tracking
  - Shows pulsing green circle with GPS icon
  - Updates every 3 seconds
  - Uses `lastKnownLat` and `lastKnownLng` from vehicle data

- **External Link (Orange)**: Vehicle with external GPS tracker
  - Shows orange circle with link icon
  - Can be clicked to open external tracking URL

- **Manual Location (Grey)**: Manually set vehicle location
  - Shows grey circle with location pin
  - Uses `manualLat` and `manualLng` from vehicle data

### 2. GPS Status Badge
At the top of the map, a colored badge shows:
- Current GPS tracking mode
- Visual indicator (icon + color)
- Status text

### 3. Map Legend
At the bottom of the map:
- **Green circle**: Start location
- **Red circle**: End location  
- **Blue/Green/Orange circle**: Vehicle (color based on GPS mode)
- **Orange circle**: Your current location

### 4. Route Visualization
- Blue polyline showing the planned route
- Distance calculation between start and end points
- Automatic camera fitting to show all markers

## How It Works

### Data Flow
1. **Vehicle GPS Data** → Retrieved from `Vehicle` model
2. **GPS Mode Check** → Determines tracking type (deviceLive, externalLink, manual)
3. **Location Update** → Uses actual GPS coordinates or fallback to route start
4. **Live Updates** → Timer updates vehicle position every 3 seconds (for live GPS)

### Vehicle Model Fields Used
```dart
final VehicleGpsMode gpsMode;        // deviceLive, externalLink, or manual
final String? gpsExternalLink;       // URL for external tracker
final double? manualLat;             // Manually set latitude
final double? manualLng;             // Manually set longitude
final double? lastKnownLat;          // Last known GPS latitude
final double? lastKnownLng;          // Last known GPS longitude
```

## Usage

### For Customers
When viewing a booking:
1. Tap the map icon on the booking card
2. See the vehicle's current location with GPS status
3. View the planned route and distance
4. Track vehicle movement in real-time (if live GPS enabled)

### For Providers
When managing bookings:
1. View customer location (if shared)
2. See your vehicle's GPS status
3. Monitor route and distance
4. Verify GPS tracking is active

## GPS Modes Explained

### Device Live GPS
- **Best for**: Active trips with real-time tracking
- **Requires**: GPS-enabled device in vehicle
- **Updates**: Every 3 seconds
- **Accuracy**: High (depends on GPS signal)

### External Link
- **Best for**: Vehicles with third-party GPS trackers
- **Requires**: External GPS service URL
- **Updates**: Via external service
- **Accuracy**: Depends on external service

### Manual Location
- **Best for**: Static locations or testing
- **Requires**: Manual coordinate entry
- **Updates**: Only when manually updated
- **Accuracy**: As accurate as manual entry

## Technical Details

### Location Resolution
The system tries to get vehicle location in this order:
1. `lastKnownLat/Lng` (most recent GPS data)
2. `manualLat/Lng` (manually set location)
3. Route start location (fallback)

### Map Features
- **OpenStreetMap tiles** for base map
- **Flutter Map** for rendering
- **Geodesy** for distance calculations
- **Auto-fit camera** to show all markers
- **Responsive legend** adapts to available markers

### Performance
- Efficient marker updates (only when location changes)
- Debounced camera movements
- Lightweight polyline rendering
- Minimal memory footprint

## Future Enhancements

### Planned Features
- [ ] Historical route playback
- [ ] Speed and ETA calculations
- [ ] Traffic overlay
- [ ] Multiple vehicle tracking
- [ ] Geofencing alerts
- [ ] Offline map caching

### Integration Ideas
- Push notifications for location updates
- Share live location link with customers
- Driver navigation integration
- Route optimization suggestions

## Testing

### Test Scenarios
1. **Live GPS**: Create booking with vehicle that has GPS enabled
2. **Manual Location**: Set manual coordinates and verify marker placement
3. **No GPS**: Test fallback to route start location
4. **Multiple Markers**: Verify all markers (start, end, vehicle, user) display correctly
5. **Camera Fit**: Ensure map zooms to show all markers

### Debug Mode
Enable debug logging to see:
- GPS mode detection
- Location resolution order
- Update frequency
- Marker placement coordinates

## Troubleshooting

### Vehicle Not Showing
- Check if vehicle has GPS coordinates set
- Verify `lastKnownLat/Lng` or `manualLat/Lng` are not null
- Ensure vehicle is associated with the booking

### GPS Not Updating
- Confirm `gpsMode` is set to `deviceLive`
- Check if timer is running (3-second interval)
- Verify GPS permissions are granted

### Map Not Fitting
- Ensure at least one marker exists
- Check if coordinates are valid (not 0,0)
- Verify camera fit is called after markers are added

## Related Files
- `lib/screens/booking_map_screen.dart` - Main map screen
- `lib/models/vehicle.dart` - Vehicle model with GPS fields
- `lib/models/booking.dart` - Booking model
- `lib/services/slot_repository.dart` - Slot data access
