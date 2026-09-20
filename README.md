# SquadSync

Friends lobby app. Tonight → seat map → one CTA → locked squad.

Who's on → seated → locked squad: create lobby from chat → sit → Ready locks → push opens THAT lobby → chat in that thread.

- **Version:** 3.4.153+155 @ `6c3c974`
- **Branch:** `cursor/revive-squadsync-be5c` — draft PR #1, do not merge
- **Bundle ID:** `com.example.codSquadApp` (temporary)
- **Stack:** Flutter + Riverpod 2.6 + Supabase + FCM + Agora

## Run

```
flutter pub get
cp .env.example .env
flutter run
```

Copy `.env.example` → `.env` locally. `.env` stays gitignored. Never commit secrets.

## Friends chrome

Tonight | Chat | You. `FRIENDS_MODE` defaults true.

## Open Spencer GATES

Device push e2e; Associated Domains + hosted AASA; lock-screen widget App ID.

## Invariants

peacock XOR `planPeacockSelfNotify`; one notify pipeline; no second presenter.

TestFlight / IPA: `docs/TESTFLIGHT_CHECKLIST.md`.
