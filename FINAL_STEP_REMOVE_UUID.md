# 🎯 FINAL STEP - Remove UUID Overloads

**Status**: TEXT/BIGINT versions deployed ✅  
**Remaining**: Remove UUID versions ⏳  
**Time**: 2 minutes

---

## Current State (Confirmed)

Your database has **10 functions** (5 UUID + 5 TEXT/BIGINT):

```
secure_create_booking     | UUID version ❌ | TEXT version ✅
secure_process_payment    | UUID version ❌ | BIGINT version ✅
secure_generate_otp       | UUID version ❌ | BIGINT version ✅
secure_verify_otp         | UUID version ❌ | BIGINT version ✅
secure_process_refund     | UUID version ❌ | BIGINT version ✅
```

**Problem**: Postgres tries UUID first → fails with casting error

**Solution**: Delete UUID versions → only TEXT/BIGINT remain → app works

---

## What To Do NOW

### 1. Copy This SQL

**File**: `DROP_UUID_OVERLOADS_NOW.sql`

```sql
DROP FUNCTION IF EXISTS public.secure_create_booking(
  p_post_id UUID,
  p_user_id TEXT,
  p_seat_keys TEXT[],
  p_booking_mode TEXT,
  p_price_snapshot NUMERIC,
  p_persons_count INTEGER
) CASCADE;

DROP FUNCTION IF EXISTS public.secure_process_payment(
  p_booking_id UUID,
  p_payment_amount NUMERIC,
  p_gateway_id TEXT,
  p_payment_method TEXT
) CASCADE;

DROP FUNCTION IF EXISTS public.secure_generate_otp(
  p_booking_id UUID,
  p_expiry_minutes INTEGER
) CASCADE;

DROP FUNCTION IF EXISTS public.secure_verify_otp(
  p_booking_id UUID,
  p_otp_code TEXT,
  p_user_id TEXT
) CASCADE;

DROP FUNCTION IF EXISTS public.secure_process_refund(
  p_booking_id UUID,
  p_refund_reason TEXT,
  p_initiated_by TEXT,
  p_refund_percentage NUMERIC
) CASCADE;
```

### 2. In Supabase SQL Editor

1. Paste the SQL above
2. Click **RUN**
3. Wait for "Query successful"

### 3. Verify Success

Run this query:

```sql
SELECT 
  p.proname AS function_name,
  pg_catalog.pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname IN ('secure_create_booking', 'secure_process_payment', 
                     'secure_generate_otp', 'secure_verify_otp', 
                     'secure_process_refund')
  AND n.nspname = 'public'
ORDER BY p.proname, args;
```

**Expected result: 5 rows only (no UUID)**

```
secure_create_booking    | p_post_id text, p_user_id text, ...
secure_process_payment   | p_booking_id bigint, p_payment_amount numeric, ...
secure_generate_otp      | p_booking_id bigint, p_expiry_minutes integer
secure_verify_otp        | p_booking_id bigint, p_otp_code text, ...
secure_process_refund    | p_booking_id bigint, p_refund_reason text, ...
```

✅ If you see 5 rows with NO "uuid" → proceed to STEP 4

### 4. Restart App

1. Close app completely
2. Wait 5 seconds
3. Reopen (full restart, not hot reload)

### 5. Test

Try to create a booking in your app.

**Expected**: Success ✅ (no UUID errors)

---

## If Something Goes Wrong

**Query shows 10 rows still (UUID not dropped)**:
- Copy DROP SQL exactly as shown above
- Make sure schema is `public` (not a different schema)
- Check for typos in function signatures
- Run it again

**App still shows UUID error after restart**:
- Force close app completely (not just background)
- Clear app cache if on web version
- Full restart (not hot reload)
- Try booking again

**Different error than UUID casting**:
- Share the error message
- I'll help diagnose

---

## Timeline

| Action | Time |
|--------|------|
| Copy SQL | 1 min |
| Run DROP | 1 min |
| Verify | 1 min |
| Restart app | 2 min |
| Test | 2 min |
| **TOTAL** | **~7 min** |

---

## Success Looks Like

**Before**: 
```
❌ Error: invalid input syntax for type uuid: "POST_ID_HERE"
```

**After**:
```
✅ Booking created successfully
✅ booking_id: 12345
✅ Payment processing
✅ OTP generation
✅ All working
```

---

## Do This Now

1. Copy the SQL from `DROP_UUID_OVERLOADS_NOW.sql`
2. Paste in Supabase SQL Editor
3. Click RUN
4. Run verification query
5. Report back with results

Then everything will work! 🚀
