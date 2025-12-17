-- Check which columns exist in chat_groups table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'chat_groups' 
AND column_name IN ('avatar_url', 'image_url')
ORDER BY column_name;
