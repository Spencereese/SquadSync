# Migrations

Files 1–4 are the slice 2 schema. Spencer reported on Nov 8 that they are already applied on project `sfckxrnoiwetmzdycqaa`, with forced row level security, and that the old app tables were left in place. This checkout did not connect to that project and did not re-apply them. Running them again would fail on objects that already exist.

File 5 is proposed only. It is not applied. Do not run it until the check below is empty, because the unique index will fail if two squads already share an owner:

```sql
select owner_id
from public.sq8_squads
group by owner_id
having count(*) > 1;
```

`supabase/tests/` is a local harness only. It is not part of the apply.

The old schema already has `public.squads`, `public.messages`, and `public.chat_read_states`. Every new table is prefixed `sq8_` so these files do not reuse those names. `profiles` and `squad_members` did not exist; they are still prefixed so the set stays together.

## Apply order

Run these in order, in one project, as the migration role:

1. `20261103_0001_profiles.sql`
2. `20261103_0002_squad_members.sql`
3. `20261103_0003_messages.sql`
4. `20261103_0004_read_state.sql`
5. `20261108_0005_own_profile_and_squad_guard.sql` — **not applied**. Spencer has to approve this one before it runs. It adds an insert of only your own profile, one squad per owner, and a lock so two overlapping joins cannot pass eight members.

## What each file does

1. **Profiles.** When someone signs up, a row is created in `sq8_profiles` with `default_game` Call of Duty. A person can read and update only their own profile until the next file. They cannot insert a profile for someone else.
2. **Squad and members.** `sq8_squads` plus `sq8_squad_members`. Creating a squad seats the owner. A second create for the same person rolls back, because that person can be a member only once. That does not need file 5. An insert of a 9th member is rejected only when the count sees eight rows already. Two overlapping inserts can both see seven and both commit, so the table can hold 9. Deleting the owner is rejected. Members can read the squad, the member list, and each other's profiles. Only the owner adds or removes members.
3. **Messages.** `sq8_messages` uses the client UUID as the primary key, so a second insert of the same id conflicts. The paging index is `(squad_id, sent_at desc, id desc)`. Members can read. An insert must be from yourself. The table is added to the `supabase_realtime` publication.
4. **Read state.** `sq8_chat_read_state` is one cursor per user per squad. You can read and write only your own row. Opening one squad does not write any other row.
5. **Own profile and squad guard.** Not applied. An authenticated person may insert `sq8_profiles` only when `id` is their own auth id. A second insert does not change the name or default game. `sq8_squads.owner_id` is unique. The member cap locks the squad row before it counts, so two overlapping adds cannot both pass eight. Without this file the live cap is not safe. This checkout did not query the live project.

## Rollback

Run these in reverse order. This deletes the slice 2 rows. It does not touch the old tables.

```sql
-- 5 only. This does not drop the cap function. It puts the unlocked count back.
drop policy if exists sq8_profiles_insert_own on public.sq8_profiles;
drop index if exists public.sq8_squads_one_owner;
revoke insert on public.sq8_profiles from authenticated;

create or replace function sq8.reject_ninth_member()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  member_count integer;
begin
  select count(*)
    into member_count
  from public.sq8_squad_members
  where squad_id = new.squad_id;

  if member_count >= 8 then
    raise exception 'sq8_squad_full' using errcode = '23514';
  end if;
  return new;
end;
$$;

revoke all on function sq8.reject_ninth_member() from public;

-- 4
drop table if exists public.sq8_chat_read_state;

-- 3
do $$
begin
  if exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'sq8_messages'
  ) then
    alter publication supabase_realtime drop table public.sq8_messages;
  end if;
end $$;
drop table if exists public.sq8_messages;

-- 2. The profile policy references the member table, so it goes first.
drop policy if exists sq8_profiles_select_squad on public.sq8_profiles;
drop trigger if exists sq8_squads_seat_owner on public.sq8_squads;
drop trigger if exists sq8_squad_members_owner on public.sq8_squad_members;
drop trigger if exists sq8_squad_members_cap on public.sq8_squad_members;
drop table if exists public.sq8_squad_members;
drop table if exists public.sq8_squads;
drop function if exists sq8.add_owner_member();
drop function if exists sq8.reject_owner_removal();
drop function if exists sq8.reject_ninth_member();
drop function if exists sq8.is_member(uuid);

-- 1
drop trigger if exists sq8_on_auth_user_created on auth.users;
drop function if exists sq8.handle_new_user();
drop table if exists public.sq8_profiles;
drop schema if exists sq8;
```

To undo only file 5, run the statements above the `-- 4` comment and stop. The rest deletes the slice 2 rows. `drop table` on members and squads removes the policies with the tables. The profile policy added in file 2 is dropped explicitly because the profiles table stays until step 1.

## Auth settings — NOT DONE

The app sends an email one-time code (`signInWithOtp` + `verifyOTP` with type `email`). It does not open a magic link. Nothing below has been changed in the dashboard.

1. **NOT DONE.** Authentication → Providers → Email: leave Email enabled. This is the only provider this slice uses.
2. **Not changed here.** An earlier workflow reported the Magic Link template was saved with `{{ .Token }}`. This run did not open the template and does not treat that report as verified. Do not edit it again unless a real sign-in shows no code. The app still expects the email to contain the code:

   ```html
   <h2>Your SquadSync code</h2>
   <p>Enter this code in the app: {{ .Token }}</p>
   ```

3. **NOT DONE.** Authentication → Providers → Email → Email OTP Expiration: leave the default, or set it under one day. The app asks for that code. It does not need a redirect for the code path.
4. **NOT DONE, only if the template still contains a link.** Authentication → URL Configuration. Add redirect URL `com.spencereese.squadsync://login-callback`. The app does not handle that link in this slice. Skip this if the template is the code-only body above.
5. **NOT DONE.** Do not enable phone, Google, or Apple for this slice. Do not put the service-role key in the app.

After files 1–4, a new signup creates the profile (default game Call of Duty). The app can insert `sq8_squads` with `owner_id` set to that person, and the owner-member trigger seats them. A person who already existed in Auth before the signup trigger has no profile row. Creating that row, and stopping two overlapping creates from making two owner squads or a ninth member, needs file 5. File 5 is not applied. Until it is, the app shows the failure on the profile form and does not pretend the row was saved. Do not hand-insert a squad row.
