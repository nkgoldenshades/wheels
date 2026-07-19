# ⭐ Review System Flow

## 🎯 When Can Users Leave Reviews?

**Answer:** Reviews are **NOT** directly tied to applying for a booking. Reviews come **AFTER** the trip is completed!

---

## 📅 Review Timeline

```
1. User books a trip
    ↓
2. Trip happens (start → end time)
    ↓
3. Trip ends (reaches end time)
    ↓
4. ✅ REVIEW BUTTON APPEARS
    ↓
5. User clicks "Leave Review"
    ↓
6. Review dialog opens
    ↓
7. User rates & comments
    ↓
8. Review saved to backend
```

---

## ✅ Review Availability Rules

### **Customer Can Review When:**

1. **Trip ended** (after end time) ✅
2. **AND ONE of these:**
   - ✅ **OTP verified** (trip completed successfully)
   - ✅ **Has GPS proof** (if trip expired without OTP)

### **Provider Can Review When:**

1. **Trip ended** (after end time) ✅
2. **AND ONE of these:**
   - ✅ **OTP verified** (trip completed successfully)
   - ✅ **Has GPS proof** (if trip expired without OTP)

---

## 🚫 When Review is BLOCKED

### **Before Trip Ends:**
```
❌ Review Button Hidden
Message: "Reviews available after trip ends (Jan 15, 6:00 PM)"
```

### **After Trip Ends BUT No Proof:**
```
⚠️ Review Button Shows Warning
Message: "Upload arrival proof photo to leave review"
```

**Why?** Prevents fake reviews from people who never showed up!

---

## 💡 Review Logic Code

```dart
bool get customerCanReview {
  // 1. Must be after trip end time
  if (DateTime.now().isBefore(tripEndTime)) {
    return false; // Trip still happening
  }
  
  // 2. If OTP verified → Can review (proof trip happened)
  if (status == BookingStatus.completed && otpVerified) {
    return true;
  }
  
  // 3. If expired without OTP → Need GPS proof
  if (status == BookingStatus.expired) {
    return tripMedia.start.customer.hasGps; // Must have arrival proof
  }
  
  return false;
}
```

---

## 🎨 UI Flow

### **During Trip:**
```
┌─────────────────────────┐
│ ⏰ Trip in progress     │
│                         │
│ Starts: 10:00 AM        │
│ Ends: 6:00 PM           │
│                         │
│ [Upload Arrival Photo]  │
│                         │
│ (No review button yet)  │
└─────────────────────────┘
```

### **After Trip Ends (With OTP):**
```
┌─────────────────────────┐
│ ✅ Trip completed       │
│                         │
│ OTP verified            │
│ Payment released        │
│                         │
│ [⭐ Leave Review]       │  ← APPEARS NOW
└─────────────────────────┘
```

### **After Trip Ends (Without OTP):**
```
┌─────────────────────────┐
│ ⚠️ Trip expired         │
│                         │
│ No OTP entered          │
│                         │
│ ✅ Has arrival photo    │
│                         │
│ [⭐ Leave Review]       │  ← APPEARS (has GPS proof)
└─────────────────────────┘
```

### **After Trip Ends (No Proof):**
```
┌─────────────────────────┐
│ ⚠️ Trip expired         │
│                         │
│ No OTP entered          │
│ No arrival photo        │
│                         │
│ [⚠️ Upload Proof First] │  ← BLOCKED (no proof)
│                         │
│ "Upload arrival proof   │
│  photo to leave review" │
└─────────────────────────┘
```

---

## 📊 Review System Benefits

### **Prevents Fake Reviews:**
- ✅ Can't review if you never showed up
- ✅ Must have OTP OR GPS proof
- ✅ Can't review before trip ends

### **Fair to Both Parties:**
- ✅ Customer reviews provider
- ✅ Provider reviews customer
- ✅ Both need proof of participation

### **Builds Trust:**
- ✅ Only real participants can review
- ✅ Verified reviews (OTP or GPS)
- ✅ Reviews appear on profile

---

