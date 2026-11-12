-- Migration: Rename 'name' column to 'profile_name' in users table
-- Run this ONLY if you already have a users table with 'name' column

-- Step 1: Rename the column
ALTER TABLE users RENAME COLUMN name TO profile_name;

-- That's it! The column is now renamed from 'name' to 'profile_name'
-- All existing data is preserved
