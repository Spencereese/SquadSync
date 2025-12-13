# Quick Start: Testing Your New Splash Screen

## Run the App

```bash
# iOS Simulator
flutter run -d "iPhone 15 Pro"

# Android Emulator
flutter run -d emulator-5554

# Physical Device
flutter run -d <device-id>
```

## What You Should See

### ✅ Correct Behavior:
1. **Tap app icon** → Black screen with splash.png appears INSTANTLY
2. **0.5 seconds** → Splash stays visible (Flutter initializing)
3. **1.5 seconds** → Splash still visible (minimum duration + data loading)
4. **2.0 seconds** → Smooth fade to main app
5. **No black screens or flickering at any point**

### ❌ If You See Problems:

| Problem | Cause | Fix |
|---------|-------|-----|
| Black screen after native splash | Flutter splash not showing | Check `SplashScreen()` widget |
| Splash disappears instantly | `FlutterNativeSplash.remove()` called too early | Check logs for timing |
| Splash never disappears | `remove()` not being called | Check error logs |
| Different image on iOS vs Android | Assets not generated | Run `dart run flutter_native_splash:create` |

## Debug Logs to Watch For

Look for these messages in your console:

```
✅ Expected logs:
🟡 OnboardingWrapper: build() called
🟡 OnboardingWrapper: Still loading - showing splash
🟡 OnboardingWrapper: Waiting for smooth transition
🎨 Native splash removed - app ready

❌ Problem logs:
❌ Failed to sync user to Supabase
⚠️ BLACK SCREEN/FLICKER
```

## Quick Debug Commands

```bash
# Check if splash assets were generated
ls android/app/src/main/res/drawable/
ls ios/Runner/Assets.xcassets/LaunchImage.imageset/

# Clean build (if splash not showing)
flutter clean
flutter pub get
dart run flutter_native_splash:create
flutter run

# Check for errors
flutter analyze
```

## Performance Check

Time your app load with a stopwatch:

| Timing | Expected | If Longer |
|--------|----------|-----------|
| Native splash appears | < 0.1s | Device issue |
| Flutter splash visible | 1.5-2.5s | Normal |
| Total to main screen | < 3s | Check Firebase/network |

## Next Steps

### 1. Monitor in Production
Add analytics to track load times:

```dart
// In OnboardingWrapper, after removing splash:
FirebaseAnalytics.instance.logEvent(
  name: 'app_ready',
  parameters: {
    'duration_ms': DateTime.now().difference(_startTime).inMilliseconds,
  },
);
```

### 2. Consider Skeleton Screens
For even better UX, replace long splash with skeleton loading:

```dart
// Instead of showing splash for 2+ seconds
if (userStateAsync.isLoading) {
  return const ChatGroupsSkeletonScreen(); // Shows app structure
}
```

### 3. Optimize Load Time
- Cache user data locally
- Lazy load non-critical features
- Use `firebase.initializeApp()` earlier
- Consider background sync

## Support

**Documentation:**
- `doc/splash_screen_setup.md` - Full setup guide
- `doc/splash_screen_flow.md` - Technical flow diagram

**Package Docs:**
- https://pub.dev/packages/flutter_native_splash

**High-End App Examples:**
- Instagram: Native → Flutter splash → Skeleton → Content
- Twitter: Native → Flutter splash → Progressive loading
- Spotify: Native → Flutter splash → Animated logo → Content
