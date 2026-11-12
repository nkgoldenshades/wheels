# 🔐 GPS Spoofing Prevention for Refunds

## ❌ THE PROBLEM

**Providers can fake their location to avoid refunds!**

### How the exploit works:
1. Provider sets vehicle GPS mode to "Manual"
2. Provider manually enters fake coordinates near pickup location
3. System thinks provider arrived → no refund for customer
4. Customer loses money even though provider never showed up

### Current vulnerability:
- `VehicleGpsMode.manual` allows providers to enter ANY lat/lng
- GPS verification only checks distance, not authenticity
- No way to distinguish real device GPS from manual input

---

## ✅ THE SOLUTION

### Approach: Track GPS Source in Trip Media

Add `gps_source` field to trip_media JSON to distinguish:
- `device` = Real-time GPS from Geolocator (TRUSTED ✅)
- `manual` = Manual coordinates (UNTRUSTED ❌)
- `external` = External GPS link (PARTIALLY TRUSTED ⚠️)

### Implementation Steps:

#### 1. Update Trip Media Model
Add `gpsSource` field to `TripMediaPhoto` class:

```dart
// lib/models/trip_media.dart
enum GpsSource {
  device,    // Real GPS from Geolocator - TRUSTED
  manual,    // Manual coordinates - NOT TRUSTED
  external,  // External GPS link - PARTIALLY TRUSTED
  unknown,   // Legacy data or no GPS
}

class TripMediaPhoto {
  final double? gpsLat;
  final double? gpsLng;
  final DateTime? gpsTimestamp;
  final GpsSource gpsSource; // NEW FIELD

  // ... rest of class
}
```

#### 2. Update Geofencing Service
Mark geofencing GPS as `device` source:

```dart
// lib/services/geofencing_service.dart
final LocationConfirmationParty updatedParty = LocationConfirmationParty(
  gpsLat: lat,
  gpsLng: lng,
  timestamp: now,
  gpsSource: GpsSource.device, // ✅ TRUSTED GPS
  isConfirmed: true,
);
```

#### 3. Update Refund Logic
Only allow refund if provider GPS is from `device` source:

```dart
// lib/services/booking_repository.dart
Future<Map<String, dynamic>> markRefundedWithVerification({
  required String bookingId,
  required bool customerAtLocation,
}) async {
  final booking = bookings.value.firstWhere((b) => b.id == bookingId);
  
  // ✅ CHECK GPS SOURCE
  final providerGps = booking.tripMedia.start.provider;
  final providerGpsIsTrusted = providerGps.gpsSource == GpsSource.device;
  
  // ❌ REJECT MANUAL GPS
  if (providerGps.hasGps && !providerGpsIsTrusted) {
    return {
      'success': false,
      'message': 'Provider used manual GPS. Cannot verify real arrival.',
    };
  }
  
  // Determine refund type
  final refundType = customerAtLocation && !providerGpsIsTrusted
      ? 'full_with_deposit' // Customer was there, provider no-show
      : 'standard';
  
  // ... rest of refund logic
}
```

#### 4. Update Database Function
Add GPS source validation to `refund_booking_with_location`:

```sql
CREATE OR REPLACE FUNCTION refund_booking_with_location(
  booking_id INT,
  user_id UUID,
  refund_type TEXT,
  customer_location_verified BOOLEAN
)
RETURNS JSONB AS $$
DECLARE
  booking_row bookings%ROWTYPE;
  provider_gps_source TEXT;
BEGIN
  -- Get booking
  SELECT * INTO booking_row FROM bookings WHERE id = booking_id;
  
  -- Extract provider GPS source from trip_media
  provider_gps_source := booking_row.trip_media->'start'->'provider'->>'gps_source';
  
  -- ❌ REJECT if provider used manual GPS
  IF provider_gps_source = 'manual' THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Provider location was manually entered. Cannot verify real arrival.'
    );
  END IF;
  
  -- ✅ ALLOW if provider GPS is from device OR provider has no GPS
  IF provider_gps_source = 'device' OR provider_gps_source IS NULL THEN
    -- Process refund...
  END IF;
END;
$$ LANGUAGE plpgsql;
```

---

## 🎯 REFUND RULES WITH GPS SOURCE

| Customer GPS | Provider GPS | Provider GPS Source | Refund Amount |
|-------------|-------------|-------------------|---------------|
| ✅ Verified | ❌ No GPS | N/A | Full + Deposit |
| ✅ Verified | ✅ Has GPS | `manual` | Full + Deposit (provider faked it) |
| ✅ Verified | ✅ Has GPS | `device` | Standard (both showed up) |
| ❌ No GPS | ✅ Has GPS | `device` | No Refund (customer didn't show) |
| ❌ No GPS | ❌ No GPS | N/A | Standard (neither showed) |

---

## 🚀 MIGRATION PLAN

### Phase 1: Add GPS Source Field (Non-breaking)
1. Update models to include `gpsSource` field with default `GpsSource.unknown`
2. Update geofencing service to mark GPS as `device`
3. Deploy app - existing data continues to work

### Phase 2: Update Refund Logic
1. Update refund functions to check GPS source
2. Reject refunds where provider used `manual` GPS
3. Show clear message: "Provider location was manually entered"

### Phase 3: UI Warnings
1. Show warning when provider sets vehicle to "Manual GPS" mode
2. Add tooltip: "Manual GPS may affect dispute resolution"
3. Encourage providers to use device GPS for accountability

---

## 🛡️ SECURITY BENEFITS

1. **Prevents GPS spoofing** - Providers can't fake arrival
2. **Fair refunds** - Customers get refunds when provider no-shows
3. **Accountability** - Clear evidence of who was at location
4. **Audit trail** - GPS source is stored for dispute resolution

---

## ⚠️ EDGE CASES

### What if provider's device GPS is broken?
- Provider can still use manual GPS for navigation
- But for refund verification, they must use device GPS
- Alternative: Use external GPS tracker (marked as `external`)

### What about legacy bookings?
- Existing data will have `gpsSource = unknown`
- Refund logic treats `unknown` as `device` for backwards compatibility
- Only reject refunds where source is explicitly `manual`

---

## 📝 SUMMARY

**Before Fix:**
- ❌ Providers can fake GPS location
- ❌ Customers lose money when provider no-shows
- ❌ No way to verify real arrival

**After Fix:**
- ✅ Only real device GPS counts for refunds
- ✅ Customers get full refund + deposit if provider fakes location
- ✅ Clear audit trail of GPS source
- ✅ Fair and transparent dispute resolution
