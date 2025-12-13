# Go Router Quick Reference

## Navigation Methods

### Basic Navigation
```dart
// Navigate to route (replaces current route in history)
context.go('/chat');

// Navigate with path parameters
context.go('/squad/Warzone');

// Navigate with query parameters
context.go('/join?code=ABC123');

// Navigate with extra data
context.go('/squad', extra: {
  'gameName': 'Warzone',
  'lobbyId': '123',
  'game': gameData,
});

// Push route (adds to navigation stack)
context.push('/profile');

// Pop current route
context.pop();

// Replace current route
context.replace('/setup');
```

### Named Routes
```dart
// Navigate using named routes
context.goNamed('chat');
context.goNamed('squadWithGame', pathParameters: {'gameName': 'Warzone'});
context.goNamed('join', queryParameters: {'code': 'ABC123'});
context.pushNamed('profile');
```

## Route Definitions

### Current Routes
```dart
'/'          → ChatGroupsScreen (home, requires auth)
'/setup'     → SetupScreen (login/signup)
'/squad'     → LobbyTabScreen (optional extra: gameName, lobbyId, game, chatGroupId)
'/squad/:gameName' → LobbyTabScreen (path param + extra)
'/chat'      → ChatGroupsScreen
'/profile'   → ProfileTab
'/clips'     → ClipsScreen
'/join'      → JoinLobbyScreen (query param: code)
'/join/:code' → JoinLobbyScreen (path param)
```

## Deep Links

### Supported Patterns
```dart
// HTTPS Universal Links
'https://lobbiesync.app/chat'
'https://lobbiesync.app/join/ABC123'
'https://lobbiesync.app/squad'
'https://lobbiesync.app/clips'
'https://lobbiesync.app/profile'

// Custom Scheme (fallback)
'codsquadapp://chat'
'codsquadapp://join/ABC123'
'codsquadapp://squad'
```

### Handle Deep Links
```dart
// In build method or callback
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) {
    DeepLinkRouter.handleDeepLink(context, ref, deepLinkUrl);
  }
});
```

## A/B Testing

### Initialize Service
```dart
final abTestService = await ABTestingService.initialize();
```

### Get Variant
```dart
final variant = await abTestService.getVariant(userId, 'experiment_v1');
// Returns: 'variant_a' or 'variant_b'
```

### Track Events
```dart
// Track navigation
await abTestService.trackNavigation('/chat', method: 'deep_link');

// Track performance
await abTestService.trackRouteTiming('/chat', duration);

// Track errors
await abTestService.trackError('/chat', 'navigation_error', errorMsg);

// Track engagement
await abTestService.trackEngagement('/chat', timeSpent);
```

### Clear Experiment (testing only)
```dart
await abTestService.clearExperimentData();
```

## Search Functionality

### ClipsTab Search
```dart
// Search is built-in, just use the search bar in UI
// Filters by: username or message text
// Real-time filtering with clear button
```

### ProfileTab Search
```dart
// Search is built-in, just use the search bar in UI
// Filters by: game name
// Real-time filtering with clear button
```

## Authentication Guards

Routes automatically redirect based on auth state:
- **Not authenticated** → Redirect to `/setup`
- **Authenticated on `/setup`** → Redirect to `/`

## Error Handling

### 404 Page
Custom error page shown for invalid routes with "Go Home" button.

### Navigation Errors
Track with A/B testing service:
```dart
try {
  context.go('/some-route');
} catch (e) {
  await abTestService.trackError('/some-route', 'navigation_error', e.toString());
}
```

## Migration from Navigator

### Before (Navigator)
```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => ChatGroupsScreen(),
  ),
);
```

### After (GoRouter)
```dart
context.push('/chat');
// or
context.go('/chat');
```

### Before (Named Routes)
```dart
Navigator.of(context).pushNamed('/squad', arguments: gameName);
```

### After (GoRouter)
```dart
context.go('/squad', extra: {'gameName': gameName});
// or
context.goNamed('squadWithGame', pathParameters: {'gameName': gameName});
```

## Best Practices

1. **Always use context methods** (`context.go()`, `context.push()`)
2. **Defer navigation in callbacks** with `addPostFrameCallback`
3. **Check mounted** before navigation in async functions
4. **Use extra for complex data**, path/query params for simple values
5. **Track important navigations** for A/B testing
6. **Test deep links** on all platforms before production

## Testing

### Unit Tests
```dart
testWidgets('navigates to chat', (tester) async {
  await tester.pumpWidget(MyApp());
  
  // Navigate
  context.go('/chat');
  await tester.pumpAndSettle();
  
  // Verify
  expect(find.byType(ChatGroupsScreen), findsOneWidget);
});
```

### Deep Link Testing
```bash
# iOS
xcrun simctl openurl booted "https://lobbiesync.app/join/ABC123"

# Android
adb shell am start -a android.intent.action.VIEW -d "https://lobbiesync.app/join/ABC123"
```

## Common Patterns

### Conditional Navigation
```dart
if (user != null && squadId != null) {
  context.go('/chat');
} else {
  context.go('/setup');
}
```

### Navigation with Loading
```dart
setState(() => isLoading = true);
try {
  await someAsyncOperation();
  if (mounted) context.go('/success');
} finally {
  if (mounted) setState(() => isLoading = false);
}
```

### Back Button Override
```dart
WillPopScope(
  onWillPop: () async {
    context.go('/custom-back-route');
    return false; // Prevent default back
  },
  child: MyScreen(),
)
```

## Performance Tips

1. Use `context.go()` for route replacement (lighter than push)
2. Avoid deep navigation stacks - use `go()` for resets
3. Track route timing with A/B testing to identify bottlenecks
4. Lazy load route widgets when possible

## Troubleshooting

### Route not found (404)
- Check route definition in `app_router.dart`
- Verify path matches exactly (case-sensitive)
- Check for typos in route string

### Deep link not opening app
- Verify universal links files are hosted
- Check entitlements/manifest configuration
- Test with adb/xcrun commands first
- Verify HTTPS certificate is valid

### Navigation not working
- Check authentication state
- Verify `mounted` before navigation
- Use `addPostFrameCallback` for initialization navigation
- Check console for router debug logs

### A/B test not tracking
- Verify Firebase Analytics is initialized
- Check variant is assigned (not null)
- Ensure events are logged (check Analytics console)
- Wait up to 24 hours for data to appear
