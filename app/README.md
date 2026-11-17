# SquadSync iOS prototype

SwiftUI iPhone app for Phase 1. The target is iPhone only. Mock data only. No networking, no Supabase client, and no third-party packages.

The Xcode project vendors no Swift packages, CocoaPods, or Carthage checkouts. A build does not fetch dependencies from the network. Simulator builds do not need a signing certificate (`CODE_SIGNING_ALLOWED` is NO).

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

`-debug-fail-sends N` is a DEBUG launch flag. The next N message sends fail, and the ones after that succeed. Use it with Retry on the simulator.

`-backend mock -scenario spotCall` opens the same screen with a half-filled Warzone spot card (4 of 8 in). You are not in it yet, so Join and then Ready are on the card. Ready stays on this phone. Nothing is written to Supabase.

`-backend mock -scenario spotCallMine` opens that card with you as the caller, so Cancel and Lock are on it.

The voice lounge is mock-only. `VoiceRoomService` is the seam for a later hosted room: join, leave, mute, participants, speaking levels, and a connection state of idle, connecting, connected, reconnecting, or failed. `InMemoryVoiceRoomService` is the fake. No voice SDK, account, or provider is included.

The prototype starts in the inbox. The States menu shows loading, empty, and error. Tap a thread for bubbles, tapbacks, swipe-to-reply, the party card, voice, and handoff.

## Live backend

Mock data is the default. `-backend live` uses the existing Supabase project for email sign-in, your profile, your squad, and squad chat. Voice stays mock. Spots and presence use the live project when those migrations are applied. Push registration and tap routing are in the app; delivery still needs the human gates in `supabase/functions/sq8-notify-message/README.md` (apply `20261110_0012_device_tokens.sql`, the APNs `.p8`, and the Push capability). `SquadSync.entitlements` is present and is not attached to the unsigned Debug and Release configs.

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
