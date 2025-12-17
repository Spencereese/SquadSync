-- Match History Table for Lobby Win/Loss Tracking
-- Created: 2025-12-16

CREATE TABLE IF NOT EXISTS match_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lobby_id TEXT NOT NULL REFERENCES lobbies(id) ON DELETE CASCADE,
  game_name TEXT NOT NULL,
  result TEXT NOT NULL CHECK (result IN ('win', 'loss', 'draw')),
  player_uids TEXT[] NOT NULL DEFAULT '{}',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  created_by TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE
);

-- Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_match_history_lobby ON match_history(lobby_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_match_history_game ON match_history(game_name, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_match_history_players ON match_history USING GIN(player_uids);
CREATE INDEX IF NOT EXISTS idx_match_history_created_by ON match_history(created_by);

-- RLS Policies
ALTER TABLE match_history ENABLE ROW LEVEL SECURITY;

-- SELECT: Any authenticated user can view match history for lobbies they're a member of
CREATE POLICY "Users can view match history for their lobbies"
  ON match_history FOR SELECT
  USING (
    auth.uid()::text IN (
      SELECT unnest(member_uids) FROM lobbies WHERE id = match_history.lobby_id
    )
  );

-- INSERT: Lobby members can record match results
CREATE POLICY "Lobby members can record match results"
  ON match_history FOR INSERT
  WITH CHECK (
    auth.uid()::text IN (
      SELECT unnest(member_uids) FROM lobbies WHERE id = match_history.lobby_id
    )
  );

-- UPDATE: Only creator can update their own match records (within 10 minutes)
CREATE POLICY "Creator can update recent match history"
  ON match_history FOR UPDATE
  USING (
    auth.uid()::text = created_by
    AND created_at > NOW() - INTERVAL '10 minutes'
  );

-- DELETE: Only creator can delete their own match records (within 10 minutes)
CREATE POLICY "Creator can delete recent match history"
  ON match_history FOR DELETE
  USING (
    auth.uid()::text = created_by
    AND created_at > NOW() - INTERVAL '10 minutes'
  );

-- Function to get lobby win/loss stats
CREATE OR REPLACE FUNCTION get_lobby_stats(p_lobby_id TEXT)
RETURNS TABLE (
  total_matches BIGINT,
  wins BIGINT,
  losses BIGINT,
  draws BIGINT,
  win_rate NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::BIGINT as total_matches,
    COUNT(*) FILTER (WHERE result = 'win')::BIGINT as wins,
    COUNT(*) FILTER (WHERE result = 'loss')::BIGINT as losses,
    COUNT(*) FILTER (WHERE result = 'draw')::BIGINT as draws,
    CASE 
      WHEN COUNT(*) > 0 THEN 
        ROUND((COUNT(*) FILTER (WHERE result = 'win')::NUMERIC / COUNT(*)::NUMERIC) * 100, 2)
      ELSE 0
    END as win_rate
  FROM match_history
  WHERE lobby_id = p_lobby_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE match_history;

-- Trigger to update lobby last_activity on match record
CREATE OR REPLACE FUNCTION update_lobby_activity_on_match()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE lobbies 
  SET last_activity = NOW()
  WHERE id = NEW.lobby_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_lobby_activity_on_match
  AFTER INSERT ON match_history
  FOR EACH ROW
  EXECUTE FUNCTION update_lobby_activity_on_match();
