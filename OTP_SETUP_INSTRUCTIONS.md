# OTP System Setup Instructions

## 📋 Overview
Your OTP system has 3 components:
1. **Backend Trigger** - Auto-generates 6-digit OTP when booking is created
2. **Backend Function** - Verifies OTP with attempt tracking and locking
3. **Frontend Service** - Flutter service to call verification function

## ✅ Current Status

### Frontend (READY ✓)
- ✅ `booking_repository.dart` - Sends `otp: null`, receives backend-generated OTP
- ✅ `otp_service.dart` - Service to verify OTP
- ✅ Booking model includes PostMode and ServiceType

### Backend (NEEDS INSTALLATION ⚠️)
- ⚠️ OTP trigger - **NOT YET INSTALLED** in Supabase
- ⚠️ Verification function - **NOT YET INSTALLED** in Supabase

## 🚀 Installation Steps

### Step 1: Install OTP Trigger
1. Open Supabase Dashboard → SQL Editor
2. Copy entire contents of `INSTALL_OTP_TRIGGER_FINAL.sql`
3. Paste and click **RUN**
4. Should see:
   ```
   ✅ 2 functions created (generate_otp, set_booking_otp)
   ✅ 1 trigger created (booking_otp_trigger)
   ```

### Step 2: Install OTP Verification Function
1. In Supabase SQL Editor
2. Copy entire contents of `CREATE_OTP_VERIFICATION_FUNCTION.sql`
3. Paste and click **RUN**
4. Should see:
   ```
   ✅ Function verify_otp created
   ✅ Permissions granted
   ```

### Step 3: Test Everything
1. In Supabase SQL Editor
2. Copy entire contents of `TEST_OTP_COMPLETE.sql`
3. Paste and click **RUN**
4. Review results - should see:
   - ✅ Functions and trigger exist
   - ✅ OTP auto-generated (6 digits)
   - ✅ Wrong OTP increments attempts
   - ✅ Correct OTP verifies successfully
   - ✅ After 5 attempts, booking locks

## 🔍 Verification Queries

### Check if trigger exists:
```sql
SELECT tgname FROM pg_trigger WHERE tgname = 'booking_otp_trigger';
```
**Expected:** 1 row with `booking_otp_trigger`

### Check if functions exist:
```sql
SELECT proname FROM pg_proc 
WHERE proname IN ('generate_otp', 'set_booking_otp', 'verify_otp');
```
**Expected:** 3 rows

### Test OTP generation manually:
```sql
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
  'your-user-id',
  'provider-id',
  'some-post-id',
  'pending',
  'passenger',
  100.00,
  100.00,
  NOW(),
  NOW() + INTERVAL '1 hour',
  NULL  -- Should be auto-generated
) RETURNING id, otp_code;
```
**Expected:** Returns booking with 6-digit `otp_code`

## 🎯 How It Works

### When User Creates Booking:
1. **Frontend** (`booking_repository.dart`):
   - Creates booking with `otp: null`
   - Sends to Supabase WITHOUT `otp_code` field
   
2. **Backend Trigger** (Supabase):
   - Detects `otp_code IS NULL`
   - Calls `generate_otp()` → generates 6-digit number
   - Sets `otp_code` before INSERT completes
   
3. **Backend Response**:
   - Returns booking with generated `otp_code`
   
4. **Frontend Updates**:
   - Receives `otp_code` from response
   - Updates local booking with backend-generated OTP

### When User Verifies OTP:
1. **Frontend** (`otp_service.dart`):
   ```dart
   final result = await OtpService().verifyOtp(
     bookingId: 123,
     userId: 'user-id',
     enteredOtp: '123456',
   );
   ```

2. **Backend Function** (`verify_otp`):
   - Checks ownership (user owns booking)
   - Checks if already verified
   - Checks if locked (5+ failed attempts)
   - Compares OTP:
     - ❌ Wrong → increment attempts, lock if >= 5
     - ✅ Correct → mark verified, set timestamp

3. **Frontend Handles Result**:
   ```dart
   if (result.isSuccess) {
     // Show success, complete booking
   } else if (result.isWrongOtp) {
     // Show error, allow retry
   } else if (result.isLocked) {
     // Show locked message, contact support
   }
   ```

## 📊 Database Schema

### Bookings Table Fields:
- `otp_code` (TEXT) - 6-digit OTP (auto-generated)
- `otp_attempts` (INT) - Failed verification attempts (default: 0)
- `otp_locked` (BOOLEAN) - Locked after 5 attempts (default: false)
- `otp_verified` (BOOLEAN) - Successfully verified (default: false)
- `otp_verified_at` (TIMESTAMP) - When verified (nullable)

## 🔒 Security Features

1. **Attempt Tracking**: Counts failed OTP attempts
2. **Auto-Locking**: Locks booking after 5 failed attempts
3. **Ownership Check**: Only booking owner can verify
4. **Already Verified**: Prevents re-verification
5. **Row Locking**: Uses `FOR UPDATE` to prevent race conditions

## 🐛 Troubleshooting

### OTP is NULL in database:
- ❌ Trigger not installed → Run `INSTALL_OTP_TRIGGER_FINAL.sql`
- ❌ Trigger disabled → Check `tgenabled` in `pg_trigger`

### Verification fails:
- ❌ Function not installed → Run `CREATE_OTP_VERIFICATION_FUNCTION.sql`
- ❌ Wrong user ID → Check `profile_customer_id` matches
- ❌ Booking locked → Check `otp_locked` field

### Frontend not receiving OTP:
- ❌ Check Supabase response includes `otp_code`
- ❌ Verify `.select('id, otp_code')` in booking_repository
- ❌ Check logs: `debugPrint('✅ Booking synced: OTP=$generatedOtp')`

## 📝 Files Reference

| File | Purpose | Status |
|------|---------|--------|
| `INSTALL_OTP_TRIGGER_FINAL.sql` | Backend trigger for OTP generation | ⚠️ Run in Supabase |
| `CREATE_OTP_VERIFICATION_FUNCTION.sql` | Backend function for OTP verification | ⚠️ Run in Supabase |
| `TEST_OTP_COMPLETE.sql` | Comprehensive test suite | ⚠️ Run after setup |
| `lib/services/booking_repository.dart` | Frontend booking creation | ✅ Ready |
| `lib/services/otp_service.dart` | Frontend OTP verification | ✅ Ready |
| `lib/models/booking.dart` | Booking model with OTP fields | ✅ Ready |

## 🎉 Next Steps

1. ✅ Run `INSTALL_OTP_TRIGGER_FINAL.sql` in Supabase
2. ✅ Run `CREATE_OTP_VERIFICATION_FUNCTION.sql` in Supabase
3. ✅ Run `TEST_OTP_COMPLETE.sql` to verify
4. ✅ Test in Flutter app:
   - Create a booking
   - Check OTP is generated
   - Try verifying with wrong OTP
   - Verify with correct OTP
5. ✅ Monitor logs for any issues

---

**Need Help?** Check the test results from `TEST_OTP_COMPLETE.sql` to diagnose issues.
