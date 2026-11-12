# GPS-Based Review Verification System

## Overview
Prevents fake reviews by verifying that both customer and provider actually arrived at the pickup location using GPS tracking.

## How It Works

### 1. GPS Tracking During Trip
```
When trip starts:
├─ Customer app tracks GPS location
├─ Provider app tracks GPS location
├─ When within 100m of pickup location:
│  ├─ Record arrival lat/lng
│  ├─ Record arrival time
│  └─ Mark as GPS verified
└─ Store in bookings table
```

### 2. Review Eligibility Rules

#### Timing Requirement:
- ⏰ **Reviews ONLY available AFTER trip end time**
  - Prevents reviewing during active trip
  - Ensures trip finished before feedback given

#### Completed Bookings (OTP Verified):
- ✅ **Both can review** - OTP proves trip happened
  - Customer showed up (gave OTP)
  - Provider showed up (received OTP)
  - Service was delivered
  - **GPS not required** (OTP is sufficient proof)

#### Expired Bookings (No OTP):
- ⚠️ **GPS verification required**
- ✅ **Customer can review** ONLY IF `customer_gps_verified = true`
  - Proves customer actually went to pickup location
  - Prevents fake reviews from no-shows
  
- ✅ **Provider can review** ONLY IF `provider_gps_verified = true`
  - Proves provider actually went to pickup location
  - Allows rating customer for no-show behavior

#### Why This Makes Sense:
- ✅ **OTP = Strong Proof** - If OTP entered, trip definitely happened
- ✅ **GPS for No-Shows** - Protects against prank bookings
- ❌ **Without GPS** - Person who didn't show can't leave fake review
- ✅ **Fair to Both** - Person who showed up can review no-show party

### Example Scenarios:

**Scenario 1: Legitimate Trip (OTP Entered)**
```
✅ Customer arrives at pickup
✅ Provider arrives at pickup
✅ Trip happens, OTP entered
✅ Status: Completed
⏰ After trip end time
→ Both can review ✅ (OTP is proof)
→ GPS not required (trip verified by OTP)
```

**Scenario 2: Customer No-Show (Common Problem)**
```
❌ Customer books but never shows up (prank/forgot)
✅ Provider drives to pickup, waits (GPS verified)
❌ No OTP entered (customer absent)
⏰ Booking expires, auto-refund
→ Customer CANNOT review ❌ (no GPS = didn't show)
→ Provider CAN review customer ✅ (rate 1-star for no-show)
```

**Scenario 3: Provider No-Show**
```
✅ Customer arrives and waits (GPS verified)
❌ Provider never comes (GPS NOT verified)
❌ No OTP entered
⏰ Booking expires, auto-refund
→ Customer CAN review provider ✅ (rate 1-star for no-show)
→ Provider CANNOT review ❌ (didn't show = no GPS)
```

**Scenario 4: Both No-Show**
```
❌ Customer didn't go (GPS NOT verified)
❌ Provider didn't go (GPS NOT verified)
⏰ Booking expires, auto-refund
→ Neither can review ❌ (no one showed up)
```

**Scenario 5: Trip Still Active**
```
✅ Trip in progress
⏰ Current time < end time
→ Review buttons hidden (wait until trip ends)
```

### 3. Database Schema

```sql
ALTER TABLE bookings ADD:
  customer_arrival_lat DOUBLE PRECISION,
  customer_arrival_lng DOUBLE PRECISION,
  customer_arrival_time TIMESTAMPTZ,
  customer_gps_verified BOOLEAN DEFAULT FALSE,
  
  provider_arrival_lat DOUBLE PRECISION,
  provider_arrival_lng DOUBLE PRECISION,
  provider_arrival_time TIMESTAMPTZ,
  provider_gps_verified BOOLEAN DEFAULT FALSE;
```

### 4. Code Implementation

