-- Supabase Schema for DualDatabaseService
-- Run this SQL in your Supabase SQL Editor to create all required tables

-- ============================================================================
-- USERS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
  uid TEXT PRIMARY KEY,
  displayName TEXT,
  email TEXT,
  pinnedGames TEXT[],
  bio TEXT,
  photoURL TEXT,
  createdAt TIMESTAMPTZ DEFAULT NOW(),
  updatedAt TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- ============================================================================
-- SQUADS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS squads (
  id TEXT PRIMARY KEY,
  members TEXT[],
  currentGame TEXT,
  squadSpots TEXT[],
  name TEXT,
  hostUid TEXT,
  createdAt TIMESTAMPTZ DEFAULT NOW(),
  updatedAt TIMESTAMPTZ DEFAULT NOW()
);

-- Index for member lookups
CREATE INDEX IF NOT EXISTS idx_squads_members ON squads USING GIN(members);

-- ============================================================================
-- MESSAGES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS messages (
  id TEXT PRIMARY KEY,
  senderUid TEXT NOT NULL,
  text TEXT,
  timestamp_ms BIGINT NOT NULL,
  imageUrl TEXT,
  videoUrl TEXT,
  audioUrl TEXT,
  pollId TEXT,
  replyTo TEXT,
  delivered BOOLEAN DEFAULT TRUE,
  read BOOLEAN DEFAULT FALSE,
  edited BOOLEAN DEFAULT FALSE,
  editedAt BIGINT,
  
  -- Context fields (use appropriate one based on chat type)
  squad_id TEXT,
  chat_group_id TEXT,
  chat_id TEXT,
  user_id TEXT,
  
  -- Reactions stored as JSONB array
  reactions JSONB DEFAULT '[]'::JSONB,
  
  createdAt TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_messages_squad ON messages(squad_id, timestamp_ms DESC);
CREATE INDEX IF NOT EXISTS idx_messages_group ON messages(chat_group_id, user_id, timestamp_ms DESC);
CREATE INDEX IF NOT EXISTS idx_messages_dm ON messages(chat_id, timestamp_ms DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(senderUid);

-- ============================================================================
-- CHAT GROUPS TABLE (DMs and User Groups)
-- ============================================================================
CREATE TABLE IF NOT EXISTS chat_groups (
  id TEXT PRIMARY KEY,
  name TEXT,
  members TEXT[],
  isPublic BOOLEAN DEFAULT FALSE,
  lastMessage TEXT,
  lastMessageTime BIGINT,
  createdAt TIMESTAMPTZ DEFAULT NOW(),
  updatedAt TIMESTAMPTZ DEFAULT NOW()
);

-- Index for member lookups
CREATE INDEX IF NOT EXISTS idx_chat_groups_members ON chat_groups USING GIN(members);

-- ============================================================================
-- CHAT BACKGROUNDS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS chat_backgrounds (
  chat_group_id TEXT PRIMARY KEY,
  url TEXT,
  type TEXT, -- 'image', 'video', 'gradient'
  opacity REAL DEFAULT 0.3,
  updatedAt TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- TYPING STATUS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS typing_status (
  user_id TEXT NOT NULL,
  chat_id TEXT NOT NULL,
  is_typing BOOLEAN DEFAULT FALSE,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, chat_id)
);

-- Index for chat lookups
CREATE INDEX IF NOT EXISTS idx_typing_chat ON typing_status(chat_id);

-- Auto-expire typing status after 5 seconds (optional)
-- Requires pg_cron extension
-- SELECT cron.schedule('typing-status-cleanup', '*/5 * * * *', 
--   'DELETE FROM typing_status WHERE updated_at < NOW() - INTERVAL ''5 seconds''');

-- ============================================================================
-- USER RATINGS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_ratings (
  uid TEXT PRIMARY KEY,
  totalRatings INT DEFAULT 0,
  averageScore REAL DEFAULT 0.0,
  lastRatedBy TEXT,
  lastRatedAt BIGINT,
  updatedAt TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- BANS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS bans (
  uid TEXT PRIMARY KEY,
  bans JSONB DEFAULT '[]'::JSONB, -- Array of ban objects
  updatedAt TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- ENABLE ROW LEVEL SECURITY (RLS)
-- ============================================================================
-- Uncomment and customize based on your auth requirements

-- Users table
-- ALTER TABLE users ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Users can view all profiles" ON users FOR SELECT USING (true);
-- CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid() = uid);

-- Squads table
-- ALTER TABLE squads ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Squad members can view" ON squads FOR SELECT USING (auth.uid() = ANY(members));
-- CREATE POLICY "Squad host can update" ON squads FOR UPDATE USING (auth.uid() = hostUid);

-- Messages table
-- ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Squad members can view messages" ON messages FOR SELECT 
--   USING (
--     squad_id IN (SELECT id FROM squads WHERE auth.uid() = ANY(members))
--     OR chat_group_id IN (SELECT id FROM chat_groups WHERE auth.uid() = ANY(members))
--   );

-- ============================================================================
-- REALTIME PUBLICATION
-- ============================================================================
-- Enable realtime for all tables
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE squads;
ALTER PUBLICATION supabase_realtime ADD TABLE users;
ALTER PUBLICATION supabase_realtime ADD TABLE chat_groups;
ALTER PUBLICATION supabase_realtime ADD TABLE chat_backgrounds;
ALTER PUBLICATION supabase_realtime ADD TABLE typing_status;

-- ============================================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================================

-- Auto-update updatedAt timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updatedAt = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updatedAt
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_squads_updated_at BEFORE UPDATE ON squads
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_chat_groups_updated_at BEFORE UPDATE ON chat_groups
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_chat_backgrounds_updated_at BEFORE UPDATE ON chat_backgrounds
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_ratings_updated_at BEFORE UPDATE ON user_ratings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bans_updated_at BEFORE UPDATE ON bans
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================
-- Run these to verify schema is created correctly

-- Check all tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('users', 'squads', 'messages', 'chat_groups', 'chat_backgrounds', 'typing_status', 'user_ratings', 'bans');

-- Check indexes
SELECT indexname, tablename FROM pg_indexes WHERE schemaname = 'public';

-- Check realtime publication
SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
