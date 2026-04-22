# Backend Connection Diagram

## 🔗 Complete System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        FLUTTER APP                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ BookingRepository.createBooking()                      │    │
│  │ - Creates local booking with otp: null                 │    │
│  │ - Calls _syncBookingToSupabase()                       │    │
│  └────────────────┬───────────────────────────────────────┘    │
│                   │                                             │
│                   │ Supabase.insert(payload)                    │
│                   │ payload does NOT include otp_code           │
│                   ▼                                             │
└───────────────────┼─────────────────────────────────────────────┘
                    │
                    │ HTTPS Request
                    │
┌───────────────────▼─────────────────────────────────────────────┐
│                    SUPABASE BACKEND                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ INSERT INTO bookings (..., otp_code) VALUES (..., NULL)│    │
│  └────────────────┬───────────────────────────────────────┘    │
│                   │                                             │
│                   │ BEFORE INSERT                               │
│                   ▼                                             │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ TRIGGER: booking_otp_trigger                           │    │
│  │ - Fires BEFORE INSERT                                  │    │
│  │ - Calls set_booking_otp()                              │    │
│  └────────────────┬───────────────────────────────────────┘    │
│                   │                                             │
│                   ▼                                             │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ FUNCTION: set_booking_otp()                            │    │
│  │                                                         │    │
│  │ IF NEW.otp_code IS NULL THEN                           │    │
│  │   NEW.otp_code := generate_otp()                       │    │
│  │ END IF                                                  │    │
│  └────────────────┬───────────────────────────────────────┘    │
│                   │                                             │
│                   ▼                                             │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ FUNCTION: generate_otp()                               │    │
│  │                                                         │    │
│  │ RETURN LPAD(                                           │    │
│  │   FLOOR(RANDOM() * 900000 + 100000)::TEXT,            │    │
│  │   6, '0'                                                │    │
│  │ )                                                       │    │
│  │                                                         │    │
│  │ Result: "625265" (6-digit OTP)                         │    │
│  └────────────────┬───────────────────────────────────────┘    │
│                   │                                             │
│                   ▼                                             │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ INSERT completes with:                                 │    │
│  │ - id: 23 (auto-increment)                              │    │
│  │ - otp_code: "625265" (trigger-generated)               │    │
│  └────────────────┬───────────────────────────────────────┘    │
│                   │                                             │
│                   │ RETURNING id, otp_code                      │
│                   ▼                                             │
└───────────────────┼─────────────────────────────────────────────┘
                    │
                    │ HTTPS Response
                    │ { id: 23, otp_code: "625265" }
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                        FLUTTER APP                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ _syncBookingToSupabase() receives response            │    │
│  │ - generatedId: "23"                                    │    │
│  │ - generatedOtp: "625265"                               │    │
│  └────────────────┬───────────────────────────────────────┘    │
│                   │                                             │
│                   ▼                                             │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Update local booking:                                  │    │
│  │ booking.copyWith(                                      │    │
│  │   id: "23",         ← Updated with Supabase ID         │    │
│  │   otp: "625265"     ← Updated with generated OTP       │    │
│  │ )                                                       │    │
│  └────────────────┬───────────────────────────────────────┘    │
│                   │                                             │
│                   ▼                                             │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Booking ready with:                                    │    │
│  │ - id: "23"                                             │    │
│  │ - otp: "625265"                                        │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔐 OTP Verification Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        FLUTTER APP                               │
│                      (Provider Side)                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Provider enters OTP: "625265"                          │    │
│  └────────────────┬───────────────────────────────────────┘    │
│                   │                                             │
│                   ▼                                             │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ OtpService().verifyOtp(                                │    │
│  │   bookingId: 23,                                       │    │
│  │   userId: "user-123",                                  │    │
│  │   enteredOtp: "625265"                                 │    │
│  │ )                                                       │    │
│  └────────────────┬───────────────────────────────────────┘    │
│                   │                                             │
│                   │ Supabase.rpc('verify_otp', params)          │
│                   ▼                                             │
└───────────────────┼─────────────────────────────────────────────┘
                    │
                    │ HTTPS Request
                    │
┌───────────────────▼─────────────────────────────────────────────┐
│                    SUPABASE BACKEND                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ FUNCTION: verify_otp(23, "user-123", "625265")        │    │
│  └────────────────┬───────────────────────────────────────┘    │
│                   │                                             │
│                   ▼                                             │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ SELECT ... FROM bookings WHERE id = 23 FOR UPDATE      │    │
│  │ (Locks row to prevent race conditions)                 │    │
│  └────────────────┬───────────────────────────────────────┘    │
│                   │                                             │
│                   ▼                                             │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Security Checks:                                       │    │
│  │ 1. Booking exists? ✅                                  │    │
│  │ 2. User owns booking? ✅                               │    │
│  │ 3. Already verified? ❌                                │    │
│  │ 4. Locked (5+ attempts)? ❌                            │    │
│  └────────────────┬───────────────────────────────────────┘    │
│                   │                                             │
│                   ▼                                             │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ Compare OTP:                                           │    │
│  │ Database: "625265"                                     │    │
│  │ Entered:  "625265"                                     │    │
│  │ Match? ✅                                              │    │
│  └────────────────┬───────────────────────────────────────┘    │
│                   │                                             │
│                   ▼                                             │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ UPDATE bookings SET                                    │    │
│  │   otp_verified = TRUE,                                 │    │
│  │   otp_verified_at = NOW(),                             │    │
│  │   otp_attempts = NULL  ← Reset to save storage        │    │
│  │ WHERE id = 23                                          │    │
│  └────────────────┬───────────────────────────────────────┘    │
│                   │                                             │
│                   │ RETURN 'success'                            │
│                   ▼                                             │
└───────────────────┼─────────────────────────────────────────────┘
                    │
                    │ HTTPS Response: "success"
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                        FLUTTER APP                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ OtpVerificationResult.fromString("success")            │    │
│  └────────────────┬───────────────────────────────────────┘    │
│                   │                                             │
│                   ▼                                             │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ if (result.isSuccess) {                                │    │
│  │   showSnackBar("OTP verified successfully!")          │    │
│  │   completeBooking()                                    │    │
│  │   releasePayment()                                     │    │
│  │ }                                                       │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔗 Connection Points

### 1. Supabase Client
```dart
final _supabase = Supabase.instance.client;
```
**Connects to:** Your Supabase project URL + API key

### 2. RPC Call
```dart
await _supabase.rpc('verify_otp', params: {...});
```
**Connects to:** `verify_otp()` function in Supabase

### 3. Insert with Trigger
```dart
await supabase.from('bookings').insert(payload);
```
**Triggers:** `booking_otp_trigger` → `set_booking_otp()` → `generate_otp()`

---

## ✅ Verification Checklist

| Component | Location | Status |
|-----------|----------|--------|
| **Supabase Client** | Flutter app | ✅ Configured |
| **OtpService** | `lib/services/otp_service.dart` | ✅ Created |
| **BookingRepository** | `lib/services/booking_repository.dart` | ✅ Updated |
| **generate_otp()** | Supabase function | ✅ Installed |
| **set_booking_otp()** | Supabase function | ✅ Installed |
| **verify_otp()** | Supabase function | ✅ Installed |
| **booking_otp_trigger** | Supabase trigger | ✅ Installed |
| **Permissions** | Supabase grants | ✅ Granted |

---

**All connections are in place! Run the tests to verify.** 🔗
