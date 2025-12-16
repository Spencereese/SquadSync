-- Migrate users.user_groups JSONB from image_url to avatar_url
-- Run this in your Supabase SQL Editor
-- Date: 2025-12-16

-- Update all user_groups JSONB entries to rename image_url to avatar_url
UPDATE users
SET user_groups = (
    SELECT jsonb_agg(
        CASE 
            WHEN elem ? 'image_url' THEN
                elem - 'image_url' || jsonb_build_object('avatar_url', elem->'image_url')
            ELSE
                elem
        END
    )
    FROM jsonb_array_elements(COALESCE(user_groups, '[]'::jsonb)) AS elem
)
WHERE user_groups IS NOT NULL 
  AND user_groups != '[]'::jsonb
  AND EXISTS (
      SELECT 1 
      FROM jsonb_array_elements(user_groups) AS elem 
      WHERE elem ? 'image_url'
  );

-- Verify the migration
SELECT 
    uid,
    display_name,
    jsonb_pretty(user_groups) as user_groups_preview
FROM users
WHERE user_groups IS NOT NULL 
  AND user_groups != '[]'::jsonb
LIMIT 5;

-- Check for any remaining image_url references
SELECT 
    COUNT(*) as users_with_old_field,
    COUNT(DISTINCT uid) as affected_users
FROM users
CROSS JOIN LATERAL jsonb_array_elements(COALESCE(user_groups, '[]'::jsonb)) AS elem
WHERE elem ? 'image_url';
