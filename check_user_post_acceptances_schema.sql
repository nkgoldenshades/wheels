-- Check if user_post_acceptances table exists and has the required columns

-- Check table structure
SELECT 
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'user_post_acceptances'
ORDER BY ordinal_position;

-- Check if customer_details and selected_seats columns exist
SELECT 
    EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public'
        AND table_name = 'user_post_acceptances'
        AND column_name = 'customer_details'
    ) as has_customer_details,
    EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public'
        AND table_name = 'user_post_acceptances'
        AND column_name = 'selected_seats'
    ) as has_selected_seats;

-- If columns don't exist, the app will fail when trying to insert
-- Run add_customer_details_to_acceptances.sql to add them
