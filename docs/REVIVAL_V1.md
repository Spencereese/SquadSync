# SquadSync revival-v1 freeze

**North star:** fastest path from "who's on?" to a locked squad in-game.

Phase A froze revival quality on tip. **Phase B started** with Matchmaking Queue v1 (product queue, not Grok AI matchmaking). Remaining Phase B (session ratings, lobby polish) is still queued.

Draft PR: https://github.com/Spencereese/SquadSync/pull/1 — **do not merge**.

## Tip SHA / version note

Fill this block at freeze (and again if tip moves):

```
Branch:  cursor/revive-squadsync-be5c
SHA:     bd1850b691174910934f8b1da781d082a51efeaf
Short:   bd1850b
Version: 3.4.74+76
Date:    2026-09-03
```

At introduction of this checklist: branch `cursor/revive-squadsync-be5c`, version in `pubspec.yaml`. Subsequent slices bump patch/build on the same branch.

## In scope for freeze (must be true before Phase B)

These are revival-v1 quality gates, not new product:

- **Tip green units / analyze** on touched paths. No LateInitializationError. No dotenv / `Supabase.instance` assert in unit harnesses that construct `LobbyNotifier` or `ConstitutionManager` without overrides.
- **Simulator URL scheme:** `ios/Runner/Info.simulator.plist` registers `codsquadapp` (and `com.example.codSquadApp` for auth). Unit tests may read the plist; they must not require live SpringBoard.
- **ConstitutionManager DI:** default Riverpod path injects `SupabaseClient` (from `supabaseClientProvider` / `SupabaseService.maybeClient`). Construction without a client fails with a clear `StateError`, not a raw global assert. Voting UI goes through the provider, not `Supabase.instance` / `ConstitutionManager()`.
- **Peacock XOR (closed):** one assignment is local **or** FCM-to-self, never both. Do not reopen the closed XOR / Live Notifications / Stats slices except to keep them green.
- **Peacock product machine (wired):** `reducePeacockAssignment` is production truth. Join/leave/assign reduce **after repo success**. `processPeacockQueue` selects/returns the assigned uid and always `assignSpot`s when an assignment happens. Notify uses `planPeacockSelfNotify` (no parallel XOR). Not a scaffold.
- **Deep-link route coverage:** pure Dart parsers cover `codsquadapp` chat / join / squad / peacock / lobby / `lfg_matched` / `lfg_alert` / `screen=squad|lobby` / `lobby_id` without a simulator. Chat peacock card, notification tap, and those URLs share `locationForDeepLink` → `/squad?lobby_id=` (or `/chat` for `lfg_alert`).
- **Known human gates (not automatable here):**
  - iOS Simulator first custom-scheme open may show **"Open in Cod Squad?"** — Accept is a one-time SpringBoard tap.
  - **Keychain sign-in** / session restore on device and simulator. Dead Keychain JWT should refresh or sign out (`SupabaseService.ensureFreshSession`); a human still has to sign in when there is no session.

Bundle ID stays `com.example.codSquadApp`. Do not commit `.env`. Do not apply Supabase migrations from this freeze.

## Phase B status

| Slice | Status | Note |
| --- | --- | --- |
| Matchmaking Queue v1 | **Landed** (`3.4.70+72`) | Product LFG queue: idle → looking → matched → joined. LFG join is a **single** peacock handoff: `LobbyNotifier.assignPeacockSpot` claims the next free seat when lobby state is available (else snackbar “Handed off — claim spot in lobby”), then `joinMatched(handoffToPeacock: false)` so assign is never reduced twice. In-memory tracker only. Not Grok `AiMatchmaking` (Phase E). |
| Deep-link unify | **Landed** (`3.4.71+73`) | Chat peacock card, notification tap, and `lfg_matched` / `lfg_alert` / peacock / lobby URLs share `locationForDeepLink` + `NotificationRoutes.locationFor`. No ad-hoc `Navigator.push` for those taps. Universal Links / Open-in still Spencer-gated. |
| Lobby share / copy | **Landed** (`3.4.72+74`) | Lobby header share copies and shares `codsquadapp://lobby/<id>`. Same parse as slice 2 (`locationForDeepLink`). No QR / SMS / Universal Links. |
| Availability pings | **Landed** (`3.4.74+76`) | "I'm on now" from Looking-for-Squad chat info and lobby controls. Lobby members (minus sender) pinged via `NotificationService.sendNotificationToUsers`. Taps reuse `NotificationRoutes` (`availability_ping` → `/squad?lobby_id=`). No new table / screen / presenter. XOR still `planPeacockSelfNotify`. |
| Session ratings | Queued | Phase B remainder |
| Lobby polish | Queued | Phase B remainder |

**Parked Phase B follow-up (Spencer gate):** a shared `matchmaking_queue` (or equivalent) table plus lobby-aware `processQueue` so looking state is cross-device. v1 stays in-memory + existing `lfg_alert` / Looking-for-Squad notify. Do not apply SQL from this slice.

## Out of scope / parked until later Phase B+ / E

Do not start these on this branch:

- Performance Leaderboard
- Live Activities
- Voice (new work; existing voice room stays as-is)
- AI / Grok features (including `grok_service` `AiMatchmaking`)
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
- [ ] Deep-link parser covers `lobby_id`, `screen=squad|lobby`, peacock / lobby / `lfg_matched` / `lfg_alert` / squad / chat / join
- [ ] Peacock XOR: no local + FCM-to-self for the same assignment id
- [ ] Peacock product machine: idle → queued → assigned → notified, **wired** into LobbyNotifier + peacock notification (not scaffold)
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
| Peacock product machine | 3.4.66–3.4.67 | Reducer **wired** into join/leave/assign/notify/expire. XOR still `planPeacockSelfNotify`. |
| Matchmaking Queue v1 | 3.4.69–3.4.70 | Product LFG queue on chat info. Single peacock handoff + next-free-seat claim. In-memory only; persistence table still Spencer-gated. |
| Deep-link unify | 3.4.71 | Peacock card / notification / LFG / lobby URLs share one go_router parse. |
| Lobby share / copy | 3.4.72 | Lobby header share/copy of `codsquadapp://lobby/<id>` through `locationForDeepLink`. |
| Availability pings | 3.4.74 | "I'm on now" from LFG / lobby. Existing `NotificationService` / `NotificationManager` / `NotificationRoutes`. |

## Phase B+ parking lot (wishlist only)

1. ~~Matchmaking Queue~~ — v1 landed (`3.4.70+72`); persistence table + lobby-aware `processQueue` still Spencer-gated Phase B follow-up
2. Session ratings / lobby polish (remaining Phase B)
3. Performance Leaderboard
4. Live Activities
5. Voice / AI / public launch / TestFlight / bundle ID rename
