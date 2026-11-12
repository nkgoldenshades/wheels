-- Add customer details columns to user_post_acceptances table
-- This allows providers to collect customer information when accepting customer requests

-- Add customer_details jsonb column to store customer information
ALTER TABLE user_post_acceptances 
ADD COLUMN IF NOT EXISTS customer_details jsonb DEFAULT '{}'::jsonb;

-- Add selected_seats text array column to store compartment selections
ALTER TABLE user_post_acceptances 
ADD COLUMN IF NOT EXISTS selected_seats text[] DEFAULT ARRAY[]::text[];

-- Add comments for documentation
COMMENT ON COLUMN user_post_acceptances.customer_details IS 'Customer details collected by provider: name, age, phone, gender';
COMMENT ON COLUMN user_post_acceptances.selected_seats IS 'Compartments/seats selected by provider when accepting customer request';

-- Create index for querying by customer details
CREATE INDEX IF NOT EXISTS idx_user_post_acceptances_customer_name 
ON user_post_acceptances ((customer_details->>'name'));

-- Verify the changes
SELECT 
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'user_post_acceptances'
AND column_name IN ('customer_details', 'selected_seats')
ORDER BY ordinal_position;
