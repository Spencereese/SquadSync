-- Matchmaking Queue persistence (LFG looking survives app kill)
-- Applied: 2026-09-03
-- Table: public.matchmaking_queue
-- One row per user. Looking/matched/joined phases only (idle = no row).

CREATE TABLE IF NOT EXISTS matchmaking_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  phase TEXT NOT NULL CHECK (phase IN ('looking', 'matched', 'joined')),
  squad_id TEXT,
  lobby_id TEXT REFERENCES lobbies(id) ON DELETE SET NULL,
  game_name TEXT,
  matched_user_id TEXT,
  notification_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT matchmaking_queue_user_uid_key UNIQUE (user_uid)
);

CREATE INDEX IF NOT EXISTS idx_matchmaking_queue_phase
  ON matchmaking_queue(phase);

CREATE INDEX IF NOT EXISTS idx_matchmaking_queue_lobby
  ON matchmaking_queue(lobby_id);

CREATE INDEX IF NOT EXISTS idx_matchmaking_queue_created
  ON matchmaking_queue(created_at);

CREATE OR REPLACE FUNCTION set_matchmaking_queue_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_matchmaking_queue_updated_at ON matchmaking_queue;
CREATE TRIGGER trg_matchmaking_queue_updated_at
  BEFORE UPDATE ON matchmaking_queue
  FOR EACH ROW
  EXECUTE FUNCTION set_matchmaking_queue_updated_at();

ALTER TABLE matchmaking_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS matchmaking_queue_select ON matchmaking_queue;
CREATE POLICY matchmaking_queue_select
  ON matchmaking_queue
  FOR SELECT
  TO authenticated
  USING (
    auth.uid()::text = user_uid
    OR phase IN ('looking', 'matched')
  );

DROP POLICY IF EXISTS matchmaking_queue_insert ON matchmaking_queue;
CREATE POLICY matchmaking_queue_insert
  ON matchmaking_queue
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid()::text = user_uid);

DROP POLICY IF EXISTS matchmaking_queue_update ON matchmaking_queue;
CREATE POLICY matchmaking_queue_update
  ON matchmaking_queue
  FOR UPDATE
  TO authenticated
  USING (auth.uid()::text = user_uid)
  WITH CHECK (auth.uid()::text = user_uid);

DROP POLICY IF EXISTS matchmaking_queue_delete ON matchmaking_queue;
CREATE POLICY matchmaking_queue_delete
  ON matchmaking_queue
  FOR DELETE
  TO authenticated
  USING (auth.uid()::text = user_uid);

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE matchmaking_queue;
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END
$$;
