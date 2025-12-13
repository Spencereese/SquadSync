-- =====================================================
-- QUICK SCHEMA EXPORT - Optimized for AI Context Sharing
-- Run this ONE query to get everything you need
-- Output: JSON format for easy copy/paste
-- =====================================================

WITH 
-- Get all tables with RLS status
tables_info AS (
    SELECT 
        t.tablename,
        t.rowsecurity as rls_enabled,
        (SELECT COUNT(*) FROM pg_policies WHERE tablename = t.tablename) as policy_count,
        pg_catalog.obj_description(c.oid, 'pg_class') as table_comment
    FROM pg_tables t
    JOIN pg_class c ON c.relname = t.tablename
    WHERE t.schemaname = 'public'
),
-- Get all columns with types and constraints
columns_info AS (
    SELECT 
        c.table_name,
        jsonb_agg(
            jsonb_build_object(
                'name', c.column_name,
                'type', c.data_type,
                'nullable', c.is_nullable,
                'default', c.column_default,
                'is_pk', CASE WHEN pk.column_name IS NOT NULL THEN true ELSE false END,
                'fk_table', fk.foreign_table_name,
                'fk_column', fk.foreign_column_name
            ) ORDER BY c.ordinal_position
        ) as columns
    FROM information_schema.columns c
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
    GROUP BY c.table_name
),
-- Get all RLS policies
policies_info AS (
    SELECT 
        tablename,
        jsonb_agg(
            jsonb_build_object(
                'name', policyname,
                'command', cmd,
                'roles', roles
            )
        ) as policies
    FROM pg_policies
    WHERE schemaname = 'public'
    GROUP BY tablename
),
-- Get all functions
functions_info AS (
    SELECT 
        jsonb_agg(
            jsonb_build_object(
                'name', p.proname,
                'args', pg_get_function_arguments(p.oid),
                'returns', pg_get_function_result(p.oid)
            ) ORDER BY p.proname
        ) as functions
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
),
-- Get storage buckets
storage_info AS (
    SELECT 
        jsonb_agg(
            jsonb_build_object(
                'name', name,
                'public', public,
                'file_size_limit', file_size_limit,
                'allowed_mime_types', allowed_mime_types
            ) ORDER BY name
        ) as buckets
    FROM storage.buckets
),
-- Get realtime tables
realtime_info AS (
    SELECT 
        jsonb_agg(tablename ORDER BY tablename) as realtime_tables
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
)
-- Combine everything into one JSON output
SELECT jsonb_build_object(
    'schema_export_date', NOW(),
    'tables', (
        SELECT jsonb_object_agg(
            t.tablename,
            jsonb_build_object(
                'rls_enabled', t.rls_enabled,
                'policy_count', t.policy_count,
                'comment', t.table_comment,
                'columns', COALESCE(c.columns, '[]'::jsonb),
                'policies', COALESCE(p.policies, '[]'::jsonb)
            )
        )
        FROM tables_info t
        LEFT JOIN columns_info c ON t.tablename = c.table_name
        LEFT JOIN policies_info p ON t.tablename = p.tablename
    ),
    'functions', (SELECT functions FROM functions_info),
    'storage_buckets', (SELECT buckets FROM storage_info),
    'realtime_tables', (SELECT realtime_tables FROM realtime_info)
) as complete_schema;
