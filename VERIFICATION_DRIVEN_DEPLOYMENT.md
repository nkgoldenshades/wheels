# ✅ VERIFICATION-DRIVEN DEPLOYMENT GUIDE

**Approach**: Query → Deploy → Query → Drop → Query  
**Safety Level**: Maximum (verify at each step)  
**Risk Level**: None (backup always exists before deletion)

---

## 📋 STEP 1: Confirm Current State (Read-Only)

**Run this query in Supabase SQL Editor:**

```sql
SELECT 
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_catalog.pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname IN (
  'secure_create_booking',
  'secure_process_payment',
  'secure_generate_otp',
  'secure_verify_otp',
  'secure_process_refund'
)
ORDER BY p.proname, args;
```

**Expected output (BEFORE deployment):**
```
schema_name | function_name            | args
────────────────────────────────────────────────────────────────
public      | secure_create_booking    | p_post_id uuid, p_user_id text, p_seat_keys text[], p_booking_mode text, p_price_snapshot numeric, p_persons_count integer
public      | secure_process_payment   | p_booking_id uuid, p_payment_amount numeric, p_gateway_id text, p_payment_method text
public      | secure_generate_otp      | p_booking_id uuid, p_expiry_minutes integer
public      | secure_verify_otp        | p_booking_id uuid, p_otp_code text, p_user_id text
public      | secure_process_refund    | p_booking_id uuid, p_refund_reason text, p_initiated_by text, p_refund_percentage numeric

Total: 5 rows (all UUID signatures, no TEXT/BIGINT)
```

✅ **Checkpoint**: If you see exactly 5 rows with UUID signatures → proceed to STEP 2

---

## 🚀 STEP 2: Deploy TEXT/BIGINT Versions

**File to deploy**: `SECURE_FUNCTIONS_SCHEMA_CORRECTED.sql`

**In Supabase SQL Editor:**

1. Open `c:\quickohunt\SECURE_FUNCTIONS_SCHEMA_CORRECTED.sql`
2. Copy **all content** (from `-- ============` to the end, including verification queries)
3. Paste into Supabase SQL Editor
4. Click **RUN**
5. Wait for "Query successful" message

**What this does:**
- Creates 5 new functions with TEXT/BIGINT signatures
- Does NOT delete the UUID versions (different signatures)
- Result: Both UUID and TEXT versions coexist

✅ **Checkpoint**: Should see success with no errors

---

## 🔍 STEP 3: Verify Deployment (Read-Only)

**Run the same query from STEP 1:**

```sql
SELECT 
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_catalog.pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname IN (
  'secure_create_booking',
  'secure_process_payment',
  'secure_generate_otp',
  'secure_verify_otp',
  'secure_process_refund'
)
ORDER BY p.proname, args;
```

**Expected output (AFTER deployment):**
```
schema_name | function_name            | args
────────────────────────────────────────────────────────────────────────────────
public      | secure_create_booking    | p_post_id uuid, p_user_id text, p_seat_keys text[], p_booking_mode text, p_price_snapshot numeric, p_persons_count integer
public      | secure_create_booking    | p_post_id text, p_user_id text, p_seat_keys text, p_booking_mode text, p_price_snapshot numeric, p_persons_count integer
public      | secure_process_payment   | p_booking_id uuid, p_payment_amount numeric, p_gateway_id text, p_payment_method text
public      | secure_process_payment   | p_booking_id bigint, p_payment_amount numeric, p_gateway_id text, p_payment_method text
public      | secure_generate_otp      | p_booking_id uuid, p_expiry_minutes integer
public      | secure_generate_otp      | p_booking_id bigint, p_expiry_minutes integer
public      | secure_verify_otp        | p_booking_id uuid, p_otp_code text, p_user_id text
public      | secure_verify_otp        | p_booking_id bigint, p_otp_code text, p_user_id text
public      | secure_process_refund    | p_booking_id uuid, p_refund_reason text, p_initiated_by text, p_refund_percentage numeric
public      | secure_process_refund    | p_booking_id bigint, p_refund_reason text, p_initiated_by text, p_refund_percentage numeric

Total: 10 rows (5 UUID + 5 TEXT/BIGINT = both versions exist ✅)
```

