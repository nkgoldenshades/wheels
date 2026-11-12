-- Add AI Credits column to profiles table
-- Run this in Supabase SQL Editor

-- Add ai_credits column with default value of 50 for new users
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS ai_credits INTEGER NOT NULL DEFAULT 50;

-- Update existing users to have 50 credits
UPDATE profiles 
SET ai_credits = 50 
WHERE ai_credits IS NULL OR ai_credits = 0;

-- Add comment to column
COMMENT ON COLUMN profiles.ai_credits IS 'AI chat credits - 1 credit per message. New users get 50 free credits.';

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_profiles_ai_credits ON profiles(ai_credits);

-- Verify the changes
SELECT id, full_name, ai_credits 
FROM profiles 
LIMIT 10;
