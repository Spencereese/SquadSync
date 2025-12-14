-- =====================================================
-- CLEANUP TEST GROUPS SQL SCRIPT
-- Run this in your Supabase SQL Editor to clean up test groups
-- Generated: December 14, 2025
-- =====================================================

-- =====================================================
-- SAFETY: Create backup before cleanup
-- =====================================================
-- Uncomment to create backup tables
-- CREATE TABLE chat_groups_backup AS SELECT * FROM chat_groups;
-- CREATE TABLE users_backup AS SELECT * FROM users;

-- =====================================================
-- 1. Find and display empty groups (no members)
-- =====================================================
SELECT 
    id,
    name,
    created_by,
    is_public,
    array_length(member_uids, 1) as member_count,
    created_at,
    updated_at
FROM chat_groups
WHERE array_length(member_uids, 1) IS NULL 
   OR array_length(member_uids, 1) = 0
ORDER BY created_at DESC;

-- =====================================================
-- 2. Find groups with only 1 or 2 members (likely test groups)
-- =====================================================
SELECT 
    id,
    name,
    created_by,
    is_public,
    member_uids,
    array_length(member_uids, 1) as member_count,
    created_at,
    updated_at
FROM chat_groups
WHERE array_length(member_uids, 1) <= 2
ORDER BY created_at DESC;

-- =====================================================
-- 3. Find groups with no recent activity (older than 7 days)
-- =====================================================
SELECT 
    id,
    name,
    created_by,
    is_public,
    member_uids,
    array_length(member_uids, 1) as member_count,
    last_activity,
    AGE(NOW(), last_activity) as time_since_activity,
    created_at
FROM chat_groups
WHERE last_activity IS NULL 
   OR last_activity < NOW() - INTERVAL '7 days'
ORDER BY last_activity DESC NULLS LAST;

-- =====================================================
-- 4. DELETE EMPTY GROUPS (NO MEMBERS)
-- Run this after reviewing the results above
-- =====================================================
-- Uncomment to execute deletion
/*
DELETE FROM chat_groups
WHERE array_length(member_uids, 1) IS NULL 
   OR array_length(member_uids, 1) = 0;
*/

-- =====================================================
-- 5. DELETE TEST GROUPS (OPTIONAL - BE CAREFUL!)
-- Delete groups with specific test names or patterns
-- =====================================================
-- Uncomment and modify as needed
/*
DELETE FROM chat_groups
WHERE name ILIKE '%test%'
   OR name ILIKE '%demo%'
   OR name ILIKE '%temp%';
*/

-- =====================================================
-- 6. CLEAN UP ORPHANED USER_GROUPS ENTRIES
-- Remove references to deleted chat groups from users.user_groups
-- =====================================================
-- This query finds users with orphaned group references
WITH valid_groups AS (
    SELECT id FROM chat_groups
)
SELECT 
    u.uid,
    u.display_name,
    ug.value->>'chat_group_id' as orphaned_group_id
FROM users u
CROSS JOIN LATERAL jsonb_array_elements(COALESCE(u.user_groups, '[]'::jsonb)) AS ug(value)
WHERE (ug.value->>'chat_group_id') NOT IN (SELECT id FROM valid_groups)
ORDER BY u.display_name;

-- =====================================================
-- 7. DELETE ORPHANED USER_GROUPS ENTRIES
-- Run this after reviewing the results above
-- =====================================================
-- Uncomment to execute cleanup
/*
UPDATE users
SET user_groups = (
    SELECT jsonb_agg(elem)
    FROM jsonb_array_elements(COALESCE(user_groups, '[]'::jsonb)) AS elem
    WHERE (elem->>'chat_group_id') IN (SELECT id FROM chat_groups)
)
WHERE EXISTS (
    SELECT 1
    FROM jsonb_array_elements(COALESCE(user_groups, '[]'::jsonb)) AS ug
    WHERE (ug->>'chat_group_id') NOT IN (SELECT id FROM chat_groups)
);
*/

-- =====================================================
-- 8. VERIFY CLEANUP
-- Run these after deletion to verify
-- =====================================================
-- Count remaining groups
SELECT 
    COUNT(*) as total_groups,
    COUNT(*) FILTER (WHERE is_public = true) as public_groups,
    COUNT(*) FILTER (WHERE is_public = false) as private_groups,
    COUNT(*) FILTER (WHERE array_length(member_uids, 1) IS NULL OR array_length(member_uids, 1) = 0) as empty_groups
FROM chat_groups;

-- Verify no orphaned user_groups entries
SELECT 
    COUNT(*) as users_with_orphaned_groups
FROM users u
WHERE EXISTS (
    SELECT 1
    FROM jsonb_array_elements(COALESCE(u.user_groups, '[]'::jsonb)) AS ug
    WHERE (ug->>'chat_group_id') NOT IN (SELECT id FROM chat_groups)
);

-- =====================================================
-- 9. PREVENTATIVE TRIGGER: Auto-delete empty groups
-- Creates a trigger to automatically delete groups when last member leaves
-- =====================================================
-- Uncomment to create trigger
/*
CREATE OR REPLACE FUNCTION delete_empty_chat_groups()
RETURNS TRIGGER AS $$
BEGIN
    -- Delete the group if member_uids is empty or null
    IF NEW.member_uids IS NULL OR array_length(NEW.member_uids, 1) IS NULL OR array_length(NEW.member_uids, 1) = 0 THEN
        DELETE FROM chat_groups WHERE id = NEW.id;
        RETURN NULL; -- Prevent the update since we're deleting
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_delete_empty_chat_groups ON chat_groups;
CREATE TRIGGER trigger_delete_empty_chat_groups
    AFTER UPDATE OF member_uids ON chat_groups
    FOR EACH ROW
    EXECUTE FUNCTION delete_empty_chat_groups();
*/

-- =====================================================
-- 10. MANUAL CLEANUP FOR YOUR SPECIFIC USER
-- Replace 'YOUR_USER_ID' with your actual UID
-- =====================================================
-- Find all groups you're in
/*
SELECT 
    cg.id,
    cg.name,
    cg.created_by,
    array_length(cg.member_uids, 1) as member_count,
    cg.created_at
FROM chat_groups cg
WHERE 'YOUR_USER_ID' = ANY(cg.member_uids)
ORDER BY cg.created_at DESC;
*/

-- Leave all groups except specific ones you want to keep
/*
WITH groups_to_leave AS (
    SELECT id, member_uids
    FROM chat_groups
    WHERE 'YOUR_USER_ID' = ANY(member_uids)
      AND name NOT LIKE '%Keep%'  -- Modify this condition
)
UPDATE chat_groups
SET member_uids = array_remove(member_uids, 'YOUR_USER_ID'),
    updated_at = NOW()
WHERE id IN (SELECT id FROM groups_to_leave);
*/

-- =====================================================
-- NOTES
-- =====================================================
-- 1. Always review results before running DELETE statements
-- 2. Create backups before major cleanup operations
-- 3. Test on a subset first by adding LIMIT clauses
-- 4. The trigger in step 9 will prevent empty groups in the future
-- 5. Consider running these queries periodically for maintenance
