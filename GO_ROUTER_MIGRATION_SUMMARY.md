# Go Router Migration & Enhancements - Implementation Summary

## Overview
Migrated SquadSync from legacy Navigator to **go_router** for type-safe routing, enhanced deep links with universal links support, added search functionality, and implemented A/B testing with analytics tracking.

## ✅ Completed Tasks

### 1. Go Router Implementation
- **Added dependency**: `go_router: ^14.6.2` in `pubspec.yaml`
- **Created router config**: `lib/core/app_router.dart` with type-safe routes
- **Updated MaterialApp**: Migrated from `MaterialApp` to `MaterialApp.router` in `widgets/app_widgets.dart`
- **Deferred navigation**: All deep link navigation uses `WidgetsBinding.instance.addPostFrameCallback` to avoid `_debugLocked` assertion

### 2. Routing Configuration
All routes are now defined with type safety:

```dart
'/': ChatGroupsScreen (home)
'/setup': SetupScreen (auth)
'/squad': LobbyTabScreen (with optional params)
'/squad/:gameName': LobbyTabScreen (with path param)
'/chat': ChatGroupsScreen
'/profile': ProfileTab
'/clips': ClipsScreen
'/join': JoinLobbyScreen (with query param)
'/join/:code': JoinLobbyScreen (with path param)
```

#### Key Features:
- **Authentication guard**: Automatic redirect to `/setup` if not authenticated
- **404 handling**: Custom error page with "Go Home" button
- **Firebase Analytics integration**: Route observer tracks all navigation
- **Deep link handling**: Centralized in `DeepLinkRouter` class

### 3. Universal Links (iOS/Android/Web)

#### iOS Configuration
**File**: `ios/Runner/Runner.entitlements`
```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:lobbiesync.app</string>
    <string>applinks:www.lobbiesync.app</string>
</array>
```

**Required**: Host `apple-app-site-association` file at:
- `https://lobbiesync.app/.well-known/apple-app-site-association`

#### Android Configuration
**File**: `android/app/src/main/AndroidManifest.xml`
```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    
    <data android:scheme="https" />
    <data android:host="lobbiesync.app" />
    <data android:host="www.lobbiesync.app" />
    <data android:pathPrefix="/join/" />
    <data android:pathPrefix="/chat" />
    <data android:pathPrefix="/squad/" />
    <data android:pathPrefix="/clips" />
</intent-filter>
```

**Required**: Host `assetlinks.json` file at:
- `https://lobbiesync.app/.well-known/assetlinks.json`

#### Supported Deep Link Patterns
- `https://lobbiesync.app/chat` → Opens chat
- `https://lobbiesync.app/join/CODE` → Join lobby with code
- `https://lobbiesync.app/squad` → Squad tab
- `https://lobbiesync.app/clips` → Clips feed
- `codsquadapp://chat` → Custom scheme fallback
- `codsquadapp://join/CODE` → Custom scheme fallback

### 4. Search Bars

#### ClipsTab Search (`lib/lobbies_tab/widgets/clips_tab.dart`)
- **Search by**: Username or message text
- **Features**:
  - Real-time filtering as user types
  - Clear button when search active
  - "No results" empty state
  - Hides Clip of the Day when searching
  - Material 3 themed search field

#### ProfileTab Search (`lib/profile_tab.dart`)
- **Search by**: Game name
- **Features**:
  - Filters pinned games list
  - Real-time filtering
  - Clear button
  - "No games found" empty state
  - Maintains scroll position

### 5. A/B Testing with Analytics

#### Service Implementation
**File**: `lib/services/ab_testing_service.dart`

**Features**:
- Deterministic variant assignment (50/50 split based on user ID hash)
- Persistent variant storage (SharedPreferences)
- Firebase Analytics integration
- Performance tracking (route timing)
- Error tracking
- Engagement tracking (time on route)

**Events Tracked**:
- `ab_test_assigned`: Variant assignment
- `navigation_event`: Route navigation with variant
- `route_timing`: Navigation performance
- `routing_error`: Error events
- `route_engagement`: Time spent on route

#### Integration Points
- **Router provider**: `abTestingServiceProvider` in `app_router.dart`
- **Navigation tracking**: Automatic in redirect function
- **Analytics observer**: `FirebaseAnalyticsObserver` attached to router

#### Usage Example
```dart
final abTestService = await ABTestingService.initialize();
final variant = await abTestService.getVariant(userId, 'routing_experiment_v1');

// Track navigation
await abTestService.trackNavigation('/chat', method: 'deep_link');

// Track timing
final tracker = RoutePerformanceTracker(abTestService);
tracker.startTracking('/chat');
// ... navigation happens ...
await tracker.endTracking('/chat');
```

### 6. Deep Link Handling Updates

#### Changes in `main.dart`
- Simplified `_handleDeepLink` to use `DeepLinkRouter.handleDeepLink()`
- All navigation deferred with `addPostFrameCallback`
- Updated Siri shortcuts to use `context.go('/chat')`

