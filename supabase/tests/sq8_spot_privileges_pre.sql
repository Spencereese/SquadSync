-- Local throwaway only. Gives authenticated what Supabase's default
-- privileges gave it on live (read-only check, Nov 26, 2026), so 0030 is
-- tested against the real starting point. Never run this on the live project.
grant select, insert, update, delete, truncate, references, trigger
  on public.sq8_spot_calls, public.sq8_spot_rsvps to authenticated;
