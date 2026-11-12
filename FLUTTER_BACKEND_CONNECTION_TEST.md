# Flutter Backend Connection Test

## 🔍 Verify Everything is Connected

Run these tests to ensure Flutter is properly connected to the backend OTP system.

---

## Test 1: Check Supabase Connection

```dart
// In your Flutter app (e.g., in a test button)
Future<void> testSupabaseConnection() async {
  try {
    final supabase = Supabase.instance.client;
    
    // Test 1: Can we call the verify_otp function?
    final response = await supabase.rpc(
      'verify_otp',
      params: {
        'p_booking_id': 999999,  // Non-existent ID
        'p_profile_customer_id': 'test-user',
        'p_entered_otp': '000000',
      },
    );
    
    print('✅ Supabase RPC works: $response');
    // Expected: 'not_found' (because booking doesn't exist)
    
  } catch (e) {
    print('❌ Supabase connection error: $e');
  }
}
```

**Expected Output:**
```
✅ Supabase RPC works: not_found
```

**If you get an error:**
- ❌ "Function verify_otp does not exist" → Run `CREATE_OTP_VERIFICATION_FUNCTION.sql`
- ❌ "Permission denied" → Check function permissions
- ❌ "Network error" → Check Supabase URL and API key

---

## Test 2: Test OTP Generation on Booking Creation

```dart
Future<void> testOtpGeneration() async {
  try {
    final booking = await BookingRepository.instance.createBooking(
      slotId: "your-real-slot-id",  // Use a real slot from your app
      providerId: "provider-id",
      userId: AuthRepository.instance.currentUser!.id,
      price: 100.00,
      defaultCapacity: 4,
      postMode: PostMode.instant,
      serviceType: ServiceType.passenger,
    );
    
    if (booking != null) {
      print('✅ Booking created: ID=${booking.id}');
      print('✅ OTP generated: ${booking.otp}');
      
      if (booking.otp != null && booking.otp!.length == 6) {
        print('✅ OTP is valid 6-digit code');
      } else {
        print('❌ OTP is invalid: ${booking.otp}');
      }
    } else {
      print('❌ Booking creation failed');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
```

**Expected Output:**
```
✅ Booking synced to Supabase: ID=23, OTP=625265
✅ Booking created: ID=23
✅ OTP generated: 625265
✅ OTP is valid 6-digit code
```

**If OTP is NULL:**
- ❌ Trigger not installed → Run `INSTALL_OTP_TRIGGER_CORRECTED.sql`
- ❌ Trigger disabled → Run `ALTER TABLE bookings ENABLE TRIGGER booking_otp_trigger;`
- ❌ Sync failed → Check logs for "Failed to sync booking to Supabase"

---

## Test 3: Test OTP Verification

```dart
Future<void> testOtpVerification(String bookingId, String userId, String otp) async {
  try {
    // Test wrong OTP
    print('Testing wrong OTP...');
    final wrongResult = await OtpService().verifyOtp(
      bookingId: int.parse(bookingId),
      userId: userId,
      enteredOtp: '999999',  // Wrong OTP
    );
    
    print('Wrong OTP result: ${wrongResult.message}');
    // Expected: "Incorrect OTP. Please try again."
    
    // Test correct OTP
    print('Testing correct OTP...');
    final correctResult = await OtpService().verifyOtp(
      bookingId: int.parse(bookingId),
      userId: userId,
      enteredOtp: otp,  // Correct OTP
    );
    
    print('Correct OTP result: ${correctResult.message}');
    // Expected: "OTP verified successfully!"
    
    if (correctResult.isSuccess) {
      print('✅ OTP verification works correctly!');
    } else {
      print('❌ OTP verification failed: ${correctResult.message}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
```

**Expected Output:**
```
Testing wrong OTP...
🔐 Verifying OTP for booking 23
✅ OTP verification result: wrong_otp
Wrong OTP result: Incorrect OTP. Please try again.

Testing correct OTP...
🔐 Verifying OTP for booking 23
✅ OTP verification result: success
Correct OTP result: OTP verified successfully!
✅ OTP verification works correctly!
```

