-- ============================================================================
-- SquadSync Supabase Database Schema
-- Firebase → Supabase Migration
-- ============================================================================

-- Enable UUID extension (for generating IDs if needed)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- USERS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS users (
  uid TEXT PRIMARY KEY,
  email TEXT UNIQUE,
  display_name TEXT,
  photo_url TEXT,
  pinned_games JSONB DEFAULT '[]'::jsonb,
  blocked_users TEXT[] DEFAULT ARRAY[]::TEXT[],
  banned_from_squads TEXT[] DEFAULT ARRAY[]::TEXT[],
  muted_chats TEXT[] DEFAULT ARRAY[]::TEXT[],
  fcm_token TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_display_name ON users(display_name);

-- ============================================================================
-- SQUADS TABLE
-- ============================================================================

-- Drop existing table if needed (WARNING: This deletes data!)
-- Uncomment the next line if you want to start fresh:
-- DROP TABLE IF EXISTS squads CASCADE;

CREATE TABLE IF NOT EXISTS squads (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  game_name TEXT,
  created_by TEXT,  -- Will add foreign key after users table exists
  member_uids TEXT[] DEFAULT ARRAY[]::TEXT[],  -- Squad member user IDs
  squad_spots JSONB DEFAULT '[]'::jsonb,  -- Array of user IDs in spots
  spot_timers JSONB DEFAULT '{}'::jsonb,  -- Map of spot index to timer data
  peacock_queue JSONB DEFAULT '[]'::jsonb,
  viewers TEXT[] DEFAULT ARRAY[]::TEXT[],  -- Users viewing but not in squad
  statuses JSONB DEFAULT '{}'::jsonb,  -- Map of user ID to status string
  settings JSONB DEFAULT '{}'::jsonb,
  max_spots INTEGER DEFAULT 8,  -- Match entity field name
  is_active BOOLEAN DEFAULT true,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add is_public column if it doesn't exist (safe migration)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'squads' AND column_name = 'is_public'
  ) THEN
    ALTER TABLE squads ADD COLUMN is_public BOOLEAN DEFAULT true;
  END IF;
END $$;

-- Add foreign key constraint to users table (safe - only if not exists)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'squads_created_by_fkey'
  ) THEN
    ALTER TABLE squads ADD CONSTRAINT squads_created_by_fkey 
      FOREIGN KEY (created_by) REFERENCES users(uid) ON DELETE SET NULL;
  END IF;
END $$;

-- Squad indexes
CREATE INDEX IF NOT EXISTS idx_squads_game_name ON squads(game_name);
CREATE INDEX IF NOT EXISTS idx_squads_created_by ON squads(created_by);
CREATE INDEX IF NOT EXISTS idx_squads_public ON squads(is_public);

