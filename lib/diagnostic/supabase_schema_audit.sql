-- =====================================================
-- SUPABASE COMPLETE SCHEMA AUDIT
-- Run this in your Supabase SQL Editor to get full schema details
-- Generated: December 11, 2025
-- =====================================================

-- =====================================================
-- 1. ALL TABLES WITH ROW COUNTS AND COMMENTS
-- =====================================================
SELECT 
    schemaname,
    tablename,
    tableowner,
    rowsecurity as rls_enabled,
    (SELECT COUNT(*) 
     FROM pg_policies 
     WHERE schemaname = n.nspname 
     AND tablename = c.relname) as policy_count,
    pg_catalog.obj_description(c.oid, 'pg_class') as table_comment,
    (SELECT reltuples::bigint 
     FROM pg_class 
     WHERE oid = (schemaname || '.' || tablename)::regclass) as approx_row_count
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = t.schemaname
WHERE schemaname IN ('public', 'auth', 'storage', 'realtime')
ORDER BY schemaname, tablename;

-- =====================================================
-- 2. DETAILED PUBLIC SCHEMA TABLE COLUMNS
-- =====================================================
SELECT 
    c.table_name,
    c.column_name,
    c.data_type,
    c.character_maximum_length,
    c.is_nullable,
    c.column_default,
    pgd.description as column_comment,
    CASE 
        WHEN pk.column_name IS NOT NULL THEN 'PRIMARY KEY'
        WHEN fk.column_name IS NOT NULL THEN 'FOREIGN KEY'
        ELSE ''
    END as key_type,
    fk.foreign_table_name,
    fk.foreign_column_name
FROM information_schema.columns c
LEFT JOIN pg_catalog.pg_statio_all_tables st ON c.table_schema = st.schemaname AND c.table_name = st.relname
LEFT JOIN pg_catalog.pg_description pgd ON pgd.objoid = st.relid AND pgd.objsubid = c.ordinal_position
LEFT JOIN (
    SELECT ku.table_name, ku.column_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage ku ON tc.constraint_name = ku.constraint_name
    WHERE tc.constraint_type = 'PRIMARY KEY' AND tc.table_schema = 'public'
) pk ON c.table_name = pk.table_name AND c.column_name = pk.column_name
LEFT JOIN (
    SELECT 
        kcu.table_name,
        kcu.column_name,
        ccu.table_name AS foreign_table_name,
        ccu.column_name AS foreign_column_name
    FROM information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage AS ccu ON ccu.constraint_name = tc.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'public'
) fk ON c.table_name = fk.table_name AND c.column_name = fk.column_name
WHERE c.table_schema = 'public'
ORDER BY c.table_name, c.ordinal_position;

-- =====================================================
-- 3. ALL INDEXES (PUBLIC SCHEMA)
-- =====================================================
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef,
    CASE 
        WHEN indexdef LIKE '%UNIQUE%' THEN 'UNIQUE'
        WHEN indexdef LIKE '%GIN%' THEN 'GIN'
        WHEN indexdef LIKE '%GIST%' THEN 'GIST'
        ELSE 'BTREE'
    END as index_type
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- =====================================================
-- 4. ALL FOREIGN KEY CONSTRAINTS
-- =====================================================
SELECT
    tc.table_name AS from_table,
    kcu.column_name AS from_column,
    ccu.table_name AS to_table,
    ccu.column_name AS to_column,
    tc.constraint_name,
    rc.update_rule,
    rc.delete_rule
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints AS rc ON rc.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'public'
ORDER BY tc.table_name, kcu.column_name;

-- =====================================================
-- 5. ALL CHECK CONSTRAINTS
-- =====================================================
SELECT
    tc.table_name,
    tc.constraint_name,
    cc.check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
WHERE tc.table_schema = 'public' AND tc.constraint_type = 'CHECK'
ORDER BY tc.table_name;

-- =====================================================
-- 6. ALL UNIQUE CONSTRAINTS
-- =====================================================
SELECT
    tc.table_name,
    tc.constraint_name,
    STRING_AGG(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) as columns
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_schema = 'public' AND tc.constraint_type = 'UNIQUE'
GROUP BY tc.table_name, tc.constraint_name
ORDER BY tc.table_name;

-- =====================================================
-- 7. ALL RLS POLICIES
-- =====================================================
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as command,
    qual as using_expression,
    with_check as check_expression
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- =====================================================
-- 8. STORAGE BUCKETS
-- =====================================================
SELECT 
    id,
    name,
    owner,
    public,
    avif_autodetection,
    file_size_limit,
    allowed_mime_types,
    created_at,
    updated_at
FROM storage.buckets
ORDER BY name;

-- =====================================================
-- 9. STORAGE BUCKET POLICIES
-- =====================================================
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as command,
    qual as using_expression
FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects'
ORDER BY policyname;

