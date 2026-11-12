# Frontend Testing Checklist - OTP System

## 📋 Quick Testing Guide

### Prerequisites
- [ ] Backend team confirmed they ran `FIX_VERIFY_OTP_FUNCTION.sql`
- [ ] App is connected to the correct Supabase project
- [ ] You have a test account to create bookings

---

## Test Case 1: Wrong OTP (Basic)
**Time**: 1 minute

### Steps:
1. Open the app
2. Create a booking
3. Note the OTP shown (e.g., "123456")
4. Enter a different OTP (e.g., "999999")
5. Tap "Verify"

### Expected Results:
- [ ] Red snackbar appears
- [ ] Message: "Incorrect OTP. Please try again."
- [ ] No crash or error
- [ ] OTP input field remains editable

### If Failed:
- Check console for `🔐 Verifying OTP` logs
- Verify booking ID is correct
- Confirm backend fix was applied

---

## Test Case 2: Locking After 5 Attempts
**Time**: 2 minutes

### Steps:
1. Create a new booking
2. Note the correct OTP
3. Enter wrong OTP: "111111" → Tap Verify
4. Enter wrong OTP: "222222" → Tap Verify
5. Enter wrong OTP: "333333" → Tap Verify
6. Enter wrong OTP: "444444" → Tap Verify
7. Enter wrong OTP: "555555" → Tap Verify (5th attempt)
8. Try entering the CORRECT OTP → Tap Verify

### Expected Results:
- [ ] First 4 attempts: "Incorrect OTP. Please try again."
- [ ] 5th attempt: "Too many failed attempts. Booking is locked."
- [ ] 6th attempt (correct OTP): Still shows "locked" message
- [ ] Booking cannot be verified anymore

### If Failed:
- **Most likely**: Backend fix not applied yet
- Ask backend team to confirm they ran the SQL fix
- Check Supabase database: `SELECT otp_attempts, otp_locked FROM bookings WHERE id = <booking_id>`

---

## Test Case 3: Correct OTP (Happy Path)
**Time**: 1 minute

### Steps:
1. Create a new booking
2. Note the OTP (e.g., "789012")
3. Enter the CORRECT OTP
4. Tap "Verify"

### Expected Results:
- [ ] Green snackbar appears
- [ ] Message: "OTP verified successfully!"
- [ ] Booking status changes to "Completed"
- [ ] OTP input field becomes disabled or hidden
- [ ] Review prompt may appear (if implemented)

### If Failed:
- Check if OTP matches exactly (6 digits)
- Verify booking ID is correct
- Check console logs for errors

---

## Test Case 4: Already Verified
**Time**: 1 minute

### Steps:
1. Use a booking that was already verified in Test Case 3
2. Try to verify again with the same OTP
3. Tap "Verify"

### Expected Results:
- [ ] Red snackbar appears
- [ ] Message: "OTP already verified"
- [ ] No changes to booking status

### If Failed:
- Check if booking status is actually "Completed"
- Verify `otp_verified` is TRUE in database

---

## Test Case 5: Booking Not Found
**Time**: 1 minute

### Steps:
1. Create a booking
2. Delete it from Supabase database manually
3. Try to verify the OTP in the app

### Expected Results:
- [ ] Red snackbar appears
- [ ] Message: "Booking not found"
- [ ] No crash

### If Failed:
- Check error handling in code
- Verify booking ID is being sent correctly

---

## Test Case 6: Multiple Bookings
**Time**: 2 minutes

### Steps:
1. Create booking A
2. Create booking B
3. Verify booking A with correct OTP
4. Try to verify booking A again
5. Verify booking B with wrong OTP 3 times
6. Verify booking B with correct OTP

### Expected Results:
- [ ] Booking A verifies successfully
- [ ] Booking A shows "already verified" on retry
- [ ] Booking B shows "wrong OTP" 3 times
- [ ] Booking B verifies successfully after correct OTP
- [ ] No interference between bookings

### If Failed:
- Check if booking IDs are unique
- Verify state management is correct

---

## Test Case 7: Provider View (If Applicable)
**Time**: 2 minutes

