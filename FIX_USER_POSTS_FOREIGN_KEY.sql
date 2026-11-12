-- ============================================
-- FIX: Add/Update Foreign Key Constraint on User_Posts Table
-- ============================================
-- This ensures user_posts.profile_id properly references profiles.id
-- Run this in Supabase SQL Editor
-- ============================================

-- Step 1: Drop existing constraint if it exists
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE (constraint_name LIKE '%profile_id%' OR constraint_name LIKE '%user_id%')
        AND table_name = 'user_posts'
        AND constraint_type = 'FOREIGN KEY'
    ) THEN
        EXECUTE 'ALTER TABLE public.user_posts DROP CONSTRAINT ' || 
            (SELECT constraint_name FROM information_schema.table_constraints 
             WHERE (constraint_name LIKE '%profile_id%' OR constraint_name LIKE '%user_id%')
             AND table_name = 'user_posts' 
             AND constraint_type = 'FOREIGN KEY' 
             LIMIT 1);
        RAISE NOTICE 'Dropped existing foreign key constraint';
    END IF;
END $$;

-- Step 2: Rename user_id to profile_id if needed
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_posts' 
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.user_posts RENAME COLUMN user_id TO profile_id;
        RAISE NOTICE 'Renamed user_id to profile_id';
    END IF;
END $$;

-- Step 3: Ensure profile_id column exists
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_posts' 
        AND column_name = 'profile_id'
    ) THEN
        ALTER TABLE public.user_posts ADD COLUMN profile_id TEXT;
        RAISE NOTICE 'Added profile_id column';
    END IF;
END $$;

-- Step 4: Add foreign key constraint with CASCADE delete
ALTER TABLE public.user_posts
ADD CONSTRAINT user_posts_profile_id_fkey 
FOREIGN KEY (profile_id) 
REFERENCES public.profiles(id) 
ON DELETE CASCADE;

-- Step 5: Create index for better performance
CREATE INDEX IF NOT EXISTS idx_user_posts_profile_id ON public.user_posts(profile_id);

-- Step 6: Verify the constraint was created
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.delete_rule
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
JOIN information_schema.referential_constraints AS rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'user_posts'
    AND kcu.column_name = 'profile_id';
