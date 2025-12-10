-- Fix RLS policy for users table to allow authenticated users to insert their own profile
-- Date: December 8, 2025
-- Issue: New users can't save their display name due to RLS blocking INSERT

-- First, check current policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'users';

-- Drop any restrictive INSERT policies that might exist
DO $$
BEGIN
  -- Drop old policies if they exist
  IF EXISTS (
    SELECT FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'users' 
    AND policyname = 'Users can insert own profile'
  ) THEN
    DROP POLICY "Users can insert own profile" ON users;
  END IF;
  
  IF EXISTS (
    SELECT FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'users' 
    AND policyname = 'Users can create their profile'
  ) THEN
    DROP POLICY "Users can create their profile" ON users;
  END IF;
END $$;

-- Create proper INSERT policy
-- Allow authenticated users to insert a row where uid matches their auth.uid()
CREATE POLICY "Users can insert own profile"
ON users FOR INSERT
TO authenticated
WITH CHECK (uid = auth.uid()::text);

-- Also ensure UPDATE policy exists for upsert operations
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'users' 
    AND policyname = 'Users can update own profile'
  ) THEN
    CREATE POLICY "Users can update own profile"
    ON users FOR UPDATE
    TO authenticated
    USING (uid = auth.uid()::text)
    WITH CHECK (uid = auth.uid()::text);
  END IF;
END $$;

-- Ensure SELECT policy exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'users' 
    AND policyname = 'Users can view all profiles'
  ) THEN
    CREATE POLICY "Users can view all profiles"
    ON users FOR SELECT
    TO authenticated
    USING (true);
  END IF;
END $$;

-- Verify RLS is enabled
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Show final policies
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'users'
ORDER BY cmd, policyname;

-- Test query (run after the policies are created)
-- This should return your current user's UID
SELECT 
  'Current auth user: ' || auth.uid()::text as info,
  EXISTS (
    SELECT FROM users WHERE uid = auth.uid()::text
  ) as user_exists;
