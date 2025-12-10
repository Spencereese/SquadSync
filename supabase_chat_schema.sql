-- Supabase Chat Schema - Replaces Firestore chat system
-- Run this after supabase_schema.sql and supabase_friends_schema.sql
-- This updates/enhances the existing chat_messages table

-- Update existing chat_messages table structure (add missing columns if needed)
DO $$ 
BEGIN
  -- Add edited_at if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'chat_messages' AND column_name = 'edited_at'
  ) THEN
    ALTER TABLE chat_messages ADD COLUMN edited_at TIMESTAMPTZ;
  END IF;
  
  -- Add deleted if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'chat_messages' AND column_name = 'deleted'
  ) THEN
    ALTER TABLE chat_messages ADD COLUMN deleted BOOLEAN DEFAULT false;
  END IF;
  
  -- Add deleted_at if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'chat_messages' AND column_name = 'deleted_at'
  ) THEN
    ALTER TABLE chat_messages ADD COLUMN deleted_at TIMESTAMPTZ;
  END IF;
END $$;

-- Ensure indexes exist for chat queries
CREATE INDEX IF NOT EXISTS idx_chat_messages_chat_id ON chat_messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_chat_type ON chat_messages(chat_type);
CREATE INDEX IF NOT EXISTS idx_chat_messages_timestamp ON chat_messages(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender ON chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_reply ON chat_messages(reply_to);
CREATE INDEX IF NOT EXISTS idx_chat_messages_composite ON chat_messages(chat_id, timestamp DESC);

-- Update chat_metadata table to add participant_ids for DMs/user groups
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'chat_metadata' AND column_name = 'participant_ids'
  ) THEN
    ALTER TABLE chat_metadata ADD COLUMN participant_ids TEXT[] DEFAULT ARRAY[]::TEXT[];
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'chat_metadata' AND column_name = 'last_message'
  ) THEN
    ALTER TABLE chat_metadata ADD COLUMN last_message TEXT;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'chat_metadata' AND column_name = 'last_message_sender_id'
  ) THEN
    ALTER TABLE chat_metadata ADD COLUMN last_message_sender_id TEXT;
  END IF;
END $$;

