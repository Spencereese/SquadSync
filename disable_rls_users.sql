-- Completely disable RLS on users table for testing
-- This will allow all operations without policy checks

ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- Verify it's disabled
SELECT 
  schemaname,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public' 
  AND tablename = 'users';
