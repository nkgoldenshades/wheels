-- ============================================
-- MANUAL FIX: Create Your Profile
-- ============================================
-- Run this if your profile doesn't exist
-- Replace the ID with your Firebase UID
-- ============================================

-- Check if profile exists
SELECT * FROM public.profiles WHERE id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';

-- If it doesn't exist, create it manually:
INSERT INTO public.profiles (id, full_name, email, business_type, created_at, updated_at)
VALUES (
  'GbsFkKmcHCQFJ0ceVoBWz2punch1',
  'Test User',
  'test@example.com',
  'solo',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- Verify it was created
SELECT * FROM public.profiles WHERE id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';
