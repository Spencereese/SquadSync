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

Arguments go after the bundle id. `-screen` jumps to a state. `-scenario` picks the party seed. `-uitest-largeText` locks Dynamic Type at the largest accessibility size.

Screens: `inbox`, `thread-general`, `thread-warzone`, `party`, `voice`, `voice-pill`, `space`, `handoff`.

Scenarios: `seated` (viewer is Ready), `unseated` (I'm in can be tapped), `ready4` (Lock can be tapped).

```bash
xcrun simctl launch "$UDID" com.spencereese.squadsync -screen inbox -scenario seated
xcrun simctl launch "$UDID" com.spencereese.squadsync -screen thread-general -scenario unseated
xcrun simctl launch "$UDID" com.spencereese.squadsync -screen thread-warzone
xcrun simctl launch "$UDID" com.spencereese.squadsync -screen party -scenario ready4
xcrun simctl launch "$UDID" com.spencereese.squadsync -screen voice
xcrun simctl launch "$UDID" com.spencereese.squadsync -screen voice-pill
xcrun simctl launch "$UDID" com.spencereese.squadsync -screen space
xcrun simctl launch "$UDID" com.spencereese.squadsync -screen handoff
xcrun simctl launch "$UDID" com.spencereese.squadsync -uitest-largeText -screen inbox
```

The voice lounge is mock-only. `VoiceRoomService` is the seam for a later hosted room: join, leave, mute, participants, speaking levels, and a connection state of idle, connecting, connected, reconnecting, or failed. `InMemoryVoiceRoomService` is the fake. No voice SDK, account, or provider is included.

The prototype starts in the inbox. The States menu shows loading, empty, and error. Tap a thread for bubbles, tapbacks, swipe-to-reply, the party card, voice, and handoff.
