# Slot Deletion Issue: "Cannot delete post if active bookings exist"

## Problem Analysis

The error "Cannot delete post if active bookings exist" suggests there's a **database constraint** preventing slot deletion when bookings reference that slot.

## Root Cause

Looking at the code and database structure:

1. **Foreign Key Constraint**: `bookings.slot_id` references `slots.id`
2. **Default Behavior**: PostgreSQL prevents deletion of referenced records
3. **No Cascade Delete**: The constraint likely has `ON DELETE RESTRICT` (default)

## Current Code Behavior

### Frontend Logic (Working)
```dart
// In vehicle_actions_screen.dart
await SlotRepository.instance.deleteSlot(entry.slot.id);
```

### Repository Logic (Working)
```dart
// In slot_repository.dart
Future<void> deleteSlot(String slotId) async {
  // 1. Remove from local state ✅
  _slots.value = _slots.value.where((s) => s.id != slotId).toList();
  
  // 2. Delete from Supabase ❌ FAILS HERE
  await _deleteSlotFromSupabase(slotId);
}
```

### Database Constraint (Blocking)
```sql
-- This constraint prevents deletion:
ALTER TABLE bookings 
  ADD CONSTRAINT bookings_slot_id_fkey 
  FOREIGN KEY (slot_id) REFERENCES slots(id) ON DELETE RESTRICT;
```

---

## Solutions

### Option 1: Change Constraint to CASCADE (⚠️ Dangerous)
```sql
-- This would delete all bookings when slot is deleted
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_slot_id_fkey;
ALTER TABLE bookings ADD CONSTRAINT bookings_slot_id_fkey 
  FOREIGN KEY (slot_id) REFERENCES slots(id) ON DELETE CASCADE;
```

**Problems:**
- Deletes user bookings without warning
- Loses payment/refund history
- Could cause financial issues

### Option 2: Change Constraint to SET NULL (❌ Won't Work)
```sql
-- This would set slot_id to NULL when slot is deleted
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_slot_id_fkey;
ALTER TABLE bookings ADD CONSTRAINT bookings_slot_id_fkey 
  FOREIGN KEY (slot_id) REFERENCES slots(id) ON DELETE SET NULL;
```

**Problems:**
- Bookings lose reference to original slot
- Breaks booking history and reports

### Option 3: Business Logic Validation (✅ Recommended)
Add validation to prevent deletion when active bookings exist:

```dart
Future<bool> canDeleteSlot(String slotId) async {
  final activeBookings = BookingRepository.instance.bookings.value
      .where((b) => 
          b.slotId == slotId && 
          !['rejected', 'cancelled', 'completed', 'refunded'].contains(b.status.name))
      .toList();
  
  return activeBookings.isEmpty;
}
```

### Option 4: Soft Delete (✅ Best Practice)
Mark slots as deleted instead of actually deleting them:

```sql
-- Add deleted_at column to slots
ALTER TABLE slots ADD COLUMN deleted_at timestamptz NULL;

-- Update queries to exclude soft-deleted slots
SELECT * FROM slots WHERE deleted_at IS NULL;
```

---

## Recommended Solution: Business Logic + User Choice

### Step 1: Add Validation Before Deletion
```dart
Future<void> deleteSlot(String slotId) async {
  // Check for active bookings first
  final activeBookings = BookingRepository.instance.bookings.value
      .where((b) => 
          b.slotId == slotId && 
          !['rejected', 'cancelled', 'completed', 'refunded'].contains(b.status.name))
      .toList();
  
  if (activeBookings.isNotEmpty) {
    throw Exception('Cannot delete post: ${activeBookings.length} active booking(s) exist');
  }
  
  // Proceed with deletion if no active bookings
  _slots.value = _slots.value.where((s) => s.id != slotId).toList();
  _buildSlotEntries();
  await _saveSlots();
  await _deleteSlotFromSupabase(slotId);
}
```

### Step 2: Update UI to Handle the Error
```dart
// In vehicle_actions_screen.dart
try {
  await SlotRepository.instance.deleteSlot(entry.slot.id);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post deleted')),
    );
  }
} catch (e) {
  if (context.mounted) {
    if (e.toString().contains('active booking')) {
      // Show specific error for active bookings
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot Delete Post'),
          content: const Text(
            'This post has active bookings and cannot be deleted. '
            'Wait for bookings to complete or be cancelled first.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      // Show generic error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete post: $e')),
      );
    }
  }
}
```

### Step 3: Alternative - Offer to Cancel Bookings
```dart
// Show dialog with options
showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('Active Bookings Found'),
    content: Text(
      'This post has ${activeBookings.length} active booking(s). '
      'What would you like to do?'
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Keep Post'),
      ),
      TextButton(
        onPressed: () async {
          Navigator.pop(ctx);
          // Cancel all active bookings first
          for (final booking in activeBookings) {
            await BookingRepository.instance.markRejected(booking.id);
          }
          // Then delete the slot
          await SlotRepository.instance.deleteSlot(slotId);
        },
        style: TextButton.styleFrom(foregroundColor: Colors.orange),
        child: const Text('Cancel Bookings & Delete'),
      ),
    ],
  ),
);
```

---

## Database Fix (If Needed)

If the constraint is too restrictive, we can modify it:

```sql
-- Check current constraint
SELECT 
    tc.constraint_name,
    rc.delete_rule
FROM information_schema.table_constraints AS tc 
JOIN information_schema.referential_constraints AS rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.table_name = 'bookings' 
    AND tc.constraint_type = 'FOREIGN KEY'
    AND tc.constraint_name LIKE '%slot_id%';

-- If delete_rule is 'RESTRICT', we might want to change it
-- But better to handle in business logic
```

---

## Summary

**Current Issue:** Database foreign key constraint prevents slot deletion when bookings exist.

**Best Solution:** 
1. Add business logic validation to check for active bookings
2. Show user-friendly error message
3. Optionally offer to cancel bookings first
4. Keep database constraint for data integrity

**Quick Fix:** Implement the validation logic in `SlotRepository.deleteSlot()` method.
