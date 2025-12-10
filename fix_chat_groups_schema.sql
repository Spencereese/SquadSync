-- Fix chat_groups schema to auto-generate IDs and match code expectations
-- Run this in Supabase SQL Editor

-- CRITICAL: The table has duplicate columns (members AND member_uids)
-- This script will clean up the schema

-- First, check current state
DO $$
BEGIN
  RAISE NOTICE 'Current chat_groups schema:';
END $$;

SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'chat_groups'
ORDER BY ordinal_position;

-- Drop redundant 'members' column if it exists (we use member_uids)
ALTER TABLE chat_groups DROP COLUMN IF EXISTS members CASCADE;

-- Recreate chat_groups table with correct schema
CREATE TABLE IF NOT EXISTS chat_groups (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  name TEXT NOT NULL,
  member_uids TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  is_dm BOOLEAN DEFAULT false,
  is_public BOOLEAN DEFAULT false,
  game_name TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  member_count INTEGER DEFAULT 0
);

-- If table already exists, alter it to add defaults
DO $$ 
BEGIN
  -- Set default for id column
  BEGIN
    ALTER TABLE chat_groups ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;
  EXCEPTION
    WHEN others THEN
      RAISE NOTICE 'Could not set default for id column: %', SQLERRM;
  END;
  
  -- Ensure member_uids has proper default and is NOT NULL
  BEGIN
    ALTER TABLE chat_groups ALTER COLUMN member_uids SET DEFAULT ARRAY[]::TEXT[];
    ALTER TABLE chat_groups ALTER COLUMN member_uids SET NOT NULL;
  EXCEPTION
    WHEN others THEN
      RAISE NOTICE 'Could not set default/not-null for member_uids: %', SQLERRM;
  END;
  
  -- Add member_count if missing
  BEGIN
    ALTER TABLE chat_groups ADD COLUMN IF NOT EXISTS member_count INTEGER DEFAULT 0;
  EXCEPTION
    WHEN others THEN
      RAISE NOTICE 'Could not add member_count column: %', SQLERRM;
  END;
END $$;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_chat_groups_member_uids ON chat_groups USING GIN(member_uids);
CREATE INDEX IF NOT EXISTS idx_chat_groups_created_by ON chat_groups(created_by);
CREATE INDEX IF NOT EXISTS idx_chat_groups_is_public ON chat_groups(is_public);
CREATE INDEX IF NOT EXISTS idx_chat_groups_updated_at ON chat_groups(updated_at DESC);

-- Enable RLS
ALTER TABLE chat_groups ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "allow_all_authenticated" ON chat_groups;
DROP POLICY IF EXISTS "Users can view groups they are members of" ON chat_groups;
DROP POLICY IF EXISTS "Users can create groups" ON chat_groups;
DROP POLICY IF EXISTS "Users can update groups they created" ON chat_groups;

-- Create permissive RLS policies for authenticated users
CREATE POLICY "allow_all_authenticated" 
ON chat_groups FOR ALL 
TO authenticated 
USING (true) 
WITH CHECK (true);

-- Verify schema
SELECT 
  column_name,
  data_type,
  column_default,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'chat_groups'
ORDER BY ordinal_position;
