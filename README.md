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
4. **Presence.** Not this slice. Steam, Xbox, and PlayStation are not connected. The availability board is a separate self check-in: available now, available later at a chosen time, or unavailable. Being in the app is not available. See the completion table.
5. **Calls, calendar, and RSVPs.**
6. **Fact-check and squad memory.** Server-side only. The phone never holds the model key.

## Completion

| Gate | State |
| --- | --- |
| Demo chat, labeled, not presented as live | Implemented and widget-tested |
| Email code sign-in, session restore, sign-out | Implemented and widget-tested against a fake session. A real code on a device was not run. The email template was not opened or changed in this run |
| Own profile and default game | Save of an existing row is implemented and widget-tested on the fake. A missing row can be created only for the signed-in person. That insert policy is in `20261108_0005_own_profile_and_squad_guard.sql` and is not applied. If the server rejects it, the form stays and nothing is saved |
| First squad, owner seated, cap 8 | The app will not send a second squad. Two owner creates already end as one squad without migration `0005`, because a person can belong to only one squad. Two member inserts that both see seven people can both commit on the file-2 trigger, so a squad can reach 9. A throwaway database shows that breach, and shows that file 5's row lock stops it at 8. File 5 is not applied. This checkout did not read the live database, so the live cap is not known to be safe |
| Send, fail, retry the same id, echo dedupe | Implemented. Widget-tested on the fake. Reload keeps a failed row |
| Earlier messages and reload | Implemented and tested |
| Availability board | Implemented and tested on a fake clock and a throwaway database. "Available now" lasts 60 minutes from the check-in. "Available later" stays later until the chosen time ("Maybe later from …"), then the phone shows them as available for 60 minutes ("Available since …") without rewriting the row. Last seen is when that window ended, not the check-in time. Unavailable is explicit. No row means not checked in. Opening the app does not check anyone in. Migration `20261108_0006_check_ins.sql` is not applied, so a live project without that table shows that availability is not enabled |
| Invite code | The owner can make or replace an 8-character code. A friend can join with it. The same squad is a no-op. An empty squad they own is removed first. A squad they own with other people, or a squad they only belong to, is refused. A missing invite table says invites are not enabled. Migration `20261109_0008_invites.sql` is not applied. File 7 records the owner select policy and is idempotent |
| Live OTP on a phone | Not verified. No device sign-in and no two-client session were run. The email template was not read or changed in this run |
| Push to the squad chat | Not live. The phone shows "Notifications off" until a real device token exists. Migration `20261110_0012_device_tokens.sql` and `supabase/functions/sq8-notify-message` are not applied or deployed. Spencer's secrets and console steps are in `supabase/functions/sq8-notify-message/README.md`. |
| App Store / TestFlight | Not done |

## What does not happen

Nothing in this repo ships to the App Store or TestFlight. This agent does not apply live SQL.
