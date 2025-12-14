-- =====================================================
-- DELETE ALL CHAT GROUPS - START FRESH
-- Run this in your Supabase SQL Editor
-- Generated: December 14, 2025
-- =====================================================

-- =====================================================
-- STEP 1: Review what will be deleted
-- =====================================================

-- Count total groups
SELECT 
    COUNT(*) as total_groups,
    COUNT(*) FILTER (WHERE is_public = true) as public_groups,
    COUNT(*) FILTER (WHERE is_public = false) as private_groups
FROM chat_groups;

-- List all groups with details
SELECT 
    id,
    name,
    is_public,
    array_length(member_uids, 1) as member_count,
    created_at,
    last_activity
FROM chat_groups
ORDER BY created_at DESC;

-- Check for related messages (optional - if you want to see message counts)
SELECT 
    cg.name,
    COUNT(cm.id) as message_count
FROM chat_groups cg
LEFT JOIN chat_messages cm ON cm.chat_group_id = cg.id
GROUP BY cg.id, cg.name
ORDER BY message_count DESC;

-- =====================================================
-- STEP 2: DELETE ALL GROUPS (UNCOMMENT TO EXECUTE)
-- =====================================================

-- WARNING: This will delete ALL chat groups!
-- Uncomment the line below when ready to delete:

-- DELETE FROM chat_groups;

-- =====================================================
-- STEP 3: Clean up orphaned data
-- =====================================================

-- After deleting groups, clean up users.user_groups references
-- Uncomment when ready:

/*
UPDATE users
SET user_groups = '[]'::jsonb
WHERE user_groups IS NOT NULL 
  AND user_groups != '[]'::jsonb;
*/

-- =====================================================
-- STEP 4: Optional - Delete messages too
-- =====================================================

-- If you also want to delete all messages (uncomment when ready):

/*
DELETE FROM chat_messages;
*/

-- =====================================================
-- STEP 5: Verify deletion
-- =====================================================

-- After deletion, verify everything is clean:
SELECT COUNT(*) as remaining_groups FROM chat_groups;
SELECT COUNT(*) as remaining_messages FROM chat_messages;
SELECT COUNT(*) as users_with_groups 
FROM users 
WHERE user_groups IS NOT NULL 
  AND user_groups != '[]'::jsonb;

-- =====================================================
-- QUICK SINGLE COMMAND (Use this if you want one-shot)
-- =====================================================

-- Uncomment this block to do everything at once:

/*
BEGIN;
  DELETE FROM chat_messages;
  DELETE FROM chat_groups;
  UPDATE users SET user_groups = '[]'::jsonb WHERE user_groups IS NOT NULL;
  SELECT 
    (SELECT COUNT(*) FROM chat_groups) as groups_remaining,
    (SELECT COUNT(*) FROM chat_messages) as messages_remaining,
    (SELECT COUNT(*) FROM users WHERE user_groups != '[]'::jsonb) as users_with_groups;
COMMIT;
*/
