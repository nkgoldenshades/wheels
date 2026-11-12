# Database Relationship Flow

## Your Question
**"vehicles.id → slots.vehicle_id → seat_layouts.slot_id - is the flow like this?"**

## Answer: NO, the flow is DIFFERENT!

---

## ACTUAL FLOW (What Your Code Does)

```
vehicles.id
    ↓
slots.vehicle_id
    ↓
slots.seat_layout_owner_id  ← NOT a foreign key!
    ↓
seat_layouts.id (matched by owner_id, NOT slot_id)
```

### The Key Difference

**Your assumption:**
```sql
seat_layouts.slot_id → slots.id  ❌ WRONG
```

**Reality:**
```sql
slots.seat_layout_owner_id → seat_layouts.id  ✅ CORRECT
```

---

## Detailed Explanation

### 1. VEHICLES Table
```sql
CREATE TABLE vehicles (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  is_user_vehicle BOOLEAN DEFAULT false,
  -- ...
);
```

**Example:**
```
┌──────────┬─────────┬───────┬──────┬─────────────────┐
│ id       │ user_id │ name  │ type │ is_user_vehicle │
├──────────┼─────────┼───────┼──────┼─────────────────┤
│ vehicle1 │ user123 │ Swift │ Car  │ false           │
└──────────┴─────────┴───────┴──────┴─────────────────┘
```

### 2. SLOTS Table
```sql
CREATE TABLE slots (
  id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL REFERENCES vehicles(id),
  seat_layout_owner_id TEXT,  -- ← NOT a foreign key!
  service_type TEXT NOT NULL,
  price DOUBLE PRECISION NOT NULL,
  capacity INTEGER NOT NULL,
  -- ...
);
```

**Example:**
```
┌────────┬───────────┬──────────────────────┬──────────┬───────┐
│ id     │ vehicle_id│ seat_layout_owner_id │ capacity │ price │
├────────┼───────────┼──────────────────────┼──────────┼───────┤
│ slot1  │ vehicle1  │ layout123            │ 4        │ 500   │
│ slot2  │ vehicle1  │ NULL                 │ 2        │ 300   │
└────────┴───────────┴──────────────────────┴──────────┴───────┘
```

**Key Points:**
- `vehicle_id` → Links to vehicles table ✅
- `seat_layout_owner_id` → Just a TEXT field (NOT a foreign key) ⚠️
- Can be NULL (simple seating mode)

### 3. SEAT_LAYOUTS Table
```sql
CREATE TABLE seat_layouts (
  id UUID PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  name TEXT NOT NULL,
  layout_data JSONB NOT NULL,  -- Contains seat positions, prices
  -- ...
);
```

**Example:**
```
┌───────────┬─────────┬──────────────┬─────────────────────────┐
│ id        │ user_id │ name         │ layout_data             │
├───────────┼─────────┼──────────────┼─────────────────────────┤
│ layout123 │ user123 │ Swift Layout │ {"cells": {...}}        │
└───────────┴─────────┴──────────────┴─────────────────────────┘
```

**Key Points:**
- `id` → UUID (not TEXT like slots)
- `user_id` → Owner of the layout
- `layout_data` → JSONB with seat configuration
- NO `slot_id` column! ❌

---

## How They Connect

### The Lookup Process

```dart
// In Dart code (lib/models/slot.dart)
class Slot {
  final String id;
  final String vehicleId;
  final String? seatLayoutOwnerId;  // ← This is the link!
  // ...
}
```

**Step-by-step:**

1. **Get Slot:**
   ```dart
   final slot = Slot(
     id: "slot1",
     vehicleId: "vehicle1",
     seatLayoutOwnerId: "layout123",  // ← Stored as TEXT
   );
   ```

2. **Find Vehicle:**
   ```dart
   final vehicle = await supabase
     .from('vehicles')
     .select()
     .eq('id', slot.vehicleId)  // vehicle1
     .single();
   ```

3. **Find Seat Layout (if exists):**
   ```dart
   if (slot.seatLayoutOwnerId != null) {
     final layout = await supabase
       .from('seat_layouts')
       .select()
       .eq('id', slot.seatLayoutOwnerId)  // layout123
       .single();
   }
   ```

---

## Why This Design?

### Reason 1: Optional Seat Layouts

Not all slots need seat layouts:

