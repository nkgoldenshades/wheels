-- Add upi_id column to profiles_private table
-- This stores the user's UPI ID for instant payouts via Razorpay

-- Add column if it doesn't exist
ALTER TABLE profiles_private
ADD COLUMN IF NOT EXISTS upi_id TEXT;

-- Add comment
COMMENT ON COLUMN profiles_private.upi_id IS 'UPI ID for instant payouts (format: user@provider)';

-- Create index for faster lookups (optional but recommended)
CREATE INDEX IF NOT EXISTS idx_profiles_private_upi_id 
ON profiles_private(upi_id) 
WHERE upi_id IS NOT NULL;

-- Verify column was added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles_private' 
  AND column_name = 'upi_id';
