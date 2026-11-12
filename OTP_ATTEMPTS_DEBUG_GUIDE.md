# OTP Attempts Not Incrementing - Debug Guide

## Problem
User reports that `otp_attempts` is not incrementing in the database when wrong OTP is entered. It stays at 0 instead of incrementing to 1, 2, 3, etc.

## Current Status
✅ **Backend trigger installed** - Generates OTP on INSERT  
✅ **Backend function installed** - `verify_otp()` exists  
✅ **Flutter code updated** - Calls `OtpService().verifyOtp()`  
❌ **Attempts not incrementing** - Database shows 0 attempts after wrong OTP

## Possible Root Causes

### 1. RLS Policy Blocking UPDATE
**Symptom**: Function returns 'wrong_otp' but database doesn't update  
**Cause**: Row Level Security (RLS) policy on `bookings` table blocks UPDATE operations  
**Solution**: Add RLS policy to allow UPDATE or use SECURITY DEFINER

### 2. Function Not Using SECURITY DEFINER
**Symptom**: Function can't bypass RLS policies  
**Cause**: Function created without `SECURITY DEFINER` clause  
**Solution**: Recreate function with `SECURITY DEFINER`

### 3. Data Type Mismatch
**Symptom**: Function not found or parameter error  
**Cause**: Flutter sends STRING booking ID but function expects BIGINT  
**Solution**: Cast ID to int in Flutter: `int.parse(bookingId)`

### 4. Function Not Being Called
**Symptom**: No logs in Flutter console  
**Cause**: Code path not reaching `OtpService().verifyOtp()`  
**Solution**: Add debug logs and verify code execution

### 5. Wrong Column Names
**Symptom**: SQL error in function execution  
**Cause**: Function uses wrong column names  
**Solution**: Verify column names match schema

## Debugging Steps

### Step 1: Run SQL Test
Run `TEST_OTP_ATTEMPTS_COMPLETE.sql` in Supabase SQL Editor:
1. Execute each section step-by-step
2. Check if `otp_attempts` increments after Step 5
3. If it increments in SQL but not in Flutter, the issue is in Flutter
4. If it doesn't increment in SQL, the issue is in the backend

### Step 2: Check RLS Policies
```sql
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'bookings';
```

**Look for**:
- Policies with `cmd = 'UPDATE'`
- Policies that might block the UPDATE operation
- Missing policies for authenticated users

### Step 3: Verify Function Security
```sql
SELECT 
  routine_name,
  routine_type,
  security_type,
  specific_name
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'verify_otp';
```

**Expected**: `security_type = 'DEFINER'`  
**If not**: Function needs to be recreated with `SECURITY DEFINER`

### Step 4: Test Direct UPDATE
```sql
UPDATE public.bookings
SET otp_attempts = 99
WHERE id = <YOUR_BOOKING_ID>;

SELECT id, otp_attempts FROM public.bookings WHERE id = <YOUR_BOOKING_ID>;
```

**If otp_attempts is still not 99**: RLS policy is blocking UPDATE

### Step 5: Run Flutter Test
1. Add `TEST_OTP_FLUTTER_DEBUG.dart` to your project
2. Navigate to the test screen
3. Run the test
4. Check the logs for:
   - ✅ "Attempts incremented correctly" = Working
   - ❌ "Attempts did NOT increment" = Not working

### Step 6: Check Flutter Logs
When verifying OTP in your app, look for these logs:
```
🔐 Verifying OTP for booking X
   User ID: Y
   Entered OTP: Z
✅ OTP verification result: wrong_otp
```

**If you don't see these logs**: Function is not being called

## Solutions

### Solution 1: Fix RLS Policy
If RLS is blocking UPDATE, add this policy:

```sql
-- Allow users to update their own bookings
CREATE POLICY "Users can update their own bookings"
ON public.bookings
FOR UPDATE
TO authenticated
USING (profile_customer_id = auth.uid()::text)
WITH CHECK (profile_customer_id = auth.uid()::text);
```

### Solution 2: Ensure SECURITY DEFINER
Recreate function with proper security:

