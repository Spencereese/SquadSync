-- SquadSync: Missing Supabase Schemas for Firebase Migration
-- Date: December 7, 2025
-- Purpose: Create remaining tables needed for complete Firebase → Supabase migration
-- 
-- EXISTING TABLES (Already created):
-- ✅ users, squads, chat_groups, chat_messages, chat_metadata, chat_read_states
-- ✅ direct_messages, friends, friend_requests, typing_indicators
-- ✅ user_ratings, muted_games
--
-- MISSING TABLES (Created by this script):
-- ❌ polls (for poll_service.dart)
-- ❌ reactions (for reaction_service.dart)
-- ❌ peacocks (peacock queue - squad_tab.dart, peacock_modal.dart)
-- ❌ clips (may already exist - verify)
-- ❌ uid_migration_map (optional - Firebase → Supabase UID mapping)

-- Run in Supabase SQL Editor

-- =============================================================================
-- 1. POLLS TABLE
-- =============================================================================
-- Used by: lib/services/poll_service.dart
-- Purpose: Store message polls with voting options
-- Migration: From Firestore 'polls' collection

CREATE TABLE IF NOT EXISTS polls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id TEXT NOT NULL,  -- Changed from UUID to TEXT to match chat_messages.id
  chat_id TEXT,  -- Optional: for filtering polls by chat
  question TEXT NOT NULL,
  options JSONB NOT NULL,  -- Array of {text: string, votes: [user_ids]}
  created_by TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  total_votes INT DEFAULT 0,
  
  -- Foreign key to chat_messages (message_id is TEXT to match your schema)
  CONSTRAINT fk_poll_message
    FOREIGN KEY (message_id)
    REFERENCES chat_messages(id)
    ON DELETE CASCADE,
  
  -- Foreign key to users
  CONSTRAINT fk_poll_creator
    FOREIGN KEY (created_by)
    REFERENCES users(uid)
    ON DELETE CASCADE
);

-- Indexes for polls
CREATE INDEX IF NOT EXISTS idx_polls_message_id ON polls(message_id);
CREATE INDEX IF NOT EXISTS idx_polls_chat_id ON polls(chat_id);
CREATE INDEX IF NOT EXISTS idx_polls_created_by ON polls(created_by);
CREATE INDEX IF NOT EXISTS idx_polls_created_at ON polls(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_polls_expires_at ON polls(expires_at) WHERE expires_at IS NOT NULL;

-- RLS Policies for polls
ALTER TABLE polls ENABLE ROW LEVEL SECURITY;

-- Users can create polls
CREATE POLICY "Users can create polls"
ON polls FOR INSERT
TO authenticated
WITH CHECK (created_by = auth.uid()::text);

-- Users can view polls in their chats
CREATE POLICY "Users can view polls"
ON polls FOR SELECT
TO authenticated
USING (true);  -- Adjust based on chat membership if needed

-- Users can update their own polls (close/modify)
CREATE POLICY "Users can update own polls"
ON polls FOR UPDATE
TO authenticated
USING (created_by = auth.uid()::text);

-- Users can delete their own polls
CREATE POLICY "Users can delete own polls"
ON polls FOR DELETE
TO authenticated
USING (created_by = auth.uid()::text);

-- Comment
COMMENT ON TABLE polls IS 'Message polls with voting options';
COMMENT ON COLUMN polls.options IS 'JSONB array: [{text: string, votes: [user_uid]}]';

-- =============================================================================
-- 2. REACTIONS TABLE
-- =============================================================================
-- Used by: lib/services/reaction_service.dart, lib/chat/services/reaction_service.dart
-- Purpose: Store emoji reactions on messages
-- Migration: From Firestore 'reactions' subcollection

CREATE TABLE IF NOT EXISTS reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id TEXT NOT NULL,  -- Changed from UUID to TEXT to match chat_messages.id
  user_id TEXT NOT NULL,
  emoji TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Unique constraint: one user can only react once per emoji per message
  CONSTRAINT unique_message_user_emoji UNIQUE(message_id, user_id, emoji),
  
  -- Foreign key to chat_messages (message_id is TEXT to match your schema)
  CONSTRAINT fk_reaction_message
    FOREIGN KEY (message_id)
    REFERENCES chat_messages(id)
    ON DELETE CASCADE,
  
  -- Foreign key to users
  CONSTRAINT fk_reaction_user
    FOREIGN KEY (user_id)
    REFERENCES users(uid)
    ON DELETE CASCADE
);

