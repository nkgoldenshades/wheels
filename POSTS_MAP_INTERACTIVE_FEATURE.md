# Posts Map - Interactive Feature

## Overview
The Posts Map now shows markers **on-demand** when clicked, making the map cleaner and easier to understand.

## How It Works

### Default View (No Selection)
- All posts show their **3 location markers** (base, pickup, drop-off)
- Markers are **normal size** (40x40)
- **No radius circles** are shown
- **No vehicle locations** are shown
- Map is clean and uncluttered

### When You Click a Marker
1. **Selected markers grow larger** (50x50) with blue border
2. **Radius circle appears** around the base location (orange)
3. **Vehicle's current location** appears as a blue car icon
4. **Bottom sheet** shows post details (vehicle, price, capacity, etc.)

### Click Again to Deselect
- Click the same marker again to hide the radius and vehicle location
- Map returns to clean default view

## Marker Types

| Icon | Color | Meaning | Has Radius? |
|------|-------|---------|-------------|
| 🏠 Home | Orange | Base Location | ✅ Yes (when selected) |
| ▶️ Play Arrow | Green | Pickup Point | ❌ No |
| 🚩 Flag | Red | Drop-off Point | ❌ No |
| 🚗 Car | Blue | Vehicle Location | ❌ No (only shows when post selected) |

## Benefits

✅ **Cleaner Map**: No overlapping circles when many posts are nearby
✅ **Focus on One Post**: See radius and vehicle location for selected post only
✅ **Better UX**: Users can explore posts one at a time
✅ **Visual Feedback**: Selected markers are larger with blue border
✅ **Easy Toggle**: Click to select, click again to deselect

## Legend
The map includes a legend in the top-right corner explaining all marker types.

## Implementation Details

### State Management
- `_selectedPost` tracks which post is currently selected
- When a marker is clicked, it toggles selection
- Only the selected post shows radius circle and vehicle location

### Visual Indicators
- **Normal marker**: 40x40, white border (2px)
- **Selected marker**: 50x50, blue border (3px), larger shadow
- **Radius circle**: Semi-transparent orange (20% opacity)
- **Vehicle marker**: Blue car icon (only for selected post)

## Code Location
`lib/screens/posts_map_screen.dart`
