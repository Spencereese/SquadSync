-- Quick fix for immediate issues
-- Run this in Supabase SQL Editor

-- 1. Fix chat_groups RLS policies (remove any that reference users.id)
DROP POLICY IF EXISTS "allow_all_authenticated" ON chat_groups;
DROP POLICY IF EXISTS "Users can view groups they are members of" ON chat_groups;
DROP POLICY IF EXISTS "Users can create groups" ON chat_groups;
DROP POLICY IF EXISTS "Users can update groups they created" ON chat_groups;
DROP POLICY IF EXISTS "Members can view groups" ON chat_groups;
DROP POLICY IF EXISTS "Authenticated users can create groups" ON chat_groups;

-- Create simple permissive policy
CREATE POLICY "chat_groups_all_access" 
ON chat_groups FOR ALL 
TO authenticated 
USING (true) 
WITH CHECK (true);

-- 2. Verify the policy was created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'chat_groups';

-- 3. Check if there are any foreign key constraints referencing users.id
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
  AND tc.table_name='chat_groups'
  AND ccu.table_name='users';
