# 🚗 Vehicle Deletion Rules - Simple Guide

## ✅ When Can I Delete a Vehicle?

### Rule 1: No Active Posts
```
❌ BLOCKED: Vehicle has active posts (is_active = true)
✅ ALLOWED: Vehicle has no posts OR all posts are inactive
```

### Rule 2: No Active Bookings
```
❌ BLOCKED: Vehicle has bookings with status:
           - pending
           - confirmed
           - in_progress
           - accepted
           
✅ ALLOWED: Vehicle has no bookings OR all bookings are:
           - completed
           - cancelled
           - rejected
           - refunded
```

---

## 🎯 Quick Decision Tree

```
Want to delete vehicle?
    │
    ▼
Does it have active posts? ──YES──> ❌ BLOCKED
    │                                Delete posts first
    NO
    │
    ▼
Does it have active bookings? ──YES──> ❌ BLOCKED
    │                                   Complete/cancel bookings first
    NO
    │
    ▼
✅ DELETION ALLOWED!
```

---

## 📊 Examples

### ✅ CAN Delete
```
Vehicle: Car A
├─ Posts: None
└─ Bookings: None
Result: ✅ DELETE ALLOWED
```

```
Vehicle: Car B
├─ Posts: 2 (both inactive)
└─ Bookings: 3 (all completed)
Result: ✅ DELETE ALLOWED
```

### ❌ CANNOT Delete
```
Vehicle: Car C
├─ Posts: 1 active ❌
└─ Bookings: None
Result: ❌ BLOCKED - Delete the post first
```

```
Vehicle: Car D
├─ Posts: None
└─ Bookings: 1 confirmed ❌
Result: ❌ BLOCKED - Complete/cancel the booking first
```

```
Vehicle: Car E
├─ Posts: 1 active ❌
└─ Bookings: 2 confirmed ❌
Result: ❌ BLOCKED - Delete post and complete bookings first
```

---

## 🔧 How to Prepare for Deletion

### Step 1: Handle Active Posts
1. Go to "My Posts" or "Provider Posts"
2. Find posts using this vehicle
3. Either:
   - **Delete** the posts
   - **Deactivate** the posts (toggle off)

### Step 2: Handle Active Bookings
1. Go to "Bookings"
2. Find bookings for this vehicle
3. Either:
   - **Wait** for them to complete
   - **Cancel** them (if allowed)
   - **Reject** them (if you're provider)

### Step 3: Delete Vehicle
1. Long press the vehicle
2. Click "Delete"
3. Confirm
4. ✅ Success!

---

## 💡 Key Points

| What | Blocks Deletion? |
|------|------------------|
| Active posts | ❌ YES |
| Inactive posts | ✅ NO |
| Active bookings | ❌ YES |
| Completed bookings | ✅ NO |
| Cancelled bookings | ✅ NO |
| No posts at all | ✅ NO |
| No bookings at all | ✅ NO |

---

## 🎯 Summary

**Delete is allowed ONLY when:**
- ✅ No active posts
- ✅ No active bookings

**Delete is blocked when:**
- ❌ At least 1 active post exists
- ❌ At least 1 active booking exists

**To delete a vehicle:**
1. Remove/deactivate all active posts
2. Complete/cancel all active bookings
3. Then delete the vehicle

Simple! 🚀
