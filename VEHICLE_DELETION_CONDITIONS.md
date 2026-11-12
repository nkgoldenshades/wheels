# 🚗 Vehicle Deletion - Conditions & Rules

## ✅ When Deletion is ALLOWED

A vehicle can be deleted **ONLY** when:

1. ✅ **No active posts exist** for this vehicle
2. ✅ **No active bookings exist** for this vehicle

If both conditions are met → **Deletion allowed** ✅

---

## ❌ When Deletion is BLOCKED

### Condition 1: Active Posts Exist

**Blocked if:** The vehicle has any posts with `is_active = true`

**Error Message:**
```
Cannot delete vehicle: X active post(s) exist.
Please delete or deactivate all posts using this vehicle first.
```

**What to do:**
1. Go to "My Posts" or "Provider Posts"
2. Find all posts using this vehicle
3. Either:
   - **Delete** the posts, OR
   - **Deactivate** the posts (set `is_active = false`)
4. Then try deleting the vehicle again

---

### Condition 2: Active Bookings Exist

**Blocked if:** The vehicle has any bookings with status NOT in:
- `rejected`
- `cancelled`
- `completed`
- `refunded`

**Active booking statuses** (these block deletion):
- `pending`
- `confirmed`
- `in_progress`
- `accepted`
- Any other status except the 4 above

**Error Message:**
```
Cannot delete vehicle: X active booking(s) exist.
Please wait for bookings to complete or cancel them first.
```