-- ============================================================================
-- CHAT MESSAGES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS chat_messages (
  id TEXT PRIMARY KEY,
  sender_id TEXT NOT NULL,
  chat_id TEXT NOT NULL,  -- squad_id or chat_group_id
  chat_type TEXT NOT NULL DEFAULT 'squad',  -- squad, dm, userGroup
  text TEXT,
  message_type TEXT NOT NULL DEFAULT 'text',  -- text, image, video, audio, poll, etc.
  media_url TEXT,
  media_type TEXT,
  reactions JSONB DEFAULT '{}'::jsonb,
  reply_to TEXT,  -- Will add FK after table is fully created
  poll JSONB,
  voice_note_url TEXT,
  voice_note_duration INTEGER,
  ai_response TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  clip_data JSONB,
  is_edited BOOLEAN DEFAULT false,
  edited_at TIMESTAMPTZ,
  is_deleted BOOLEAN DEFAULT false,
  deleted_at TIMESTAMPTZ,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add foreign key constraints (safe - only if not exists)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'chat_messages_sender_id_fkey'
  ) THEN
    ALTER TABLE chat_messages ADD CONSTRAINT chat_messages_sender_id_fkey 
      FOREIGN KEY (sender_id) REFERENCES users(uid) ON DELETE CASCADE;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'chat_messages_reply_to_fkey'
  ) THEN
    ALTER TABLE chat_messages ADD CONSTRAINT chat_messages_reply_to_fkey 
      FOREIGN KEY (reply_to) REFERENCES chat_messages(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Message indexes for performance
CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON chat_messages(chat_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_type ON chat_messages(message_type);
CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON chat_messages(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_messages_deleted ON chat_messages(is_deleted) WHERE is_deleted = false;

-- ============================================================================
-- CHAT METADATA TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS chat_metadata (
  id TEXT PRIMARY KEY,  -- chat_id
  squad_id TEXT,
  chat_type TEXT DEFAULT 'squad',
  last_message_timestamp BIGINT DEFAULT 0,
  unread_counts JSONB DEFAULT '{}'::jsonb,  -- {userId: count}
  typing_users TEXT[] DEFAULT ARRAY[]::TEXT[],
  last_read_message_id JSONB DEFAULT '{}'::jsonb,  -- {userId: messageId}
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add foreign key constraint (safe - only if not exists)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'chat_metadata_squad_id_fkey'
  ) THEN
    ALTER TABLE chat_metadata ADD CONSTRAINT chat_metadata_squad_id_fkey 
      FOREIGN KEY (squad_id) REFERENCES squads(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Metadata indexes
CREATE INDEX IF NOT EXISTS idx_metadata_squad_id ON chat_metadata(squad_id);
CREATE INDEX IF NOT EXISTS idx_metadata_updated ON chat_metadata(updated_at DESC);

-- ============================================================================
-- CHAT GROUPS TABLE (for DMs and custom groups)
-- ============================================================================

CREATE TABLE IF NOT EXISTS chat_groups (
  id TEXT PRIMARY KEY,
  name TEXT,
  member_uids TEXT[] NOT NULL,
  is_dm BOOLEAN DEFAULT false,
  is_public BOOLEAN DEFAULT false,
  game_name TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add foreign key constraint (safe - only if not exists)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'chat_groups_created_by_fkey'
  ) THEN
    ALTER TABLE chat_groups ADD CONSTRAINT chat_groups_created_by_fkey 
      FOREIGN KEY (created_by) REFERENCES users(uid) ON DELETE SET NULL;
  END IF;
END $$;

-- Chat groups indexes
CREATE INDEX IF NOT EXISTS idx_chat_groups_members ON chat_groups USING GIN(member_uids);
CREATE INDEX IF NOT EXISTS idx_chat_groups_game ON chat_groups(game_name);
CREATE INDEX IF NOT EXISTS idx_chat_groups_public ON chat_groups(is_public);

-- ============================================================================
-- USER RATINGS TABLE (for reputation system)
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_ratings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  rated_user_uid TEXT NOT NULL,
  rater_uid TEXT NOT NULL,
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  feedback TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add unique constraint (safe - only if not exists)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'user_ratings_rated_user_uid_rater_uid_key'
  ) THEN
    ALTER TABLE user_ratings ADD CONSTRAINT user_ratings_rated_user_uid_rater_uid_key 
      UNIQUE(rated_user_uid, rater_uid);
  END IF;
END $$;

-- Add foreign key constraints (safe - only if not exists)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'user_ratings_rated_user_uid_fkey'
  ) THEN
    ALTER TABLE user_ratings ADD CONSTRAINT user_ratings_rated_user_uid_fkey 
      FOREIGN KEY (rated_user_uid) REFERENCES users(uid) ON DELETE CASCADE;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'user_ratings_rater_uid_fkey'
  ) THEN
    ALTER TABLE user_ratings ADD CONSTRAINT user_ratings_rater_uid_fkey 
      FOREIGN KEY (rater_uid) REFERENCES users(uid) ON DELETE CASCADE;
  END IF;
END $$;

-- Rating indexes
CREATE INDEX IF NOT EXISTS idx_ratings_rated_user ON user_ratings(rated_user_uid);
CREATE INDEX IF NOT EXISTS idx_ratings_rater ON user_ratings(rater_uid);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE squads ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_ratings ENABLE ROW LEVEL SECURITY;

-- Users: View all, update own profile
CREATE POLICY "Users can view all users" 
  ON users FOR SELECT 
  USING (true);

CREATE POLICY "Users can update own profile" 
  ON users FOR UPDATE 
  USING (auth.uid()::text = uid);

CREATE POLICY "Users can insert own profile"
  ON users FOR INSERT
  WITH CHECK (auth.uid()::text = uid);

-- Squads: Anyone can view, creators can update
CREATE POLICY "Anyone can view squads" 
  ON squads FOR SELECT 
  USING (true);

CREATE POLICY "Squad creators can update" 
  ON squads FOR UPDATE 
  USING (auth.uid()::text = created_by);

CREATE POLICY "Authenticated users can create squads"
  ON squads FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Messages: Anyone can view, authenticated can insert
CREATE POLICY "Anyone can view messages" 
  ON chat_messages FOR SELECT 
  USING (true);

CREATE POLICY "Authenticated users can send messages" 
  ON chat_messages FOR INSERT 
  WITH CHECK (auth.uid()::text = sender_id);

CREATE POLICY "Users can update own messages"
  ON chat_messages FOR UPDATE
  USING (auth.uid()::text = sender_id);

CREATE POLICY "Users can delete own messages"
  ON chat_messages FOR DELETE
  USING (auth.uid()::text = sender_id);

-- Chat Metadata: Anyone can view, system can update
CREATE POLICY "Anyone can view chat metadata"
  ON chat_metadata FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can update metadata"
  ON chat_metadata FOR ALL
  USING (auth.uid() IS NOT NULL);

-- Chat Groups: Members can view, creators can update
CREATE POLICY "Members can view groups"
  ON chat_groups FOR SELECT
  USING (auth.uid()::text = ANY(member_uids) OR is_public = true);

CREATE POLICY "Authenticated users can create groups"
  ON chat_groups FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Creators can update groups"
  ON chat_groups FOR UPDATE
  USING (auth.uid()::text = created_by);

-- Ratings: Anyone can view, users can rate others
CREATE POLICY "Anyone can view ratings"
  ON user_ratings FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can rate"
  ON user_ratings FOR INSERT
  WITH CHECK (auth.uid()::text = rater_uid AND auth.uid()::text != rated_user_uid);

-- ============================================================================
-- REAL-TIME SUBSCRIPTIONS
-- ============================================================================

-- Enable real-time for critical tables
ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE chat_metadata;
ALTER PUBLICATION supabase_realtime ADD TABLE squads;
ALTER PUBLICATION supabase_realtime ADD TABLE chat_groups;

-- ============================================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables with updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_squads_updated_at BEFORE UPDATE ON squads
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_chat_metadata_updated_at BEFORE UPDATE ON chat_metadata
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_chat_groups_updated_at BEFORE UPDATE ON chat_groups
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- MIGRATION NOTES
-- ============================================================================

/*
Migration Checklist:

1. ✅ Run this schema in Supabase SQL Editor
2. ⏳ Verify tables created successfully
3. ⏳ Test RLS policies with authenticated user
4. ⏳ Enable real-time subscriptions in Supabase dashboard
5. ⏳ Run data migration script (firestore_to_supabase_migrator.dart)
6. ⏳ Enable dual-write mode in app
7. ⏳ Monitor for errors and data consistency
8. ⏳ Gradually shift reads to Supabase
9. ⏳ Deprecate Firestore after 30 days

Key Differences from Firestore:
- Firestore: `timestampMs` (int) → Supabase: `timestamp` (TIMESTAMPTZ)
- Firestore: `senderId` → Supabase: `sender_id` (snake_case)
- Firestore: Collections → Supabase: Tables with foreign keys
- Firestore: Security Rules → Supabase: RLS Policies
- Firestore: Subcollections → Supabase: chat_id column for grouping

Performance Improvements:
- Indexed queries for O(log n) lookups
- PostgreSQL query optimizer
- Connection pooling (pgBouncer)
- Better complex query support (JOINs, aggregations)

Cost Savings:
- Firestore: $0.06 per 100k reads → Supabase: Included in flat rate
- Estimated 60% cost reduction for chat operations
*/
