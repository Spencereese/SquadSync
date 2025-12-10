-- ============================================================================
-- TEMPORARY PERMISSIVE POLICY FOR MIGRATION
-- This allows any authenticated user to insert messages during migration
-- We'll tighten this later once the auth mapping is working
-- ============================================================================

-- First, let's check what auth.uid() actually returns
SELECT 
  auth.uid() as supabase_auth_id,
  auth.jwt() ->> 'email' as email;

-- Drop the restrictive INSERT policy
DROP POLICY IF EXISTS "Authenticated users can insert messages" ON chat_messages;

-- Create a more permissive policy - just check if user is authenticated
-- Don't validate the sender_id matches auth.uid() yet
CREATE POLICY "Allow authenticated users to insert any message"
  ON chat_messages FOR INSERT
  TO authenticated  -- Only authenticated users (not anonymous)
  WITH CHECK (true);  -- Allow any message data

-- Also fix the users table policy
DROP POLICY IF EXISTS "Authenticated users can insert profiles" ON users;
DROP POLICY IF EXISTS "Users can update profiles" ON users;

CREATE POLICY "Allow authenticated users to insert any profile"
  ON users FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update any profile"
  ON users FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Verify the new policies
SELECT tablename, policyname, cmd, roles, with_check
FROM pg_policies 
WHERE tablename IN ('chat_messages', 'users')
ORDER BY tablename, cmd;

-- Test: Try to get current auth user info
SELECT 
  auth.uid() as auth_user_id,
  auth.email() as auth_email,
  (SELECT uid FROM users LIMIT 1) as sample_user_uid;
