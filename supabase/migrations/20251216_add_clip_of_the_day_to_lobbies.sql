-- Add clip_of_the_day_id column to lobbies table
-- This allows lobbies to pin a specific clip as the "clip of the day"

ALTER TABLE lobbies 
ADD COLUMN IF NOT EXISTS clip_of_the_day_id TEXT;

-- Add comment for documentation
COMMENT ON COLUMN lobbies.clip_of_the_day_id IS 'ID of the manually pinned clip of the day (references clips table)';

-- Optional: Add index for faster lookups if needed
CREATE INDEX IF NOT EXISTS idx_lobbies_clip_of_the_day ON lobbies(clip_of_the_day_id) WHERE clip_of_the_day_id IS NOT NULL;
