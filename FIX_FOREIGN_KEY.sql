-- EMERGENCY FIX - Drop and recreate chat_groups foreign key
-- This should fix the "users.id does not exist" error

-- ============================================================================
-- Drop the existing foreign key (it's pointing to wrong column)
-- ============================================================================
ALTER TABLE chat_groups 
DROP CONSTRAINT IF EXISTS chat_groups_created_by_fkey CASCADE;

-- ============================================================================
-- Recreate it pointing to users.uid (the correct column)
-- ============================================================================
ALTER TABLE chat_groups 
ADD CONSTRAINT chat_groups_created_by_fkey 
FOREIGN KEY (created_by) 
REFERENCES users(uid) 
ON DELETE SET NULL;

-- ============================================================================
-- Verify it was created correctly
-- ============================================================================
SELECT
  tc.table_name AS source_table,
  kcu.column_name AS source_column,
  ccu.table_name AS target_table,
  ccu.column_name AS target_column,
  tc.constraint_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_name = 'chat_groups'
  AND tc.constraint_name = 'chat_groups_created_by_fkey';

-- Success
DO $$
BEGIN
  RAISE NOTICE '✅ Foreign key fixed!';
  RAISE NOTICE '   chat_groups.created_by now references users.uid';
END $$;
