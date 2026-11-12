-- Add missing context_id column to ai_conversations table
ALTER TABLE ai_conversations 
ADD COLUMN IF NOT EXISTS context_id TEXT;

-- Add index for better performance
CREATE INDEX IF NOT EXISTS idx_ai_conversations_context_id 
ON ai_conversations(context_id);

-- Verify column was added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'ai_conversations' 
AND column_name = 'context_id';