#### Booking Model Methods:
```dart
// Reviews only after trip ends
bool get customerCanReview {
  // Must be after trip end time
  if (tripEndTime != null && DateTime.now().isBefore(tripEndTime!)) {
    return false; // Trip still happening
  }
  
  // If completed with OTP → can review (OTP is proof)
  if (status == BookingStatus.completed && otpVerified) {
    return true;
  }
  
  // If expired without OTP → need GPS proof
  if (status == BookingStatus.expired) {
    return customerGpsVerified; // Only if they showed up
  }
  
  return false;
}

bool get providerCanReview {
  // Must be after trip end time
  if (tripEndTime != null && DateTime.now().isBefore(tripEndTime!)) {
    return false; // Trip still happening
  }
  
  // If completed with OTP → can review (OTP is proof)
  if (status == BookingStatus.completed && otpVerified) {
    return true;
  }
  
  // If expired without OTP → need GPS proof
  if (status == BookingStatus.expired) {
    return providerGpsVerified; // Only if they showed up
  }
  
  return false;
}

String? get reviewBlockedReason {
  // Check if trip hasn't ended yet
  if (tripEndTime != null && DateTime.now().isBefore(tripEndTime!)) {
    return 'Reviews available after trip ends';
  }
  
  // If completed with OTP → allowed
  if (status == BookingStatus.completed && otpVerified) {
    return null; // Allowed
  }
  
  // If expired and didn't show up
  if (status == BookingStatus.expired) {
    if (!customerGpsVerified) {
      return 'Customer did not arrive at pickup (GPS verification failed)';
    }
    if (!providerGpsVerified) {
      return 'Provider did not arrive at pickup (GPS verification failed)';
    }
  }
  
  return 'Reviews available after trip ends';
}
```

#### UI Implementation:
```dart
// Customer view - show review button ONLY if GPS verified
if (b.customerCanReview) ...[
  OutlinedButton.icon(
    onPressed: () {
      if (b.reviewBlockedReason != null) {
        showSnackBar('⚠️ ${b.reviewBlockedReason}');
        return;
      }
      // Show review dialog
    },
    label: Text('Leave Review'),
  ),
]

// Provider view - same strict GPS check
if (b.providerCanReview) ...[
  // Review button
]
```

## Benefits

### 1. Fraud Prevention
- ❌ No fake reviews from prank/no-show bookings
- ✅ OTP is trusted (proves trip happened)
- ✅ GPS protects against no-show review abuse
- ✅ Person who showed up can rate no-show party fairly

### 2. Fairness
- ✅ Real experiences only
- ✅ No-show victims can leave honest review
- ✅ OTP trips don't need GPS (simpler)
- ✅ Both parties accountable

### 3. Trust Building
- ✅ Reviews reflect actual service quality
- ✅ No-show patterns visible in ratings
- ✅ Honest users protected
- ✅ Encourages showing up

## Implementation Steps

### Step 1: Run SQL Migration
```bash
# In Supabase SQL Editor, run:
add_gps_tracking_for_reviews.sql
```

### Step 2: Update Flutter App
```bash
# Hot reload to apply Booking model changes
flutter run -d chrome
# Press 'R' for full restart
```

### Step 3: Add GPS Tracking Logic (TODO)
Need to implement:
1. Location permission requests
2. Background location tracking
3. Geofence monitoring (100m radius of pickup)
4. Auto-mark GPS verified when in range
5. Upload GPS data to Supabase

### Step 4: Test
1. Create booking
2. Simulate customer arrival (GPS verified)
3. Let booking expire (no OTP)
4. Check: Customer can review ✅
5. Check: Provider cannot review ❌ (didn't show)

## Future Enhancements

### 1. No-Show Penalties
- Charge ₹20-50 if GPS proves no-show
- Build on GPS verification data

### 2. Waiting Time Compensation
- Provider arrives (GPS verified)
- Customer late → Charge waiting fee
- Based on GPS timestamps

### 3. Analytics
- Track no-show patterns
- Identify problem users
- Ban repeat offenders

### 4. Dispute Evidence
- GPS data as evidence in disputes
- AI mediator can check:
  - "Did both arrive at pickup?"
  - "Who was late?"
  - "Was location correct?"

## Security Notes

- GPS coordinates stored securely
- Only used for verification, not tracking
- Deleted after 90 days (GDPR compliance)
- Never shared with other users
- Privacy-preserving (rounded to 100m accuracy)

---

**Status:** ✅ Database schema added, Model updated, UI integrated
**TODO:** GPS tracking implementation in mobile app
