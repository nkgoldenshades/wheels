-- Add dispute-related columns to ai_conversations table
-- Note: booking_id already exists - we can fetch slot_id from booking table!
-- Note: context_type will be 'dispute' or 'dispute_completed' (no separate status field needed)

ALTER TABLE ai_conversations 
ADD COLUMN IF NOT EXISTS dispute_party TEXT CHECK (dispute_party IN ('customer', 'provider')),
ADD COLUMN IF NOT EXISTS disputed_by TEXT, -- Profile ID of who raised the dispute
ADD COLUMN IF NOT EXISTS metadata JSONB; -- Store all context (booking, vehicle, profiles)

-- Add indexes for fast dispute queries
CREATE INDEX IF NOT EXISTS idx_ai_conversations_booking_id 
ON ai_conversations(booking_id) 
WHERE context_type LIKE 'dispute%';

CREATE INDEX IF NOT EXISTS idx_ai_conversations_dispute_party 
ON ai_conversations(dispute_party) 
WHERE context_type LIKE 'dispute%';

CREATE INDEX IF NOT EXISTS idx_ai_conversations_disputed_by 
ON ai_conversations(disputed_by) 
WHERE context_type LIKE 'dispute%';

CREATE INDEX IF NOT EXISTS idx_ai_conversations_context_type 
ON ai_conversations(context_type);

-- Index for finding both threads of same dispute (using existing booking_id field)
CREATE INDEX IF NOT EXISTS idx_ai_conversations_dispute_threads
ON ai_conversations(booking_id, context_type)
WHERE context_type LIKE 'dispute%';

COMMENT ON COLUMN ai_conversations.booking_id IS 'Booking ID - used for disputes to link both chat threads and fetch all related data';
COMMENT ON COLUMN ai_conversations.context_type IS 'Chat type: general, dispute, dispute_completed';
COMMENT ON COLUMN ai_conversations.dispute_party IS 'customer or provider - identifies which party this chat belongs to';
COMMENT ON COLUMN ai_conversations.disputed_by IS 'profile_id of who raised the dispute';
COMMENT ON COLUMN ai_conversations.metadata IS 'Full context: booking, vehicle, profiles, slot, trip_media - all data for AI analysis';
