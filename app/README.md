# SquadSync iOS prototype

SwiftUI iPhone app for Phase 1. The target is iPhone only. Mock data only. No networking, no Supabase client, and no third-party packages.

The only dependency is the Stream Video Swift SDK, through Swift Package Manager, pinned to exactly 1.57.0 with `Package.resolved` committed. The first build resolves it from GitHub. There are no CocoaPods or Carthage checkouts. Simulator builds are arm64 only (`EXCLUDED_ARCHS[sdk=iphonesimulator*] = x86_64`) and unsigned (`CODE_SIGNING_ALLOWED[sdk=iphonesimulator*] = NO`), so they need no certificate. Device builds sign automatically with Apple Development for team `K4ZTXPQ8J9`, with no command-line overrides; the Mac needs that team's Apple Development certificate.

Builds, simulator runs, and screenshots happen on the Mac mini. GitHub Actions on this branch runs the Linux SQL RLS and FCM payload jobs only.

- Bundle id: `com.spencereese.squadsync`
- Deployment: iOS 17
- Swift: 5.9
- `app/SquadSync.xcodeproj` is already committed and matches `app/project.yml`.

Commands below run from the repository root.

## XcodeGen

Optional. The checked-in project already builds. To rewrite it from the spec:

```bash
xcodegen generate --spec app/project.yml
```

## Simulator

Use iPhone 17 Pro. When more than one runtime is installed, target it by id so `xcodebuild` does not stop on multiple matches:

```bash
UDID=$(xcrun simctl list devices available | sed -n 's/^[[:space:]]*iPhone 17 Pro (\([^)]*\)).*/\1/p' | head -1)
echo "$UDID"
DEST="platform=iOS Simulator,id=$UDID"
```

A single installed iPhone 17 Pro can use the name instead: `platform=iOS Simulator,name=iPhone 17 Pro`.

## Build

```bash
xcodebuild -project app/SquadSync.xcodeproj -scheme SquadSync -destination "$DEST" build
```

## Test

Known issues, including the AX5 reactions layout hang: [docs/known-issues.md](docs/known-issues.md).

```bash
xcodebuild -project app/SquadSync.xcodeproj -scheme SquadSync -destination "$DEST" test
```

That runs the unit tests and `AccessibilityUITests`, which looks up `tab-inbox`, `tab-space`, `voice-room`, and `handoff-menu`.

## Run in the Simulator

```bash
xcodebuild -project app/SquadSync.xcodeproj -scheme SquadSync -destination "$DEST" build
open -a Simulator
xcrun simctl boot "$UDID" || true
APP=$(xcodebuild -project app/SquadSync.xcodeproj -scheme SquadSync -destination "$DEST" -showBuildSettings | awk -F ' = ' '/ BUILT_PRODUCTS_DIR / {print $2; exit}')
xcrun simctl install "$UDID" "$APP/SquadSync.app"
xcrun simctl launch "$UDID" com.spencereese.squadsync
```

## Launch arguments

Arguments go after the bundle id.

