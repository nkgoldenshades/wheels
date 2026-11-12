-- Complete fix for bookings table UUID issue
-- Drops constraints, triggers, and converts to TEXT

-- Step 1: Drop ALL constraints on user_id and provider_id
DO $$ 
DECLARE
    constraint_name text;
BEGIN
    FOR constraint_name IN 
        SELECT conname 
        FROM pg_constraint 
        WHERE conrelid = 'public.bookings'::regclass 
          AND conkey::text LIKE '%user_id%' OR conkey::text LIKE '%provider_id%'
    LOOP
        EXECUTE format('ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS %I', constraint_name);
    END LOOP;
END $$;

-- Step 2: Drop any triggers that might cast to UUID
DROP TRIGGER IF EXISTS booking_otp_trigger ON public.bookings;

-- Step 3: Convert columns to TEXT
ALTER TABLE public.bookings 
  ALTER COLUMN user_id TYPE text USING user_id::text,
  ALTER COLUMN provider_id TYPE text USING provider_id::text;

-- Step 4: Recreate the OTP trigger
CREATE OR REPLACE FUNCTION generate_booking_otp()
RETURNS TRIGGER AS $$
BEGIN
  -- Generate 6-digit OTP
  NEW.otp := LPAD(FLOOR(RANDOM() * 900000 + 100000)::TEXT, 6, '0');
  NEW.otp_attempts := 0;
  NEW.otp_verified := false;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER booking_otp_trigger
  BEFORE INSERT ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION generate_booking_otp();

-- Step 5: Recreate foreign keys with TEXT type
ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
  ADD CONSTRAINT bookings_provider_id_fkey 
    FOREIGN KEY (provider_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- Verify the fix
SELECT 
  column_name, 
  data_type,
  udt_name
FROM information_schema.columns 
WHERE table_schema='public' 
  AND table_name='bookings' 
  AND column_name IN ('user_id', 'provider_id');
