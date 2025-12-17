-- Update Peacock Queue Auto-Assignment to 5-Minute Lock Timer
-- Migration: 2025-12-16
-- Updates the timer processing to require lock-in within 5 minutes when auto-assigned from queue
-- Note: This migration assumes squad_timers, squad_spots, and peacock_queue tables exist
-- If they don't exist, you need to run the timer setup SQL first (SUPABASE_TIMER_CRON.sql)

-- Replace the process_expired_timers function with updated 5-minute logic
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
        RAISE NOTICE 'Freeing spot % in lobby % (game: %)', 
            expired_timer.spot_index, 
            expired_timer.lobby_id, 
            expired_timer.game_name;

        -- Free the spot
        UPDATE squad_spots 
        SET 
            occupied_by_uid = NULL,
            status = 'available',
            updated_at = NOW()
        WHERE 
            lobby_id = expired_timer.lobby_id 
            AND game_name = expired_timer.game_name 
            AND spot_index = expired_timer.spot_index;

        -- Check if there's someone in the peacock queue
        SELECT * INTO next_in_queue
        FROM peacock_queue
        WHERE 
            lobby_id = expired_timer.lobby_id
            AND game_name = expired_timer.game_name
        ORDER BY position ASC
        LIMIT 1;

        -- If queue exists, auto-assign to next person with 5-minute lock-in timer
        IF FOUND THEN
            RAISE NOTICE 'Auto-assigning spot to next in queue: %', next_in_queue.user_uid;

            -- Auto-assign spot for next person (needs lock-in within 5 minutes)
            UPDATE squad_spots
            SET 
                occupied_by_uid = next_in_queue.user_uid,
                status = 'claimed', -- Status is 'claimed' until user locks in
                updated_at = NOW()
            WHERE 
                lobby_id = expired_timer.lobby_id
                AND game_name = expired_timer.game_name
                AND spot_index = expired_timer.spot_index;

            -- Create 5-minute lock-in timer (user must hit lock button or loses spot)
            INSERT INTO squad_timers (
                lobby_id, 
                game_name, 
                spot_index, 
                claimed_by_uid, 
                timer_duration, 
                expires_at
            ) VALUES (
                expired_timer.lobby_id,
                expired_timer.game_name,
                expired_timer.spot_index,
                next_in_queue.user_uid,
                300, -- 5 minutes to lock in
                NOW() + INTERVAL '5 minutes'
            )
            ON CONFLICT (lobby_id, game_name, spot_index) 
            DO UPDATE SET
                claimed_by_uid = EXCLUDED.claimed_by_uid,
                timer_duration = EXCLUDED.timer_duration,
                expires_at = EXCLUDED.expires_at;

            -- Remove from queue after assignment
            DELETE FROM peacock_queue WHERE id = next_in_queue.id;

            -- Reposition remaining queue members
            UPDATE peacock_queue
            SET position = position - 1
            WHERE 
                lobby_id = expired_timer.lobby_id
                AND game_name = expired_timer.game_name
                AND position > next_in_queue.position;

            -- NOTE: Push notification sending should be handled client-side
            -- Add notification marker to track that user needs alert
            -- Client app will listen for this via Realtime and show notification
            -- Alternative: Use Supabase Edge Function invocation (requires pg_net extension)
            
            RAISE NOTICE 'User % assigned to spot - notification should be sent', next_in_queue.user_uid;
        END IF;

        -- Delete expired timer
        DELETE FROM squad_timers WHERE id = expired_timer.id;
    END LOOP;

    RAISE NOTICE 'Timer processing complete';
END;
$$ LANGUAGE plpgsql;

-- Verify the function was updated
SELECT 'process_expired_timers function updated to 5-minute lock timer' AS status;
