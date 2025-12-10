-- ============================================================================
-- FIX INSERT POLICY FOR CHAT_MESSAGES
-- The INSERT policy is missing the WITH CHECK clause
-- ============================================================================

-- Drop the broken INSERT policy
DROP POLICY IF EXISTS "Authenticated users can insert messages" ON chat_messages;

-- Recreate with proper WITH CHECK clause
CREATE POLICY "Authenticated users can insert messages"
  ON chat_messages FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Verify the fix
SELECT tablename, policyname, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'chat_messages' AND cmd = 'INSERT';
