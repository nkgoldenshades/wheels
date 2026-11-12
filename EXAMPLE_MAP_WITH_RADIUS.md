# How to Use Map with Radius Circle

## What I Added

✅ Added `radiusInKm` parameter to `MapLocationPicker`
✅ Added `CircleLayer` to display radius on map
✅ Circle updates automatically when map moves

---

## Usage Example

### Basic Usage (No Radius)

```dart
// Open map picker without radius
final result = await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const MapLocationPicker(),
  ),
);
```

### With Radius Circle

```dart
// Open map picker with 5km radius circle
final result = await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const MapLocationPicker(
      radiusInKm: 5.0, // ✅ Show 5km radius circle
    ),
  ),
);
```

### With Initial Location and Radius

```dart
// Open map with initial location and radius
final result = await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => MapLocationPicker(
      initialLocation: LatLng(13.0827, 80.2707), // Chennai
      initialAddress: 'Chennai, Tamil Nadu',
      radiusInKm: 10.0, // ✅ Show 10km radius circle
    ),
  ),
);
```

---

## Customizing the Radius Circle

If you want to change the circle appearance, edit `lib/widgets/map_location_picker.dart`:

```dart
CircleMarker(
  point: _centerPosition,
  radius: widget.radiusInKm! * 1000, // Convert km to meters
  useRadiusInMeter: true,
  color: Colors.blue.withOpacity(0.2), // ✅ Fill color
  borderColor: Colors.blue, // ✅ Border color
  borderStrokeWidth: 2, // ✅ Border width
),
```

### Color Options:

```dart
// Red circle
color: Colors.red.withOpacity(0.2),
borderColor: Colors.red,

// Green circle
color: Colors.green.withOpacity(0.2),
borderColor: Colors.green,

// Purple circle
color: Colors.purple.withOpacity(0.2),
borderColor: Colors.purple,
```

---

## How It Works

1. **Pass `radiusInKm`** when opening the map
2. **Circle is drawn** centered on the selected location
3. **Circle moves** automatically when you drag the map
4. **Radius is in kilometers** (e.g., 5.0 = 5km radius)

---

## Example: Use in Create Post Screen

If you want to show the radius when selecting a location for a post:

```dart
// In your create post screen
final result = await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => MapLocationPicker(
      initialLocation: _fromLocation,
      initialAddress: _fromAddress,
      radiusInKm: _radius, // ✅ Use the radius from your form
    ),
  ),
);
```

---

## Visual Result

```
┌─────────────────────────────┐
│   Selected Location         │
│   123 Main St, Chennai      │
│   Lat: 13.0827, Lng: 80.27  │
└─────────────────────────────┘

        ╭─────────────╮
       ╱               ╲
      │    📍 Pin       │  ← Center
       ╲               ╱
        ╰─────────────╯
         ← 5km radius →
```

The blue circle shows the coverage area around the selected location.

---

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `initialLocation` | `LatLng?` | No | Starting map position |
| `initialAddress` | `String?` | No | Starting address text |
| `radiusInKm` | `double?` | No | Radius circle in kilometers |

---

## Notes

- Radius is **optional** - if not provided, no circle is shown
- Radius is in **kilometers** (not meters)
- Circle is **semi-transparent** so you can see the map underneath
- Circle **moves with the pin** when you drag the map

---

## Test It

```bash
flutter run
```

Then navigate to any screen that uses `MapLocationPicker` and pass `radiusInKm: 5.0` to see the circle!
