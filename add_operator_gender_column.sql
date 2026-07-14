-- Add operator_gender column to vehicles table
-- This shows the gender of the vehicle operator (male/female)
-- Important for user safety and comfort preferences

ALTER TABLE public.vehicles 
ADD COLUMN IF NOT EXISTS operator_gender text CHECK (operator_gender IN ('male', 'female'));

-- Add comment to explain the column
COMMENT ON COLUMN public.vehicles.operator_gender IS 'Gender of the vehicle operator: male or female';

-- Create index for faster filtering by operator gender
CREATE INDEX IF NOT EXISTS idx_vehicles_operator_gender ON public.vehicles(operator_gender) WHERE operator_gender IS NOT NULL;
