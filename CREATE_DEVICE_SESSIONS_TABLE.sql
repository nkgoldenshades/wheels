-- ============================================================
-- device_sessions table
-- Stores one row per login event with device + IP details.
-- Run this in your Supabase SQL editor.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.device_sessions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         text NOT NULL,                  -- Firebase UID
  ip_address      text,
  country         text,
  city            text,
  isp             text,
  platform        text,                           -- android | ios | web | windows | macos | linux
  device_model    text,
  os_version      text,
  device_id       text,
  browser         text,                           -- web only
  app_version     text,
  collected_at    timestamptz NOT NULL DEFAULT now(),
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Index for fast per-user lookups
CREATE INDEX IF NOT EXISTS idx_device_sessions_user_id
  ON public.device_sessions (user_id);

-- Index for time-based queries
CREATE INDEX IF NOT EXISTS idx_device_sessions_collected_at
  ON public.device_sessions (collected_at DESC);

-- ── Row Level Security ──────────────────────────────────────
ALTER TABLE public.device_sessions ENABLE ROW LEVEL SECURITY;

-- Users can only read their own sessions
CREATE POLICY "Users can view own sessions"
  ON public.device_sessions
  FOR SELECT
  USING (user_id = (auth.jwt() ->> 'sub'));

-- Allow inserts from authenticated users (for their own user_id)
CREATE POLICY "Users can insert own sessions"
  ON public.device_sessions
  FOR INSERT
  WITH CHECK (user_id = (auth.jwt() ->> 'sub'));

-- Admins can read all sessions (optional — requires service role key)
-- CREATE POLICY "Admins can view all sessions"
--   ON public.device_sessions
--   FOR SELECT
--   USING (auth.role() = 'service_role');

-- ── Useful Queries ──────────────────────────────────────────

-- View all sessions for a user:
-- SELECT * FROM device_sessions WHERE user_id = '<firebase_uid>' ORDER BY collected_at DESC;

-- View recent logins across all users:
-- SELECT user_id, ip_address, country, platform, device_model, collected_at
-- FROM device_sessions ORDER BY collected_at DESC LIMIT 50;

-- Count logins per platform:
-- SELECT platform, COUNT(*) FROM device_sessions GROUP BY platform;

-- Detect suspicious logins (multiple countries in 24h):
-- SELECT user_id, COUNT(DISTINCT country) as countries, array_agg(DISTINCT country) as country_list
-- FROM device_sessions
-- WHERE collected_at > now() - interval '24 hours'
-- GROUP BY user_id
-- HAVING COUNT(DISTINCT country) > 1;
