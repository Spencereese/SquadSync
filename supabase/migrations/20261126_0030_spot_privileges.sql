-- NOT applied live. Needs Spencer's yes (it's a security change).
-- Apply after 0013. Safe to run again.
--
-- Read-only check on sfckxrnoiwetmzdycqaa (Nov 26, 2026): authenticated holds
-- SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES and TRIGGER on
-- sq8_spot_calls and sq8_spot_rsvps. Those came from Supabase's default
-- privileges; 0013 revoked public and anon only and meant SELECT. Forced RLS
-- with select-only policies already refuses insert, update and delete, but
-- TRUNCATE skips RLS, so any signed-in person could empty both tables.
-- This puts back exactly what 0013 granted: SELECT. All writes already go
-- through security definer functions (0013, 0020, 0028), which run as the
-- owner and don't need these grants. The service role is not touched.

revoke insert, update, delete, truncate, references, trigger
  on public.sq8_spot_calls from authenticated;
revoke insert, update, delete, truncate, references, trigger
  on public.sq8_spot_rsvps from authenticated;
revoke all on public.sq8_spot_calls from public, anon;
revoke all on public.sq8_spot_rsvps from public, anon;
grant select on public.sq8_spot_calls to authenticated;
grant select on public.sq8_spot_rsvps to authenticated;
