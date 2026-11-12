-- Add UPI ID column to profiles_private table for Razorpay payouts
ALTER TABLE profiles_private
ADD COLUMN upi_id TEXT;

-- Add comment
COMMENT ON COLUMN profiles_private.upi_id IS 'User UPI ID for Razorpay payouts (e.g., user@okhdfcbank)';

-- Create index for faster queries
CREATE INDEX idx_profiles_private_upi_id ON profiles_private(upi_id);

-- Verify the column exists
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_schema='public' 
  AND table_name='profiles_private' 
  AND column_name='upi_id';
