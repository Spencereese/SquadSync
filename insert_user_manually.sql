-- Quick fix: Manually insert your user into Supabase
-- Run this in Supabase SQL Editor to allow messages to be inserted

INSERT INTO users (uid, email, display_name, photo_url, created_at, updated_at)
VALUES (
  'RSeYMsTfUghqQ0TkUM3Ep5HknJ92',  -- Your Firebase UID
  'your@email.com',  -- Replace with your actual email
  'Your Display Name',  -- Replace with your display name
  NULL,  -- photo_url (optional)
  NOW(),
  NOW()
)
ON CONFLICT (uid) DO NOTHING;

-- Verify the user was inserted
SELECT uid, display_name, email, created_at 
FROM users 
WHERE uid = 'RSeYMsTfUghqQ0TkUM3Ep5HknJ92';

-- After running this, send a test message - it should work!