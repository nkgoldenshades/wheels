-- Query 1: Check column types
SELECT column_name, data_type, udt_name
FROM information_schema.columns 
WHERE table_schema='public' 
  AND table_name='bookings' 
  AND column_name IN ('user_id', 'provider_id');

-- Query 2: Check RLS policies
SELECT polname, pg_get_expr(polqual, polrelid) AS using_expr, pg_get_expr(polwithcheck, polrelid) AS with_check
FROM pg_policy 
WHERE polrelid = 'public.bookings'::regclass;

-- Query 3: Check triggers
SELECT tgname, pg_get_triggerdef(oid) AS trigger_def
FROM pg_trigger 
WHERE tgrelid = 'public.bookings'::regclass 
  AND NOT tgisinternal;

-- Query 4: Check foreign keys
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.bookings'::regclass
  AND contype = 'f';