-- User-specific chat read states
CREATE TABLE IF NOT EXISTS chat_read_states (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  chat_id TEXT NOT NULL,
  last_read_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  unread_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  UNIQUE(user_id, chat_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_read_states_user ON chat_read_states(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_read_states_chat ON chat_read_states(chat_id);

-- Typing indicators (ephemeral, cleaned by cron)
CREATE TABLE IF NOT EXISTS typing_indicators (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  chat_id TEXT NOT NULL,
  is_typing BOOLEAN DEFAULT false,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_typing_indicators_chat ON typing_indicators(chat_id);
CREATE INDEX IF NOT EXISTS idx_typing_indicators_updated ON typing_indicators(updated_at);

-- RLS Policies for chat_messages

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can read messages from their chats" ON chat_messages;
DROP POLICY IF EXISTS "Users can send messages to their chats" ON chat_messages;
DROP POLICY IF EXISTS "Users can edit their own messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can delete their own messages" ON chat_messages;

-- Helper function to check if user is in a chat
CREATE OR REPLACE FUNCTION is_user_in_chat(p_user_id TEXT, p_chat_id TEXT, p_chat_type TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  IF p_chat_type = 'squad' THEN
    -- Check if user is in squad
    RETURN EXISTS (
      SELECT 1 FROM squad_members 
      WHERE squad_id = p_chat_id::UUID 
      AND user_id = p_user_id
    );
  ELSIF p_chat_type = 'dm' OR p_chat_type = 'userGroup' THEN
    -- Check if user is in participant list
    RETURN EXISTS (
      SELECT 1 FROM chat_metadata m
      WHERE m.id = p_chat_id
      AND p_user_id = ANY(m.participant_ids)
    );
  ELSE
    RETURN false;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Users can read messages from chats they're in
CREATE POLICY "Users can read messages from their chats"
  ON chat_messages FOR SELECT
  USING (is_user_in_chat(auth.uid()::TEXT, chat_messages.chat_id, chat_messages.chat_type));

-- Users can send messages to chats they're in
CREATE POLICY "Users can send messages to their chats"
  ON chat_messages FOR INSERT
  WITH CHECK (
    chat_messages.sender_id = auth.uid()::TEXT AND
    is_user_in_chat(auth.uid()::TEXT, chat_messages.chat_id, chat_messages.chat_type)
  );

-- Users can edit their own messages
CREATE POLICY "Users can edit their own messages"
  ON chat_messages FOR UPDATE
  USING (chat_messages.sender_id = auth.uid()::TEXT)
  WITH CHECK (chat_messages.sender_id = auth.uid()::TEXT);

-- Users can delete their own messages (soft delete)
CREATE POLICY "Users can delete their own messages"
  ON chat_messages FOR UPDATE
  USING (chat_messages.sender_id = auth.uid()::TEXT AND chat_messages.deleted = false)
  WITH CHECK (chat_messages.sender_id = auth.uid()::TEXT AND chat_messages.deleted = true);

-- RLS Policies for chat_metadata

ALTER TABLE chat_metadata ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read chat metadata for their chats" ON chat_metadata;
DROP POLICY IF EXISTS "System can update chat metadata" ON chat_metadata;

-- Users can read metadata for chats they're in
CREATE POLICY "Users can read chat metadata for their chats"
  ON chat_metadata FOR SELECT
  USING (
    chat_metadata.chat_type IS NULL OR 
    is_user_in_chat(auth.uid()::TEXT, chat_metadata.id, COALESCE(chat_metadata.chat_type, 'squad'))
  );

-- System can update chat metadata (use service role)
CREATE POLICY "System can update chat metadata"
  ON chat_metadata FOR ALL
  USING (true)
  WITH CHECK (true);

-- RLS Policies for chat_read_states

ALTER TABLE chat_read_states ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own read states" ON chat_read_states;

-- Users can manage their own read states
CREATE POLICY "Users can manage their own read states"
  ON chat_read_states FOR ALL
  USING (chat_read_states.user_id = auth.uid()::TEXT)
  WITH CHECK (chat_read_states.user_id = auth.uid()::TEXT);

-- RLS Policies for typing_indicators

ALTER TABLE typing_indicators ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read typing indicators for their chats" ON typing_indicators;
DROP POLICY IF EXISTS "Users can manage their own typing indicators" ON typing_indicators;

-- Users can read typing indicators for chats they're in
CREATE POLICY "Users can read typing indicators for their chats"
  ON typing_indicators FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM chat_metadata m
      WHERE m.id = typing_indicators.chat_id
      AND is_user_in_chat(auth.uid()::TEXT, m.id, COALESCE(m.chat_type, 'squad'))
    )
  );

-- Users can manage their own typing indicators
CREATE POLICY "Users can manage their own typing indicators"
  ON typing_indicators FOR ALL
  USING (typing_indicators.user_id = auth.uid()::TEXT)
  WITH CHECK (typing_indicators.user_id = auth.uid()::TEXT);

-- Enable realtime for chat messages (only if not already added)
DO $$
BEGIN
  -- Check if chat_messages is already in the publication
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'chat_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
  END IF;
  
  -- Check if typing_indicators is already in the publication
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'typing_indicators'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE typing_indicators;
  END IF;
END $$;

-- Function to update chat metadata on new message
CREATE OR REPLACE FUNCTION update_chat_metadata_on_message()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO chat_metadata (id, chat_type, last_message, last_message_timestamp, last_message_sender_id)
  VALUES (NEW.chat_id, NEW.chat_type, NEW.text, EXTRACT(EPOCH FROM NEW.timestamp)::BIGINT * 1000, NEW.sender_id)
  ON CONFLICT (id) DO UPDATE
  SET 
    last_message = NEW.text,
    last_message_timestamp = EXTRACT(EPOCH FROM NEW.timestamp)::BIGINT * 1000,
    last_message_sender_id = NEW.sender_id,
    updated_at = now();
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_chat_metadata_trigger ON chat_messages;
CREATE TRIGGER update_chat_metadata_trigger
  AFTER INSERT ON chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_chat_metadata_on_message();

-- Function to increment unread counts
CREATE OR REPLACE FUNCTION increment_unread_counts()
RETURNS TRIGGER AS $$
BEGIN
  -- Get all participants in the chat (except sender)
  IF NEW.chat_type = 'squad' THEN
    -- For squads, increment for all squad members except sender
    INSERT INTO chat_read_states (user_id, chat_id, unread_count)
    SELECT user_id, NEW.chat_id, 1
    FROM squad_members
    WHERE squad_id = NEW.chat_id::UUID AND user_id != NEW.sender_id
    ON CONFLICT (user_id, chat_id) DO UPDATE
    SET unread_count = chat_read_states.unread_count + 1;
  ELSE
    -- For DMs/user groups, increment for participants except sender
    INSERT INTO chat_read_states (user_id, chat_id, unread_count)
    SELECT participant_id, NEW.chat_id, 1
    FROM (
      SELECT unnest(m.participant_ids) AS participant_id
      FROM chat_metadata m
      WHERE m.id = NEW.chat_id
    ) participants
    WHERE participant_id != NEW.sender_id
    ON CONFLICT (user_id, chat_id) DO UPDATE
    SET unread_count = chat_read_states.unread_count + 1;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS increment_unread_trigger ON chat_messages;
CREATE TRIGGER increment_unread_trigger
  AFTER INSERT ON chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION increment_unread_counts();

-- Function to clean old typing indicators (run via cron)
CREATE OR REPLACE FUNCTION clean_old_typing_indicators()
RETURNS void AS $$
BEGIN
  DELETE FROM typing_indicators
  WHERE updated_at < now() - INTERVAL '10 seconds';
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON chat_messages TO authenticated;
GRANT SELECT ON chat_metadata TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON chat_read_states TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON typing_indicators TO authenticated;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