-- Indexes for reactions
CREATE INDEX IF NOT EXISTS idx_reactions_message_id ON reactions(message_id);
CREATE INDEX IF NOT EXISTS idx_reactions_user_id ON reactions(user_id);
CREATE INDEX IF NOT EXISTS idx_reactions_created_at ON reactions(created_at DESC);

-- RLS Policies for reactions
ALTER TABLE reactions ENABLE ROW LEVEL SECURITY;

-- Users can add reactions
CREATE POLICY "Users can add reactions"
ON reactions FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid()::text);

-- Users can view all reactions
CREATE POLICY "Users can view reactions"
ON reactions FOR SELECT
TO authenticated
USING (true);

-- Users can delete their own reactions
CREATE POLICY "Users can delete own reactions"
ON reactions FOR DELETE
TO authenticated
USING (user_id = auth.uid()::text);

-- Comment
COMMENT ON TABLE reactions IS 'Emoji reactions on chat messages';

-- =============================================================================
-- 3. PEACOCKS TABLE (Peacock Queue)
-- =============================================================================
-- Used by: lib/chat/peacock_modal.dart, lib/squad_tab/squad_tab.dart
-- Purpose: Store peacock queue entries (users waiting for squad spots)
-- Migration: From Firestore 'peacocks' collection

CREATE TABLE IF NOT EXISTS peacocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id TEXT NOT NULL,
  user_uid TEXT NOT NULL,
  game_name TEXT NOT NULL,
  position INT NOT NULL DEFAULT 0,  -- Queue position
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,  -- Optional: auto-expire entries
  
  -- Unique constraint: one entry per user per squad per game
  CONSTRAINT unique_squad_user_game UNIQUE(squad_id, user_uid, game_name),
  
  -- Foreign key to squads
  CONSTRAINT fk_peacock_squad
    FOREIGN KEY (squad_id)
    REFERENCES squads(id)
    ON DELETE CASCADE,
  
  -- Foreign key to users
  CONSTRAINT fk_peacock_user
    FOREIGN KEY (user_uid)
    REFERENCES users(uid)
    ON DELETE CASCADE
);

-- Indexes for peacocks
CREATE INDEX IF NOT EXISTS idx_peacocks_squad_id ON peacocks(squad_id);
CREATE INDEX IF NOT EXISTS idx_peacocks_user_uid ON peacocks(user_uid);
CREATE INDEX IF NOT EXISTS idx_peacocks_game_name ON peacocks(game_name);
CREATE INDEX IF NOT EXISTS idx_peacocks_position ON peacocks(position);
CREATE INDEX IF NOT EXISTS idx_peacocks_created_at ON peacocks(created_at);

-- RLS Policies for peacocks
ALTER TABLE peacocks ENABLE ROW LEVEL SECURITY;

-- Users can add themselves to peacock queue
CREATE POLICY "Users can join peacock queue"
ON peacocks FOR INSERT
TO authenticated
WITH CHECK (user_uid = auth.uid()::text);

-- Users can view peacock queue entries
CREATE POLICY "Users can view peacock queue"
ON peacocks FOR SELECT
TO authenticated
USING (true);

-- Users can update their own entries
CREATE POLICY "Users can update own peacock entry"
ON peacocks FOR UPDATE
TO authenticated
USING (user_uid = auth.uid()::text);

-- Users can remove themselves from queue
CREATE POLICY "Users can leave peacock queue"
ON peacocks FOR DELETE
TO authenticated
USING (user_uid = auth.uid()::text);

-- Comment
COMMENT ON TABLE peacocks IS 'Peacock queue for squad spots (waiting list)';

-- =============================================================================
-- 4. CLIPS TABLE (VERIFY IF EXISTS)
-- =============================================================================
-- Used by: lib/services/clip_service.dart, lib/presentation/notifiers/clip_notifier.dart
-- Purpose: Store game clips metadata (video stored in Supabase Storage)
-- Migration: From Firestore 'clips' collection

