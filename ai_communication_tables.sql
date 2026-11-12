-- 🤖 AI COMMUNICATION TABLES
-- Add these to your database for AI communication features

-- ============================================================================
-- 1. CONVERSATIONS TABLE (Chat between users)
-- ============================================================================
CREATE TABLE public.conversations (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  booking_id text REFERENCES public.bookings(id) ON DELETE CASCADE,
  customer_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  provider_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- AI features
  ai_translation_enabled boolean DEFAULT false,
  ai_sentiment_monitoring boolean DEFAULT true,
  ai_auto_responses boolean DEFAULT false,
  
  -- Status
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- ============================================================================
-- 2. MESSAGES TABLE (Individual messages)
-- ============================================================================
CREATE TABLE public.messages (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  conversation_id text NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  
  -- Message content
  original_text text NOT NULL,
  translated_text text, -- AI translated version
  message_type text DEFAULT 'text' CHECK (message_type IN ('text', 'location', 'image', 'ai_suggestion')),
  
  -- AI analysis
  ai_sentiment text, -- 'positive', 'negative', 'neutral'
  ai_confidence_score numeric,
  ai_language_detected text,
  ai_auto_generated boolean DEFAULT false,
  
  -- Status
  is_read boolean DEFAULT false,
  read_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now()
);

-- ============================================================================
-- 3. AI SUGGESTIONS TABLE (Smart replies, templates)
-- ============================================================================
CREATE TABLE public.ai_suggestions (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  context_type text NOT NULL, -- 'booking_confirmed', 'arrival_soon', 'payment_due'
  language text DEFAULT 'en',
  
  -- Suggestion content
  suggestion_text text NOT NULL,
  category text, -- 'greeting', 'eta_update', 'payment', 'emergency'
  
  -- Usage stats
  usage_count integer DEFAULT 0,
  success_rate numeric DEFAULT 0,
  
  created_at timestamp with time zone DEFAULT now()
);

-- ============================================================================
-- 4. INDEXES FOR PERFORMANCE
-- ============================================================================
CREATE INDEX idx_conversations_booking ON public.conversations(booking_id);
CREATE INDEX idx_conversations_users ON public.conversations(customer_id, provider_id);
CREATE INDEX idx_messages_conversation ON public.messages(conversation_id);
CREATE INDEX idx_messages_sender ON public.messages(sender_id);
CREATE INDEX idx_messages_created ON public.messages(created_at);
CREATE INDEX idx_ai_suggestions_context ON public.ai_suggestions(context_type, language);

-- ============================================================================
-- 5. RLS POLICIES
-- ============================================================================

-- Conversations RLS
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own conversations" ON public.conversations
  FOR SELECT USING (
    customer_id = auth.jwt()->>'sub' OR 
    provider_id = auth.jwt()->>'sub'
  );

CREATE POLICY "Users can create conversations for own bookings" ON public.conversations
  FOR INSERT WITH CHECK (
    customer_id = auth.jwt()->>'sub' OR 
    provider_id = auth.jwt()->>'sub'
  );

-- Messages RLS  
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view messages in own conversations" ON public.messages
  FOR SELECT USING (
    conversation_id IN (
      SELECT id FROM public.conversations 
      WHERE customer_id = auth.jwt()->>'sub' OR provider_id = auth.jwt()->>'sub'
    )
  );

CREATE POLICY "Users can send messages in own conversations" ON public.messages
  FOR INSERT WITH CHECK (
    sender_id = auth.jwt()->>'sub' AND
    conversation_id IN (
      SELECT id FROM public.conversations 
      WHERE customer_id = auth.jwt()->>'sub' OR provider_id = auth.jwt()->>'sub'
    )
  );

-- AI Suggestions (public read)
ALTER TABLE public.ai_suggestions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view AI suggestions" ON public.ai_suggestions
  FOR SELECT USING (true);