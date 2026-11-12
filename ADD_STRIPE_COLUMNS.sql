-- ============================================
-- STRIPE ESCROW SCHEMA - PRODUCTION SAFE
-- ============================================
-- Run this in Supabase SQL Editor
-- This adds all columns needed for Stripe escrow payment system

-- Add Stripe / escrow columns to bookings table
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS stripe_payment_intent_id TEXT,
  ADD COLUMN IF NOT EXISTS stripe_transfer_id TEXT,
  ADD COLUMN IF NOT EXISTS stripe_refund_id TEXT,
  ADD COLUMN IF NOT EXISTS commission_amount INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS countdown_end_time TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS refund_processing BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS refund_error TEXT,
  ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS refund_failed_at TIMESTAMPTZ;

-- Add status constraint to ensure valid booking states
ALTER TABLE public.bookings 
  DROP CONSTRAINT IF EXISTS bookings_status_check,
  ADD CONSTRAINT bookings_status_check 
  CHECK (status = ANY (ARRAY[
    'pending',
    'confirmed', 
    'completed',
    'cancelled',
    'refunded',
    'refund_failed',
    'failed'
  ]));

-- Indexes for escrow workflow performance
CREATE INDEX IF NOT EXISTS idx_bookings_status_countdown 
  ON public.bookings (status, countdown_end_time) 
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_bookings_payment_intent 
  ON public.bookings (stripe_payment_intent_id);

CREATE INDEX IF NOT EXISTS idx_bookings_transfer_id 
  ON public.bookings (stripe_transfer_id);

CREATE INDEX IF NOT EXISTS idx_bookings_refund_id 
  ON public.bookings (stripe_refund_id);

-- Add stripe_account_id to users table (for providers to receive payouts)
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS stripe_account_id TEXT,
  ADD COLUMN IF NOT EXISTS stripe_onboarding_completed BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_users_stripe_account 
  ON public.users(stripe_account_id) 
  WHERE stripe_account_id IS NOT NULL;

-- Foreign key constraints for referential integrity
ALTER TABLE public.bookings 
  ADD CONSTRAINT IF NOT EXISTS bookings_user_fkey 
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
  ADD CONSTRAINT IF NOT EXISTS bookings_provider_fkey 
    FOREIGN KEY (provider_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================
-- Run these to verify the schema changes

-- Check new columns exist
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'bookings'
  AND (column_name LIKE '%stripe%' OR column_name LIKE '%refund%' OR column_name = 'countdown_end_time');

-- Check indexes were created
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'bookings' 
  AND schemaname = 'public'
  AND indexname LIKE 'idx_bookings_%';

-- Check constraint exists
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.bookings'::regclass
  AND conname = 'bookings_status_check';
