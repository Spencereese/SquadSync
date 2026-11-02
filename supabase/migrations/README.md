# Migrations

These four files are the slice 2 schema. **They have not been applied.** Do not run them against the live Supabase project until Spencer says so. `supabase/tests/` is a local harness only. It is not part of the apply.

The old schema already has `public.squads`, `public.messages`, and `public.chat_read_states`. Every new table is prefixed `sq8_` so these files do not reuse those names. `profiles` and `squad_members` did not exist; they are still prefixed so the set stays together.

## Apply order

Run these in order, in one project, as the migration role:

1. `20261103_0001_profiles.sql`
2. `20261103_0002_squad_members.sql`
3. `20261103_0003_messages.sql`
4. `20261103_0004_read_state.sql`

## What each file does

1. **Profiles.** When someone signs up, a row is created in `sq8_profiles` with `default_game` Call of Duty. A person can read and update only their own profile until the next file. They cannot insert a profile for someone else.
2. **Squad and members.** `sq8_squads` plus `sq8_squad_members`. Creating a squad seats the owner. An insert of a 9th member is rejected. Deleting the owner is rejected. A person is in at most one squad. Members can read the squad, the member list, and each other's profiles. Only the owner adds or removes members.
3. **Messages.** `sq8_messages` uses the client UUID as the primary key, so a second insert of the same id conflicts. The paging index is `(squad_id, sent_at desc, id desc)`. Members can read. An insert must be from yourself. The table is added to the `supabase_realtime` publication.
4. **Read state.** `sq8_chat_read_state` is one cursor per user per squad. You can read and write only your own row. Opening one squad does not write any other row.

## Rollback

Run these in reverse order. This deletes the slice 2 rows. It does not touch the old tables.

```sql
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

`drop table` on members and squads removes the policies with the tables. The profile policy added in file 2 is dropped explicitly because the profiles table stays until step 1.

## Auth settings — NOT DONE

The app sends an email one-time code (`signInWithOtp` + `verifyOTP` with type `email`). It does not open a magic link. Nothing below has been changed in the dashboard.

1. **NOT DONE.** Authentication → Providers → Email: leave Email enabled. This is the only provider this slice uses.
2. **NOT DONE.** Authentication → Email Templates → Magic Link: replace the body so the message shows the code, because Supabase sends a magic link until this template includes the token:

   ```html
   <h2>Your SquadSync code</h2>
   <p>Enter this code in the app: {{ .Token }}</p>
   ```

3. **NOT DONE.** Authentication → Providers → Email → Email OTP Expiration: leave the default, or set it under one day. The app asks for that code. It does not need a redirect for the code path.
4. **NOT DONE, only if the template still contains a link.** Authentication → URL Configuration. Add redirect URL `com.spencereese.squadsync://login-callback`. The app does not handle that link in this slice. Skip this if the template is the code-only body above.
5. **NOT DONE.** Do not enable phone, Google, or Apple for this slice. Do not put the service-role key in the app.

After the four migrations, the first squad row is still not created. Spencer signs in once (that creates his profile), then inserts the squad himself. That insert is **NOT RUN** here:

```sql
insert into public.sq8_squads (owner_id)
values ('<spencer auth user uuid>');
```

The owner-member trigger seats him. He adds the other seven from the app, up to eight total.
