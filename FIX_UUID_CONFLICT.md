# 🔴 CRITICAL: UUID Function Overload Conflict

## Problem Identified

Your database has **TWO versions** of `secure_create_booking`:

1. ✅ **TEXT version** (NEW, CORRECT)
   ```sql
   secure_create_booking(TEXT, TEXT, TEXT, TEXT, NUMERIC, INTEGER)
   Returns: booking_id BIGINT
   ```

2. ❌ **UUID version** (OLD, WRONG)
   ```sql
   secure_create_booking(UUID, TEXT, TEXT[], TEXT, NUMERIC, INTEGER)
   Returns: booking_id UUID
   ```

When you call the function, **Postgres tries the UUID version first** and attempts to cast your TEXT string to UUID, causing:

```
22P02: invalid input syntax for type uuid: "POST_ID_HERE"
```

---

## Why This Happens

Postgres function overload resolution checks parameter types in this order:
1. UUID parameters (UUID version exists) ← **Postgres tries this first**
2. TEXT parameters (TEXT version exists) ← Falls back here if UUID fails

Since the UUID version exists, it gets priority. The UUID cast fails before it ever tries the TEXT version.

---

## Solution: Remove the UUID Overload

### Step 1: Verify Both Versions Exist

Run in Supabase SQL Editor:

```sql
SELECT 
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_catalog.pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname = 'secure_create_booking'
ORDER BY n.nspname, args;
```

**Expected output: 2 rows**
```
schema_name | function_name            | args
─────────────────────────────────────────────────────────────────
public      | secure_create_booking    | p_post_id uuid, p_user_id text, p_seat_keys text[], p_booking_mode text, p_price_snapshot numeric, p_persons_count integer
public      | secure_create_booking    | p_post_id text, p_user_id text, p_seat_keys text, p_booking_mode text, p_price_snapshot numeric, p_persons_count integer
```

---

### Step 2: Drop the UUID Version

Run in Supabase SQL Editor:

```sql
DROP FUNCTION IF EXISTS public.secure_create_booking(
  p_post_id UUID,
  p_user_id TEXT,
  p_seat_keys TEXT[],
  p_booking_mode TEXT,
  p_price_snapshot NUMERIC,
  p_persons_count INTEGER
) CASCADE;
```

**Expected message:** `Query successful`

---

### Step 3: Verify Only TEXT Version Remains

Run the same query from Step 1 again:

```sql
SELECT 
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_catalog.pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname = 'secure_create_booking'
ORDER BY n.nspname, args;
```

**Expected output: 1 row**
```
schema_name | function_name            | args
─────────────────────────────────────────────────────────────────
public      | secure_create_booking    | p_post_id text, p_user_id text, p_seat_keys text, p_booking_mode text, p_price_snapshot numeric, p_persons_count integer
```

---

## After Fix: What Works

### Before (ERROR)
```sql
SELECT * FROM secure_create_booking('post-abc', 'user-xyz', 'A1', 'shared', 500.00, 1);
-- Error: 22P02: invalid input syntax for type uuid: "post-abc"
```

### After (SUCCESS)
```sql
SELECT * FROM secure_create_booking('post-abc', 'user-xyz', 'A1', 'shared', 500.00, 1);
-- Returns: (true, 12345, 'Booking created successfully', 3)
--          ↑              ↑    ↑ BIGINT booking_id
--          ↑ success    ↑ auto-generated id
```

---

## File to Use

**Copy and run this entire file in Supabase SQL Editor:**
- File: `REMOVE_UUID_OVERLOADS.sql`
- This drops the UUID version and verifies the TEXT version remains

---

## Why We Have Both Versions

**Reason 1: File Deployment Order**
You deployed multiple SQL files in this order:
1. `create_security_functions.sql` (UUID version)
2. `ALL_DATABASE_FUNCTIONS_COMPLETE.sql` (UUID version again)
3. `SECURITY_FUNCTIONS_CORRECTED.sql` (UUID version again)
4. `SECURE_FUNCTIONS_SCHEMA_CORRECTED.sql` (TEXT version - the correct one)

**Reason 2: CREATE OR REPLACE Doesn't Remove Overloads**
When you use `CREATE OR REPLACE FUNCTION`, PostgreSQL:
- Replaces functions with **identical signatures** ✅
- **Doesn't remove** functions with different signatures ❌

So the UUID version stayed in the database alongside the TEXT version.

---

## Complete Cleanup Checklist

- [ ] Run verification query to confirm 2 overloads exist
- [ ] Run DROP FUNCTION to remove UUID version
- [ ] Run verification query again to confirm 1 overload remains
- [ ] Restart your app (full restart)
- [ ] Test booking creation:
  ```
  - Try to create a booking in your app
  - Should work without "invalid input syntax for type uuid" error
  ```

---

## Testing After Fix

### SQL Test (in Supabase SQL Editor)
```sql
SELECT * FROM secure_create_booking(
  'test-post-id',
  'test-user-id',
  'A1',
  'shared',
  500.00,
  1
);
```

**Expected result:** Booking created successfully, returns BIGINT booking_id

### App Test
1. Restart app (full restart, not hot reload)
2. Create a new booking
3. Verify it completes without UUID errors
4. Check logs for any errors

---

## Summary

| Issue | Cause | Fix |
|-------|-------|-----|
| UUID cast error | Two function overloads exist | Drop UUID version |
| Postgres picks UUID first | Wrong signature takes priority | Remove wrong signature |
| Still fails after deployment | New TEXT version created but old one remains | DROP old, keep new |

---

## Files Involved

**DO NOT USE** (old, UUID versions):
- `create_security_functions.sql`
- `SECURITY_FUNCTIONS_CORRECTED.sql`
- `ALL_DATABASE_FUNCTIONS_COMPLETE.sql`

**USE** (new, TEXT versions):
- `SECURE_FUNCTIONS_SCHEMA_CORRECTED.sql`
- `REMOVE_UUID_OVERLOADS.sql` (cleanup)

---

## Next Steps

1. **Run `REMOVE_UUID_OVERLOADS.sql`** in Supabase SQL Editor
2. **Verify** only TEXT version remains
3. **Restart** your app
4. **Test** booking creation
5. **Success** ✅

---

**This is the final fix needed. After this, all functions will work correctly with TEXT post IDs and BIGINT booking IDs.**
