-- SquadSync Notification System Schema Updates
-- Run this migration to add notification preferences and cooldown tracking

-- 1. Add favorite_groups column to users table
ALTER TABLE users
ADD COLUMN IF NOT EXISTS favorite_groups TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS notification_preferences JSONB DEFAULT '{
  "momentum_enabled": true,
  "direct_invites_enabled": true,
  "spot_available_enabled": true,
  "timer_expiring_enabled": true,
  "cooldown_minutes": 45
}'::jsonb;

-- 2. Create notification_cooldowns table for persistent cooldown tracking
CREATE TABLE IF NOT EXISTS notification_cooldowns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  lobby_id UUID NOT NULL REFERENCES lobbies(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL CHECK (notification_type IN (
    'direct_invite',
    'momentum',
    'lobby_update',
    'chat',
    'spot_available',
    'timer_expiring'
  )),
  last_sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Composite unique constraint to prevent duplicate cooldowns
  UNIQUE (user_id, lobby_id, notification_type)
);

-- Index for cooldown lookups
CREATE INDEX IF NOT EXISTS idx_notification_cooldowns_user_lobby 
ON notification_cooldowns(user_id, lobby_id, expires_at);

-- Index for cleanup queries
CREATE INDEX IF NOT EXISTS idx_notification_cooldowns_expires 
ON notification_cooldowns(expires_at);

-- 3. Create match_affinity materialized view for smart prioritization
CREATE MATERIALIZED VIEW IF NOT EXISTS match_affinity AS
SELECT 
  mh1.user_id AS user_id,
  mh2.user_id AS other_user_id,
  mh1.game_id,
  COUNT(*) AS shared_session_count,
  MAX(mh1.created_at) AS last_played_together,
  -- Affinity score: 10 points per session (max 60) + recency bonus (max 40)
  (LEAST(COUNT(*), 6) * 10 + 
   GREATEST(40 - EXTRACT(EPOCH FROM (NOW() - MAX(mh1.created_at))) / 86400 * 2, 0)
  )::INTEGER AS affinity_score
FROM match_history mh1
JOIN match_history mh2 
  ON mh1.lobby_id = mh2.lobby_id 
  AND mh1.game_id = mh2.game_id 
  AND mh1.user_id != mh2.user_id
GROUP BY mh1.user_id, mh2.user_id, mh1.game_id
HAVING COUNT(*) >= 3;  -- Only include relationships with 3+ shared sessions

-- Index for fast affinity lookups
CREATE UNIQUE INDEX IF NOT EXISTS idx_match_affinity_users_game 
ON match_affinity(user_id, other_user_id, game_id);

-- Index for sorting by affinity score
CREATE INDEX IF NOT EXISTS idx_match_affinity_score 
ON match_affinity(user_id, affinity_score DESC);

-- 4. Create function to refresh match affinity (call periodically)
CREATE OR REPLACE FUNCTION refresh_match_affinity()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY match_affinity;
END;
$$ LANGUAGE plpgsql;

-- 5. Create function to clean up expired cooldowns (call via pg_cron)
CREATE OR REPLACE FUNCTION cleanup_expired_cooldowns()
RETURNS void AS $$
BEGIN
  DELETE FROM notification_cooldowns
  WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- 6. Create function to check if user should receive notification
