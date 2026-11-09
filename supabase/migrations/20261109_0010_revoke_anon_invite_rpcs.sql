-- Proposed. Not applied to the live project. Needs Spencer's approval.
-- Supabase grants EXECUTE on new public functions to anon through default
-- privileges. File 8 revokes PUBLIC, which does not remove that anon grant.
-- anon must not call the invite RPCs. authenticated keeps the wrappers.
-- The sq8 implementations stay revoked from both anon and authenticated.

revoke execute on function public.sq8_join_with_code(text) from public, anon;
revoke execute on function public.sq8_create_invite() from public, anon;
revoke execute on function sq8.join_with_code(text) from public, anon;
revoke execute on function sq8.create_invite() from public, anon;

grant execute on function public.sq8_join_with_code(text) to authenticated;
grant execute on function public.sq8_create_invite() to authenticated;
