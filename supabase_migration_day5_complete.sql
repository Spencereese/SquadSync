-- Supabase Migration Day 5 - Complete Setup
-- Date: December 8, 2025
-- Run this file in Supabase SQL Editor to complete the migration

-- ==============================================================================
-- STEP 1: Disable RLS temporarily to allow schema changes
-- ==============================================================================
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- ==============================================================================
-- STEP 2: Add missing user profile fields
-- ==============================================================================
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS profile_image TEXT,
ADD COLUMN IF NOT EXISTS preferred_modes JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS user_blocks JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS notification_settings JSONB DEFAULT '{
  "pushNotifications": true,
  "soundEnabled": true,
  "vibrationEnabled": true,
  "showPreviews": true,
  "quietHoursEnabled": false,
  "urgentAlertsOnly": false,
  "lobbyInvites": true,
  "friendRequests": true,
  "gameUpdates": false,
  "achievementAlerts": true
}'::jsonb,
ADD COLUMN IF NOT EXISTS friends TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN IF NOT EXISTS alerts TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN IF NOT EXISTS user_groups JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS alert_circles TEXT[] DEFAULT ARRAY['Squad', 'Friends', 'Public']::TEXT[],
ADD COLUMN IF NOT EXISTS public_groups JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS pinned_messages TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN IF NOT EXISTS peacock JSONB DEFAULT NULL;

-- ==============================================================================
-- STEP 3: Ensure chat_groups table has all required fields
-- ==============================================================================
ALTER TABLE chat_groups
ADD COLUMN IF NOT EXISTS members TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN IF NOT EXISTS member_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS invite_code TEXT,
ADD COLUMN IF NOT EXISTS image_url TEXT,
ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS created_by TEXT,
ADD COLUMN IF NOT EXISTS last_message TEXT,
ADD COLUMN IF NOT EXISTS last_message_time TIMESTAMPTZ;

-- ==============================================================================
-- STEP 4: Ensure chats table has all required fields (for DMs)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS chats (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  participants TEXT[] NOT NULL,
  last_message TEXT,
  last_message_time TIMESTAMPTZ DEFAULT NOW(),
  unread_count JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for chats table
CREATE INDEX IF NOT EXISTS idx_chats_participants ON chats USING GIN (participants);
CREATE INDEX IF NOT EXISTS idx_chats_last_message_time ON chats(last_message_time DESC);

-- ==============================================================================
-- STEP 5: Re-enable RLS with permissive policies for testing
-- ==============================================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Drop existing policies and recreate
DROP POLICY IF EXISTS "Users can insert own profile" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Users can view all profiles" ON users;
DROP POLICY IF EXISTS "allow_all_authenticated" ON users;

-- Create permissive policy for authenticated users
CREATE POLICY "allow_all_authenticated" 
ON users FOR ALL 
TO authenticated 
USING (true) 
WITH CHECK (true);

-- RLS for chat_groups
ALTER TABLE chat_groups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "allow_all_authenticated" ON chat_groups;
CREATE POLICY "allow_all_authenticated" 
ON chat_groups FOR ALL 
TO authenticated 
USING (true) 
WITH CHECK (true);

-- RLS for chats
ALTER TABLE chats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "allow_all_authenticated" ON chats;
CREATE POLICY "allow_all_authenticated" 
ON chats FOR ALL 
TO authenticated 
USING (true) 
WITH CHECK (true);

-- ==============================================================================
-- STEP 6: Verify tables and columns
-- ==============================================================================
SELECT 
  table_name,
  column_name,
  data_type,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name IN ('users', 'chat_groups', 'chats')
ORDER BY table_name, ordinal_position;

-- ==============================================================================
-- STEP 7: Verify RLS policies
-- ==============================================================================
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename IN ('users', 'chat_groups', 'chats')
ORDER BY tablename, policyname;

-- ==============================================================================
-- MIGRATION NOTES
-- ==============================================================================
-- This migration adds:
-- 1. User profile fields for full app functionality
-- 2. Chat group fields for group chat support
-- 3. Chats table for direct messaging
-- 4. Permissive RLS policies for testing (tighten security later)
--
-- Next steps:
-- 1. Run this SQL in Supabase SQL Editor
-- 2. Press 'R' in Flutter terminal for hot restart
-- 3. Test: Sign in, save display name, view profile
-- 4. Migrate remaining 65 Firebase calls (chat_screen, clip_notifier, etc.)
-- ==============================================================================
