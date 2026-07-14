-- Fix ai_conversations table schema
-- Add missing columns that the app expects

ALTER TABLE ai_conversations
ADD COLUMN IF NOT EXISTS context_type TEXT DEFAULT 'general',
ADD COLUMN IF NOT EXISTS context_id TEXT,
ADD COLUMN IF NOT EXISTS booking_id TEXT REFERENCES bookings(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS dispute_party TEXT CHECK (dispute_party IN ('customer', 'provider', NULL)),
ADD COLUMN IF NOT EXISTS disputed_by TEXT REFERENCES profiles(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_ai_conversations_context_type ON ai_conversations(context_type);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_booking_id ON ai_conversations(booking_id);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_dispute_party ON ai_conversations(dispute_party);

-- Add comments for documentation
COMMENT ON COLUMN ai_conversations.context_type IS 'Type of conversation: general, dispute, dispute_completed, booking_help';
COMMENT ON COLUMN ai_conversations.context_id IS 'Optional ID linking to context (legacy, use booking_id instead)';
COMMENT ON COLUMN ai_conversations.booking_id IS 'Booking this conversation is about (for disputes)';
COMMENT ON COLUMN ai_conversations.dispute_party IS 'Which party this dispute chat belongs to (customer or provider)';
COMMENT ON COLUMN ai_conversations.disputed_by IS 'User who raised the dispute';
COMMENT ON COLUMN ai_conversations.metadata IS 'Additional context data for AI (booking details, slot info, etc)';