**Critical verification:**
- ✅ 10 rows total (5 functions × 2 versions each)
- ✅ Each function appears twice (UUID + TEXT/BIGINT)
- ✅ UUID versions unchanged
- ✅ TEXT/BIGINT versions now present
- ✅ No errors, all functions exist

### ⚠️ STOP HERE if:
- Less than 10 rows → TEXT versions didn't deploy, DEBUG and re-run STEP 2
- More than 10 rows → something unexpected, investigate before proceeding
- Errors → check Supabase logs, likely schema mismatch (posts.id type, bookings columns)

✅ **Checkpoint**: If you see exactly 10 rows (5 UUID + 5 TEXT/BIGINT) → proceed to STEP 4

---

## 🗑️ STEP 4: Drop UUID Overloads (Now Safe)

**Why it's safe now**: TEXT/BIGINT versions exist as backup. If anything goes wrong, you can redeploy.

**In Supabase SQL Editor:**

```sql
-- Drop UUID version of secure_create_booking
DROP FUNCTION IF EXISTS public.secure_create_booking(
  p_post_id UUID,
  p_user_id TEXT,
  p_seat_keys TEXT[],
  p_booking_mode TEXT,
  p_price_snapshot NUMERIC,
  p_persons_count INTEGER
) CASCADE;

-- Drop UUID version of secure_process_payment
DROP FUNCTION IF EXISTS public.secure_process_payment(
  p_booking_id UUID,
  p_payment_amount NUMERIC,
  p_gateway_id TEXT,
  p_payment_method TEXT
) CASCADE;

-- Drop UUID version of secure_generate_otp
DROP FUNCTION IF EXISTS public.secure_generate_otp(
  p_booking_id UUID,
  p_expiry_minutes INTEGER
) CASCADE;

-- Drop UUID version of secure_verify_otp
DROP FUNCTION IF EXISTS public.secure_verify_otp(
  p_booking_id UUID,
  p_otp_code TEXT,
  p_user_id TEXT
) CASCADE;

-- Drop UUID version of secure_process_refund
DROP FUNCTION IF EXISTS public.secure_process_refund(
  p_booking_id UUID,
  p_refund_reason TEXT,
  p_initiated_by TEXT,
  p_refund_percentage NUMERIC
) CASCADE;
```

1. Copy the DROP statements above
2. Paste into Supabase SQL Editor
3. Click **RUN**
4. Wait for "Query successful" message

✅ **Checkpoint**: Should see success with no errors

---

## 🔍 STEP 5: Verify Cleanup (Read-Only)

**Run the same query again:**

```sql
SELECT 
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_catalog.pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname IN (
  'secure_create_booking',
  'secure_process_payment',
  'secure_generate_otp',
  'secure_verify_otp',
  'secure_process_refund'
)
ORDER BY p.proname, args;
```

**Expected output (AFTER deletion):**
```
schema_name | function_name            | args
────────────────────────────────────────────────────────────────
public      | secure_create_booking    | p_post_id text, p_user_id text, p_seat_keys text, p_booking_mode text, p_price_snapshot numeric, p_persons_count integer
public      | secure_process_payment   | p_booking_id bigint, p_payment_amount numeric, p_gateway_id text, p_payment_method text
public      | secure_generate_otp      | p_booking_id bigint, p_expiry_minutes integer
public      | secure_verify_otp        | p_booking_id bigint, p_otp_code text, p_user_id text
public      | secure_process_refund    | p_booking_id bigint, p_refund_reason text, p_initiated_by text, p_refund_percentage numeric

Total: 5 rows (only TEXT/BIGINT versions, no UUID ✅)
```

**Critical verification:**
- ✅ 5 rows total (one per function)
- ✅ NO UUID parameters anywhere
- ✅ All use TEXT for post_id/user_id/reason/initiated_by
- ✅ All use BIGINT for booking_id
- ✅ No errors

### ⚠️ STOP HERE if:
- More than 5 rows → UUID versions still exist, UUID DROP didn't work
- Still see "uuid" → UUID versions weren't fully removed, check function signatures
- Error message → UUID version might not match exactly, check parameter types

