# SquadSync iOS prototype

SwiftUI iPhone app for Phase 1. The target is iPhone only. Mock data only. No networking, no Supabase, and no third-party packages.

- Bundle id: `com.spencereese.squadsync`
- Deployment: iOS 17
- Swift: 5.9
- The `.xcodeproj` was written by hand to match `project.yml`. XcodeGen is not required. Simulator builds do not need a signing certificate.

## Build and run on a Mac

From the repository root:

```bash
xcodebuild -project app/SquadSync.xcodeproj -scheme SquadSync -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

That command builds the app, runs the XCTest unit tests, and leaves a simulator build. To launch it in the Simulator after a build:

```bash
xcodebuild -project app/SquadSync.xcodeproj -scheme SquadSync -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
open -a Simulator
xcrun simctl boot "iPhone 16 Pro" || true
xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/SquadSync-*/Build/Products/Debug-iphonesimulator/SquadSync.app
xcrun simctl launch booted com.spencereese.squadsync
```

Or open `app/SquadSync.xcodeproj` in Xcode, choose the SquadSync scheme and an iPhone 17-or-newer simulator, and press Run.

The voice lounge is mock-only. `VoiceRoomService` is the seam for a later hosted room: join, leave, mute, participants, speaking levels, and a connection state of idle, connecting, connected, reconnecting, or failed. `InMemoryVoiceRoomService` is the fake. No voice SDK, account, or provider is included.

The prototype starts in the inbox. The States menu shows loading, empty, and error. Tap a thread for bubbles, tapbacks, swipe-to-reply, the party card, voice, and handoff.
