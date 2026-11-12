-- Add operator_dob column to vehicles table
-- This column stores the date of birth for the vehicle operator

-- Add the column (DATE type for date of birth)
ALTER TABLE vehicles 
ADD COLUMN IF NOT EXISTS operator_dob DATE;

-- Add a comment to document the column
COMMENT ON COLUMN vehicles.operator_dob IS 'Date of birth of the vehicle operator';

-- Verify the column was added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'vehicles' AND column_name = 'operator_dob';