```sql
CREATE OR REPLACE FUNCTION verify_otp(
  p_booking_id BIGINT,
  p_profile_customer_id TEXT,
  p_entered_otp TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER  -- ← This is critical
SET search_path = public
AS $$
-- ... function body ...
$$;
```

### Solution 3: Fix Data Type Mismatch
In Flutter, ensure booking ID is converted to int:

```dart
final result = await OtpService().verifyOtp(
  bookingId: int.parse(b.id),  // ← Convert to int
  userId: b.userId,
  enteredOtp: otpText,
);
```

### Solution 4: Add Debug Logging
Add more logs to track execution:

```dart
debugPrint('🔍 About to verify OTP');
debugPrint('   Booking ID: ${b.id}');
debugPrint('   Booking ID type: ${b.id.runtimeType}');
debugPrint('   User ID: ${b.userId}');
debugPrint('   Entered OTP: $otpText');

final result = await OtpService().verifyOtp(
  bookingId: int.parse(b.id),
  userId: b.userId,
  enteredOtp: otpText,
);

debugPrint('🔍 Verification result: ${result.name}');
debugPrint('   Message: ${result.message}');
```

## Current Code Status

### ✅ Backend Function (CREATE_OTP_VERIFICATION_FUNCTION.sql)
- Function exists and is callable
- Uses `SECURITY DEFINER` (should bypass RLS)
- Has correct UPDATE statement
- Returns proper status codes

### ✅ Flutter Service (lib/services/otp_service.dart)
- Calls backend RPC correctly
- Parses response properly
- Has debug logging

### ✅ Flutter Repository (lib/services/booking_repository.dart)
- Uses `OtpService().verifyOtp()` instead of local verification
- Sends correct parameters
- Updates local state after verification

### ✅ Flutter UI (lib/main.dart)
- Two locations call OTP verification
- Show specific error messages
- Handle all result types

## Next Steps for User

1. **Run SQL Test First**:
   - Open Supabase SQL Editor
   - Run `TEST_OTP_ATTEMPTS_COMPLETE.sql`
   - Execute Step 3 to create test booking
   - Execute Step 5 to test wrong OTP
   - Execute Step 6 to check if attempts incremented
   - **Share the results from Step 6**

2. **If SQL Test Passes**:
   - The backend is working correctly
   - Issue is in Flutter connection
   - Run Flutter test (`TEST_OTP_FLUTTER_DEBUG.dart`)
   - Share the Flutter logs

3. **If SQL Test Fails**:
   - Run Step 12 to check RLS policies
   - Run Step 13 to test direct UPDATE
   - Run Step 14 to check function security
   - Share the results

## Expected Behavior

### Correct Flow:
1. User enters wrong OTP
2. Flutter calls `OtpService().verifyOtp()`
3. Backend function executes
4. Function returns 'wrong_otp'
5. Database UPDATE increments `otp_attempts` by 1
6. Flutter shows error message
7. After 5 wrong attempts, `otp_locked` becomes TRUE
8. Further attempts return 'locked'

### Current Broken Flow:
1. User enters wrong OTP ✅
2. Flutter calls `OtpService().verifyOtp()` ✅
3. Backend function executes ✅
4. Function returns 'wrong_otp' ✅
5. Database UPDATE **does NOT increment** `otp_attempts` ❌
6. Flutter shows error message ✅
7. User can try unlimited times (no locking) ❌

## Files to Check

- `CREATE_OTP_VERIFICATION_FUNCTION.sql` - Backend function definition
- `lib/services/otp_service.dart` - OTP service with RPC call
- `lib/services/booking_repository.dart` - Booking repository with verifyOtp
- `lib/main.dart` - UI code that calls verification (lines ~6680 and ~6780)
- `TEST_OTP_ATTEMPTS_COMPLETE.sql` - SQL debugging test
- `TEST_OTP_FLUTTER_DEBUG.dart` - Flutter debugging test

## Contact Points

When sharing debug results, include:
1. Output from Step 6 of SQL test (otp_attempts value)
2. Output from Step 12 (RLS policies)
3. Output from Step 14 (function security type)
4. Flutter console logs when verifying OTP
5. Any error messages from Supabase logs