-- =====================================================
-- 10. REALTIME PUBLICATION TABLES
-- =====================================================
SELECT 
    schemaname,
    tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
ORDER BY schemaname, tablename;

-- =====================================================
-- 11. FUNCTIONS IN PUBLIC SCHEMA
-- =====================================================
SELECT 
    n.nspname as schema_name,
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as return_type,
    CASE p.provolatile
        WHEN 'i' THEN 'IMMUTABLE'
        WHEN 's' THEN 'STABLE'
        WHEN 'v' THEN 'VOLATILE'
    END as volatility,
    pg_catalog.obj_description(p.oid, 'pg_proc') as function_comment
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
ORDER BY p.proname;

-- =====================================================
-- 12. TRIGGERS ON PUBLIC TABLES
-- =====================================================
SELECT 
    event_object_schema as schema_name,
    event_object_table as table_name,
    trigger_name,
    event_manipulation as event,
    action_timing as timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- =====================================================
-- 13. TABLE SIZES AND STATISTICS
-- =====================================================
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as indexes_size,
    (SELECT COUNT(*) FROM pg_indexes WHERE schemaname = t.schemaname AND tablename = t.tablename) as index_count
FROM pg_tables t
WHERE schemaname IN ('public', 'storage')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- =====================================================
-- 14. ENUM TYPES (IF ANY)
-- =====================================================
SELECT 
    n.nspname AS schema_name,
    t.typname AS enum_name,
    STRING_AGG(e.enumlabel, ', ' ORDER BY e.enumsortorder) AS enum_values
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid  
JOIN pg_namespace n ON t.typnamespace = n.oid
WHERE n.nspname = 'public'
GROUP BY n.nspname, t.typname
ORDER BY t.typname;

-- =====================================================
-- 15. MATERIALIZED VIEWS (IF ANY)
-- =====================================================
SELECT 
    schemaname,
    matviewname,
    definition,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||matviewname)) as size
FROM pg_matviews
WHERE schemaname = 'public'
ORDER BY matviewname;

-- =====================================================
-- 16. SEQUENCES
-- =====================================================
SELECT 
    schemaname,
    sequencename,
    last_value,
    start_value,
    increment_by,
    max_value,
    min_value,
    cycle
FROM pg_sequences
WHERE schemaname = 'public'
ORDER BY sequencename;

-- =====================================================
-- 17. TABLE DEPENDENCIES (WHAT REFERENCES WHAT)
-- =====================================================
SELECT DISTINCT
    dependent_ns.nspname as dependent_schema,
    dependent_view.relname as dependent_table,
    source_ns.nspname as source_schema,
    source_table.relname as source_table
FROM pg_depend 
JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid 
JOIN pg_class as dependent_view ON pg_rewrite.ev_class = dependent_view.oid 
JOIN pg_class as source_table ON pg_depend.refobjid = source_table.oid 
JOIN pg_namespace dependent_ns ON dependent_ns.oid = dependent_view.relnamespace
JOIN pg_namespace source_ns ON source_ns.oid = source_table.relnamespace
WHERE dependent_ns.nspname = 'public'
    AND source_ns.nspname = 'public'
    AND source_table.relname != dependent_view.relname
ORDER BY dependent_table, source_table;

-- =====================================================
-- 18. ROW COUNTS FOR ALL PUBLIC TABLES (EXACT)
-- =====================================================
-- Note: This can be slow on large tables
DO $$
DECLARE
    r RECORD;
    row_count INTEGER;
BEGIN
    CREATE TEMP TABLE IF NOT EXISTS table_row_counts (
        table_name TEXT,
        row_count BIGINT
    );
    
    FOR r IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('SELECT COUNT(*) FROM public.%I', r.tablename) INTO row_count;
        INSERT INTO table_row_counts VALUES (r.tablename, row_count);
    END LOOP;
END $$;

SELECT * FROM table_row_counts ORDER BY table_name;

-- =====================================================
-- 19. STORAGE BUCKET OBJECT COUNTS
-- =====================================================
SELECT 
    bucket_id,
    COUNT(*) as object_count,
    pg_size_pretty(SUM((metadata->>'size')::bigint)) as total_size
FROM storage.objects
GROUP BY bucket_id
ORDER BY bucket_id;

-- =====================================================
-- 20. AUTHENTICATION USERS SUMMARY
-- =====================================================
SELECT 
    COUNT(*) as total_users,
    COUNT(*) FILTER (WHERE confirmed_at IS NOT NULL) as confirmed_users,
    COUNT(*) FILTER (WHERE last_sign_in_at > NOW() - INTERVAL '7 days') as active_7_days,
    COUNT(*) FILTER (WHERE last_sign_in_at > NOW() - INTERVAL '30 days') as active_30_days,
    COUNT(*) FILTER (WHERE deleted_at IS NOT NULL) as deleted_users
FROM auth.users;

-- =====================================================
-- SUMMARY: Run all queries above to get complete schema
-- =====================================================
