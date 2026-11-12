# SquadSync

Native iPhone messenger for one squad of eight. This branch, `ios/main`, is the integration base for the SwiftUI app.

The Flutter client is not in this tree. It stays on the frozen `squad8` pull requests (PR 4 through PR 20) as the behavior reference. Those branches are not merged here.

Bundle id: `com.spencereese.squadsync`.

## What this branch keeps

- `supabase/migrations/` files `0001` through `0016`, in order
- SQL row-level security tests in `supabase/tests/`
- Edge functions and the FCM payload tests

No migration in this tree is applied to the live project by this repository's CI. CI only runs the checks against a throwaway Postgres.

## Checks

On `ios/main` and `ios/**`:

- FCM payload tests (Deno)
- SQL RLS tests (Postgres 16)

The Flutter analyze, widget test, and APK job does not run on this line.

The SwiftUI prototype lives on `ios/slice-prototype-37ef` under `app/`. See `app/README.md` for the simulator command.
