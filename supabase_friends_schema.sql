-- ============================================================================
-- SquadSync Friends System - Supabase Schema
-- ============================================================================

-- ============================================================================
-- FRIENDS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS friends (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_uid TEXT NOT NULL,
  friend_uid TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'accepted', -- accepted, blocked
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT friends_users_different CHECK (user_uid != friend_uid),
  CONSTRAINT friends_unique_pair UNIQUE(user_uid, friend_uid)
);

-- Add foreign key constraints
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'friends_user_uid_fkey'
  ) THEN
    ALTER TABLE friends ADD CONSTRAINT friends_user_uid_fkey 
      FOREIGN KEY (user_uid) REFERENCES users(uid) ON DELETE CASCADE;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'friends_friend_uid_fkey'
  ) THEN
    ALTER TABLE friends ADD CONSTRAINT friends_friend_uid_fkey 
      FOREIGN KEY (friend_uid) REFERENCES users(uid) ON DELETE CASCADE;
  END IF;
END $$;

-- Friends indexes
CREATE INDEX IF NOT EXISTS idx_friends_user_uid ON friends(user_uid, status);
CREATE INDEX IF NOT EXISTS idx_friends_friend_uid ON friends(friend_uid, status);
CREATE INDEX IF NOT EXISTS idx_friends_created_at ON friends(created_at DESC);

-- ============================================================================
-- FRIEND REQUESTS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS friend_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  from_uid TEXT NOT NULL,
  to_uid TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, accepted, declined
  message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT friend_requests_users_different CHECK (from_uid != to_uid),
  CONSTRAINT friend_requests_unique_pair UNIQUE(from_uid, to_uid)
);

-- Add foreign key constraints
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'friend_requests_from_uid_fkey'
  ) THEN
    ALTER TABLE friend_requests ADD CONSTRAINT friend_requests_from_uid_fkey 
      FOREIGN KEY (from_uid) REFERENCES users(uid) ON DELETE CASCADE;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'friend_requests_to_uid_fkey'
  ) THEN
    ALTER TABLE friend_requests ADD CONSTRAINT friend_requests_to_uid_fkey 
      FOREIGN KEY (to_uid) REFERENCES users(uid) ON DELETE CASCADE;
  END IF;
END $$;

-- Friend requests indexes
CREATE INDEX IF NOT EXISTS idx_friend_requests_to_uid ON friend_requests(to_uid, status);
CREATE INDEX IF NOT EXISTS idx_friend_requests_from_uid ON friend_requests(from_uid, status);
CREATE INDEX IF NOT EXISTS idx_friend_requests_status ON friend_requests(status);

-- ============================================================================
-- DIRECT MESSAGES TABLE (DMs)
-- ============================================================================

CREATE TABLE IF NOT EXISTS direct_messages (
  id TEXT PRIMARY KEY,
  sender_uid TEXT NOT NULL,
  recipient_uid TEXT NOT NULL,
  text TEXT,
  message_type TEXT NOT NULL DEFAULT 'text',
  media_url TEXT,
  media_type TEXT,
  reactions JSONB DEFAULT '{}'::jsonb,
  is_read BOOLEAN DEFAULT false,
  is_edited BOOLEAN DEFAULT false,
  edited_at TIMESTAMPTZ,
  is_deleted BOOLEAN DEFAULT false,
  deleted_at TIMESTAMPTZ,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add foreign key constraints
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'direct_messages_sender_uid_fkey'
  ) THEN
    ALTER TABLE direct_messages ADD CONSTRAINT direct_messages_sender_uid_fkey 
      FOREIGN KEY (sender_uid) REFERENCES users(uid) ON DELETE CASCADE;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'direct_messages_recipient_uid_fkey'
  ) THEN
    ALTER TABLE direct_messages ADD CONSTRAINT direct_messages_recipient_uid_fkey 
      FOREIGN KEY (recipient_uid) REFERENCES users(uid) ON DELETE CASCADE;
  END IF;
