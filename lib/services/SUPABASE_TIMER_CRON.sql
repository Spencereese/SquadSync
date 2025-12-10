-- Supabase Timer Processor using pg_cron
-- This replaces Firebase Cloud Functions timer processing
-- Run this SQL in Supabase SQL Editor after enabling pg_cron extension

-- Enable pg_cron extension (requires Supabase Pro plan or self-hosted)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Grant usage to postgres user
GRANT USAGE ON SCHEMA cron TO postgres;

-- Create squad_timers table to track active timers
CREATE TABLE IF NOT EXISTS squad_timers (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    squad_id TEXT NOT NULL REFERENCES squads(id) ON DELETE CASCADE,
    game_name TEXT NOT NULL,
    spot_index INTEGER NOT NULL,
    claimed_by_uid TEXT NOT NULL REFERENCES users(id),
    timer_duration INTEGER NOT NULL, -- in seconds
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(squad_id, game_name, spot_index)
);

-- Index for efficient timer expiration queries
CREATE INDEX IF NOT EXISTS idx_squad_timers_expires ON squad_timers(expires_at);

-- Create peacock_queue table for queue management
CREATE TABLE IF NOT EXISTS peacock_queue (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    squad_id TEXT NOT NULL REFERENCES squads(id) ON DELETE CASCADE,
    game_name TEXT NOT NULL,
    user_uid TEXT NOT NULL REFERENCES users(id),
    position INTEGER NOT NULL,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    UNIQUE(squad_id, game_name, user_uid)
);

-- Index for queue position queries
CREATE INDEX IF NOT EXISTS idx_peacock_queue_squad ON peacock_queue(squad_id, game_name, position);
CREATE INDEX IF NOT EXISTS idx_peacock_queue_expires ON peacock_queue(expires_at);

-- Create squad_spots table to track current spot occupancy
CREATE TABLE IF NOT EXISTS squad_spots (
    squad_id TEXT NOT NULL REFERENCES squads(id) ON DELETE CASCADE,
    game_name TEXT NOT NULL,
    spot_index INTEGER NOT NULL,
    occupied_by_uid TEXT REFERENCES users(id),
    status TEXT DEFAULT 'available', -- 'available', 'claimed', 'calling'
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY(squad_id, game_name, spot_index)
);

-- Index for spot lookups
CREATE INDEX IF NOT EXISTS idx_squad_spots_squad ON squad_spots(squad_id, game_name);

-- Function to process expired timers
CREATE OR REPLACE FUNCTION process_expired_timers()
RETURNS void AS $$
DECLARE
    expired_timer RECORD;
    next_in_queue RECORD;
    timer_count INTEGER;
BEGIN
    -- Count expired timers
    SELECT COUNT(*) INTO timer_count
    FROM squad_timers
    WHERE expires_at <= NOW();

    RAISE NOTICE 'Processing % expired timers', timer_count;

    -- Loop through all expired timers
    FOR expired_timer IN 
        SELECT * FROM squad_timers 
        WHERE expires_at <= NOW()
    LOOP
        RAISE NOTICE 'Freeing spot % in squad % (game: %)', 
            expired_timer.spot_index, 
            expired_timer.squad_id, 
            expired_timer.game_name;

        -- Free the spot
        UPDATE squad_spots 
        SET 
            occupied_by_uid = NULL,
            status = 'available',
            updated_at = NOW()
        WHERE 
            squad_id = expired_timer.squad_id 
            AND game_name = expired_timer.game_name 
            AND spot_index = expired_timer.spot_index;

        -- Check if there's someone in the peacock queue
        SELECT * INTO next_in_queue
        FROM peacock_queue
        WHERE 
            squad_id = expired_timer.squad_id
            AND game_name = expired_timer.game_name
        ORDER BY position ASC
        LIMIT 1;

        -- If queue exists, assign to next person
        IF FOUND THEN
            RAISE NOTICE 'Assigning spot to next in queue: %', next_in_queue.user_uid;

            -- Claim spot for next person
            UPDATE squad_spots
            SET 
                occupied_by_uid = next_in_queue.user_uid,
                status = 'claimed',
                updated_at = NOW()
            WHERE 
                squad_id = expired_timer.squad_id
                AND game_name = expired_timer.game_name
                AND spot_index = expired_timer.spot_index;

            -- Create new timer (30 minutes default)
            INSERT INTO squad_timers (
                squad_id, 
                game_name, 
                spot_index, 
                claimed_by_uid, 
                timer_duration, 
                expires_at
            ) VALUES (
                expired_timer.squad_id,
                expired_timer.game_name,
                expired_timer.spot_index,
                next_in_queue.user_uid,
                1800, -- 30 minutes
                NOW() + INTERVAL '30 minutes'
            )
            ON CONFLICT (squad_id, game_name, spot_index) 
            DO UPDATE SET
                claimed_by_uid = EXCLUDED.claimed_by_uid,
                timer_duration = EXCLUDED.timer_duration,
                expires_at = EXCLUDED.expires_at;

            -- Remove from queue
            DELETE FROM peacock_queue WHERE id = next_in_queue.id;

            -- Reposition remaining queue
            UPDATE peacock_queue
            SET position = position - 1
            WHERE 
                squad_id = expired_timer.squad_id
                AND game_name = expired_timer.game_name
                AND position > next_in_queue.position;
        END IF;

        -- Delete expired timer
        DELETE FROM squad_timers WHERE id = expired_timer.id;
    END LOOP;

    RAISE NOTICE 'Timer processing complete';
