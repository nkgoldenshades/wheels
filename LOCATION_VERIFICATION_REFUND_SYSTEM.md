# 📍 Location Verification + Smart Refund System

## 🎯 Your Requirement

**"Check location on time, else those who accepted/booked the post have refund button to click and get their money WITH security deposit back"**

---

## ✅ What You Currently Have

### 1. **Manual Refund Button** (Already Working!)
Located in: `lib/main.dart` (line 10710-10730)

**Current Behavior:**
- Shows "Refund" button after trip end time
- Both customer AND provider can click it
- Calls `BookingRepository.instance.markRefunded()`
- Database function handles the refund

**Problem**: Doesn't verify location or return security deposit automatically!

---

### 2. **GPS Location Tracking** (Already Implemented!)
Located in: `lib/services/booking_repository.dart`

**Current Features:**
- Tracks customer pickup GPS
- Tracks provider pickup GPS
- Stores in `trip_media` JSON column
- Has `GpsVerificationHelper.verifyCustomerPickupLocation()`

**Problem**: Not integrated with refund logic!

---

## 🚀 What Needs to Be Added

### ✨ **New Smart Refund Logic**

```
IF customer is at pickup location (GPS verified) 
AND provider doesn't show up (OTP not entered)
AND trip start time has passed
THEN customer can click "Refund + Deposit" button
→ Get full amount back (ride price + security deposit)
```

---

## 🔧 Implementation Plan

### Step 1: Add Location Verification to Refund

**File**: `lib/services/booking_repository.dart`

**Current `markRefunded()` function**: Just marks as refunded
**New `markRefundedWithVerification()` function**: Check GPS before refund

```dart
/// Smart refund with location verification
/// Returns full amount + deposit if customer was at location
Future<Map<String, dynamic>> markRefundedWithVerification({
  required String bookingId,
  required bool customerAtLocation,  // ← New parameter
}) async {
  final currentUser = AuthRepository.instance.currentUser;
  if (currentUser == null) {
    return {'success': false, 'message': 'Not logged in'};
  }

  final booking = bookings.value.firstWhere((b) => b.id == bookingId);
  
  // 🔍 Verify customer location
  final isCustomer = booking.userId == currentUser.id;
  final gpsVerified = isCustomer && customerAtLocation;
  
  // Determine refund type
  final refundType = gpsVerified && !booking.otpVerified
      ? 'full_with_deposit'  // ← Customer was there, provider no-show
      : 'standard';          // ← Normal refund
  
  try {
    // Call enhanced database function
    final result = await Supabase.instance.client.rpc(
      'refund_booking_with_location',
      params: {
        'booking_id': int.parse(bookingId),
        'user_id': currentUser.id,
        'refund_type': refundType,
        'customer_location_verified': gpsVerified,
      },
    );

    final success = result['success'] as bool? ?? false;
    final message = result['message'] as String? ?? '';
    final refundedAmount = result['refunded_amount'] as num? ?? 0;
    final depositReturned = result['deposit_returned'] as bool? ?? false;

    if (success) {
      debugPrint('✅ Refund successful: $message');
      
      // Update local state
      bookings.value = bookings.value
          .map((b) => b.id == bookingId
              ? b.copyWith(status: BookingStatus.refunded)
              : b)
          .toList(growable: false);
      
      await _persist();
      
      return {
        'success': true,
        'message': message,
        'amount': refundedAmount,
        'deposit_returned': depositReturned,
      };
    } else {
      return {'success': false, 'message': message};
    }
  } catch (e) {
    debugPrint('❌ Refund failed: $e');
    return {'success': false, 'message': 'Refund failed: $e'};
  }
}
```

---

### Step 2: Update UI to Show Smart Refund Button

**File**: `lib/main.dart` (Update `_AutoRefundSection`)

**Current**: Simple "Refund" button
**New**: "Refund with Deposit" button (if customer verified location)

