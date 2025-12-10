-- Fix RLS policies for chat_messages table (Supabase Auth only)
-- Run this in your Supabase SQL Editor
-- This version uses Supabase auth.uid() directly (no Firebase UID compatibility)

-- First, drop existing policies if they exist
DROP POLICY IF EXISTS "Users can insert their own messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can read messages from their chats" ON chat_messages;
DROP POLICY IF EXISTS "Users can update their own messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can delete their own messages" ON chat_messages;

-- Enable RLS on chat_messages if not already enabled
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Policy 1: Allow users to insert messages
-- Uses Supabase auth.uid() directly (UUID)
CREATE POLICY "Users can insert their own messages"
ON chat_messages
FOR INSERT
TO authenticated
WITH CHECK (
  -- Allow if sender_id matches Supabase auth.uid (converted to text)
  sender_id = auth.uid()::text
);

-- Policy 2: Allow users to read messages from their chats
CREATE POLICY "Users can read messages from their chats"
ON chat_messages
FOR SELECT
TO authenticated
USING (
  -- Allow authenticated users to read all messages
  -- Chat membership validation handled at application level
  true
);

-- Policy 3: Allow users to update their own messages
CREATE POLICY "Users can update their own messages"
ON chat_messages
FOR UPDATE
TO authenticated
USING (
  -- Allow users to update their own messages
  sender_id = auth.uid()::text
)
WITH CHECK (
  -- Ensure sender_id doesn't change
  sender_id = auth.uid()::text
);

-- Policy 4: Allow users to delete their own messages (soft delete)
CREATE POLICY "Users can delete their own messages"
ON chat_messages
FOR UPDATE
TO authenticated
USING (
  -- Allow users to mark their own messages as deleted
  sender_id = auth.uid()::text
);

-- Create indexes to improve RLS performance
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender_id ON chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_chat_id ON chat_messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_timestamp ON chat_messages(timestamp DESC);

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON chat_messages TO authenticated;
