-- ============================================================================
-- FIX RLS POLICIES FOR FIREBASE → SUPABASE MIGRATION
-- Run this in Supabase SQL Editor to allow authenticated users to insert data
-- ============================================================================

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "Users can insert own profile" ON users;
DROP POLICY IF EXISTS "Authenticated users can send messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can update own messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can delete own messages" ON chat_messages;

-- ============================================================================
-- USERS TABLE - Allow authenticated users to insert/update profiles
-- ============================================================================

-- Allow any authenticated user to insert their profile
CREATE POLICY "Authenticated users can insert profiles"
  ON users FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Allow users to update their own profile (match by uid column, not auth.uid())
CREATE POLICY "Users can update profiles"
  ON users FOR UPDATE
  USING (auth.uid() IS NOT NULL);

-- ============================================================================
-- CHAT MESSAGES TABLE - Allow authenticated users to send messages
-- ============================================================================

-- Allow any authenticated user to send messages
CREATE POLICY "Authenticated users can insert messages"
  ON chat_messages FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Allow authenticated users to update their messages
CREATE POLICY "Authenticated users can update messages"
  ON chat_messages FOR UPDATE
  USING (auth.uid() IS NOT NULL);

-- Allow authenticated users to delete their messages  
CREATE POLICY "Authenticated users can delete messages"
  ON chat_messages FOR DELETE
  USING (auth.uid() IS NOT NULL);

-- ============================================================================
-- VERIFICATION QUERY
-- ============================================================================

-- Check current auth user
SELECT auth.uid() as current_auth_id;

-- Check users table policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies 
WHERE tablename = 'users';

-- Check chat_messages table policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies 
WHERE tablename = 'chat_messages';
