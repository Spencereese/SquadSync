-- ============================================================================
-- SYSTEM TABLES FOR SQUADSYNC
-- ============================================================================

-- NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS notifications (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT,
  body TEXT,
  data JSONB DEFAULT '{}'::jsonb,
  read BOOLEAN DEFAULT false,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Add foreign key constraint (safe - only if not exists)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'notifications_user_id_fkey'
  ) THEN
    ALTER TABLE notifications ADD CONSTRAINT notifications_user_id_fkey 
      FOREIGN KEY (user_id) REFERENCES users(uid) ON DELETE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_timestamp ON notifications(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read);

-- AVAILABILITY SLOTS TABLE
CREATE TABLE IF NOT EXISTS availability_slots (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  day_of_week INTEGER,  -- 0-6 for recurring slots
  is_recurring BOOLEAN DEFAULT false,
  notes TEXT,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Add foreign key constraint (safe - only if not exists)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'availability_slots_user_id_fkey'
  ) THEN
    ALTER TABLE availability_slots ADD CONSTRAINT availability_slots_user_id_fkey 
      FOREIGN KEY (user_id) REFERENCES users(uid) ON DELETE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_availability_user_id ON availability_slots(user_id);
CREATE INDEX IF NOT EXISTS idx_availability_start_time ON availability_slots(start_time);

-- BAN VOTES TABLE (daily voting system)
CREATE TABLE IF NOT EXISTS ban_votes (
  id TEXT PRIMARY KEY,
  voter_id TEXT NOT NULL,
  target_id TEXT NOT NULL,
  vote BOOLEAN NOT NULL,  -- true = ban, false = unban
  date DATE NOT NULL,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Add foreign key constraints (safe - only if not exists)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'ban_votes_voter_id_fkey'
  ) THEN
    ALTER TABLE ban_votes ADD CONSTRAINT ban_votes_voter_id_fkey 
      FOREIGN KEY (voter_id) REFERENCES users(uid) ON DELETE CASCADE;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'ban_votes_target_id_fkey'
  ) THEN
    ALTER TABLE ban_votes ADD CONSTRAINT ban_votes_target_id_fkey 
      FOREIGN KEY (target_id) REFERENCES users(uid) ON DELETE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_ban_votes_date ON ban_votes(date);
CREATE INDEX IF NOT EXISTS idx_ban_votes_voter ON ban_votes(voter_id);
CREATE INDEX IF NOT EXISTS idx_ban_votes_target ON ban_votes(target_id);

-- BANS TABLE
DROP TABLE IF EXISTS bans CASCADE;

CREATE TABLE bans (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL UNIQUE,
  reason TEXT,
  banned_at TIMESTAMPTZ DEFAULT NOW(),
  banned_by TEXT
);

-- Add foreign key constraints (safe - only if not exists)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'bans_user_id_fkey'
  ) THEN
    ALTER TABLE bans ADD CONSTRAINT bans_user_id_fkey 
      FOREIGN KEY (user_id) REFERENCES users(uid) ON DELETE CASCADE;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'bans_banned_by_fkey'
  ) THEN
    ALTER TABLE bans ADD CONSTRAINT bans_banned_by_fkey 
      FOREIGN KEY (banned_by) REFERENCES users(uid) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_bans_user_id ON bans(user_id);
CREATE INDEX IF NOT EXISTS idx_bans_banned_at ON bans(banned_at DESC);

-- ANALYTICS TABLE
CREATE TABLE IF NOT EXISTS analytics (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  event TEXT NOT NULL,
  data JSONB DEFAULT '{}'::jsonb,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Add foreign key constraint (safe - only if not exists)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'analytics_user_id_fkey'
  ) THEN
    ALTER TABLE analytics ADD CONSTRAINT analytics_user_id_fkey 
      FOREIGN KEY (user_id) REFERENCES users(uid) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_analytics_user_id ON analytics(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_event ON analytics(event);
CREATE INDEX IF NOT EXISTS idx_analytics_timestamp ON analytics(timestamp DESC);

-- SYSTEM HEALTH TABLE (for availability checks)
CREATE TABLE IF NOT EXISTS system_health (
  id TEXT PRIMARY KEY DEFAULT 'health',
  status TEXT DEFAULT 'ok',
  last_checked TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Insert default health record
INSERT INTO system_health (id, status) VALUES ('health', 'ok')
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- RLS POLICIES FOR SYSTEM TABLES
-- ============================================================================

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE availability_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE ban_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE bans ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_health ENABLE ROW LEVEL SECURITY;

-- Notifications: Users can only see their own
CREATE POLICY "Users can view own notifications"
  ON notifications FOR SELECT
  USING (auth.uid()::text = user_id);

CREATE POLICY "System can create notifications"
  ON notifications FOR INSERT
  WITH CHECK (true);  -- Allow system to create notifications for any user

CREATE POLICY "Users can update own notifications"
  ON notifications FOR UPDATE
  USING (auth.uid()::text = user_id);

CREATE POLICY "Users can delete own notifications"
  ON notifications FOR DELETE
  USING (auth.uid()::text = user_id);

-- Availability: Users can manage their own slots
CREATE POLICY "Users can view own availability"
  ON availability_slots FOR SELECT
  USING (auth.uid()::text = user_id);

CREATE POLICY "Users can create own availability"
  ON availability_slots FOR INSERT
  WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can update own availability"
  ON availability_slots FOR UPDATE
  USING (auth.uid()::text = user_id);

CREATE POLICY "Users can delete own availability"
  ON availability_slots FOR DELETE
  USING (auth.uid()::text = user_id);

-- Ban Votes: Authenticated users can vote
CREATE POLICY "Authenticated users can view votes"
  ON ban_votes FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can vote"
  ON ban_votes FOR INSERT
  WITH CHECK (auth.uid()::text = voter_id);

-- Bans: Everyone can view, only system can modify
CREATE POLICY "Anyone can view bans"
  ON bans FOR SELECT
  USING (true);

CREATE POLICY "System can manage bans"
  ON bans FOR ALL
  USING (true);  -- TODO: Restrict to admin users

-- Analytics: System only
CREATE POLICY "System can manage analytics"
  ON analytics FOR ALL
  USING (true);

-- System Health: Everyone can view
CREATE POLICY "Anyone can view system health"
  ON system_health FOR SELECT
  USING (true);

-- ============================================================================
-- REAL-TIME SUBSCRIPTIONS FOR SYSTEM TABLES
-- ============================================================================

ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE availability_slots;