#### Deep Link Router Class
**File**: `lib/core/app_router.dart`

**Features**:
- Centralized deep link handling logic
- Authentication/squad state checks
- Automatic navigation guards
- User feedback via SnackBars
- Support for all link formats (custom scheme + HTTPS)

## 📁 Files Created/Modified

### Created Files
1. `lib/core/app_router.dart` - Router configuration with A/B testing
2. `lib/services/ab_testing_service.dart` - A/B testing service
3. `doc/universal_links_setup.md` - Universal links deployment guide

### Modified Files
1. `pubspec.yaml` - Added go_router dependency
2. `lib/main.dart` - Updated imports, simplified deep link handling
3. `lib/widgets/app_widgets.dart` - Migrated to MaterialApp.router
4. `lib/lobbies_tab/widgets/clips_tab.dart` - Added search bar
5. `lib/profile_tab.dart` - Added game search bar
6. `ios/Runner/Runner.entitlements` - Added universal links domains
7. `android/app/src/main/AndroidManifest.xml` - Added App Links intent filter

## 🚀 Testing

### Local Testing
```bash
# iOS Simulator
xcrun simctl openurl booted "https://lobbiesync.app/join/ABC123"
xcrun simctl openurl booted "codsquadapp://chat"

# Android Emulator
adb shell am start -a android.intent.action.VIEW -d "https://lobbiesync.app/join/ABC123"
adb shell am start -a android.intent.action.VIEW -d "codsquadapp://chat"
```

### Search Functionality
1. **ClipsTab**: Type in search bar to filter by username or caption
2. **ProfileTab**: Type in search bar to filter pinned games by name

### A/B Testing
1. Check variant assignment in SharedPreferences
2. Navigate between routes and verify events in Firebase Analytics console
3. Compare metrics between variants A and B

## 📊 Analytics Dashboard Queries

### Variant Distribution
```
Event: ab_test_assigned
Group by: variant
```

### Navigation Performance
```
Event: route_timing
Metric: duration_ms
Group by: variant, route
```

### Error Rate
```
Event: routing_error
Group by: variant, route
```

### Engagement
```
Event: route_engagement
Metric: time_spent_seconds
Group by: variant, route
```

## 🔧 Production Deployment Checklist

### Universal Links Setup
- [ ] Upload `apple-app-site-association` to `https://lobbiesync.app/.well-known/`
- [ ] Upload `assetlinks.json` to `https://lobbiesync.app/.well-known/`
- [ ] Update Team ID in `apple-app-site-association`
- [ ] Generate and add SHA256 fingerprints for release keystore
- [ ] Verify files are accessible via HTTPS
- [ ] Test deep links on iOS device
- [ ] Test deep links on Android device

### A/B Testing
- [ ] Define experiment ID in production
- [ ] Set up Firebase Analytics dashboard
- [ ] Document success metrics (conversion rate, time to navigate, error rate)
- [ ] Plan experiment duration (recommend 2-4 weeks)
- [ ] Monitor variant balance (should be ~50/50)

### Router Migration
- [ ] Test all navigation flows manually
- [ ] Verify authentication guards work correctly
- [ ] Check 404 page handles invalid routes
- [ ] Test back button behavior
- [ ] Verify deep links work on all platforms

## 🎯 Key Benefits

1. **Type Safety**: No more string-based navigation errors
2. **Declarative Routing**: Routes defined in one place
3. **Better Deep Links**: Universal links work across platforms
4. **Enhanced Discovery**: Search bars improve content findability
5. **Data-Driven**: A/B testing enables evidence-based decisions
6. **Performance Tracking**: Built-in analytics for route timing
7. **Better UX**: Deferred navigation prevents UI glitches

## 📝 Notes

- Go router version installed: `14.8.1` (latest compatible with dependencies)
- All navigation uses type-safe methods (`context.go()`, `context.push()`)
- Legacy `Navigator.push()` calls still exist in some screens but can be migrated incrementally
- A/B testing is opt-in - service initializes but doesn't force variant assignment
- Search functionality is local-only (filters in-memory data)

## 🔍 Future Enhancements

1. **Server-side search**: Backend API for more powerful search
2. **Search history**: Save recent searches
3. **Advanced filters**: Filter clips by date, popularity, game
4. **Multi-variant A/B tests**: Test more than 2 variants
5. **Feature flags**: Toggle features for specific user segments
6. **Deep link previews**: Show preview cards for shared links
7. **Migration tracking**: Track users migrating from old navigation to new

## 📚 Documentation References

- [go_router documentation](https://pub.dev/packages/go_router)
- [Universal Links (iOS)](https://developer.apple.com/ios/universal-links/)
- [App Links (Android)](https://developer.android.com/training/app-links)
- [Firebase Analytics](https://firebase.google.com/docs/analytics)
- See `doc/universal_links_setup.md` for detailed setup guide