END $$;

-- DM indexes
CREATE INDEX IF NOT EXISTS idx_dm_sender ON direct_messages(sender_uid, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_dm_recipient ON direct_messages(recipient_uid, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_dm_conversation ON direct_messages(sender_uid, recipient_uid, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_dm_unread ON direct_messages(recipient_uid, is_read) WHERE is_read = false;

-- ============================================================================
-- MUTED GAMES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS muted_games (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_uid TEXT NOT NULL,
  game_slug TEXT NOT NULL,
  game_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT muted_games_unique_pair UNIQUE(user_uid, game_slug)
);

-- Add foreign key constraint
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'muted_games_user_uid_fkey'
  ) THEN
    ALTER TABLE muted_games ADD CONSTRAINT muted_games_user_uid_fkey 
      FOREIGN KEY (user_uid) REFERENCES users(uid) ON DELETE CASCADE;
  END IF;
END $$;

-- Muted games indexes
CREATE INDEX IF NOT EXISTS idx_muted_games_user ON muted_games(user_uid);
CREATE INDEX IF NOT EXISTS idx_muted_games_slug ON muted_games(game_slug);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS
ALTER TABLE friends ENABLE ROW LEVEL SECURITY;
ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE direct_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE muted_games ENABLE ROW LEVEL SECURITY;

-- Helper function to get Firebase UID from Supabase auth user metadata
CREATE OR REPLACE FUNCTION get_firebase_uid()
RETURNS TEXT AS $$
BEGIN
  -- Get Firebase UID from user metadata (stored during signup/signin)
  RETURN COALESCE(
    (auth.jwt() -> 'user_metadata' ->> 'firebase_uid')::text,
    auth.uid()::text  -- Fallback to Supabase UID if no Firebase UID
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Friends policies (using Firebase UID from metadata)
DROP POLICY IF EXISTS "Users can view own friends" ON friends;
CREATE POLICY "Users can view own friends"
  ON friends FOR SELECT
  USING (get_firebase_uid() = user_uid OR get_firebase_uid() = friend_uid);

DROP POLICY IF EXISTS "Users can manage own friendships" ON friends;
CREATE POLICY "Users can manage own friendships"
  ON friends FOR ALL
  USING (get_firebase_uid() = user_uid);

-- Friend requests policies
DROP POLICY IF EXISTS "Users can view own requests" ON friend_requests;
CREATE POLICY "Users can view own requests"
  ON friend_requests FOR SELECT
  USING (get_firebase_uid() = from_uid OR get_firebase_uid() = to_uid);

DROP POLICY IF EXISTS "Users can send friend requests" ON friend_requests;
CREATE POLICY "Users can send friend requests"
  ON friend_requests FOR INSERT
  WITH CHECK (get_firebase_uid() = from_uid);

DROP POLICY IF EXISTS "Users can respond to requests sent to them" ON friend_requests;
CREATE POLICY "Users can respond to requests sent to them"
  ON friend_requests FOR UPDATE
  USING (get_firebase_uid() = to_uid);

DROP POLICY IF EXISTS "Users can delete own sent requests" ON friend_requests;
CREATE POLICY "Users can delete own sent requests"
  ON friend_requests FOR DELETE
  USING (get_firebase_uid() = from_uid);

-- Direct messages policies
DROP POLICY IF EXISTS "Users can view own DMs" ON direct_messages;
CREATE POLICY "Users can view own DMs"
  ON direct_messages FOR SELECT
  USING (get_firebase_uid() = sender_uid OR get_firebase_uid() = recipient_uid);

DROP POLICY IF EXISTS "Users can send DMs" ON direct_messages;
CREATE POLICY "Users can send DMs"
  ON direct_messages FOR INSERT
  WITH CHECK (get_firebase_uid() = sender_uid);

DROP POLICY IF EXISTS "Users can update own sent messages" ON direct_messages;
CREATE POLICY "Users can update own sent messages"
  ON direct_messages FOR UPDATE
  USING (get_firebase_uid() = sender_uid);

DROP POLICY IF EXISTS "Users can delete own messages" ON direct_messages;
CREATE POLICY "Users can delete own messages"
  ON direct_messages FOR DELETE
  USING (get_firebase_uid() = sender_uid);

-- Muted games policies
DROP POLICY IF EXISTS "Users can view own muted games" ON muted_games;
CREATE POLICY "Users can view own muted games"
  ON muted_games FOR SELECT
  USING (get_firebase_uid() = user_uid);

DROP POLICY IF EXISTS "Users can manage own muted games" ON muted_games;
CREATE POLICY "Users can manage own muted games"
  ON muted_games FOR ALL
  USING (get_firebase_uid() = user_uid);

-- ============================================================================
-- REAL-TIME SUBSCRIPTIONS
-- ============================================================================

ALTER PUBLICATION supabase_realtime ADD TABLE friends;
ALTER PUBLICATION supabase_realtime ADD TABLE friend_requests;
ALTER PUBLICATION supabase_realtime ADD TABLE direct_messages;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Auto-update updated_at
CREATE TRIGGER update_friends_updated_at BEFORE UPDATE ON friends
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_friend_requests_updated_at BEFORE UPDATE ON friend_requests
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to create bidirectional friendship when request is accepted
CREATE OR REPLACE FUNCTION accept_friend_request(request_id UUID)
RETURNS VOID AS $$
DECLARE
  from_user TEXT;
  to_user TEXT;
BEGIN
  -- Get the users from the request
  SELECT from_uid, to_uid INTO from_user, to_user
  FROM friend_requests
  WHERE id = request_id AND status = 'pending';
  
  IF from_user IS NULL THEN
    RAISE EXCEPTION 'Friend request not found or already processed';
  END IF;
  
  -- Update request status
  UPDATE friend_requests
  SET status = 'accepted', updated_at = NOW()
  WHERE id = request_id;
  
  -- Create bidirectional friendship
  INSERT INTO friends (user_uid, friend_uid, status)
  VALUES (from_user, to_user, 'accepted')
  ON CONFLICT (user_uid, friend_uid) DO NOTHING;
  
  INSERT INTO friends (user_uid, friend_uid, status)
  VALUES (to_user, from_user, 'accepted')
  ON CONFLICT (user_uid, friend_uid) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to remove friendship (bidirectional)
CREATE OR REPLACE FUNCTION remove_friendship(user1_uid TEXT, user2_uid TEXT)
RETURNS VOID AS $$
BEGIN
  DELETE FROM friends
  WHERE (user_uid = user1_uid AND friend_uid = user2_uid)
     OR (user_uid = user2_uid AND friend_uid = user1_uid);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- USAGE NOTES
-- ============================================================================

/*
Friend System Workflow:

1. Send Friend Request:
   INSERT INTO friend_requests (from_uid, to_uid, message)
   VALUES ('user1', 'user2', 'Hey, let's play together!');

2. Accept Request (creates bidirectional friendship):
   SELECT accept_friend_request(request_id);

3. Decline Request:
   UPDATE friend_requests SET status = 'declined' WHERE id = request_id;

4. Remove Friend (bidirectional):
   SELECT remove_friendship('user1', 'user2');

5. Send DM:
   INSERT INTO direct_messages (sender_uid, recipient_uid, text)
   VALUES ('user1', 'user2', 'Hello!');

6. Stream Friends (real-time):
   SELECT u.* FROM friends f
   JOIN users u ON u.uid = f.friend_uid
   WHERE f.user_uid = current_user_uid AND f.status = 'accepted';

7. Stream DMs:
   SELECT * FROM direct_messages
   WHERE (sender_uid = user1 AND recipient_uid = user2)
      OR (sender_uid = user2 AND recipient_uid = user1)
   ORDER BY timestamp DESC;
*/
