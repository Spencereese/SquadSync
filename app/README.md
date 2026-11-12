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

## Build

```bash
xcodebuild -project app/SquadSync.xcodeproj -scheme SquadSync -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

## Test

```bash
xcodebuild -project app/SquadSync.xcodeproj -scheme SquadSync -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

## Run in the Simulator

```bash
xcodebuild -project app/SquadSync.xcodeproj -scheme SquadSync -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
open -a Simulator
xcrun simctl boot "iPhone 16 Pro" || true
APP=$(xcodebuild -project app/SquadSync.xcodeproj -scheme SquadSync -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -showBuildSettings | awk -F ' = ' '/ BUILT_PRODUCTS_DIR / {print $2; exit}')
xcrun simctl install booted "$APP/SquadSync.app"
xcrun simctl launch booted com.spencereese.squadsync
```

If this Mac has no iPhone 16 Pro simulator, substitute the installed phone name in every command above. On Xcode 26 that name is `iPhone 17 Pro`.

The voice lounge is mock-only. `VoiceRoomService` is the seam for a later hosted room: join, leave, mute, participants, speaking levels, and a connection state of idle, connecting, connected, reconnecting, or failed. `InMemoryVoiceRoomService` is the fake. No voice SDK, account, or provider is included.

The prototype starts in the inbox. The States menu shows loading, empty, and error. Tap a thread for bubbles, tapbacks, swipe-to-reply, the party card, voice, and handoff.
