# SquadSync

A private chat for one squad of eight friends, on iPhone and Android.

This tree is a fresh start. The previous app is not the base of this branch. Without a Supabase URL and anon key the app is a labeled demo: messages stay on the phone. With both values it uses the live project. A URL without a running client shows "Not connected" and does not fall back to the demo.

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

1. **Tests.** Squad rules, send states, history paging, and unread.
2. **Lockdown.** Supabase auth, `sq8_` tables, row level security, and JWT. See `supabase/migrations/README.md`.
3. **Server timers.** Expiry and deadlines owned by the database, not the phone.
4. **Presence.** Steam for PC players on Steam, Xbox for linked Microsoft accounts, and an honor-system check-in for PlayStation and for any session those APIs cannot see.
5. **Calls, calendar, and RSVPs.**
6. **Fact-check and squad memory.** Server-side only. The phone never holds the model key.

## Completion

| Gate | State |
| --- | --- |
| Demo chat, labeled, not presented as live | Implemented and widget-tested |
| Email code sign-in, session restore, sign-out | Implemented and widget-tested against a fake session. A real code still needs the email template and a device |
| Own profile and default game | Implemented. Call of Duty is the column default. Save is widget-tested on the fake |
| First squad, owner seated, cap 8 | Implemented in the app and in SQL. Widget-tested on the fake. The 9th member and owner removal are enforced by the database triggers |
| Send, fail, retry the same id, echo dedupe | Implemented. Widget-tested on the fake. Reload keeps a failed row |
| Earlier messages and reload | Implemented and tested |
| Live OTP on a phone | Not released. Signing, install, and the code email are still Spencer's |
| App Store / TestFlight | Not done |

## What does not happen

Nothing in this repo ships to the App Store or TestFlight. This agent does not apply live SQL.
