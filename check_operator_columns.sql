-- Check all operator-related columns in vehicles table

SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'vehicles' 
    AND column_name LIKE 'operator%'
ORDER BY ordinal_position;

-- Alternative: Show full table structure
SELECT 
    column_name, 
    data_type, 
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'vehicles'
ORDER BY ordinal_position;
