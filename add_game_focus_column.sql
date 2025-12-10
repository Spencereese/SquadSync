-- Add game_focus column to chat_groups table
ALTER TABLE chat_groups 
ADD COLUMN IF NOT EXISTS game_focus TEXT;

-- Add index for game_focus lookups
CREATE INDEX IF NOT EXISTS idx_chat_groups_game_focus ON chat_groups(game_focus);