**If you get "booking not found":**
- ❌ Booking ID mismatch → Check if booking.id is updated with Supabase ID
- ❌ Booking not synced → Check Supabase table for the booking

---

## Test 4: Test 5-Attempt Limit

```dart
Future<void> testAttemptLimit(String bookingId, String userId) async {
  try {
    print('Testing 5-attempt limit...');
    
    for (int i = 1; i <= 6; i++) {
      final result = await OtpService().verifyOtp(
        bookingId: int.parse(bookingId),
        userId: userId,
        enteredOtp: '000000',  // Wrong OTP
      );
      
      print('Attempt $i: ${result.message}');
      
      if (result.isLocked) {
        print('✅ Booking locked after $i attempts');
        break;
      }
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
```

**Expected Output:**
```
Testing 5-attempt limit...
Attempt 1: Incorrect OTP. Please try again.
Attempt 2: Incorrect OTP. Please try again.
Attempt 3: Incorrect OTP. Please try again.
Attempt 4: Incorrect OTP. Please try again.
Attempt 5: Too many failed attempts. Booking is locked.
✅ Booking locked after 5 attempts
```

---

## Test 5: Check Database Directly

Run this in Supabase SQL Editor:

```sql
-- Check recent bookings
SELECT 
  id,
  profile_customer_id,
  otp_code,
  otp_attempts,
  otp_locked,
  otp_verified,
  created_at
FROM public.bookings
ORDER BY created_at DESC
LIMIT 5;
```

**What to check:**
- ✅ `otp_code` is 6-digit number (not NULL)
- ✅ `otp_attempts` is NULL or 0-5
- ✅ `otp_locked` is false (unless 5+ attempts)
- ✅ `otp_verified` is false (until verified)

---

## Complete Connection Checklist

Run through this checklist:

### Backend (Supabase):
- [ ] Run `VERIFY_BACKEND_CONNECTION.sql` - All steps pass
- [ ] Functions exist: `generate_otp`, `set_booking_otp`, `verify_otp`
- [ ] Trigger exists: `booking_otp_trigger`
- [ ] Trigger is enabled
- [ ] Permissions granted to `anon` and `authenticated`

### Flutter App:
- [ ] `OtpService` imported in files that use it
- [ ] `booking_repository.dart` uses backend verification
- [ ] `main.dart` shows specific error messages
- [ ] Booking model has `id` parameter in `copyWith()`
- [ ] Booking ID is updated with Supabase ID after sync

### Integration:
- [ ] Test 1: Supabase RPC works
- [ ] Test 2: OTP generated on booking creation
- [ ] Test 3: OTP verification works (wrong + correct)
- [ ] Test 4: 5-attempt limit works
- [ ] Test 5: Database shows correct data

---

## 🚨 Common Issues

### Issue 1: "Function verify_otp does not exist"
**Solution:** Run `CREATE_OTP_VERIFICATION_FUNCTION.sql` in Supabase

### Issue 2: OTP is NULL
**Solution:** Run `INSTALL_OTP_TRIGGER_CORRECTED.sql` in Supabase

### Issue 3: "Booking not found"
**Solution:** Check if booking.id is updated with Supabase ID (should be fixed now)

### Issue 4: "Permission denied"
**Solution:** Run `GRANT EXECUTE ON FUNCTION verify_otp(BIGINT, TEXT, TEXT) TO anon, authenticated;`

### Issue 5: Attempts not incrementing
**Solution:** Check if using `OtpService().verifyOtp()` instead of local verification

---

## 📊 Success Criteria

All these should work:

✅ Create booking → OTP auto-generated (6 digits)  
✅ Wrong OTP → "Incorrect OTP. Please try again."  
✅ 5 wrong attempts → "Too many failed attempts. Booking is locked."  
✅ Correct OTP → "OTP verified successfully!"  
✅ Database shows: otp_verified = true, otp_attempts = NULL  

---

**Run these tests to verify everything is connected!** 🔍
