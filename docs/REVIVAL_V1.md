# SquadSync revival-v1 freeze

**North star:** fastest path from "who's on?" to a locked squad in-game.

Phase A froze revival quality on tip. **Phase B started** with Matchmaking Queue v1 (product queue, not Grok AI matchmaking). Lobby polish Tonight strip landed; remaining Phase B follow-ups stay parked.

Draft PR: https://github.com/Spencereese/SquadSync/pull/1 — **do not merge**.

## Tip SHA / version note

Fill this block at freeze (and again if tip moves):

```
Branch:  cursor/revive-squadsync-be5c
SHA:     4c6e1172b9f4b58b0204a553357ed70d59e12d17
Short:   4c6e117
Version: 3.4.79+81
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

Bundle ID stays `com.example.codSquadApp`. Do not commit `.env`. SQL for this LFG persist slice is granted (Spencer YES): `supabase/migrations/20260903_create_matchmaking_queue.sql`.

## Phase B status

| Slice | Status | Note |
| --- | --- | --- |
| Matchmaking Queue v1 | **Landed** (`3.4.70+72`) | Product LFG queue: idle → looking → matched → joined. LFG join is a **single** peacock handoff: `LobbyNotifier.assignPeacockSpot` claims the next free seat when lobby state is available (else snackbar “Claim seat N”), then `joinMatched(handoffToPeacock: false)` so assign is never reduced twice. In-memory tracker only. Not Grok `AiMatchmaking` (Phase E). |
| Deep-link unify | **Landed** (`3.4.71+73`) | Chat peacock card, notification tap, and `lfg_matched` / `lfg_alert` / peacock / lobby URLs share `locationForDeepLink` + `NotificationRoutes.locationFor`. No ad-hoc `Navigator.push` for those taps. Universal Links / Open-in still Spencer-gated. |
| Lobby share / copy | **Landed** (`3.4.72+74`) | Lobby header share copies and shares `codsquadapp://lobby/<id>`. Same parse as slice 2 (`locationForDeepLink`). No QR / SMS / Universal Links. |
| Availability pings | **Landed** (`3.4.74+76`) | "I'm on now" from Looking-for-Squad chat info and lobby controls. Lobby members (minus sender) pinged via `NotificationService.sendNotificationToUsers`. Taps reuse `NotificationRoutes` (`availability_ping` → `/squad?lobby_id=`). No new table / screen / presenter. XOR still `planPeacockSelfNotify`. |
| Session ratings | **Landed** (`3.4.75+77`) | Rate a squad session after Win/Loss on lobby controls and stats Record win/loss. Pure `reduceSessionRating`; persisted in existing `match_history.notes`. Average tiles read those notes. No new table / screen. XOR still `planPeacockSelfNotify`. |
| Lobby polish | **Landed** (`3.4.76+78`) | Tonight strip on chat-info / lobby actions: I am on, Looking for Squad, Invite. Voice + Video under More. Dead Search entry removed (coming-soon snackbar is not a feature). XOR still `planPeacockSelfNotify`. |
| Lobby seat chip / offer | **Landed** (`3.4.77+79`) | Lobby status chip seated / peacock / lock mm:ss from existing peacock + LFG. Offered spot pulses. Copy “Claim seat N”. Offer banner Accept / Decline → `assignPeacockSpot` + `joinMatched(handoffToPeacock: false)` / expire. XOR still `planPeacockSelfNotify`. |
| Ready / Lock | **Landed** (`3.4.78+80`) | Seated spots toggle Ready on the live lobby path. All seated Ready → lobby Locks. Seated members (minus actor) notified via `NotificationService.sendNotificationToUsers`. Taps reuse `NotificationRoutes` (`lobby_locked` → `/squad?lobby_id=`). XOR still `planPeacockSelfNotify`. |
| LFG persist / matchmaking_queue | **Landed** (`3.4.79+81`) | Looking survives app kill via `matchmaking_queue` + Realtime hydrate. Lobby-aware `processQueueAndPersist` on LFG tap and lobby stream. Single peacock handoff (`assignPeacockSpot` then `joinMatched(handoffToPeacock: false)`). XOR still `planPeacockSelfNotify`. No second presenter. |

**LFG persist SQL (this slice, Spencer YES):** file `supabase/migrations/20260903_create_matchmaking_queue.sql` (table `matchmaking_queue`). Live apply: REST GET `public.matchmaking_queue` on project `sfckxrnoiwetmzdycqaa` returned PGRST205 (table missing). `npx supabase projects list` failed (`LegacyPlatformAuthRequiredError` — no access token). No service_role / DB password in this environment. Migration file is the apply artifact.

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
- [ ] LFG persist SQL applied: `20260903_create_matchmaking_queue.sql` (`matchmaking_queue`)
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
| Session ratings | 3.4.75 | Rate ended session from lobby Win/Loss + stats Record. `match_history.notes` JSON. Reducer `reduceSessionRating`. |
| Lobby polish | 3.4.76 | Tonight strip regroup. Voice+Video under More. Search entry gone. |
| Lobby seat chip / offer | 3.4.77 | Chip seated / peacock / lock mm:ss. Offered spot pulse. Claim seat N. Accept / Decline banner. |
| Ready / Lock | 3.4.78 | Seated Ready toggle. All seated Ready locks the lobby. Notify via existing NotificationService / NotificationRoutes. |
| LFG persist | 3.4.79 | `matchmaking_queue` + Realtime + lobby-aware `processQueue`. Looking survives app kill. |

## Phase B+ parking lot (wishlist only)

1. ~~Matchmaking Queue~~ — v1 landed (`3.4.70+72`); persist + lobby-aware `processQueue` landed (`3.4.79+81`)
2. ~~Session ratings / lobby polish~~ — ratings `3.4.75+77`; Tonight strip `3.4.76+78`
3. Performance Leaderboard
4. Live Activities
5. Voice / AI / public launch / TestFlight / bundle ID rename