### Steps:
1. Switch to provider account
2. View a booking where you're the provider
3. Ask customer for their OTP (or use test account)
4. Enter wrong OTP 2 times
5. Enter correct OTP

### Expected Results:
- [ ] Provider can verify customer's OTP
- [ ] Wrong OTP shows error message
- [ ] Correct OTP releases payment (if escrow enabled)
- [ ] Booking status updates

### If Failed:
- Check if provider has permission to verify
- Verify `profile_provider_id` matches

---

## Test Case 8: Edge Cases
**Time**: 3 minutes

### Test 8a: Empty OTP
- Enter nothing → Tap Verify
- [ ] Expected: "Please enter 6-digit OTP"

### Test 8b: Short OTP
- Enter "123" → Tap Verify
- [ ] Expected: "Please enter 6-digit OTP"

### Test 8c: Long OTP
- Enter "1234567" → Tap Verify
- [ ] Expected: Input limited to 6 digits OR validation error

### Test 8d: Non-numeric OTP
- Enter "abcdef" → Tap Verify
- [ ] Expected: Keyboard prevents letters OR validation error

### Test 8e: Network Error
- Turn off internet → Try to verify
- [ ] Expected: "An error occurred. Please try again."

---

## Console Logs to Check

### Successful Verification:
```
🔐 Verifying OTP for booking 123
   User ID: user-abc
   Entered OTP: 123456
✅ OTP verification result: success
```

### Wrong OTP:
```
🔐 Verifying OTP for booking 123
   User ID: user-abc
   Entered OTP: 999999
✅ OTP verification result: wrong_otp
```

### Locked:
```
🔐 Verifying OTP for booking 123
   User ID: user-abc
   Entered OTP: 123456
✅ OTP verification result: locked
```

---

## Database Verification (Optional)

If you have access to Supabase, check the database:

```sql
-- Check a specific booking
SELECT 
  id,
  otp_code,
  otp_attempts,
  otp_locked,
  otp_verified,
  otp_verified_at
FROM bookings
WHERE id = <booking_id>;
```

### Expected Values:
- After 1 wrong attempt: `otp_attempts = 1`, `otp_locked = false`
- After 5 wrong attempts: `otp_attempts = 5`, `otp_locked = true`
- After verification: `otp_verified = true`, `otp_attempts = null`

---

## Summary Checklist

### Must Pass:
- [ ] Test Case 1: Wrong OTP shows error
- [ ] Test Case 2: Locking after 5 attempts
- [ ] Test Case 3: Correct OTP verifies
- [ ] Test Case 4: Already verified message

### Should Pass:
- [ ] Test Case 5: Booking not found
- [ ] Test Case 6: Multiple bookings
- [ ] Test Case 8: Edge cases

### Optional:
- [ ] Test Case 7: Provider view

---

## Reporting Issues

If any test fails, provide:
1. **Test case number** (e.g., "Test Case 2 failed")
2. **Steps to reproduce**
3. **Expected result**
4. **Actual result**
5. **Console logs** (copy the `🔐 Verifying OTP` section)
6. **Screenshots** (if UI issue)

### Example Issue Report:
```
Test Case 2 Failed: Locking not working

Steps:
1. Created booking ID 456
2. Entered wrong OTP 5 times
3. Tried correct OTP

Expected: "Too many failed attempts. Booking is locked."
Actual: "OTP verified successfully!" (should be locked)

Console logs:
🔐 Verifying OTP for booking 456
✅ OTP verification result: success

Database check:
otp_attempts = 0 (should be 5)
otp_locked = false (should be true)

Conclusion: Backend fix not applied
```

---

## Quick Test (30 seconds)

If you only have 30 seconds:
1. Create booking
2. Enter wrong OTP 5 times
3. Check if it locks

✅ If it locks → System working  
❌ If it doesn't lock → Backend fix not applied

---

## Sign-off

After all tests pass:
- [ ] All critical tests passed
- [ ] No crashes or errors
- [ ] Error messages display correctly
- [ ] Locking works after 5 attempts
- [ ] Ready for production

**Tested by**: _______________  
**Date**: _______________  
**App version**: _______________  
**Backend version**: _______________
