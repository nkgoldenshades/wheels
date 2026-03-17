-- User Post Acceptances Table
-- Tracks when providers accept user posts and manages OTP verification and payment

CREATE TABLE IF NOT EXISTS user_post_acceptances (
  id TEXT PRIMARY KEY,
  post_id TEXT NOT NULL REFERENCES user_posts(id) ON DELETE CASCADE,
  provider_id TEXT NOT NULL, -- Firebase UID of provider
  user_id TEXT NOT NULL, -- Firebase UID of post owner
  amount DECIMAL(10, 2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, otpVerified, paid, cancelled
  otp TEXT, -- 6-digit OTP
  otp_expires_at TIMESTAMPTZ,
  razorpay_order_id TEXT,
  razorpay_payment_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  paid_at TIMESTAMPTZ,
  
  CONSTRAINT valid_status CHECK (status IN ('pending', 'otpVerified', 'paid', 'cancelled'))
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_post_acceptances_post_id ON user_post_acceptances(post_id);
CREATE INDEX IF NOT EXISTS idx_user_post_acceptances_provider_id ON user_post_acceptances(provider_id);
CREATE INDEX IF NOT EXISTS idx_user_post_acceptances_user_id ON user_post_acceptances(user_id);
CREATE INDEX IF NOT EXISTS idx_user_post_acceptances_status ON user_post_acceptances(status);

-- RLS Policies
ALTER TABLE user_post_acceptances ENABLE ROW LEVEL SECURITY;

-- Users can view acceptances where they are either the provider or post owner
CREATE POLICY "Users can view their acceptances"
  ON user_post_acceptances
  FOR SELECT
  USING (
    auth.uid()::text = provider_id OR 
    auth.uid()::text = user_id
  );

-- Providers can create acceptances
CREATE POLICY "Providers can accept posts"
  ON user_post_acceptances
  FOR INSERT
  WITH CHECK (auth.uid()::text = provider_id);

-- Both parties can update acceptances (for OTP verification and payment)
CREATE POLICY "Users can update their acceptances"
  ON user_post_acceptances
  FOR UPDATE
  USING (
    auth.uid()::text = provider_id OR 
    auth.uid()::text = user_id
  );

-- Both parties can cancel
CREATE POLICY "Users can cancel acceptances"
  ON user_post_acceptances
  FOR DELETE
  USING (
    auth.uid()::text = provider_id OR 
    auth.uid()::text = user_id
  );
