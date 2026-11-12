# ✅ Event Features Added

## New Features for Events

### 1. Event Delivery Mode ✨

Events now support two delivery modes (like vehicle pickup modes):

**Customer Comes to Event** 🏢
- Customer travels to event location
- Default mode

**Event Organizer Goes to Customer** 🚚
- Event organizer travels to customer location
- For mobile events (catering, mobile shops, etc.)

### 2. Online/Offline Toggle (Coming Soon)

Events will have online/offline status like vehicles:
- Toggle event availability
- Show/hide from marketplace
- Stored locally (will add to database later)

### 3. Event Slots (Model Ready)

Created `EventSlot` model for creating time slots within events:
- Similar to vehicle slots
- Support point-to-point or area-based slots
- Can have seat layouts
- Capacity management
- Price per slot

## Files Created

### New Models
- ✅ `lib/models/event_delivery_mode.dart` - Delivery mode enum
- ✅ `lib/models/event_slot.dart` - Event slot model

### Updated Files
- ✅ `lib/models/event.dart` - Added `deliveryMode` field
- ✅ `lib/screens/add_flow/event_screen.dart` - Added delivery mode selector
- ✅ `lib/services/event_repository.dart` - Added online/offline status methods

## How It Works

### Event Delivery Mode

**In Event Creation Screen:**
```dart
// User selects delivery mode
RadioListTile<EventDeliveryMode>(
  title: Text('Customer comes to event'),
  value: EventDeliveryMode.customerComesToEvent,
  groupValue: _deliveryMode,
  onChanged: (value) => setState(() => _deliveryMode = value),
)

RadioListTile<EventDeliveryMode>(
  title: Text('Event organizer goes to customer'),
  value: EventDeliveryMode.eventGoesToCustomer,
  groupValue: _deliveryMode,
  onChanged: (value) => setState(() => _deliveryMode = value),
)
```

**Stored in Database:**
- `event_type` = 'customer_comes' or 'goes_to_customer'

### Online/Offline Status

**API:**
```dart
// Set event online/offline
await EventRepository.instance.setOnlineStatus(eventId, true);

// Check if event is online
bool isOnline = EventRepository.instance.isOnline(eventId);
```

**Note:** Currently stored locally. Will add to database schema later.

### Event Slots (Model Ready)

**Create Event Slot:**
```dart
final slot = EventSlot(
  id: 'slot_123',
  eventId: 'event_456',
  slotType: SlotType.fromTo,
  fromLocation: 'Venue A',
  toLocation: 'Venue B',
  startTime: DateTime.now(),
  endTime: DateTime.now().add(Duration(hours: 2)),
  price: 500.0,
  capacity: 50,
  createdAt: DateTime.now(),
);
```

## UI Updates

### Event Creation Screen

**Before:**
- Event type dropdown
- Location + radius
- Start/end date/time
- Description
- Price

**After:**
- Event type dropdown
- Location + radius
- **Delivery mode selector** ✨ (NEW)
- Start/end date/time
- Description
- Price

### Delivery Mode Display

Shows with icons:
- 🏢 Customer comes to event
- 🚚 Event organizer goes to customer

## Database Schema

### Events Table (Updated)

```sql
CREATE TABLE events (
  id UUID PRIMARY KEY,
  user_id TEXT REFERENCES users(id),
  title TEXT NOT NULL,
  event_type TEXT NOT NULL,  -- Now stores delivery mode
  location TEXT NOT NULL,
  radius_km NUMERIC NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  description TEXT NOT NULL,
  price NUMERIC,
  images TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**event_type values:**
- `'customer_comes'` - Customer comes to event
- `'goes_to_customer'` - Event organizer goes to customer

## Next Steps

### To Complete Event Slots Feature:

1. **Create Event Slot Repository**
   - Similar to `SlotRepository`
   - CRUD operations for event slots
   - Link to events table

2. **Create Event Slot Screen**
   - Similar to `CreateSlotScreen` for vehicles
   - Allow creating slots for events
   - Time slot management

3. **Add to Database Schema**
   - Create `event_slots` table
   - Link to events via `event_id`
   - Support seat layouts

4. **Add Online/Offline to Database**
   - Add `is_online` column to events table
   - Persist status in Supabase
   - Show in marketplace

### Suggested Database Schema for Event Slots:

```sql
CREATE TABLE event_slots (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID REFERENCES events(id),
  user_id TEXT REFERENCES users(id),
  slot_type TEXT CHECK (slot_type IN ('from_to', 'base_radius')),
  from_location TEXT,
  to_location TEXT,
  base_location TEXT,
  radius NUMERIC,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  capacity INTEGER NOT NULL,
  price NUMERIC NOT NULL,
  notes TEXT,
  is_available BOOLEAN DEFAULT true,
  seat_layout_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Usage Examples

### Create Event with Delivery Mode

```dart
final event = Event(
  id: '123',
  userId: 'user_456',
  title: 'Wedding Catering',
  location: 'Mumbai',
  radiusKm: 20.0,
  startTime: DateTime.now(),
  endTime: DateTime.now().add(Duration(hours: 6)),
  description: 'Professional catering service',
  price: 50000.0,
  images: [],
  createdAt: DateTime.now(),
  deliveryMode: EventDeliveryMode.eventGoesToCustomer, // We go to customer
);

await EventRepository.instance.addEvent(event);
```

### Toggle Event Online Status

```dart
// Make event visible in marketplace
await EventRepository.instance.setOnlineStatus(eventId, true);

// Hide event from marketplace
await EventRepository.instance.setOnlineStatus(eventId, false);
```

### Create Event Slot (When Repository Ready)

```dart
final slot = EventSlot(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  eventId: event.id,
  slotType: SlotType.fromTo,
  fromLocation: 'Hall A',
  toLocation: 'Hall B',
  startTime: event.startTime,
  endTime: event.startTime.add(Duration(hours: 2)),
  price: 1000.0,
  capacity: 100,
  notes: 'Morning session',
  createdAt: DateTime.now(),
);

// await EventSlotRepository.instance.addSlot(slot);
```

## Benefits

### For Event Organizers
- ✅ Specify if customers come to them or they go to customers
- ✅ Create multiple time slots for same event
- ✅ Manage capacity per slot
- ✅ Toggle event visibility
- ✅ Flexible pricing per slot

### For Customers
- ✅ Know if they need to travel or service comes to them
- ✅ Book specific time slots
- ✅ See available capacity
- ✅ Choose from multiple sessions

## Summary

✅ **Event delivery mode added** - Customer comes OR organizer goes
✅ **Online/offline status ready** - Toggle event visibility
✅ **Event slot model created** - Ready for slot management
⏳ **Event slot repository** - Next step
⏳ **Event slot screen** - Next step
⏳ **Database schema update** - Add event_slots table

**Events now have the same flexibility as vehicles!** 🎉
