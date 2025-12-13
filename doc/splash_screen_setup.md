# Professional Splash Screen Implementation

## Overview
This app now uses **flutter_native_splash** for a smooth, professional splash screen experience similar to high-end apps like Instagram, Twitter, and Spotify.

## How It Works

### 3-Stage Loading Process:

1. **Native Splash** (Instant)
   - Shows immediately when app is tapped
   - Displays while Flutter engine initializes
   - Managed by native platform (iOS/Android)

2. **Flutter Splash** (Data Loading)
   - Smooth transition from native splash
   - Shows while Firebase, Supabase, and app state loads
   - Matches native splash appearance

3. **Main App** (Ready)
   - Native splash removed when all data is loaded
   - Smooth fade-in to actual content

## Setup Instructions

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Generate Native Splash Screens
```bash
dart run flutter_native_splash:create
```

This command generates:
- iOS launch screen storyboard
- Android splash screen resources (including Android 12+)
- Web splash (if enabled)

### 3. Build & Test
```bash
# iOS
flutter run -d ios

# Android
flutter run -d android
```

## Configuration

### Current Setup (pubspec.yaml)
```yaml
flutter_native_splash:
  image: assets/images/splash.png
  color: "#000000"
  android_12:
    image: assets/images/splash.png
    color: "#000000"
  ios: true
  android: true
```

### Advanced Options
```yaml
flutter_native_splash:
  image: assets/images/splash.png
  color: "#000000"
  
  # Branding image (bottom logo)
  # image_dark: assets/images/splash_dark.png  # Dark mode support
  # branding: assets/images/branding.png        # Bottom branding
  
  # Android 12+ specific
  android_12:
    image: assets/images/splash.png
    color: "#000000"
    # icon_background_color: "#000000"  # Icon background
  
  # Platform toggles
  ios: true
  android: true
  web: false
  
  # Fullscreen (hides status bar)
  fullscreen: true
  
  # Info.plist modifications (iOS)
  ios_content_mode: scaleAspectFit
  
  # Android gravity
  android_gravity: center
```

## Best Practices from High-End Apps

### ✅ What We Implemented:
1. **Keep native splash visible** until app is ready
2. **Minimum display time** (1.5s) - prevents flickering
3. **Smooth transition** with delay before removing native splash
4. **Progressive loading** - Flutter splash while data loads
5. **Error handling** - Remove splash even on errors

### 🎯 Additional Optimizations You Could Add:

#### 1. Skeleton Screens (Like Facebook/LinkedIn)
Instead of showing splash for too long, show the app structure with loading placeholders:

```dart
// In OnboardingWrapper
if (userStateAsync.isLoading) {
  return const ChatGroupsSkeletonScreen(); // Shows gray boxes where content will be
}
```

#### 2. Fade Animation
Add smooth fade when removing splash:

```dart
FlutterNativeSplash.remove(
  onRemove: () {
    // Trigger fade animation
  }
);
```

#### 3. Dark Mode Support
Add dark mode splash:

```yaml
flutter_native_splash:
  image: assets/images/splash.png
  image_dark: assets/images/splash_dark.png
  color: "#000000"
  color_dark: "#1a1a1a"
```

## Troubleshooting

### Splash Not Showing?
```bash
# Regenerate splash screens
dart run flutter_native_splash:create

# Clean build
flutter clean
flutter pub get
flutter run
```

### Splash Stuck/Won't Dismiss?
- Check that `FlutterNativeSplash.remove()` is called
- Verify no exceptions in initialization code
- Check debug logs for "Native splash removed" message

### Different Image on iOS/Android?
- Ensure `splash.png` is properly sized (2732x2732 recommended)
- Regenerate: `dart run flutter_native_splash:create`

## Testing Checklist

- [ ] Cold start (app not in memory)
- [ ] Warm start (app in background)
- [ ] Hot restart (development)
- [ ] Network delays (slow connection)
- [ ] Auth errors
- [ ] Dark mode (if implemented)
- [ ] Android 12+ splash (branding area)
- [ ] iOS different device sizes

## Performance Metrics

### Target Times:
- **Native splash visible**: 500-1500ms
- **Total loading time**: < 3 seconds
- **Smooth transition**: No flicker or black screens

### Monitoring:
Add this to track loading performance:

```dart
final startTime = DateTime.now();

// After FlutterNativeSplash.remove()
final loadTime = DateTime.now().difference(startTime);
FirebaseAnalytics.instance.logEvent(
  name: 'app_load_time',
  parameters: {'duration_ms': loadTime.inMilliseconds},
);
```

## References

- [flutter_native_splash package](https://pub.dev/packages/flutter_native_splash)
- [iOS Launch Screen](https://developer.apple.com/design/human-interface-guidelines/ios/visual-design/launch-screen/)
- [Android Splash Screens](https://developer.android.com/develop/ui/views/launch/splash-screen)
- [Material Design: Launch screens](https://m3.material.io/styles/motion/transitions/transition-patterns#7e48ca86-90d4-4ee0-9862-8e6a0e4e90c8)
