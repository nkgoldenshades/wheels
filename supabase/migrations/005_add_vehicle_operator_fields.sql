-- =====================================================
-- ADD VEHICLE OPERATOR FIELDS MIGRATION
-- =====================================================
-- This migration adds operator fields to vehicles table
-- Operators are people who handle/operate specific vehicles
-- Generated: 2026-03-26

-- -----------------------------------------------------
-- ADD OPERATOR FIELDS TO VEHICLES TABLE
-- -----------------------------------------------------
ALTER TABLE public.vehicles
  ADD COLUMN IF NOT EXISTS operator_name text,
  ADD COLUMN IF NOT EXISTS operator_phone text,
  ADD COLUMN IF NOT EXISTS operator_photo text,
  ADD COLUMN IF NOT EXISTS operator_license text;

COMMENT ON COLUMN public.vehicles.operator_name IS 'Name of person who operates/handles this vehicle (optional)';
COMMENT ON COLUMN public.vehicles.operator_phone IS 'Contact phone of vehicle operator (optional)';
COMMENT ON COLUMN public.vehicles.operator_photo IS 'Photo of vehicle operator - base64 or URL (optional)';
COMMENT ON COLUMN public.vehicles.operator_license IS 'License number of vehicle operator for records (optional)';

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================
-- Summary:
-- - Added 4 operator fields to vehicles table
-- - All fields are optional (nullable)
-- - When operator is assigned, their contact will be shown to users instead of owner contact
-- =====================================================
