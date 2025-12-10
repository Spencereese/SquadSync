-- Add lobby_ids JSONB array to chat_groups for multiple lobby support
-- This allows chat groups to have multiple active lobbies simultaneously

-- Add lobby_ids column to chat_groups table
ALTER TABLE chat_groups
ADD COLUMN IF NOT EXISTS lobby_ids JSONB DEFAULT '[]'::jsonb;

-- Create index for faster lobby_ids queries
CREATE INDEX IF NOT EXISTS idx_chat_groups_lobby_ids 
ON chat_groups USING GIN (lobby_ids);

-- Add comment for documentation
COMMENT ON COLUMN chat_groups.lobby_ids IS 'Array of lobby IDs linked to this chat group, allows multiple active lobbies per group';

-- Create pg_cron job for lobby expiration cleanup
-- Deletes inactive lobbies older than 1 hour

-- First, ensure pg_cron extension is enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule job to run every 5 minutes
SELECT cron.schedule(
  'cleanup-inactive-lobbies',  -- job name
  '*/5 * * * *',               -- cron expression: every 5 minutes
  $$
  DELETE FROM lobbies
  WHERE is_active = false
    AND updated_at < NOW() - INTERVAL '1 hour';
  $$
);

-- Alternative: Mark lobbies as inactive if no activity for 1 hour
SELECT cron.schedule(
  'mark-inactive-lobbies',     -- job name
  '*/5 * * * *',               -- cron expression: every 5 minutes
  $$
  UPDATE lobbies
  SET is_active = false
  WHERE is_active = true
    AND updated_at < NOW() - INTERVAL '1 hour';
  $$
);

-- View scheduled cron jobs
SELECT * FROM cron.job WHERE jobname LIKE '%lobby%' OR jobname LIKE '%lobbies%';

-- To unschedule/remove a job (if needed):
-- SELECT cron.unschedule('cleanup-inactive-lobbies');
-- SELECT cron.unschedule('mark-inactive-lobbies');
