# Seat Layout Structure Implementation

## ✅ COMPLETED: SimpleSeatLayout Model

The `SimpleSeatLayout` model has been updated to match the FINAL REFINED structure.

### Key Changes Made:

1. **Unified key naming**: Changed from `seat_key`/`slot_key` to just `key` for both passenger and parcel
2. **Removed country field**: No longer required in the structure
3. **Removed user data from layout**: No `name` or `gender` stored in booked seats
   - Only `booking_id` is stored
   - User info fetched from bookings table when needed
4. **Added gap status**: New `SlotStatus.gap` for empty spaces in grid
5. **Separated passenger and parcel**: 
   - `PassengerSeat` class for passenger seats
   - `ParcelSlot` class for parcel slots
   - Both extend `LayoutItem` base class

## 📋 JSON Structure

### Passenger Layout
```json
{
  "type": "passenger",
  "layout": [
    {
      "key": "S1",
      "matrix": "1x1",
      "status": "available",
      "allowed_gender": "Male",
      "price": 500
    },
    {
      "key": "S2",
      "matrix": "1x2",
      "status": "booked",
      "booking_id": "B001",
      "allowed_gender": "Any",
      "price": 500
    },
    {
      "key": "S3",
      "matrix": "1x3",
      "status": "gap"
    }
  ]
}
```

### Parcel Layout
```json
{
  "type": "parcel",
  "layout": [
    {
      "key": "P1",
      "matrix": "1x1",
      "status": "available",
      "price": 200,
      "parcel_type": "Normal",
      "dimensions": {
        "h": 10,
        "w": 20,
        "l": 30,
        "b": 15
      }
    },
    {
      "key": "P2",
      "matrix": "1x2",
      "status": "booked",
      "booking_id": "B002",
      "price": 300,
      "parcel_type": "Fragile"
    },
    {
      "key": "P3",
      "matrix": "1x3",
      "status": "gap"
    }
  ]
}
```

## 🎯 Status Values

- `available` - Selectable ✅
- `booked` - Filled 🔒
- `locked` - Disabled ❌
- `gap` - Empty space ⬜

## 🚀 Next Steps

### 1. Grid UI Renderer
Create a widget that:
- Reads matrix values (e.g., "1x1", "2x3")
- Builds grid layout dynamically
- Handles status-based styling
- Implements gender restriction UI

### 2. Gender Restriction Logic
```dart
// Booking validation
IF status != available → block
IF allowed_gender != "Any" AND user.gender != allowed_gender
  → show error "Not allowed for your gender"
  → block selection ❌
ELSE
  → allow selection ✅
```

### 3. Seat Layout Builder Update
- Update existing builder to output this JSON format
- Convert grid-based layout to SimpleSeatLayout
- Save to `seat_layout_structure` JSONB field

### 4. Booking Flow Integration
- Update booking confirm sheet to use SimpleSeatLayout
- Implement gender validation
- Send booking data: `{key, user_gender, user_name}`

### 5. Database Integration
- Store in `seat_layout_structure` JSONB field in posts table
- Only update `status` and `booking_id` on booking
- Never rewrite full JSON

## 📝 Model Classes

### SlotStatus Enum
- `available`, `booked`, `locked`, `gap`

### LayoutItem (Base Class)
- `key`: String
- `matrix`: String (e.g., "1x1")
- `status`: SlotStatus
- `price`: int
- `bookingId`: String?
- Helper: `row`, `col`, `isAvailable`, `isBooked`, `isLocked`, `isGap`

### PassengerSeat extends LayoutItem
- `allowedGender`: String ("Male", "Female", "Any")
- Method: `canBook(userGender)` - validates gender restriction

### ParcelSlot extends LayoutItem
- `parcelType`: String? ("Normal", "Fragile", etc.)
- `dimensions`: ParcelDimensions? (h, w, l, b)

### SimpleSeatLayout
- `type`: String ("passenger" or "parcel")
- `layout`: List<LayoutItem>
- Helpers: `getItem()`, `availableItems`, `bookedItems`, `updateItemStatus()`
- Grid info: `maxRow`, `maxCol`

## ✅ Benefits

1. **Unified structure**: Same key naming for passenger and parcel
2. **Clean data**: No duplicate user info in layout
3. **Flexible**: Optional fields (country, dimensions)
4. **Type-safe**: Separate classes for passenger/parcel
5. **Scalable**: Easy to add new layout types
