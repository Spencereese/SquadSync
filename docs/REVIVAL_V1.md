# SquadSync revival-v1 freeze

**North star:** fastest path from "who's on?" to a locked squad in-game.

Phase A freezes revival quality on tip before stacking more wishlist. This file is the freeze contract: what must already be true, what is parked until Phase B+, and the exit checklist.

Draft PR: https://github.com/Spencereese/SquadSync/pull/1 — **do not merge**.

## Tip SHA / version note

Fill this block at freeze (and again if tip moves):

```
Branch:  cursor/revive-squadsync-be5c
SHA:     <git rev-parse HEAD>
Short:   <git rev-parse --short HEAD>
Version: <pubspec.yaml version, e.g. 3.4.63+65>
Date:    <ISO date>
```

At introduction of this checklist: branch `cursor/revive-squadsync-be5c`, version in `pubspec.yaml`. Subsequent revival-v1 slices bump patch/build on the same branch.

## In scope for freeze (must be true before Phase B)

These are revival-v1 quality gates, not new product:

- **Tip green units / analyze** on touched paths. No LateInitializationError. No dotenv / `Supabase.instance` assert in unit harnesses that construct `LobbyNotifier` or `ConstitutionManager` without overrides.
- **Simulator URL scheme:** `ios/Runner/Info.simulator.plist` registers `codsquadapp` (and `com.example.codSquadApp` for auth). Unit tests may read the plist; they must not require live SpringBoard.
- **ConstitutionManager DI:** default Riverpod path injects `SupabaseClient` (from `supabaseClientProvider` / `SupabaseService.maybeClient`). Construction without a client fails with a clear `StateError`, not a raw global assert. Voting UI goes through the provider, not `Supabase.instance` / `ConstitutionManager()`.
- **Peacock XOR (closed):** one assignment is local **or** FCM-to-self, never both. Do not reopen the closed XOR / Live Notifications / Stats slices except to keep them green.
- **Deep-link route coverage:** pure Dart parsers cover `codsquadapp` chat / join / squad / peacock / `screen=squad|lobby` / `lobby_id` without a simulator.
- **Known human gates (not automatable here):**
  - iOS Simulator first custom-scheme open may show **"Open in Cod Squad?"** — Accept is a one-time SpringBoard tap.
  - **Keychain sign-in** / session restore on device and simulator. Dead Keychain JWT should refresh or sign out (`SupabaseService.ensureFreshSession`); a human still has to sign in when there is no session.

Bundle ID stays `com.example.codSquadApp`. Do not commit `.env`. Do not apply Supabase migrations from this freeze.

## Out of scope / parked until Phase B+

Do not start these on this freeze branch:

- Matchmaking Queue
- Performance Leaderboard
- Live Activities
- Voice (new work; existing voice room stays as-is)
- AI / Grok features
- Public launch
- Bundle ID change
- TestFlight

Also parked: reopening closed wishlist slices (Stats Dashboard, Live Notifications v1, Peacock XOR). Keep them green; do not restyle or expand them.

## Freeze exit checklist

### Automated (CI / local)

- [ ] `flutter test` green on revival-v1 suites (lobby notifier harness, constitution DI, deep-link routes, peacock XOR + assignment machine, notification routes)
- [ ] `flutter analyze` clean on touched lib/test paths
- [ ] No LateInit / dotenv / `Supabase.instance` harness failures in lobby / constitution unit tests
- [ ] `constitutionManagerProvider` default injects a client; tests override the provider
- [ ] `ios/Runner/Info.simulator.plist` registers `codsquadapp` (asserted by unit test, no SpringBoard)
- [ ] Deep-link parser covers `lobby_id`, `screen=squad|lobby`, peacock / squad / chat / join
- [ ] Peacock XOR: no local + FCM-to-self for the same assignment id
- [ ] Peacock product machine: idle → queued → assigned → notified (unit-tested)
- [ ] `.env` and `_test_shots/` untracked
- [ ] Bundle ID still `com.example.codSquadApp`

### Human gates (do not block the freeze commit; record when exercised)

- [ ] Simulator "Open in Cod Squad?" Accept on first `codsquadapp://` open
- [ ] Keychain / session sign-in on simulator or device after cold start
- [ ] End-to-end: notification or deep link lands on `/squad` with the right `lobby_id`

### Process

- [ ] Draft PR #1 updated; **not merged**
- [ ] No commits on `~/projects/cod_squad_app` (lobby-inc3 stays dirty)
- [ ] No Supabase SQL migrations applied from this work
- [ ] Tip SHA / version filled in the template above

## Closed on tip (do not reopen)

| Slice | Approx. version | Note |
| --- | --- | --- |
| Stats Dashboard | 3.4.49–3.4.52 | Fetch errors surface; do not swallow zeros |
| Live Notifications v1 | 3.4.53–3.4.55 | Local display, Android FCM, `peacock_assigned` routing |
| Peacock XOR | 3.4.57–3.4.59 | Skip FCM to self after local Realtime; inactive = foreground |
| Simulator `codsquadapp` scheme | 3.4.60 | `Info.simulator.plist` |
| Lobby notifier LateInit / dotenv harness | 3.4.61 | Bind deps before swallowed offline init |
| ConstitutionManager provider | 3.4.62 | Tests override; default must inject client (this freeze) |

## Phase B+ parking lot (wishlist only)

Record here so Phase A does not grow:

1. Matchmaking Queue
2. Performance Leaderboard
3. Live Activities
4. Voice / AI / public launch / TestFlight / bundle ID rename