**Which backend:** a launch is live whenever `Config.xcconfig` sets the Supabase URL and anon key, in Debug and Release. Without them the app shows "This build isn't connected to a server" instead of sample data. Mock data needs `-backend mock`; in Debug a `-scenario` launch with no `-backend` flag is also mock (that's how the UI tests run), and the app hosting unit tests stays on mock. Every UI test passes `-backend mock`.

`-screen` jumps to a state. `-scenario` picks the party seed. `-uitest-largeText` locks Dynamic Type at the largest accessibility size.

Screens: `inbox`, `thread-general`, `thread-warzone`, `party`, `voice`, `voice-pill`, `space`, `handoff`.

Scenarios: `seated` (viewer is Ready), `unseated` (I'm in can be tapped), `ready4` (Lock can be tapped), `noSquad` (create-squad form on the mock backend), `invite` (invite, remove, and join on the mock backend), `almostFull` (7 members, so the next join fills 8 and the one after is rejected).

```bash
xcrun simctl launch "$UDID" com.spencereese.squadsync -backend mock -screen inbox -scenario seated
xcrun simctl launch "$UDID" com.spencereese.squadsync -backend mock -screen thread-general -scenario unseated
xcrun simctl launch "$UDID" com.spencereese.squadsync -backend mock -screen thread-warzone
xcrun simctl launch "$UDID" com.spencereese.squadsync -backend mock -screen party -scenario ready4
xcrun simctl launch "$UDID" com.spencereese.squadsync -backend mock -screen voice
xcrun simctl launch "$UDID" com.spencereese.squadsync -backend mock -screen voice-pill
xcrun simctl launch "$UDID" com.spencereese.squadsync -backend mock -screen space
xcrun simctl launch "$UDID" com.spencereese.squadsync -backend mock -screen handoff
xcrun simctl launch "$UDID" com.spencereese.squadsync -backend mock -uitest-largeText -screen inbox
xcrun simctl launch "$UDID" com.spencereese.squadsync -backend mock -scenario noSquad
xcrun simctl launch "$UDID" com.spencereese.squadsync -backend mock -scenario invite
xcrun simctl launch "$UDID" com.spencereese.squadsync -backend mock -scenario spotCall
```

`-backend mock -scenario noSquad` opens the live session screen against the in-memory mock, already signed in and not in a squad. The create-squad form is on screen. It does not write to Supabase.

`-backend mock -scenario invite` opens that screen as the owner of a mock squad named Friday, with Riley already in it and one message from Riley (`message-row-seed-1`). The Members button opens invite, join, and remove. Create invite, share or copy the code, and the join field are in that sheet. Codes `EXPIRED2`, `REVOKED2`, `FULL2345`, and `ALREADY2` show those errors. Any other code seats the next person who is not already in the squad, until 8. Nothing is written to Supabase.

`-backend mock -scenario almostFull` opens the same screen with 7 members. One join fills it to 8. The next join says the squad is full. The owner can remove someone. A member cannot leave on their own until `supabase/migrations/20261115_0019_self_leave.sql` is applied. That file is not applied. The Members sheet probes for `sq8_leave_squad` and keeps an honest line while the function is missing.

`-debug-push-open '<json>'` stands in for tapping a notification with that payload at launch (a cold tap), for example `{"type":"squad_message","squad_id":"00000000-0000-0000-0000-000000000010","message_id":"00000000-0000-0000-0000-00000000A001"}`. Add `-debug-push-open-after <seconds>` (up to 120) to deliver the same tap that many seconds after launch instead, as if the app were already open (a warm tap). A tap that lands closes any sheet or confirmation over the chat (the voice room keeps running) and scrolls to the message. A message newer than what's loaded is fetched first, so a tap that beats the realtime socket still opens it. A side-thread reply's payload (`{"type":"thread_message","squad_id":"…","thread_id":"…","message_id":"…"}`) opens that side thread over the chat instead, with the reply on screen; the mock backend has one side group, "Ranked" (`thread_id` `00000000-0000-0000-0000-00000000B001`, newest reply `00000000-0000-0000-0000-00000000B103`). Side threads: the squad bar's side threads button (or "Open side threads" in the Members panel, which is where it lives at accessibility text sizes) lists your side groups and DMs with the last reply and time, newest first, with loading, empty and error states. New picks one or more squad members: one makes a DM, two or more make a group with an optional name. Creation is two requests under the live 0017/0024 policies (the thread, then one bulk insert of the seats), so it needs no new SQL. There is no unread dot because the only read state is per squad. `-mock-side-threads empty` starts the mock with no threads and `-mock-side-threads down` makes its reads fail (UI tests). The real-device APNs checklist is in [docs/push-device-test.md](docs/push-device-test.md).

`-debug-fail-sends N` is a DEBUG launch flag. The next N message sends fail, and the ones after that succeed. Use it with Retry on the simulator.

`-backend mock -scenario spotCall` opens the same screen with a half-filled Warzone spot card (4 of 8 in). You are not in it yet, so Join and then Ready are on the card. Ready stays on this phone. Nothing is written to Supabase.

`-backend mock -scenario spotCallMine` opens that card with you as the caller, so Cancel and Lock are on it.

`-backend mock -scenario playSessions` opens the chat with play sessions: Alex's Warzone session tonight (Alex and Jordan in, Sam out, you haven't answered), your Halo Infinite session in two days, a cancelled one, and one that's over. The next one sits in a bar above the chat; tap it for the list. Schedule a session is in the composer's + menu. `playSessionsEmpty` starts with none, `playSessionsMissing` acts like a server without the `sq8_sessions` tables (the sheet says so and Schedule is off), and `playSessionsFailed` fails every read until you tap Try again. Play sessions use the live `sq8_sessions` and `sq8_session_rsvps` tables from migration 0016; 0025 adds server-side guards and is not applied live yet.

The voice lounge is mock-only. `VoiceRoomService` is the seam for a later hosted room: join, leave, mute, participants, speaking levels, and a connection state of idle, connecting, connected, reconnecting, or failed. `InMemoryVoiceRoomService` is the fake. The live squad room is separate and uses Stream; see [Voice](#voice).

The prototype starts in the inbox. The States menu shows loading, empty, and error. Tap a thread for bubbles, tapbacks, swipe-to-reply, the party card, voice, and handoff.

## Live backend

Mock data is the default. `-backend live` uses the existing Supabase project for email sign-in, your profile, your squad, and squad chat. Voice uses Stream (see [Voice](#voice)) and shows "Voice isn't set up yet" until `sq8-voice-token` is deployed. Spots and presence use the live project when those migrations are applied. Push registration and tap routing are in the app; delivery still needs the human gates in `supabase/functions/sq8-notify-message/README.md` (`20261110_0012_device_tokens.sql` was applied live on Nov 18, 2026; the APNs `.p8` and the Push capability on the App ID are still needed). `SquadSync.entitlements` (`aps-environment` = development) is set as `CODE_SIGN_ENTITLEMENTS` for Debug and Release. Unsigned simulator builds ignore it; a signed device build signs it in (check with `codesign -d --entitlements :- <path to SquadSync.app>`).

Before building, create the local config. The anon key is not in git.

```bash
cp app/Config.example.xcconfig app/Config.xcconfig
```

Open `app/Config.xcconfig` and replace `paste-anon-key-here` with the project anon key. The URL line is already the `sfckxrnoiwetmzdycqaa` project, written so xcconfig does not treat `//` as a comment.

The build reads `app/Base.xcconfig` (tracked, empty Supabase values), which pulls in `Config.xcconfig` with `#include?`. Without `Config.xcconfig` the build still succeeds and the app opens on "This build isn't connected to a server".

Then launch the simulator build with the live flag:

```bash
xcrun simctl launch "$UDID" com.spencereese.squadsync -backend live
```

Leave the flag off for the mock prototype and for the existing UI tests. Use `-backend mock -scenario noSquad` when you need the create-squad form without a live row.

## Voice

With `-backend live`, the voice pill opens `SquadVoiceSheet`, an audio-only room for the squad. It has join, leave, mute, and a list of who is in the room. The mock backend keeps the in-memory pill.

How it works:

- `SupabaseSquadVoiceTokens` (`Backend/SquadVoice.swift`) POSTs `{"squad_id": ...}` to `functions/v1/sq8-voice-token` with your session. On a 401 it refreshes the session once and tries again. A 404 (function not deployed), a 503, or `voice_not_configured` means "Voice isn't set up yet". A 403 means you aren't in the squad.
- `StreamVoiceEngine` (`Backend/StreamVoiceEngine.swift`) is the live engine. It uses the Stream Video Swift SDK, pinned to exactly **1.57.0** (SPM, product `StreamVideo` on the app target; `Package.resolved` is committed under `SquadSync.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`). It joins call type `default`, id `sq8-<squad uuid>`, with `videoOn: false`. It mutes with `call.microphone`, lists people from `call.state.participants`, and asks the function again when Stream says the token expired. A dropped connection shows as a failure, never as still connected.
- `LiveSessionModel.makeVoiceEngine` picks `StreamVoiceEngine` wherever `StreamVideo` can be imported. Elsewhere (the Linux harness) it picks `UnlinkedSquadVoiceEngine`, which never connects. Unit tests use fakes.
- `SquadVoiceSession` holds the state for the sheet and the pill: idle, joining, connected, not set up, or failed. Leaving during a slow join wins, and mute only changes once the engine accepts it.

Still needed before anyone can talk:

1. **Deploy `sq8-voice-token`.** It is not deployed and needs Spencer's yes. See `supabase/functions/sq8-voice-token/README.md`. Until then every join ends at "Voice isn't set up yet".
2. **Build and test on the Mac.** Resolve packages, then build, run the unit tests, and try two devices. Nothing here has been built with the SDK or tested on a device yet.

The mic prompt comes from the build setting `INFOPLIST_KEY_NSMicrophoneUsageDescription` (Debug and Release): "SquadSync uses the microphone only while you're in your squad's voice room."