-- Check if clips table exists first
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'clips') THEN
    -- Create clips table if it doesn't exist
    CREATE TABLE clips (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      squad_id TEXT,
      user_uid TEXT NOT NULL,
      game_name TEXT,
      title TEXT,
      description TEXT,
      video_url TEXT NOT NULL,  -- Supabase Storage URL
      thumbnail_url TEXT,
      duration_seconds INT,
      file_size_bytes BIGINT,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW(),
      views_count INT DEFAULT 0,
      likes_count INT DEFAULT 0,
      is_public BOOLEAN DEFAULT true,
      
      -- Foreign key to squads (optional - clips can be personal)
      CONSTRAINT fk_clip_squad
        FOREIGN KEY (squad_id)
        REFERENCES squads(id)
        ON DELETE SET NULL,
      
      -- Foreign key to users
      CONSTRAINT fk_clip_user
        FOREIGN KEY (user_uid)
        REFERENCES users(uid)
        ON DELETE CASCADE
    );
    
    -- Indexes for clips
    CREATE INDEX idx_clips_squad_id ON clips(squad_id);
    CREATE INDEX idx_clips_user_uid ON clips(user_uid);
    CREATE INDEX idx_clips_game_name ON clips(game_name);
    CREATE INDEX idx_clips_created_at ON clips(created_at DESC);
    CREATE INDEX idx_clips_is_public ON clips(is_public) WHERE is_public = true;
    
    -- RLS Policies for clips
    ALTER TABLE clips ENABLE ROW LEVEL SECURITY;
    
    -- Users can upload clips
    CREATE POLICY "Users can upload clips"
    ON clips FOR INSERT
    TO authenticated
    WITH CHECK (user_uid = auth.uid()::text);
    
    -- Users can view public clips or their own clips
    CREATE POLICY "Users can view clips"
    ON clips FOR SELECT
    TO authenticated
    USING (is_public = true OR user_uid = auth.uid()::text);
    
    -- Users can update their own clips
    CREATE POLICY "Users can update own clips"
    ON clips FOR UPDATE
    TO authenticated
    USING (user_uid = auth.uid()::text);
    
    -- Users can delete their own clips
    CREATE POLICY "Users can delete own clips"
    ON clips FOR DELETE
    TO authenticated
    USING (user_uid = auth.uid()::text);
    
    -- Comment
    COMMENT ON TABLE clips IS 'Game clips metadata (videos in Supabase Storage)';
    
    RAISE NOTICE 'clips table created successfully';
  ELSE
    RAISE NOTICE 'clips table already exists - skipping creation';
  END IF;
END $$;

-- =============================================================================
-- 5. UID_MIGRATION_MAP TABLE (OPTIONAL)
-- =============================================================================
-- Purpose: Map Firebase UIDs (28-char) to Supabase UIDs (36-char UUID)
-- Use: If you need to maintain backward compatibility during migration
-- Note: Only create if you're keeping Firebase Auth alongside Supabase Auth

CREATE TABLE IF NOT EXISTS uid_migration_map (
  firebase_uid TEXT PRIMARY KEY,
  supabase_uid UUID NOT NULL,
  migrated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Ensure one-to-one mapping
  CONSTRAINT unique_supabase_uid UNIQUE(supabase_uid)
);

-- Index for reverse lookup
CREATE INDEX IF NOT EXISTS idx_uid_map_supabase ON uid_migration_map(supabase_uid);

-- RLS Policies for uid_migration_map (admin only)
ALTER TABLE uid_migration_map ENABLE ROW LEVEL SECURITY;

-- Only allow authenticated users to read (no insert/update for regular users)
CREATE POLICY "Users can read UID mappings"
ON uid_migration_map FOR SELECT
TO authenticated
USING (true);

-- Comment
COMMENT ON TABLE uid_migration_map IS 'Firebase to Supabase UID mapping for migration';

-- =============================================================================
-- 6. STORAGE BUCKETS (If not already created)
-- =============================================================================
-- Create storage buckets for media files

DO $$ 
BEGIN
  -- Create clips bucket
  IF NOT EXISTS (SELECT FROM storage.buckets WHERE id = 'clips') THEN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('clips', 'clips', true);
    RAISE NOTICE 'clips bucket created';
  ELSE
    RAISE NOTICE 'clips bucket already exists';
  END IF;
  
  -- Create avatars bucket
  IF NOT EXISTS (SELECT FROM storage.buckets WHERE id = 'avatars') THEN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('avatars', 'avatars', true);
    RAISE NOTICE 'avatars bucket created';
  ELSE
    RAISE NOTICE 'avatars bucket already exists';
  END IF;
  
  -- Create media bucket (for chat media)
  IF NOT EXISTS (SELECT FROM storage.buckets WHERE id = 'media') THEN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('media', 'media', false);
    RAISE NOTICE 'media bucket created';
  ELSE
    RAISE NOTICE 'media bucket already exists';
  END IF;
END $$;

-- =============================================================================
-- 7. STORAGE RLS POLICIES
-- =============================================================================

