-- Clean metadata field in existing messages to remove old schema (photos/videos/audio)
-- Run this in Supabase SQL Editor

-- Update messages to set metadata to NULL if it contains old fields
UPDATE chat_messages
SET metadata = NULL
WHERE metadata IS NOT NULL
  AND (
    metadata ? 'photos' 
    OR metadata ? 'videos' 
    OR metadata ? 'audio'
  );

-- Verify the update
SELECT id, metadata, created_at
FROM chat_messages
WHERE chat_id = '1765314013486'
ORDER BY created_at DESC
LIMIT 10;