✅ **Checkpoint**: If you see exactly 5 rows with only TEXT/BIGINT → proceed to STEP 6

---

## 🔄 STEP 6: Restart App

1. **Close your app completely** (force close if on mobile)
2. **Wait 5 seconds**
3. **Reopen the app** (full restart, not hot reload)
4. **Don't use hot reload** (won't pick up new function signatures)

---

## 🧪 STEP 7: Test

**In your app:**

1. **Try to create a booking**
   - Expected: Success ✅
   - If error: Check logs for specific error message

2. **Try to process payment** (if you can reach that point)
   - Expected: Success ✅

3. **Try to generate OTP** (if applicable)
   - Expected: Success ✅

✅ **Checkpoint**: If booking creation works without UUID errors → DEPLOYMENT SUCCESSFUL ✅

---

## 📊 Decision Tree

```
STEP 1 Query Results?
├─ 5 rows, all UUID? → Proceed to STEP 2 ✅
├─ 10 rows (mixed)? → TEXT versions already exist, consider skipping STEP 2
├─ Different results? → Something else present, investigate before proceeding

STEP 3 Query Results?
├─ 10 rows (5 UUID + 5 TEXT/BIGINT)? → Proceed to STEP 4 ✅
├─ Still 5 rows (no TEXT added)? → STEP 2 failed, redeploy SECURE_FUNCTIONS_SCHEMA_CORRECTED.sql
├─ More than 10 rows? → Something unexpected, investigate

STEP 5 Query Results?
├─ 5 rows, all TEXT/BIGINT? → Proceed to STEP 6 ✅
├─ 10 rows still? → STEP 4 (DROP) didn't work, check DROP signatures
├─ Still contain "uuid"? → UUID versions partially removed, re-run DROP

STEP 7 Test Results?
├─ Booking creation works? → SUCCESS ✅✅✅
├─ Still UUID error? → App using old cached function, force restart
├─ Different error? → Check logs, likely connection issue
```

---

## 📁 Files Needed

1. **`SECURE_FUNCTIONS_SCHEMA_CORRECTED.sql`** → Deploy in STEP 2
2. **This guide** → Reference for expected outputs
3. **Supabase SQL Editor** → Where to run queries

---

## ⏱️ Timeline

| Step | Action | Time | Required |
|------|--------|------|----------|
| 1 | Query current state | 1 min | Yes |
| 2 | Deploy TEXT versions | 2 min | Yes |
| 3 | Verify deployment | 1 min | Yes |
| 4 | Drop UUID versions | 1 min | Yes* |
| 5 | Verify cleanup | 1 min | Yes |
| 6 | Restart app | 2 min | Yes |
| 7 | Test | 5 min | Yes |
| **TOTAL** | | **~13 min** | |

*Optional if you want to keep both versions

---

## 🛡️ Rollback (If Needed)

If anything goes wrong at any point:

1. Run STEP 1 query to see current state
2. If UUID versions were dropped but TEXT versions don't exist:
   - Redeploy `SECURE_FUNCTIONS_SCHEMA_CORRECTED.sql`
   - All functions restored

3. If STEP 2 deployment failed:
   - Redeploy `SECURE_FUNCTIONS_SCHEMA_CORRECTED.sql`
   - No data loss, only function definitions

---

## ✅ Success Criteria

All of these must be true:

- ✅ STEP 1: 5 rows (UUID only)
- ✅ STEP 3: 10 rows (UUID + TEXT)
- ✅ STEP 5: 5 rows (TEXT only)
- ✅ STEP 7: Booking creation works
- ✅ No "uuid" in any function signature
- ✅ All functions use TEXT/BIGINT

---

## 📞 Providing Query Results

If something goes wrong, share:

1. **Which step failed?** (1-7)
2. **Query results** (from that step's verification query)
3. **Error message** (if any)
4. **Expected vs Actual** (from guide above)

With this info, I can provide exact remediation steps.

---

**You're ready! Start with STEP 1 and follow the checkpoints. Reply with STEP 3 query output when complete.** ✅

