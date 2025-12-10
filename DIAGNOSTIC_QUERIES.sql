-- COMPREHENSIVE SUPABASE SCHEMA DIAGNOSTIC
-- Run this entire script in Supabase SQL Editor
-- Copy ALL output and send it back

-- ============================================================================
-- 1. USERS TABLE SCHEMA
-- ============================================================================
SELECT 
  column_name,
  data_type,
  column_default,
  is_nullable,
  character_maximum_length
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'users'
ORDER BY ordinal_position;

-- ============================================================================
-- 2. USERS TABLE PRIMARY KEY
-- ============================================================================
SELECT
  tc.constraint_name,
  kcu.column_name,
  tc.constraint_type
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_schema = 'public'
  AND tc.table_name = 'users'
  AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE');

-- ============================================================================
-- 3. CHAT_GROUPS TABLE SCHEMA
-- ============================================================================
SELECT 
  column_name,
  data_type,
  column_default,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'chat_groups'
ORDER BY ordinal_position;

-- ============================================================================
-- 4. CHAT_GROUPS FOREIGN KEYS
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
  AND tc.table_name = 'chat_groups';

-- ============================================================================
-- 5. CHAT_GROUPS RLS POLICIES
-- ============================================================================
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual AS using_expression,
  with_check AS with_check_expression
FROM pg_policies 
WHERE tablename = 'chat_groups';

-- ============================================================================
-- 6. USERS RLS POLICIES
-- ============================================================================
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual AS using_expression,
  with_check AS with_check_expression
FROM pg_policies 
WHERE tablename = 'users';

-- ============================================================================
-- 7. CHECK IF complaints TABLE EXISTS
-- ============================================================================
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_schema = 'public' 
  AND table_name = 'complaints'
) AS complaints_exists;

-- ============================================================================
-- 8. CHECK IF user_ratings TABLE EXISTS
-- ============================================================================
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_schema = 'public' 
  AND table_name = 'user_ratings'
) AS user_ratings_exists;

-- ============================================================================
-- 9. LIST ALL TABLES IN PUBLIC SCHEMA
-- ============================================================================
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- ============================================================================
-- 10. SAMPLE DATA FROM USERS (to see which column has actual values)
-- ============================================================================
SELECT 
  uid,
  display_name,
  email,
  created_at
FROM users
LIMIT 3;

-- ============================================================================
-- 11. CHECK AUTH.USERS INTEGRATION
-- ============================================================================
SELECT 
  id AS auth_id,
  email,
  created_at
FROM auth.users
LIMIT 3;
