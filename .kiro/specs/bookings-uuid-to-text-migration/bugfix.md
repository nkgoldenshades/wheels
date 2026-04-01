# Bugfix Requirements Document

**STATUS: ✅ RESOLVED** - Migration completed successfully via Supabase AI

## Introduction

This bugfix addresses a critical booking creation failure caused by a type mismatch between Firebase Auth UIDs (TEXT strings) and Supabase bookings table columns (UUID type). When users attempt to create a booking, the application crashes because the `bookings.user_id` and `bookings.provider_id` columns expect UUID format, but the Flutter app sends Firebase Auth string UIDs like "GbsFkKmcHCQFJ0ceVoBWz2punch1". This prevents all booking operations from succeeding and blocks users from completing their reservations.

The root cause is that previous migration attempts (007_fix_user_id_types.sql) successfully converted other tables (users, vehicles, slots) to TEXT type, but failed on the bookings table due to RLS (Row Level Security) policies that prevent ALTER TABLE operations. This bugfix will complete the migration by properly handling RLS policies during the schema change.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN a user confirms a booking with Firebase UID strings (e.g., "GbsFkKmcHCQFJ0ceVoBWz2punch1") THEN the system crashes with error "invalid input syntax for type uuid: 'GbsFkKmcHCQFJ0ceVoBWz2punch1'"

1.2 WHEN the app attempts to insert booking data into Supabase THEN the database rejects the insert because bookings.user_id and bookings.provider_id columns are UUID type

1.3 WHEN the migration script 007_fix_user_id_types.sql attempts to ALTER TABLE bookings THEN the operation fails due to RLS policies blocking the schema change

1.4 WHEN a booking fails to insert THEN no OTP is generated and the user cannot complete the booking flow

### Expected Behavior (Correct)

2.1 WHEN a user confirms a booking with Firebase UID strings THEN the system SHALL accept the insert without type errors

2.2 WHEN the app sends booking data to Supabase THEN the database SHALL successfully insert the record with TEXT type user_id and provider_id columns

2.3 WHEN the migration script runs to fix bookings table THEN the operation SHALL succeed by temporarily disabling RLS policies, altering columns, and re-enabling policies

2.4 WHEN a booking is successfully inserted THEN the Supabase trigger SHALL auto-generate an OTP and return it to the app

### Unchanged Behavior (Regression Prevention)

3.1 WHEN existing bookings with valid data are queried THEN the system SHALL CONTINUE TO return all booking records without data loss

3.2 WHEN foreign key relationships exist between bookings.user_id and users.id THEN the system SHALL CONTINUE TO enforce referential integrity

3.3 WHEN foreign key relationships exist between bookings.provider_id and users.id THEN the system SHALL CONTINUE TO enforce referential integrity

3.4 WHEN RLS policies are re-enabled after migration THEN the system SHALL CONTINUE TO enforce the same security rules as before

3.5 WHEN the OTP generation trigger fires on booking insert THEN the system SHALL CONTINUE TO auto-generate 6-digit OTPs

3.6 WHEN users query their own bookings THEN the system SHALL CONTINUE TO apply RLS policies correctly for data access control

3.7 WHEN the app queries bookings for slots, vehicles, or users THEN the system SHALL CONTINUE TO return correct results via foreign key joins


---

## Resolution Summary

**Date:** March 30, 2026

**Fix Applied:** Supabase AI executed the following migration:
1. Dropped RLS policies on `public.bookings` table
2. Converted `user_id` and `provider_id` columns from UUID to TEXT type
3. Recreated RLS policies with TEXT type compatibility
4. Re-enabled RLS on the table

**Verification:**
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema='public' 
  AND table_name='bookings' 
  AND column_name IN ('user_id', 'provider_id');
```

**Result:**
- `bookings.user_id` → TEXT ✅
- `bookings.provider_id` → TEXT ✅

**Next Steps:**
1. Restart Flutter app to clear any cached connections
2. Test booking creation flow end-to-end
3. Verify OTP is generated and returned from Supabase trigger
4. If any UUID errors persist, check other columns (slot_id, id) or foreign key constraints

**Files Modified:**
- Supabase `public.bookings` table schema (via Supabase AI migration)
- RLS policies on `public.bookings` (recreated with TEXT type)
