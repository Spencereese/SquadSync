-- Test the service role key dual-write functionality
-- This should work now that we're using the service role key

-- Check if messages are being inserted
SELECT
  id,
  sender_id,
  text,
  chat_type,
  timestamp,
  created_at
FROM chat_messages
ORDER BY timestamp DESC
LIMIT 10;

-- Check if users are being inserted
SELECT
  uid,
  display_name,
  email,
  created_at
FROM users
ORDER BY created_at DESC
LIMIT 5;

-- Verify RLS is bypassed (should return data even without auth)
SELECT COUNT(*) as total_messages FROM chat_messages;
SELECT COUNT(*) as total_users FROM users;