END;
$$ LANGUAGE plpgsql;

-- Function to process expired peacock queue entries
CREATE OR REPLACE FUNCTION process_expired_queue()
RETURNS void AS $$
DECLARE
    expired_count INTEGER;
BEGIN
    -- Count expired queue entries
    SELECT COUNT(*) INTO expired_count
    FROM peacock_queue
    WHERE expires_at <= NOW();

    RAISE NOTICE 'Removing % expired queue entries', expired_count;

    -- Delete expired queue entries
    DELETE FROM peacock_queue
    WHERE expires_at <= NOW();

    -- Reposition remaining queue entries per squad/game
    WITH ranked_queue AS (
        SELECT 
            id,
            ROW_NUMBER() OVER (
                PARTITION BY squad_id, game_name 
                ORDER BY joined_at
            ) - 1 AS new_position
        FROM peacock_queue
    )
    UPDATE peacock_queue pq
    SET position = rq.new_position
    FROM ranked_queue rq
    WHERE pq.id = rq.id
    AND pq.position != rq.new_position;

    RAISE NOTICE 'Queue cleanup complete';
END;
$$ LANGUAGE plpgsql;

-- Schedule timer processor to run every 30 seconds
SELECT cron.schedule(
    'process-timers',
    '30 seconds',
    $$
    SELECT process_expired_timers();
    $$
);

-- Schedule queue cleanup to run every 1 minute (using cron format)
SELECT cron.schedule(
    'process-queue',
    '* * * * *',
    $$
    SELECT process_expired_queue();
    $$
);

-- Function to manually trigger timer processing (for testing)
CREATE OR REPLACE FUNCTION trigger_timer_processing()
RETURNS TABLE(
    expired_timers_count INTEGER,
    expired_queue_count INTEGER
) AS $$
DECLARE
    timer_count INTEGER;
    queue_count INTEGER;
BEGIN
    -- Process timers
    PERFORM process_expired_timers();
    
    -- Process queue
    PERFORM process_expired_queue();
    
    -- Return counts
    SELECT COUNT(*) INTO timer_count FROM squad_timers WHERE expires_at <= NOW();
    SELECT COUNT(*) INTO queue_count FROM peacock_queue WHERE expires_at <= NOW();
    
    RETURN QUERY SELECT timer_count, queue_count;
END;
$$ LANGUAGE plpgsql;

-- Enable Realtime for timer tables
ALTER PUBLICATION supabase_realtime ADD TABLE squad_timers;
ALTER PUBLICATION supabase_realtime ADD TABLE peacock_queue;
ALTER PUBLICATION supabase_realtime ADD TABLE squad_spots;

-- RLS Policies for timer tables
ALTER TABLE squad_timers ENABLE ROW LEVEL SECURITY;
ALTER TABLE peacock_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE squad_spots ENABLE ROW LEVEL SECURITY;

-- Squad members can view timers
CREATE POLICY timers_select ON squad_timers FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM squads
        WHERE squads.id = squad_timers.squad_id
        AND auth.uid()::text = ANY(squads.member_uids)
    )
);

-- Squad members can view queue
CREATE POLICY queue_select ON peacock_queue FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM squads
        WHERE squads.id = peacock_queue.squad_id
        AND auth.uid()::text = ANY(squads.member_uids)
    )
);

-- Squad members can join queue
CREATE POLICY queue_insert ON peacock_queue FOR INSERT WITH CHECK (
    auth.uid()::text = user_uid
);

-- Squad members can view spots
CREATE POLICY spots_select ON squad_spots FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM squads
        WHERE squads.id = squad_spots.squad_id
        AND auth.uid()::text = ANY(squads.member_uids)
    )
);

-- Verification queries
SELECT 'Timer processor installed successfully!' AS status;
SELECT jobname, schedule, active FROM cron.job WHERE jobname IN ('process-timers', 'process-queue');

-- Test timer processing manually (uncomment to test)
-- SELECT * FROM trigger_timer_processing();
