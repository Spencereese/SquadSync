-- Add missing user profile fields to users table
-- Date: December 8, 2025

-- Add profile fields
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS profile_image TEXT,
ADD COLUMN IF NOT EXISTS preferred_modes JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS user_blocks JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS notification_settings JSONB DEFAULT '{
  "pushNotifications": true,
  "soundEnabled": true,
  "vibrationEnabled": true,
  "showPreviews": true,
  "quietHoursEnabled": false,
  "urgentAlertsOnly": false,
  "lobbyInvites": true,
  "friendRequests": true,
  "gameUpdates": false,
  "achievementAlerts": true
}'::jsonb,
ADD COLUMN IF NOT EXISTS friends TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN IF NOT EXISTS alerts TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN IF NOT EXISTS user_groups JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS alert_circles TEXT[] DEFAULT ARRAY['Squad', 'Friends', 'Public']::TEXT[],
ADD COLUMN IF NOT EXISTS public_groups JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS pinned_messages TEXT[] DEFAULT ARRAY[]::TEXT[];

-- Verify the columns were added
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'users'
ORDER BY ordinal_position;
