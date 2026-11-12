-- Add demand_plan column to posts table
-- This replaces the boolean requiresVerifiedVehicle and requiresExpertVehicle flags
-- with a single choice system

ALTER TABLE posts
ADD COLUMN IF NOT EXISTS demand_plan TEXT NOT NULL DEFAULT 'basic';

-- Valid values: 'basic', 'verified', 'expert'
-- 'basic' = Anyone can see and accept (free)
-- 'verified' = Only verified providers can see and accept
-- 'expert' = Only expert providers can see and accept

-- Optional: Migrate existing posts based on old boolean flags
-- Uncomment if you want to convert existing data:

/*
UPDATE posts
SET demand_plan = 'expert'
WHERE requires_expert_vehicle = true;

UPDATE posts
SET demand_plan = 'verified'
WHERE requires_verified_vehicle = true
AND requires_expert_vehicle = false;
*/

-- Add check constraint to ensure only valid values (optional but recommended)
ALTER TABLE posts
ADD CONSTRAINT posts_demand_plan_check 
CHECK (demand_plan IN ('basic', 'verified', 'expert'));
