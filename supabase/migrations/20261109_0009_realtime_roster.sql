-- Proposed. Not applied to the live project.
-- sq8_messages is already in supabase_realtime (file 3). Members and
-- check-ins are not. Realtime still obeys row level security: a person only
-- receives rows they are allowed to select. Resume and pull-to-refresh do
-- not need this publication.

do $$
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    create publication supabase_realtime;
  end if;
end $$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array['sq8_squad_members', 'sq8_check_ins']
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = table_name
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        table_name
      );
    end if;
  end loop;
end $$;
