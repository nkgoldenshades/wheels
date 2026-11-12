-- Add JSONB column to profiles_private to track AI credit transactions
-- This stores both purchase and usage history in a single column

-- Add ai_credit_transactions JSONB column
ALTER TABLE profiles_private
ADD COLUMN IF NOT EXISTS ai_credit_transactions JSONB DEFAULT '{"transactions": []}'::jsonb;

-- Add comment explaining the structure
COMMENT ON COLUMN profiles_private.ai_credit_transactions IS 
'JSONB array tracking AI credit purchases and usage. Structure:
{
  "transactions": [
    {
      "type": "purchase",
      "amount": 100,
      "price_paid": 10.00,
      "payment_id": "pay_xxx",
      "timestamp": "2026-08-28T10:30:00Z"
    },
    {
      "type": "usage",
      "amount": -5,
      "conversation_id": "abc123",
      "message_count": 10,
      "timestamp": "2026-08-28T11:00:00Z"
    },
    {
      "type": "welcome_bonus",
      "amount": 10,
      "timestamp": "2026-08-28T09:00:00Z"
    }
  ]
}';

-- Create index for faster queries on transaction type
CREATE INDEX IF NOT EXISTS idx_ai_credit_transactions_type 
ON profiles_private USING gin ((ai_credit_transactions -> 'transactions'));

-- Example: Query to get all purchases for a user
-- SELECT ai_credit_transactions -> 'transactions' 
-- FROM profiles_private 
-- WHERE profile_id = 'user-uuid';

-- Example: Add a new transaction (from app code)
-- UPDATE profiles_private 
-- SET ai_credit_transactions = jsonb_set(
--   ai_credit_transactions,
--   '{transactions}',
--   (ai_credit_transactions -> 'transactions') || '[{"type":"purchase","amount":100,"price_paid":10.0,"timestamp":"2026-08-28T10:30:00Z"}]'::jsonb
-- )
-- WHERE profile_id = 'user-uuid';
