-- Add Peacock Queue Notification System
-- Migration: 2025-12-16
-- Creates notification tracking for peacock queue auto-assignments
-- Client app listens to this table via Realtime to trigger push notifications

-- Create peacock_notifications table for tracking assignment alerts
CREATE TABLE IF NOT EXISTS peacock_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_uid TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
    lobby_id TEXT NOT NULL REFERENCES lobbies(id) ON DELETE CASCADE,
    game_name TEXT NOT NULL,
    spot_index INTEGER NOT NULL,
    notification_type TEXT NOT NULL DEFAULT 'spot_assigned',
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB DEFAULT '{}'::jsonb,
    sent BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for efficient queries
CREATE INDEX idx_peacock_notifications_user_uid ON peacock_notifications(user_uid);
CREATE INDEX idx_peacock_notifications_sent ON peacock_notifications(sent);
CREATE INDEX idx_peacock_notifications_created_at ON peacock_notifications(created_at);

-- RLS policies
ALTER TABLE peacock_notifications ENABLE ROW LEVEL SECURITY;

-- Users can view their own notifications
CREATE POLICY "Users can view own notifications"
ON peacock_notifications
FOR SELECT
USING (auth.uid()::text = user_uid);

-- Users can update their own notifications (mark as sent)
CREATE POLICY "Users can update own notifications"
ON peacock_notifications
FOR UPDATE
USING (auth.uid()::text = user_uid);

-- System can insert notifications (for server-side timer processing)
CREATE POLICY "System can insert notifications"
ON peacock_notifications
FOR INSERT
WITH CHECK (true);

-- Auto-delete old notifications after 24 hours
CREATE OR REPLACE FUNCTION delete_old_peacock_notifications()
RETURNS void AS $$
BEGIN
    DELETE FROM peacock_notifications
    WHERE created_at < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update the process_expired_timers function to create notifications
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
                status = 'claimed',
                updated_at = NOW()
            WHERE 
                lobby_id = expired_timer.lobby_id
                AND game_name = expired_timer.game_name
                AND spot_index = expired_timer.spot_index;

            -- Create 5-minute lock-in timer
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
                300,
                NOW() + INTERVAL '5 minutes'
            )
            ON CONFLICT (lobby_id, game_name, spot_index) 
            DO UPDATE SET
                claimed_by_uid = EXCLUDED.claimed_by_uid,
                timer_duration = EXCLUDED.timer_duration,
                expires_at = EXCLUDED.expires_at;

            -- Create notification for user (client will listen via Realtime)
            INSERT INTO peacock_notifications (
                user_uid,
                lobby_id,
                game_name,
                spot_index,
                notification_type,
                title,
                body,
                data
            ) VALUES (
                next_in_queue.user_uid,
                expired_timer.lobby_id,
                expired_timer.game_name,
                expired_timer.spot_index,
                'spot_assigned',
                '🎮 Your spot is ready!',
                format('Lock in within 5 minutes for %s', expired_timer.game_name),
                jsonb_build_object(
                    'type', 'peacock_assigned',
                    'lobby_id', expired_timer.lobby_id,
                    'game_name', expired_timer.game_name,
                    'spot_index', expired_timer.spot_index
                )
            );

            -- Remove from queue after assignment
            DELETE FROM peacock_queue WHERE id = next_in_queue.id;

            -- Reposition remaining queue members
            UPDATE peacock_queue
            SET position = position - 1
            WHERE 
                lobby_id = expired_timer.lobby_id
                AND game_name = expired_timer.game_name
                AND position > next_in_queue.position;

            RAISE NOTICE 'Notification created for user %', next_in_queue.user_uid;
        END IF;

        -- Delete expired timer
        DELETE FROM squad_timers WHERE id = expired_timer.id;
    END LOOP;

    -- Clean up old notifications
    PERFORM delete_old_peacock_notifications();

    RAISE NOTICE 'Timer processing complete';
END;
$$ LANGUAGE plpgsql;

-- Verify setup
SELECT 'Peacock notification system created successfully' AS status;
