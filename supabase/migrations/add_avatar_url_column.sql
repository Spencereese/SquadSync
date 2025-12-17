-- Add avatar_url column to chat_groups table if it doesn't exist
-- Run this in your Supabase SQL Editor
-- Date: 2025-12-16

-- Check if column exists and add it if missing
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'chat_groups' 
        AND column_name = 'avatar_url'
    ) THEN
        ALTER TABLE chat_groups ADD COLUMN avatar_url TEXT;
        RAISE NOTICE 'Added avatar_url column to chat_groups table';
    ELSE
        RAISE NOTICE 'avatar_url column already exists';
    END IF;
    
    -- Also check for image_url and migrate data if it exists
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'chat_groups' 
        AND column_name = 'image_url'
    ) THEN
        -- Copy image_url to avatar_url if avatar_url is null
        UPDATE chat_groups 
        SET avatar_url = image_url 
        WHERE avatar_url IS NULL AND image_url IS NOT NULL;
        
        RAISE NOTICE 'Migrated image_url data to avatar_url';
    END IF;
END $$;

-- Verify the column exists
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'chat_groups' 
AND column_name IN ('avatar_url', 'image_url')
ORDER BY column_name;
