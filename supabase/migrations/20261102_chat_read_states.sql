-- Per-user unread counts for a chat group.
-- Not applied from the app. Dart in lib/core/chat_read_state.dart
-- ignores a missing table and keeps the in-memory badge.

CREATE TABLE IF NOT EXISTS chat_read_states (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  chat_id text NOT NULL,
  unread_count integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, chat_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_read_states_user
  ON chat_read_states (user_id);
