-- ============================================
-- FIX: Add/Update Foreign Key Constraint on Posts Table
-- ============================================
-- This ensures posts.profile_id properly references profiles.id
-- Run this in Supabase SQL Editor
-- ============================================

-- Step 1: Drop existing constraint if it exists (might be named differently)
DO $$ 
BEGIN
    -- Try to drop any existing foreign key constraints on profile_id
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name LIKE '%profile_id%' 
        AND table_name = 'posts'
        AND constraint_type = 'FOREIGN KEY'
    ) THEN
        EXECUTE 'ALTER TABLE public.posts DROP CONSTRAINT ' || 
            (SELECT constraint_name FROM information_schema.table_constraints 
             WHERE constraint_name LIKE '%profile_id%' 
             AND table_name = 'posts' 
             AND constraint_type = 'FOREIGN KEY' 
             LIMIT 1);
        RAISE NOTICE 'Dropped existing foreign key constraint';
    END IF;
END $$;

-- Step 2: Ensure profile_id column exists and is correct type
DO $$ 
BEGIN
    -- Check if column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'posts' 
        AND column_name = 'profile_id'
    ) THEN
        -- Add column if it doesn't exist
        ALTER TABLE public.posts ADD COLUMN profile_id TEXT;
        RAISE NOTICE 'Added profile_id column';
    END IF;
END $$;

-- Step 3: Add foreign key constraint with CASCADE delete
ALTER TABLE public.posts
ADD CONSTRAINT posts_profile_id_fkey 
FOREIGN KEY (profile_id) 
REFERENCES public.profiles(id) 
ON DELETE CASCADE;

-- Step 4: Create index for better performance
CREATE INDEX IF NOT EXISTS idx_posts_profile_id ON public.posts(profile_id);

-- Step 5: Verify the constraint was created
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
    AND tc.table_name = 'posts'
    AND kcu.column_name = 'profile_id';

-- Step 6: Check for any orphaned posts (posts without valid profile_id)
SELECT 
    COUNT(*) as orphaned_posts,
    'Posts with invalid profile_id' as description
FROM public.posts p
LEFT JOIN public.profiles pr ON p.profile_id = pr.id
WHERE pr.id IS NULL;

-- If you have orphaned posts, you can either:
-- A) Delete them:
-- DELETE FROM public.posts WHERE profile_id NOT IN (SELECT id FROM public.profiles);
-- 
-- B) Or assign them to a specific user:
-- UPDATE public.posts SET profile_id = 'YOUR_USER_ID' WHERE profile_id IS NULL;