## 🎯 Example Scenarios

### **Scenario 1: Successful Trip**
```
1. Customer books ride (10 AM - 6 PM)
2. Provider arrives, customer gets in
3. Trip happens normally
4. Provider enters OTP at end
5. Payment released to provider
6. ✅ Review button appears for BOTH
7. Both can leave reviews
```

### **Scenario 2: Customer No-Show**
```
1. Customer books ride
2. Provider arrives and waits
3. Customer never shows up
4. Provider takes arrival photo (GPS proof)
5. Trip expires (no OTP)
6. ✅ Provider can review customer (has GPS)
7. ❌ Customer CANNOT review (no GPS proof)
```

### **Scenario 3: Provider No-Show**
```
1. Customer books ride
2. Customer arrives at pickup
3. Provider never shows up
4. Customer takes arrival photo (GPS proof)
5. Trip expires (no OTP)
6. ✅ Customer can review provider (has GPS)
7. ❌ Provider CANNOT review (no GPS proof)
```

---

## 🔄 Complete Booking → Review Flow

```
┌──────────────────────────────────────┐
│ 1. BOOKING CREATED                   │
│    - Payment held in escrow          │
│    - Status: "pending"               │
└──────────────────────────────────────┘
              ↓
┌──────────────────────────────────────┐
│ 2. TRIP STARTS                       │
│    - Start time reached              │
│    - Both parties upload photos      │
│    - Status: "in_progress"           │
└──────────────────────────────────────┘
              ↓
┌──────────────────────────────────────┐
│ 3. TRIP ENDS                         │
│    - End time reached                │
│    - OTP entered (if successful)     │
│    - Status: "completed" or "expired"│
└──────────────────────────────────────┘
              ↓
┌──────────────────────────────────────┐
│ 4. REVIEW ENABLED ⭐                 │
│    - Review button appears           │
│    - Both can leave reviews          │
│    - (if they have proof)            │
└──────────────────────────────────────┘
              ↓
┌──────────────────────────────────────┐
│ 5. REVIEW SUBMITTED                  │
│    - Rating (1-5 stars)              │
│    - Comment (optional)              │
│    - Saved to backend                │
│    - Appears on reviewee's profile   │
└──────────────────────────────────────┘
```

---

## 🎨 Review Dialog

When user clicks "Leave Review":

```
┌─────────────────────────────────────┐
│ Leave Review                    [X] │
├─────────────────────────────────────┤
│                                     │
│ How was your experience?            │
│                                     │
│ ⭐⭐⭐⭐⭐                          │
│ (Tap to rate)                       │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ Write a comment (optional)      │ │
│ │                                 │ │
│ │                                 │ │
│ └─────────────────────────────────┘ │
│                                     │
│         [Cancel]  [Submit Review]   │
└─────────────────────────────────────┘
```

---

## 🗄️ Backend Storage

**Table: `reviews`**

```sql
INSERT INTO reviews (
  id,
  booking_id,
  reviewer_id,      -- Who left the review
  reviewee_id,      -- Who is being reviewed
  rating,           -- 1-5 stars
  comment,
  type,             -- 'user_to_provider' or 'provider_to_user'
  created_at
) VALUES (
  'review_123',
  'booking_456',
  'customer_xyz',
  'provider_abc',
  5.0,
  'Great service!',
  'user_to_provider',
  NOW()
);
```

---

## ✅ Summary

**Reviews appear AFTER trip ends, not during application!**

### **Timeline:**
1. Apply for booking → Booking created
2. Trip happens → Photos uploaded
3. Trip ends → OTP entered (if successful)
4. **Review button appears** ← THIS IS WHEN!
5. User leaves review

### **Requirements to Review:**
- ✅ Trip must have ended
- ✅ Must have OTP OR GPS proof
- ✅ Can review once per booking

### **Benefits:**
- ✅ Prevents fake reviews
- ✅ Fair to both parties
- ✅ Builds trust in platform
- ✅ Only real participants can review

**Your review system is perfectly designed!** 🎉