CREATE OR REPLACE FUNCTION should_send_notification(
  p_user_id UUID,
  p_lobby_id UUID,
  p_notification_type TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  v_cooldown_expires TIMESTAMPTZ;
  v_user_prefs JSONB;
  v_type_enabled BOOLEAN;
BEGIN
  -- Check user preferences
  SELECT notification_preferences INTO v_user_prefs
  FROM users
  WHERE id = p_user_id;
  
  -- Check if notification type is enabled
  v_type_enabled := COALESCE((v_user_prefs->>(p_notification_type || '_enabled'))::BOOLEAN, TRUE);
  
  IF NOT v_type_enabled THEN
    RETURN FALSE;
  END IF;
  
  -- Check cooldown
  SELECT expires_at INTO v_cooldown_expires
  FROM notification_cooldowns
  WHERE user_id = p_user_id
    AND lobby_id = p_lobby_id
    AND notification_type = p_notification_type
    AND expires_at > NOW();
  
  -- If cooldown exists and hasn't expired, don't send
  IF v_cooldown_expires IS NOT NULL THEN
    RETURN FALSE;
  END IF;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 7. Create function to set notification cooldown
CREATE OR REPLACE FUNCTION set_notification_cooldown(
  p_user_id UUID,
  p_lobby_id UUID,
  p_notification_type TEXT,
  p_cooldown_minutes INTEGER DEFAULT 45
)
RETURNS void AS $$
BEGIN
  INSERT INTO notification_cooldowns (
    user_id,
    lobby_id,
    notification_type,
    last_sent_at,
    expires_at
  )
  VALUES (
    p_user_id,
    p_lobby_id,
    p_notification_type,
    NOW(),
    NOW() + (p_cooldown_minutes || ' minutes')::INTERVAL
  )
  ON CONFLICT (user_id, lobby_id, notification_type)
  DO UPDATE SET
    last_sent_at = NOW(),
    expires_at = NOW() + (p_cooldown_minutes || ' minutes')::INTERVAL;
END;
$$ LANGUAGE plpgsql;

-- 8. Row Level Security for notification_cooldowns
ALTER TABLE notification_cooldowns ENABLE ROW LEVEL SECURITY;

-- Users can only see their own cooldowns
CREATE POLICY notification_cooldowns_select_policy ON notification_cooldowns
  FOR SELECT USING (auth.uid() = user_id);

-- Users can only insert their own cooldowns
CREATE POLICY notification_cooldowns_insert_policy ON notification_cooldowns
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can only update their own cooldowns
CREATE POLICY notification_cooldowns_update_policy ON notification_cooldowns
  FOR UPDATE USING (auth.uid() = user_id);

-- 9. Add pg_cron job for cooldown cleanup (requires pg_cron extension)
-- Run every hour to clean up expired cooldowns
-- SELECT cron.schedule(
--   'cleanup-notification-cooldowns',
--   '0 * * * *',  -- Every hour
--   'SELECT cleanup_expired_cooldowns();'
-- );

-- 10. Add pg_cron job for match affinity refresh (expensive, run daily)
-- SELECT cron.schedule(
--   'refresh-match-affinity',
--   '0 2 * * *',  -- 2 AM daily
--   'SELECT refresh_match_affinity();'
-- );

-- 11. Grant permissions
GRANT SELECT ON match_affinity TO authenticated;
GRANT ALL ON notification_cooldowns TO authenticated;

-- 12. Comments for documentation
COMMENT ON TABLE notification_cooldowns IS 'Tracks notification cooldowns to prevent spam (30-60 min per lobby/person)';
COMMENT ON MATERIALIZED VIEW match_affinity IS 'Pre-computed match affinity scores for smart notification prioritization (3+ shared sessions)';
COMMENT ON COLUMN users.favorite_groups IS 'Array of group IDs for iOS Live Activities (best friends/favorite groups get persistent widgets)';
COMMENT ON COLUMN users.notification_preferences IS 'User notification preferences: enabled types and cooldown duration';
COMMENT ON FUNCTION should_send_notification IS 'Check if user should receive notification based on preferences and cooldown';
COMMENT ON FUNCTION set_notification_cooldown IS 'Set notification cooldown for user/lobby/type combination';
COMMENT ON FUNCTION cleanup_expired_cooldowns IS 'Remove expired cooldown entries (called hourly via pg_cron)';
COMMENT ON FUNCTION refresh_match_affinity IS 'Refresh materialized view for match affinity scores (called daily via pg_cron)';