-- Clips bucket policies (public read, authenticated write)
DO $$
BEGIN
  -- Allow authenticated users to upload clips
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Users can upload clips'
  ) THEN
    CREATE POLICY "Users can upload clips"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
      bucket_id = 'clips' 
      AND auth.uid()::text = (storage.foldername(name))[1]
    );
  END IF;
  
  -- Allow public read for clips
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Public can view clips'
  ) THEN
    CREATE POLICY "Public can view clips"
    ON storage.objects FOR SELECT
    TO public
    USING (bucket_id = 'clips');
  END IF;
  
  -- Allow users to delete their own clips
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Users can delete own clips'
  ) THEN
    CREATE POLICY "Users can delete own clips"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
      bucket_id = 'clips' 
      AND auth.uid()::text = (storage.foldername(name))[1]
    );
  END IF;
END $$;

-- Avatars bucket policies (public read, authenticated write)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Users can upload avatars'
  ) THEN
    CREATE POLICY "Users can upload avatars"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
      bucket_id = 'avatars' 
      AND auth.uid()::text = (storage.foldername(name))[1]
    );
  END IF;
  
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Public can view avatars'
  ) THEN
    CREATE POLICY "Public can view avatars"
    ON storage.objects FOR SELECT
    TO public
    USING (bucket_id = 'avatars');
  END IF;
  
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Users can update own avatars'
  ) THEN
    CREATE POLICY "Users can update own avatars"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
      bucket_id = 'avatars' 
      AND auth.uid()::text = (storage.foldername(name))[1]
    );
  END IF;
END $$;

-- Media bucket policies (private - authenticated only)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Users can upload media'
  ) THEN
    CREATE POLICY "Users can upload media"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
      bucket_id = 'media' 
      AND auth.uid()::text = (storage.foldername(name))[1]
    );
  END IF;
  
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Users can view own media'
  ) THEN
    CREATE POLICY "Users can view own media"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
      bucket_id = 'media' 
      AND auth.uid()::text = (storage.foldername(name))[1]
    );
  END IF;
END $$;

-- =============================================================================
-- 8. VERIFICATION QUERIES
-- =============================================================================

-- Run these to verify tables were created successfully

-- Check all tables
SELECT 
  table_name,
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as column_count
FROM information_schema.tables t
WHERE table_schema = 'public'
  AND table_name IN ('polls', 'reactions', 'peacocks', 'clips', 'uid_migration_map')
ORDER BY table_name;

-- Check RLS is enabled
SELECT 
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('polls', 'reactions', 'peacocks', 'clips', 'uid_migration_map');

-- Check storage buckets
SELECT id, name, public FROM storage.buckets 
WHERE id IN ('clips', 'avatars', 'media');

-- Check foreign key relationships for new tables
SELECT 
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name IN ('polls', 'reactions', 'peacocks', 'clips')
ORDER BY tc.table_name, kcu.column_name;

-- =============================================================================
-- MIGRATION READINESS CHECK
-- =============================================================================

-- Final verification: all required tables exist
DO $$
DECLARE
  missing_tables TEXT[] := ARRAY[]::TEXT[];
  required_tables TEXT[] := ARRAY['users', 'squads', 'chat_messages', 'chat_metadata', 
                                   'polls', 'reactions', 'peacocks', 'clips'];
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY required_tables
  LOOP
    IF NOT EXISTS (SELECT FROM information_schema.tables WHERE table_name = tbl) THEN
      missing_tables := array_append(missing_tables, tbl);
    END IF;
  END LOOP;
  
  IF array_length(missing_tables, 1) > 0 THEN
    RAISE WARNING 'Missing tables: %', array_to_string(missing_tables, ', ');
  ELSE
    RAISE NOTICE '✅ All required tables exist! Migration schema ready.';
  END IF;
END $$;

-- =============================================================================
-- NOTES FOR MIGRATION
-- =============================================================================

-- 1. chat_messages.id type:
--    - ✅ UPDATED: chat_messages.id is TEXT (not UUID)
--    - polls.message_id and reactions.message_id are now TEXT to match
--    - Foreign key constraints updated accordingly

-- 2. UID format:
--    - Supabase Auth uses UUID format (36-char)
--    - Firebase uses custom format (28-char)
--    - The uid_migration_map table helps maintain compatibility
--    - You may need to update existing users table UIDs during migration

-- 3. Storage organization:
--    - clips bucket: /user_uid/clip_id/video.mp4
--    - avatars bucket: /user_uid/avatar.jpg
--    - media bucket: /user_uid/chat_id/filename.ext

-- 4. Next steps:
--    - Run firestore_to_supabase_migrator.dart to migrate data
--    - Update Dart services to use these new tables
--    - Test RLS policies with multiple users
--    - Monitor Supabase logs for any access issues

-- =============================================================================
-- END OF SCHEMA
-- =============================================================================