**What to do:**
1. Go to "Bookings" section
2. Find all bookings for posts using this vehicle
3. Either:
   - **Wait** for bookings to complete naturally, OR
   - **Cancel** the bookings (if allowed), OR
   - **Reject** the bookings (if you're the provider)
4. Then try deleting the vehicle again

---

## 🔍 How the Check Works

### Step-by-Step Logic

```
┌─────────────────────────────────────────┐
│ User: Long press vehicle → Delete      │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ CHECK 1: Active Posts?                  │
│                                         │
│ Query: SELECT * FROM posts              │
│        WHERE vehicle_id = 'xxx'         │
│        AND is_active = true             │
└────────────────┬────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
    Found posts?      No posts?
        │                 │
        ▼                 ▼
    ❌ BLOCK          ✅ Continue
    Show error
        │
        │
        └─────────────────┐
                          │
                          ▼
        ┌─────────────────────────────────────────┐
        │ CHECK 2: Active Bookings?               │
        │                                         │
        │ Query: SELECT * FROM bookings           │
        │        WHERE status NOT IN              │
        │        ('rejected','cancelled',         │
        │         'completed','refunded')         │
        └────────────────┬────────────────────────┘
                         │
                ┌────────┴────────┐
                │                 │
                ▼                 ▼
        Found bookings?      No bookings?
                │                 │
                ▼                 ▼
        Check if for          ✅ ALLOW
        this vehicle          Delete vehicle
                │             Show success
                ▼
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
    For this         Not for this
    vehicle?         vehicle?
        │                 │
        ▼                 ▼
    ❌ BLOCK          ✅ ALLOW
    Show error        Delete vehicle
                      Show success
```

---

## 📊 Deletion Scenarios

### Scenario 1: Clean Vehicle (No Posts, No Bookings)
```
Vehicle: Car A
Posts: None
Bookings: None

Result: ✅ DELETION ALLOWED
```

### Scenario 2: Vehicle with Inactive Posts
```
Vehicle: Car A
Posts: 
  - Post 1 (is_active = false) ✅
  - Post 2 (is_active = false) ✅
Bookings: None

Result: ✅ DELETION ALLOWED
(Inactive posts don't block deletion)
```

### Scenario 3: Vehicle with Active Posts
```
Vehicle: Car A
Posts: 
  - Post 1 (is_active = true) ❌
  - Post 2 (is_active = false) ✅
Bookings: None

Result: ❌ DELETION BLOCKED
Error: "Cannot delete vehicle: 1 active post exists"
```

### Scenario 4: Vehicle with Completed Bookings
```
Vehicle: Car A
Posts: 
  - Post 1 (is_active = false) ✅
Bookings:
  - Booking 1 (status = completed) ✅
  - Booking 2 (status = cancelled) ✅

Result: ✅ DELETION ALLOWED
(Completed/cancelled bookings don't block deletion)
```

### Scenario 5: Vehicle with Active Bookings
```
Vehicle: Car A
Posts: 
  - Post 1 (is_active = false) ✅
Bookings:
  - Booking 1 (status = confirmed) ❌
  - Booking 2 (status = completed) ✅

Result: ❌ DELETION BLOCKED
Error: "Cannot delete vehicle: 1 active booking exists"
```

### Scenario 6: Vehicle with Both Active Posts and Bookings
```
Vehicle: Car A
Posts: 
  - Post 1 (is_active = true) ❌
Bookings:
  - Booking 1 (status = confirmed) ❌

Result: ❌ DELETION BLOCKED
Error: "Cannot delete vehicle: 1 active post exists"
(Checks posts first, so shows post error)
```

---

## 🎯 Quick Reference

### Deletion Allowed When:
| Condition | Status |
|-----------|--------|
| Active posts | ✅ None (or all inactive) |
| Active bookings | ✅ None (or all completed/cancelled/rejected/refunded) |

### Deletion Blocked When:
| Condition | Status |
|-----------|--------|
| Active posts | ❌ At least 1 post with `is_active = true` |
| Active bookings | ❌ At least 1 booking with status = `pending`, `confirmed`, `in_progress`, etc. |

---

## 🔧 How to Prepare a Vehicle for Deletion

### Step 1: Check Active Posts
```sql
-- Run in Supabase SQL Editor
SELECT id, start_time, end_time, is_active
FROM posts
WHERE vehicle_id = 'YOUR_VEHICLE_ID'
  AND is_active = true;
```

**If results found:**
- Delete the posts, OR
- Set `is_active = false` for each post

### Step 2: Check Active Bookings
```sql
-- Run in Supabase SQL Editor
SELECT b.id, b.status, b.post_id, p.vehicle_id
FROM bookings b
JOIN posts p ON b.post_id = p.id
WHERE p.vehicle_id = 'YOUR_VEHICLE_ID'
  AND b.status NOT IN ('rejected', 'cancelled', 'completed', 'refunded');
```

**If results found:**
- Wait for bookings to complete, OR
- Cancel the bookings, OR
- Reject the bookings (if you're the provider)

### Step 3: Try Deletion Again
Once both checks return no results, deletion will succeed! ✅

---

## 💡 Why These Conditions?

### Data Integrity
- **Active posts** mean the vehicle is currently being offered
- **Active bookings** mean customers have paid/reserved the vehicle
- Deleting would break these relationships and cause errors

### User Experience
- Prevents accidental deletion of vehicles in use
- Protects customer bookings
- Ensures clean data

### Business Logic
- Vehicles with active business should not be deleted
- Complete all transactions first
- Then clean up

---

## 🎓 Understanding the Code

### Provider Vehicles (VehicleRepository)
```dart
Future<void> deleteVehicle(String vehicleId) async {
  // CHECK 1: Active posts?
  final activePosts = await _supabase
      .from('posts')
      .select('id, start_time, end_time')
      .eq('vehicle_id', vehicleId)
      .eq('is_active', true);
  
  if (activePosts.isNotEmpty) {
    throw Exception('Cannot delete vehicle: X active posts exist');
  }
  
  // CHECK 2: Active bookings?
  final activeBookings = await _supabase
      .from('bookings')
      .select('id, status, post_id')
      .not('status', 'in', '(rejected,cancelled,completed,refunded)');
  
  if (activeBookings.isNotEmpty) {
    // Check if bookings are for THIS vehicle's posts
    final vehiclePosts = await _supabase
        .from('posts')
        .select('id')
        .eq('vehicle_id', vehicleId);
    
    final vehiclePostIds = vehiclePosts.map((p) => p['id']).toSet();
    final bookingsForThisVehicle = activeBookings
        .where((b) => vehiclePostIds.contains(b['post_id']))
        .toList();
    
    if (bookingsForThisVehicle.isNotEmpty) {
      throw Exception('Cannot delete vehicle: X active bookings exist');
    }
  }
  
  // SAFE TO DELETE
  await _supabase.from('vehicles').delete().eq('id', vehicleId);
}
```

### Customer Vehicles (CustomerVehicleRepository)
Same logic, but checks `user_posts` table instead of `posts` table.

---

## 📋 Summary

### ✅ Deletion Allowed
- No active posts (`is_active = false` or deleted)
- No active bookings (all are `completed`, `cancelled`, `rejected`, or `refunded`)

### ❌ Deletion Blocked
- At least 1 active post (`is_active = true`)
- At least 1 active booking (status is `pending`, `confirmed`, `in_progress`, etc.)

### 🎯 To Delete a Vehicle
1. Delete or deactivate all active posts
2. Complete, cancel, or reject all active bookings
3. Then delete the vehicle

---

## 🆘 Common Questions

### Q: I deleted all posts but still can't delete the vehicle
**A:** Check for active bookings. Even if posts are deleted, bookings might still exist with status `pending`, `confirmed`, etc.

### Q: Can I delete a vehicle with completed bookings?
**A:** Yes! ✅ Completed bookings don't block deletion. Only active bookings do.

### Q: Can I delete a vehicle with inactive posts?
**A:** Yes! ✅ Inactive posts (`is_active = false`) don't block deletion. Only active posts do.

### Q: What if I get "column bookings.slot_id does not exist"?
**A:** This is a database RLS policy issue. Run `FIND_AND_FIX_SLOT_ID.sql` to fix it. See `START_HERE_VEHICLE_DELETION.md`.

### Q: Can I force delete a vehicle?
**A:** No. The protection is intentional to prevent data corruption and broken bookings. You must resolve active posts/bookings first.

---

## 🎉 Best Practices

1. **Before deleting a vehicle:**
   - Check for active posts
   - Check for active bookings
   - Resolve any issues

2. **If you want to temporarily stop using a vehicle:**
   - Don't delete it
   - Set it to "Offline" instead
   - Or deactivate its posts

3. **If you want to permanently remove a vehicle:**
   - Complete all active bookings
   - Delete or deactivate all posts
   - Then delete the vehicle

This ensures clean data and happy customers! 🚀
