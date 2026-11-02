# SquadSync

A private chat for one squad of eight friends, on iPhone and Android.

This tree is a fresh start. The previous app is not the base of this branch. The screen runs on in-memory fakes unless a Supabase URL and anon key are provided. No SQL has been applied to a live project.

Bundle id: `com.spencereese.squadsync`.

## Run

Developed on Flutter 3.47.9 stable (Dart 3.13.7).

```bash
flutter pub get
flutter run
```

To point the app at Supabase, copy `env.json.example` to `env.json` (that file stays untracked) and run:

```bash
flutter run --dart-define-from-file=env.json
```

The same two values work as `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`. Without them the app stays on the fakes and does not show sign-in. Sign-in is an email code, not a magic link.

Checks:

```bash
flutter analyze --fatal-warnings
flutter test
flutter build apk --debug
```

iOS and Android only. There is no web or desktop target.

## Phase order

1. **Tests.** Squad rules, send states, history paging, and unread, on fakes. This slice.
2. **Lockdown.** Supabase auth, squad and chat tables, row level security, and JWT. The SQL is in `supabase/migrations/` and is not applied. See that folder's README.
3. **Server timers.** Expiry and deadlines owned by the database, not the phone.
4. **Presence.** Steam for PC players on Steam, Xbox for linked Microsoft accounts, and an honor-system check-in for PlayStation and for any session those APIs cannot see.
5. **Calls, calendar, and RSVPs.**
6. **Fact-check and squad memory.** Server-side only. The phone never holds the model key.

## What does not happen

Nothing in this repo ships to the App Store or TestFlight. No live SQL is applied without Spencer.