```dart
// Inside _AutoRefundSectionState.build()

// Check if customer GPS is verified
final booking = widget.booking;
final hasGpsData = booking.tripMedia?.customerGpsData != null;
final customerAtLocation = hasGpsData &&
    GpsVerificationHelper.verifyCustomerPickupLocation(booking);

// User view: Show SMART refund option
return Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // Show GPS status
    if (hasGpsData)
      Row(
        children: [
          Icon(
            customerAtLocation ? Icons.check_circle : Icons.location_off,
            size: 14,
            color: customerAtLocation ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            customerAtLocation
                ? 'You were at pickup location ✓'
                : 'Location not verified',
            style: TextStyle(
              fontSize: 11,
              color: customerAtLocation ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    
    const SizedBox(height: 8),
    
    // Refund button
    Row(
      children: [
        Icon(Icons.timer_off_outlined, size: 12, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          'Service time ended',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        const Spacer(),
        
        // Smart refund button
        InkWell(
          onTap: () async {
            // Show confirmation dialog
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Request Refund'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('You will receive:'),
                    const SizedBox(height: 8),
                    Text('• Ride price: ${AppPreferences.instance.formatMoney(booking.price.toInt())}'),
                    if (customerAtLocation && booking.securityDeposit != null)
                      Text(
                        '• Security deposit: ${AppPreferences.instance.formatMoney(booking.securityDeposit!.toInt())} ✓',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (customerAtLocation)
                      const Text(
                        '✓ Your location was verified at pickup time.',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      )
                    else
                      const Text(
                        '⚠ Location not verified. Deposit may not be refunded.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirm Refund'),
                  ),
                ],
              ),
            );

            if (confirmed != true || !context.mounted) return;

            // Show loading
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(
                child: CircularProgressIndicator(),
              ),
            );

            // Process refund with location verification
            final result = await BookingRepository.instance
                .markRefundedWithVerification(
              bookingId: booking.id,
              customerAtLocation: customerAtLocation,
            );

            if (!context.mounted) return;
            Navigator.pop(context); // Close loading

            // Show result
            final success = result['success'] as bool;
            final message = result['message'] as String;
            final depositReturned = result['deposit_returned'] as bool? ?? false;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? depositReturned
                          ? '✅ Full refund + deposit returned!'
                          : '✅ Refund processed'
                      : '❌ $message',
                ),
                backgroundColor: success ? Colors.green : Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: customerAtLocation ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.undo, size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  customerAtLocation ? 'Refund + Deposit' : 'Refund',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ],
);
```

---

### Step 3: Create Database Function

**File**: Create new SQL file `refund_with_location_verification.sql`

```sql
-- Enhanced refund function with location verification
CREATE OR REPLACE FUNCTION refund_booking_with_location(
  booking_id INTEGER,
  user_id TEXT,
  refund_type TEXT,  -- 'full_with_deposit' or 'standard'
  customer_location_verified BOOLEAN
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking RECORD;
  v_deposit_amount NUMERIC;
  v_ride_price NUMERIC;
  v_total_refund NUMERIC;
  v_deposit_returned BOOLEAN := FALSE;
BEGIN
  -- Get booking details
  SELECT * INTO v_booking
  FROM bookings
  WHERE id = booking_id;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', FALSE,
      'message', 'Booking not found'
    );
  END IF;

  -- Security: Only customer or provider can refund
  IF v_booking.profile_customer_id != user_id 
     AND v_booking.profile_provider_id != user_id THEN
    RETURN json_build_object(
      'success', FALSE,
      'message', 'Unauthorized'
    );
  END IF;

  -- Already refunded?
  IF v_booking.status = 'refunded' THEN
    RETURN json_build_object(
      'success', FALSE,
      'message', 'Already refunded'
    );
  END IF;

  -- Calculate amounts
  v_deposit_amount := COALESCE(v_booking.deposit_snapshot, 0);
  v_ride_price := v_booking.price_snapshot;

  -- Determine refund amount based on verification
  IF refund_type = 'full_with_deposit' 
     AND customer_location_verified 
     AND v_booking.profile_customer_id = user_id THEN
    -- Customer was at location, provider no-show
    -- → Return EVERYTHING (ride + deposit)
    v_total_refund := v_ride_price + v_deposit_amount;
    v_deposit_returned := TRUE;
    
    -- Mark booking as refunded with note
    UPDATE bookings
    SET 
      status = 'refunded',
      refunded_at = NOW(),
      refund_note = 'Full refund: Customer location verified, provider no-show'
    WHERE id = booking_id;

  ELSE
    -- Standard refund (ride price only, deposit logic depends on OTP)
    IF v_booking.otp_verified THEN
      -- OTP verified = trip completed, no refund
      RETURN json_build_object(
        'success', FALSE,
        'message', 'Trip completed, cannot refund'
      );
    END IF;

    -- Refund ride price only
    v_total_refund := v_ride_price;
    v_deposit_returned := FALSE;

    UPDATE bookings
    SET 
      status = 'refunded',
      refunded_at = NOW(),
      refund_note = 'Standard refund: Ride price only'
    WHERE id = booking_id;
  END IF;

  -- Free up slot capacity
  UPDATE slots
  SET remaining_capacity = remaining_capacity + 1
  WHERE id = v_booking.slot_id
    AND remaining_capacity < total_capacity;

  RETURN json_build_object(
    'success', TRUE,
    'message', 'Refund processed successfully',
    'refunded_amount', v_total_refund,
    'deposit_returned', v_deposit_returned
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', FALSE,
      'message', 'Database error: ' || SQLERRM
    );
END;
$$;
```

