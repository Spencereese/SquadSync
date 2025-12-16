-- Migrate existing image_url data to avatar_url
-- Run this in your Supabase SQL Editor
-- Date: 2025-12-16

-- Copy image_url to avatar_url for all rows where avatar_url is null
UPDATE chat_groups 
SET avatar_url = image_url 
WHERE avatar_url IS NULL 
  AND image_url IS NOT NULL;

-- Verify the migration
SELECT 
    id,
    name,
    avatar_url,
    image_url,
    CASE 
        WHEN avatar_url IS NOT NULL THEN '✅ Has avatar_url'
        WHEN image_url IS NOT NULL THEN '⚠️ Only has image_url (needs migration)'
        ELSE '❌ No avatar'
    END as status
FROM chat_groups
WHERE avatar_url IS NOT NULL OR image_url IS NOT NULL
ORDER BY name;

-- Optional: After verifying data looks good, you can drop the image_url column
-- (Uncomment when ready)
-- ALTER TABLE chat_groups DROP COLUMN image_url;
