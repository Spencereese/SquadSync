# SquadSync

A private chat for one squad of eight friends, on iPhone and Android.

This tree is a fresh start. The previous app is not the base of this branch. Nothing here talks to Supabase, Firebase, or a store. The screen runs on in-memory fakes.

Bundle id: `com.spencereese.squadsync`.

## Run

Developed on Flutter 3.47.9 stable (Dart 3.13.7).

```bash
flutter pub get
flutter run
```

Checks:

```bash
flutter analyze --fatal-warnings
flutter test
flutter build apk --debug
```

iOS and Android only. There is no web or desktop target.

## Phase order

1. **Tests.** Squad rules, send states, history paging, and unread, on fakes. This slice.
2. **Lockdown.** Supabase auth, squad and chat tables, row level security, and JWT. No live SQL without Spencer.
3. **Server timers.** Expiry and deadlines owned by the database, not the phone.
4. **Presence.** Steam for PC players on Steam, Xbox for linked Microsoft accounts, and an honor-system check-in for PlayStation and for any session those APIs cannot see.
5. **Calls, calendar, and RSVPs.**
6. **Fact-check and squad memory.** Server-side only. The phone never holds the model key.

## What does not happen

Nothing in this repo ships to the App Store or TestFlight. No live SQL is applied without Spencer.