---

## 🎯 Complete Flow

### Scenario 1: Customer at Location, Provider No-Show ✅

```
1. Customer books ride: ₹5,000 + ₹2,000 deposit = ₹7,000 paid
2. Customer reaches pickup location on time
3. App tracks GPS: ✓ Customer at correct location
4. Provider doesn't show up
5. Trip start time passes
6. Customer sees: "You were at pickup location ✓"
7. Customer clicks: "Refund + Deposit" button
8. Confirmation dialog: "You will get ₹7,000 (ride + deposit)"
9. Database verifies: customer_location_verified = TRUE
10. ✅ Full refund: ₹7,000 returned to customer
```

**Result**: Customer gets EVERYTHING back (fair!)

---

### Scenario 2: Customer NOT at Location ⚠️

```
1. Customer books ride: ₹5,000 + ₹2,000 deposit = ₹7,000 paid
2. Customer doesn't go to pickup location
3. App checks GPS: ❌ Customer location not verified
4. Trip start time passes
5. Customer sees: "⚠ Location not verified"
6. Customer clicks: "Refund" button
7. Confirmation: "Deposit may not be refunded"
8. Database sees: customer_location_verified = FALSE
9. ✅ Partial refund: ₹5,000 (ride only), ₹2,000 kept by provider
```

**Result**: Provider keeps deposit (fair compensation!)

---

### Scenario 3: Customer Late, But Shows Up Eventually 🤔

```
1. Customer books ride at 2:00 PM
2. Pickup time: 2:30 PM
3. Customer arrives at 2:45 PM (15 mins late)
4. GPS tracked at 2:45 PM: ✓ Customer at location
5. Provider cancels (already waited too long)
6. Customer clicks refund at 2:50 PM
7. System checks: GPS verified BUT after scheduled time
8. ⚠️ Ambiguous case - may need manual review
```

**Solution**: Add time tolerance (e.g., ±10 minutes)

---

## 🔒 Security Considerations

### Prevent GPS Spoofing:
```dart
// In GpsVerificationHelper
static bool verifyCustomerPickupLocation(Booking booking) {
  final gps = booking.tripMedia?.customerGpsData;
  if (gps == null) return false;
  
  final pickupLat = booking.fromLatitude;
  final pickupLng = booking.fromLongitude;
  
  // 1. Check distance (already implemented)
  final distance = Geolocator.distanceBetween(
    gps.latitude, gps.longitude,
    pickupLat, pickupLng,
  );
  
  // 2. Check timestamp (NEW - prevent old GPS data)
  final gpsTime = gps.timestamp;
  final scheduledTime = booking.startTime;
  final timeDiff = gpsTime.difference(scheduledTime).inMinutes.abs();
  
  // GPS must be within ±15 minutes of scheduled time
  if (timeDiff > 15) return false;
  
  // 3. Check accuracy (NEW - reject inaccurate GPS)
  if (gps.accuracy > 50) return false;  // > 50 meters = suspicious
  
  return distance < 500; // 500 meters tolerance
}
```

---

## 📱 UI Mockup

```
┌──────────────────────────────────────────┐
│ Booking #1234                            │
│ ─────────────────────────────────────────│
│ From: Chennai Central                    │
│ To: Bangalore Junction                   │
│ Status: Pending                          │
│                                          │
│ ✓ You were at pickup location            │ ← GPS verified
│   (Verified at 2:28 PM)                  │
│                                          │
│ ⏱️ Service time ended                    │
│                                          │
│ [  Refund + Deposit  ]                   │ ← Green button
│                                          │
│ Expected refund: ₹7,000                  │
│ (₹5,000 ride + ₹2,000 deposit)          │
└──────────────────────────────────────────┘
```

---

## ✅ Summary

| What | Status | File |
|------|--------|------|
| Manual refund button | ✅ Already exists | `lib/main.dart` |
| GPS location tracking | ✅ Already exists | `lib/services/booking_repository.dart` |
| Location verification | ❌ Need to integrate | `GpsVerificationHelper` |
| Smart refund logic | ❌ Need to create | `markRefundedWithVerification()` |
| Database function | ❌ Need to create | `refund_with_location_verification.sql` |
| Enhanced UI | ❌ Need to update | `_AutoRefundSection` |

**Bottom line**: You have all the pieces, just need to connect them! 🔧
