-- Bind lobbies created from chat to that chat group so friends can open
-- the same lobby. Lead/CoS applies live. Safe if the column already exists.

ALTER TABLE lobbies
ADD COLUMN IF NOT EXISTS chat_group_id TEXT;

CREATE INDEX IF NOT EXISTS idx_lobbies_chat_group_id
  ON lobbies (chat_group_id)
  WHERE chat_group_id IS NOT NULL;
