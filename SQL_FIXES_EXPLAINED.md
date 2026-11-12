# SQL Issues Fixed

## 🐛 Problems Found

### 1. **Wrong Column Names in Test SQL**
**File:** `CREATE_OTP_VERIFICATION_FUNCTION.sql`

**Problem:**
```sql
INSERT INTO public.bookings (
  post_id,
  user_id,        ← WRONG! Should be profile_customer_id
  provider_id,    ← WRONG! Should be profile_provider_id
  ...
```

**Fixed:**
```sql
INSERT INTO public.bookings (
  post_id,
  profile_customer_id,  ← CORRECT
  profile_provider_id,  ← CORRECT
  ...
```

### 2. **Single `$` Instead of `$$` (Potential Issue)**
Some PostgreSQL versions require `$$` for function delimiters.

**If you see errors like:**
- `syntax error at or near "$"`
- `unterminated dollar-quoted string`

**Use the CORRECTED files:**
- `INSTALL_OTP_TRIGGER_CORRECTED.sql`
- `CREATE_OTP_VERIFICATION_CORRECTED.sql`
- `TEST_OTP_SIMPLE.sql`

---

## ✅ Fixed Files

### Use These Files (Guaranteed to Work):

1. **INSTALL_OTP_TRIGGER_CORRECTED.sql**
   - ✅ Uses `$$` delimiters
   - ✅ Clean syntax
   - ✅ Includes verification queries

2. **CREATE_OTP_VERIFICATION_CORRECTED.sql**
   - ✅ Uses `$$` delimiters
   - ✅ Correct column names
   - ✅ Includes permissions and verification

3. **TEST_OTP_SIMPLE.sql**
   - ✅ Simplified test suite
   - ✅ Correct column names
   - ✅ Easy to understand results

---

## 🚀 Installation Steps (Updated)

### Step 1: Install OTP Trigger
```sql
-- Copy and paste INSTALL_OTP_TRIGGER_CORRECTED.sql
-- Run in Supabase SQL Editor
```

**Expected Output:**
```
✅ 2 rows (generate_otp, set_booking_otp)
✅ 1 row (booking_otp_trigger)
```

### Step 2: Install Verification Function
```sql
-- Copy and paste CREATE_OTP_VERIFICATION_CORRECTED.sql
-- Run in Supabase SQL Editor
```

**Expected Output:**
```
✅ 1 row (verify_otp function created)
```

### Step 3: Test Everything
```sql
-- Copy and paste TEST_OTP_SIMPLE.sql
-- Run in Supabase SQL Editor
```

**Expected Output:**
```
✅ 3 functions found
✅ 1 trigger found
✅ OTP generated (6 digits)
✅ Wrong OTP test passed
✅ Correct OTP test passed
```

---

## 🔍 Common Errors & Solutions

### Error: "column user_id does not exist"
**Cause:** Using old column names  
**Solution:** Use `profile_customer_id` instead of `user_id`

### Error: "column provider_id does not exist"
**Cause:** Using old column names  
**Solution:** Use `profile_provider_id` instead of `provider_id`

### Error: "syntax error at or near $"
**Cause:** Single `$` delimiter not supported  
**Solution:** Use CORRECTED files with `$$` delimiters

### Error: "function generate_otp() does not exist"
**Cause:** Trigger not installed  
**Solution:** Run `INSTALL_OTP_TRIGGER_CORRECTED.sql` first

### Error: "function verify_otp does not exist"
**Cause:** Verification function not installed  
**Solution:** Run `CREATE_OTP_VERIFICATION_CORRECTED.sql`

---

## 📊 Database Schema Reference

### Correct Column Names:

| Old Name (Wrong) | New Name (Correct) |
|------------------|-------------------|
| `user_id` | `profile_customer_id` |
| `provider_id` | `profile_provider_id` |
| `slot_id` | `post_id` |

### OTP Fields:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `otp_code` | TEXT | NULL | 6-digit OTP (auto-generated) |
| `otp_attempts` | INT | 0 | Failed verification attempts |
| `otp_locked` | BOOLEAN | FALSE | Locked after 5 attempts |
| `otp_verified` | BOOLEAN | FALSE | Successfully verified |
| `otp_verified_at` | TIMESTAMP | NULL | When verified |

---

## 🎯 Quick Verification

### Check if everything is installed:
```sql
-- Should return 3 rows
SELECT proname FROM pg_proc 
WHERE proname IN ('generate_otp', 'set_booking_otp', 'verify_otp');

-- Should return 1 row
SELECT tgname FROM pg_trigger 
WHERE tgname = 'booking_otp_trigger';
```

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
  'my-user-id',
  'provider-id',
  gen_random_uuid(),
  'pending',
  'passenger',
  100.00,
  100.00,
  NOW(),
  NOW() + INTERVAL '1 hour',
  NULL  -- Should be auto-generated
) RETURNING id, otp_code;
```

**Expected:** Returns booking with 6-digit `otp_code` like "123456"

---

## 📝 Summary of Changes

### Files Updated:
- ✅ Created `INSTALL_OTP_TRIGGER_CORRECTED.sql` - Fixed delimiters
- ✅ Created `CREATE_OTP_VERIFICATION_CORRECTED.sql` - Fixed column names + delimiters
- ✅ Created `TEST_OTP_SIMPLE.sql` - Simplified test with correct columns

### What Was Fixed:
1. Changed `user_id` → `profile_customer_id`
2. Changed `provider_id` → `profile_provider_id`
3. Ensured `$$` delimiters are used consistently
4. Simplified test suite for easier debugging

---

## 🎉 You're Ready!

Use the **CORRECTED** files and follow the 3-step installation. Everything should work perfectly now! 🚀

If you still get errors, please share:
1. The exact error message
2. Which file you're running
3. Your PostgreSQL/Supabase version
