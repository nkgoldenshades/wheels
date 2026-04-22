# URGENT: Fix OTP Attempts Not Incrementing

## Problem Identified
The `verify_otp` function has a potential issue with the delimiter and NULL handling that may prevent `otp_attempts` from incrementing.

## Quick Fix (Run This First)

### Step 1: Run the Fixed Function
Open Supabase SQL Editor and run `FIX_VERIFY_OTP_FUNCTION.sql`

This will:
- Fix the function delimiter ($ → $$)
- Add `SET search_path = public` for security
- Add `COALESCE` to handle NULL `otp_attempts`
- Reset attempts to NULL after successful verification

### Step 2: Test the Fix
After running the fix, test with these SQL commands:

```sql
-- 1. Create test booking
INSERT INTO public.bookings (
  profile_customer_id,
  profile_provider_id,
  post_id,
  status,
  service_type,
  total_price,
  price_snapshot,
  start_time,
  end_time,
  otp_code
) VALUES (
  'test-quick-fix',
  'test-provider',
  (SELECT id FROM public.posts ORDER BY created_at DESC LIMIT 1),
  'pending',
  'passenger',
  100.00,
  100.00,
  NOW(),
  NOW() + INTERVAL '1 hour',
  NULL
) RETURNING id, otp_code, otp_attempts;

-- 2. Test wrong OTP (should increment attempts)
SELECT verify_otp(
  (SELECT id FROM bookings WHERE profile_customer_id = 'test-quick-fix' ORDER BY created_at DESC LIMIT 1),
  'test-quick-fix',
  '999999'
);

-- 3. Check if attempts incremented to 1
SELECT 
  id,
  otp_code,
  otp_attempts,  -- Should be 1 now
  otp_locked
FROM bookings
WHERE profile_customer_id = 'test-quick-fix'
ORDER BY created_at DESC
LIMIT 1;
```

**Expected Result**: `otp_attempts` should be 1 after step 3

### Step 3: Test in Flutter App
After confirming the SQL test works:
1. Run your Flutter app
2. Create a booking
3. Try entering a wrong OTP
4. Check the console logs for:
   ```
   🔐 Verifying OTP for booking X
   ✅ OTP verification result: wrong_otp
   ```
5. Check Supabase database - `otp_attempts` should increment

## What Was Wrong?

### Issue 1: Delimiter
**Before**: `AS $`  
**After**: `AS $$`

The single `$` delimiter might cause parsing issues in some PostgreSQL versions.

### Issue 2: NULL Handling
**Before**: `otp_attempts + 1`  
**After**: `COALESCE(otp_attempts, 0) + 1`

If `otp_attempts` is NULL (which it is by default), then `NULL + 1 = NULL`. The `COALESCE` function converts NULL to 0 first.

### Issue 3: Missing search_path
**Before**: No `SET search_path`  
**After**: `SET search_path = public`

This prevents potential security issues with search path attacks.

## If This Doesn't Fix It

If the fix doesn't work, run the comprehensive debug test:

### Option A: SQL Debug Test
Run `TEST_OTP_ATTEMPTS_COMPLETE.sql` and share:
- Step 6 output (otp_attempts value)
- Step 12 output (RLS policies)
- Step 13 output (direct UPDATE test)

### Option B: Flutter Debug Test
1. Add `TEST_OTP_FLUTTER_DEBUG.dart` to your project
2. Run the test screen
3. Share the complete log output

## Files Created

1. **FIX_VERIFY_OTP_FUNCTION.sql** - Fixed function (RUN THIS FIRST)
2. **TEST_OTP_ATTEMPTS_COMPLETE.sql** - Comprehensive SQL debugging
3. **TEST_OTP_FLUTTER_DEBUG.dart** - Flutter debugging test
4. **OTP_ATTEMPTS_DEBUG_GUIDE.md** - Complete debugging guide

## Expected Behavior After Fix

1. User enters wrong OTP → `otp_attempts` = 1
2. User enters wrong OTP again → `otp_attempts` = 2
3. After 5 wrong attempts → `otp_locked` = TRUE
4. Further attempts return 'locked'
5. Correct OTP → `otp_verified` = TRUE, `otp_attempts` = NULL

## Next Steps

1. ✅ Run `FIX_VERIFY_OTP_FUNCTION.sql` in Supabase
2. ✅ Run the SQL test (steps 1-3 above)
3. ✅ Confirm `otp_attempts` increments in SQL
4. ✅ Test in Flutter app
5. ✅ Confirm `otp_attempts` increments from Flutter

## Contact

If the fix doesn't work, share:
- Output from SQL test step 3
- Flutter console logs when verifying OTP
- Any error messages from Supabase logs

The issue is likely one of:
- NULL handling (fixed by COALESCE)
- RLS policy blocking UPDATE
- Function not using SECURITY DEFINER properly
- Data type mismatch between Flutter and Supabase
