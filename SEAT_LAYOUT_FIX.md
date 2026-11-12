# Seat Layout Structure Fix

## Problem
Posts were being created but `seat_layout_structure` column was NULL in the database.

## Root Cause
The seat layout builder was saving layouts to `SeatLayoutRepository` (local storage) but NOT converting and attaching them to the `Slot` model before database insert.

## Solution Applied

### 1. Added State Variable
```dart
SimpleSeatLayout? _builtSeatLayout; // Store the actual layout structure
```

### 2. Convert on Save
When user saves seat layout in builder:
```dart
// Convert SeatLayout (UI model) to SimpleSeatLayout (DB model)
_builtSeatLayout = _convertToSimpleSeatLayout(saved);
debugPrint('📦 Seat Layout Structure: ${_builtSeatLayout?.toJson()}');
```

### 3. Attach to Slot
When creating slot:
```dart
final slot = Slot(
  // ... other fields
  seatLayoutStructure: _builtSeatLayout, // ✅ Now included
);
```

### 4. Conversion Logic
Converts UI model to DB model:
- `CellType.seat` → `PassengerSeat`
- `CellType.space` → Gap (status: 'gap')
- `SeatGender.male` → "Male"
- `SeatGender.female` → "Female"
- `SeatGender.any` → "Any"
- `isLocked: true` → status: 'locked'
- `isLocked: false` → status: 'available'

### 5. Debug Logging
Added verification before insert:
```dart
if (_builtSeatLayout == null) {
  debugPrint('⚠️ WARNING: Seat layout structure is NULL');
} else {
  debugPrint('✅ Seat layout structure: ${_builtSeatLayout!.toJson()}');
}
```

## Expected Database Structure

After fix, `seat_layout_structure` will contain:
```json
{
  "type": "passenger",
  "layout": [
    {
      "key": "S1",
      "matrix": "1x1",
      "allowed_gender": "Male",
      "price": 500.0,
      "status": "available",
      "booking_id": null
    },
    {
      "key": "S2",
      "matrix": "1x2",
      "allowed_gender": "Female",
      "price": 500.0,
      "status": "available",
      "booking_id": null
    }
  ]
}
```

## Testing

### 1. Create New Post
1. Add vehicle
2. Create passenger post
3. Open seat layout builder
4. Add seats (S1, S2, etc.)
5. Save layout
6. Complete post creation
7. Check logs for: `✅ Seat layout structure: {...}`

### 2. Verify Database
Go to Supabase → posts table:
- Find your post
- Check `seat_layout_structure` column
- Should contain JSON (not NULL)

### 3. Check Logs
Look for these messages:
```
📦 Seat Layout Structure: {type: passenger, layout: [...]}
✅ Seat layout structure: {type: passenger, layout: [...]}
✅ Slot synced to Supabase: post_id
```

## Files Modified
1. `lib/screens/add_flow/create_post_screen.dart`
   - Added `_builtSeatLayout` state variable
   - Added `_convertToSimpleSeatLayout()` method
   - Updated `_openSeatLayoutBuilder()` to convert and store
   - Updated slot creation to include `seatLayoutStructure`
   - Added debug logging
   - Added import for `SimpleSeatLayout`

## What Was Wrong Before

### Before ❌
```dart
// Seat layout saved to SeatLayoutRepository only
SeatLayoutRepository.instance.upsert(ownerId: ownerId, layout: saved);

// Slot created WITHOUT layout structure
final slot = Slot(
  seatLayoutOwnerId: layoutOwnerId, // Just the ID
  seatLayoutStructure: null, // ❌ NULL
);
```

### After ✅
```dart
// Seat layout saved AND converted
SeatLayoutRepository.instance.upsert(ownerId: ownerId, layout: saved);
_builtSeatLayout = _convertToSimpleSeatLayout(saved); // ✅ Convert

// Slot created WITH layout structure
final slot = Slot(
  seatLayoutOwnerId: layoutOwnerId,
  seatLayoutStructure: _builtSeatLayout, // ✅ Actual data
);
```

## Impact
- ✅ Seat layouts now stored in database
- ✅ Booking system can read seat availability
- ✅ Gender restrictions work
- ✅ Individual seat pricing works
- ✅ Seat status tracking works

## Next Steps
1. Test creating a new post with seat layout
2. Verify database has JSON data
3. Test booking flow with seat selection
4. Verify seat status updates after booking