```
Simple Mode (no layout):
┌────────┬───────────┬──────────────────────┬──────────┐
│ slot_id│ vehicle_id│ seat_layout_owner_id │ capacity │
├────────┼───────────┼──────────────────────┼──────────┤
│ slot1  │ vehicle1  │ NULL                 │ 4        │
└────────┴───────────┴──────────────────────┴──────────┘
User just enters: "4 seats, ₹500 each"

Layout Mode (with layout):
┌────────┬───────────┬──────────────────────┬──────────┐
│ slot_id│ vehicle_id│ seat_layout_owner_id │ capacity │
├────────┼───────────┼──────────────────────┼──────────┤
│ slot2  │ vehicle1  │ layout123            │ 4        │
└────────┴───────────┴──────────────────────┴──────────┘
User creates visual layout with individual seat prices
```

### Reason 2: Reusable Layouts

One layout can be used by multiple slots:

```
seat_layouts:
┌───────────┬──────────────┐
│ id        │ name         │
├───────────┼──────────────┤
│ layout123 │ Swift Layout │ ← Created once
└───────────┴──────────────┘

slots:
┌────────┬──────────────────────┐
│ id     │ seat_layout_owner_id │
├────────┼──────────────────────┤
│ slot1  │ layout123            │ ← Reuses layout
│ slot2  │ layout123            │ ← Reuses layout
│ slot3  │ layout123            │ ← Reuses layout
└────────┴──────────────────────┘
```

### Reason 3: User Owns Layouts

Layouts belong to users, not slots:

```
User creates layout → Saved to seat_layouts
User creates slot → References layout by ID
User deletes slot → Layout still exists
User creates new slot → Can reuse same layout
```

---

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         USERS                               │
│  ┌────────────────────────────────────────────────────┐    │
│  │ id: "user123"                                       │    │
│  │ email: "user@example.com"                          │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                    │
                    │ user_id
                    ↓
┌─────────────────────────────────────────────────────────────┐
│                       VEHICLES                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ id: "vehicle1"                                      │    │
│  │ user_id: "user123"                                 │    │
│  │ name: "Swift"                                      │    │
│  │ is_user_vehicle: false                             │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                    │
                    │ vehicle_id
                    ↓
┌─────────────────────────────────────────────────────────────┐
│                         SLOTS                               │
│  ┌────────────────────────────────────────────────────┐    │
│  │ id: "slot1"                                         │    │
│  │ vehicle_id: "vehicle1"                             │    │
│  │ seat_layout_owner_id: "layout123"  ← TEXT field    │    │
│  │ capacity: 4                                        │    │
│  │ price: 500                                         │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                    │
                    │ seat_layout_owner_id (lookup by id)
                    ↓
┌─────────────────────────────────────────────────────────────┐
│                     SEAT_LAYOUTS                            │
│  ┌────────────────────────────────────────────────────┐    │
│  │ id: "layout123"  ← UUID                            │    │
│  │ user_id: "user123"                                 │    │
│  │ name: "Swift Layout"                               │    │
│  │ layout_data: {                                     │    │
│  │   "cells": {                                       │    │
│  │     "0,0": {"type": "seat", "price": 500},        │    │
│  │     "0,1": {"type": "seat", "price": 500},        │    │
│  │     "1,0": {"type": "seat", "price": 600},        │    │
│  │     "1,1": {"type": "seat", "price": 600}         │    │
│  │   }                                                │    │
│  │ }                                                  │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                    │
                    │ (used for booking)
                    ↓
┌─────────────────────────────────────────────────────────────┐
│                       BOOKINGS                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ id: "booking1"                                      │    │
│  │ slot_id: "slot1"                                   │    │
│  │ customer_id: "user456"                             │    │
│  │ provider_id: "user123"                             │    │
│  │ seat_key: "0,0"  ← References layout_data         │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## Summary

### What You Thought ❌
```
vehicles.id
    ↓
slots.vehicle_id
    ↓
seat_layouts.slot_id  ← This column doesn't exist!
```

### What It Actually Is ✅
```
vehicles.id
    ↓
slots.vehicle_id
    ↓
slots.seat_layout_owner_id (TEXT field, not foreign key)
    ↓
seat_layouts.id (lookup by matching id)
```

### Key Differences

| Your Assumption | Reality |
|----------------|---------|
| `seat_layouts.slot_id` | No such column exists |
| Foreign key relationship | Just a TEXT field lookup |
| One layout per slot | One layout can be reused by many slots |
| Slot owns layout | User owns layout |
| Layout deleted with slot | Layout persists after slot deletion |

The relationship is **looser** than you thought - it's more like a "reference" than a "foreign key"!
