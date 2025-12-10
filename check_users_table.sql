-- Check what's in the users table
SELECT uid, email, display_name, created_at
FROM users
ORDER BY created_at DESC
LIMIT 10;
