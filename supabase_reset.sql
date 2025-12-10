-- ============================================================================
-- SquadSync Supabase - CLEAN RESET SCRIPT
-- ⚠️  WARNING: This will DELETE ALL DATA and start fresh!
-- ============================================================================

-- Drop all existing tables (CASCADE handles policies and foreign keys automatically)
DROP TABLE IF EXISTS user_ratings CASCADE;
DROP TABLE IF EXISTS chat_metadata CASCADE;
DROP TABLE IF EXISTS chat_messages CASCADE;
DROP TABLE IF EXISTS chat_groups CASCADE;
DROP TABLE IF EXISTS squads CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Confirm cleanup
SELECT 'All tables and policies dropped. Ready for fresh install.' as status;
