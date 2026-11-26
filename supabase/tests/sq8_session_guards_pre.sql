-- Local throwaway only. Before 0025: give authenticated what Supabase's
-- default privileges gave it on the live project (everything on both session
-- tables), so the 0025 revoke is actually tested. Not the live project.
\set ON_ERROR_STOP on
grant all on public.sq8_sessions to authenticated;
grant all on public.sq8_session_rsvps to authenticated;
