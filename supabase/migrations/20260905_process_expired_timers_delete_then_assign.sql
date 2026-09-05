-- process_expired_timers: delete expired row, then assign next queue uid.
-- Clients display expired/assigned; this function is the assigner.
--
-- SPENCER YES required to apply. Do not apply to live / prod from this
-- slice. Repo sketch only.
--
-- Fixes: INSERT ... ON CONFLICT then DELETE WHERE id = expired_timer.id
-- removed the 5-minute lock-in timer that had just been upserted onto
-- the same unique (lobby_id, game_name, spot_index) row.

CREATE OR REPLACE FUNCTION process_expired_timers()
RETURNS void AS $$
DECLARE
    expired_timer RECORD;
    next_in_queue RECORD;
    timer_count INTEGER;
    has_next BOOLEAN;
BEGIN
    SELECT COUNT(*) INTO timer_count
    FROM squad_timers
    WHERE expires_at <= NOW();

    RAISE NOTICE 'Processing % expired timers', timer_count;

    FOR expired_timer IN
        SELECT * FROM squad_timers
        WHERE expires_at <= NOW()
    LOOP
        RAISE NOTICE 'Freeing spot % in lobby % (game: %)',
            expired_timer.spot_index,
            expired_timer.lobby_id,
            expired_timer.game_name;

        SELECT * INTO next_in_queue
        FROM peacock_queue
        WHERE
            lobby_id = expired_timer.lobby_id
            AND game_name = expired_timer.game_name
        ORDER BY position ASC
        LIMIT 1;
        has_next := FOUND;

        DELETE FROM squad_timers WHERE id = expired_timer.id;

        UPDATE squad_spots
        SET
            occupied_by_uid = NULL,
            status = 'available',
            updated_at = NOW()
        WHERE
            lobby_id = expired_timer.lobby_id
            AND game_name = expired_timer.game_name
            AND spot_index = expired_timer.spot_index;

        IF has_next THEN
            RAISE NOTICE 'Auto-assigning spot to next in queue: %', next_in_queue.user_uid;

            UPDATE squad_spots
            SET
                occupied_by_uid = next_in_queue.user_uid,
                status = 'claimed',
                updated_at = NOW()
            WHERE
                lobby_id = expired_timer.lobby_id
                AND game_name = expired_timer.game_name
                AND spot_index = expired_timer.spot_index;

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
            );

            IF to_regclass('public.peacock_notifications') IS NOT NULL THEN
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
                    'Your spot is ready!',
                    format('Lock in within 5 minutes for %s', expired_timer.game_name),
                    jsonb_build_object(
                        'type', 'peacock_assigned',
                        'lobby_id', expired_timer.lobby_id,
                        'game_name', expired_timer.game_name,
                        'spot_index', expired_timer.spot_index
                    )
                );
            END IF;

            DELETE FROM peacock_queue WHERE id = next_in_queue.id;

            UPDATE peacock_queue
            SET position = position - 1
            WHERE
                lobby_id = expired_timer.lobby_id
                AND game_name = expired_timer.game_name
                AND position > next_in_queue.position;

            RAISE NOTICE 'User % assigned to spot', next_in_queue.user_uid;
        END IF;
    END LOOP;

    IF to_regclass('public.peacock_notifications') IS NOT NULL THEN
        PERFORM delete_old_peacock_notifications();
    END IF;

    RAISE NOTICE 'Timer processing complete';
END;
$$ LANGUAGE plpgsql;

SELECT 'process_expired_timers sketch: delete then assign (Spencer YES to apply)' AS status;
