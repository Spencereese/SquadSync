-- Owner can read the squad row they just inserted.
-- Reported live policy, not re-checked against the project from this checkout.
-- insert().select() needs this because the member-only select policy does not
-- see the owner seat until the insert statement has finished.
-- Idempotent: a database that already has this policy is left unchanged.
-- Does not read or write the old public.users, squads, or messages tables.

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'sq8_squads'
      and policyname = 'sq8_squads_select_owner'
  ) then
    create policy sq8_squads_select_owner
      on public.sq8_squads
      for select
      to authenticated
      using (owner_id = auth.uid());
  end if;
end $$;
