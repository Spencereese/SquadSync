-- Simplified RLS fix for users table
-- This removes all policies and creates permissive ones for testing

-- Disable RLS temporarily to see if that's the issue
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- Check if this allows the insert to work
-- If it does, we know it's definitely an RLS issue

-- To re-enable with proper policies later, run:
-- ALTER TABLE users ENABLE ROW LEVEL SECURITY;
-- 
-- CREATE POLICY "allow_all_authenticated" 
-- ON users FOR ALL 
-- TO authenticated 
-- USING (true) 
-- WITH CHECK (true);
