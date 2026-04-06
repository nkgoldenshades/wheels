-- Fix vehicle_owner field to match the schema
-- This migration updates the vehicles table to use vehicle_owner enum instead of is_user_vehicle boolean

-- Step 1: Create the vehicle_owner enum type if it doesn't exist
DO $$ BEGIN
    CREATE TYPE vehicle_owner_type AS ENUM ('customer', 'provider');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Step 2: Add the vehicle_owner column if it doesn't exist
DO $$ BEGIN
    ALTER TABLE vehicles ADD COLUMN vehicle_owner vehicle_owner_type DEFAULT 'provider';
EXCEPTION
    WHEN duplicate_column THEN null;
END $$;

-- Step 3: Migrate existing data from is_user_vehicle to vehicle_owner
UPDATE vehicles 
SET vehicle_owner = CASE 
    WHEN is_user_vehicle = true THEN 'customer'::vehicle_owner_type
    ELSE 'provider'::vehicle_owner_type
END
WHERE vehicle_owner IS NULL;

-- Step 4: Drop the old is_user_vehicle column if it exists
DO $$ BEGIN
    ALTER TABLE vehicles DROP COLUMN IF EXISTS is_user_vehicle;
EXCEPTION
    WHEN others THEN null;
END $$;

-- Step 5: Update the vehicle_owner column to match the schema
ALTER TABLE vehicles ALTER COLUMN vehicle_owner SET NOT NULL;
ALTER TABLE vehicles ALTER COLUMN vehicle_owner SET DEFAULT 'provider';

-- Verify the changes
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'vehicles' 
AND column_name IN ('vehicle_owner', 'is_user_vehicle');