-- Find what's still referencing users.id
-- Run this in Supabase SQL Editor

-- ============================================================================
-- 1. Check for triggers on chat_groups
-- ============================================================================
SELECT 
  trigger_name,
  event_manipulation,
  action_statement,
  action_timing
FROM information_schema.triggers
WHERE event_object_table = 'chat_groups';

-- ============================================================================
-- 2. Check for functions that might reference users.id
-- ============================================================================
SELECT 
  routine_name,
  routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_definition LIKE '%users.id%';

-- ============================================================================
-- 3. Check ALL foreign keys on ALL tables referencing users
-- ============================================================================
SELECT
  tc.table_name AS source_table,
  kcu.column_name AS source_column,
  ccu.table_name AS target_table,
  ccu.column_name AS target_column,
  tc.constraint_name,
  rc.update_rule,
  rc.delete_rule
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints AS rc
  ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND ccu.table_name = 'users';

-- ============================================================================
-- 4. Check if there's a view or materialized view involved
-- ============================================================================
SELECT 
  table_name,
  view_definition
FROM information_schema.views
WHERE table_schema = 'public'
  AND view_definition LIKE '%users%';

-- ============================================================================
-- 5. Get the ACTUAL error from PostgreSQL logs
-- ============================================================================
-- Check what query is being executed when group is created
-- Enable query logging temporarily
SET log_statement = 'all';

-- Try to see recent errors
SELECT * FROM pg_stat_statements 
WHERE query LIKE '%chat_groups%' 
LIMIT 10;
