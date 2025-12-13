# SquadSync Integration Tests

This directory contains integration tests for critical user flows in the SquadSync Flutter app.

## Test Coverage

### 1. Authentication Tests (`auth_test.dart`)
Tests Supabase authentication flows via AuthWrapper:
- ✅ Email/password sign-in
- ✅ Apple Sign-In (iOS)
- ✅ Sign-out flow
- ✅ Error handling (invalid credentials, network timeout)
- ✅ Session persistence across app restarts
- ✅ AuthWrapper redirects (authenticated vs unauthenticated)

### 2. Lobby Tests (`lobby_test.dart`)
Tests lobby join/leave with real-time Supabase updates:
- ✅ Join lobby via invite code
- ✅ Create lobby and receive real-time updates
- ✅ Leave lobby
- ✅ Real-time spot updates from other members
- ✅ Invalid invite code handling
- ✅ User lobby list updates
- 🔄 Edge cases: lobby deletion, network disconnection, concurrent spot claims

### 3. Chat Tests (`chat_test.dart`)
Tests chat messaging with Supabase streams and SQLite fallback:
- ✅ Send text message to chat group
- ✅ Receive messages via Supabase real-time stream
- ✅ Offline message caching to SQLite
- ✅ Message sync from SQLite to Supabase on reconnect
- ✅ Send image messages
- ✅ Typing indicators
- ✅ Delete and reply to messages
- 🔄 Edge cases: long messages, rapid sending, upload failures, SQLite errors

### 4. Game Selection Tests (`game_selection_test.dart`)
Tests onboarding game selection with IGDB integration:
- ✅ Complete onboarding flow
- ✅ Search games via IGDB API
- ✅ Offline fallback to local JSON
- ✅ Minimum game selection validation
- ✅ Game card information display
- ✅ Skip onboarding
- ✅ Update selections post-onboarding
- ✅ Empty search results handling
- 🔄 Edge cases: rate limiting, malformed data, long names, rapid queries

## Running Tests

### Prerequisites
```bash
# Ensure integration_test package is in dev_dependencies (already added)
flutter pub get

# Generate mocks
flutter pub run build_runner build --delete-conflicting-outputs
```

### Run All Integration Tests
```bash
flutter test integration_test
```

### Run Specific Test File
```bash
flutter test integration_test/auth_test.dart
flutter test integration_test/lobby_test.dart
flutter test integration_test/chat_test.dart
flutter test integration_test/game_selection_test.dart
```

### Run with Custom Driver
```bash
flutter test integration_test --driver=integration_test/test_driver.dart
```

### Run for Specific Platform
```bash
flutter test integration_test --platform chrome  # Web
flutter test integration_test -d <device-id>     # Mobile/Desktop
```

### Generate Test Report (JSON)
```bash
flutter test integration_test --machine > test_results.json
```

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Integration Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Generate mocks
        run: flutter pub run build_runner build --delete-conflicting-outputs
      
      - name: Run integration tests
        run: flutter test integration_test --machine > test_results.json
      
      - name: Upload test results
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: test_results.json
```

## Mocking Strategy

### Repository Pattern
Tests use Mockito to mock repository implementations:

```dart
@GenerateMocks([LobbyRepository, AuthServiceSupabase])
import 'lobby_test.mocks.dart';

// In test
final mockRepository = MockLobbyRepository();
when(mockRepository.joinLobby(any, any)).thenAnswer((_) async {});
```

### Provider Overrides
Riverpod providers are overridden with mocks:

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      lobbyRepositoryProvider.overrideWithValue(mockRepository),
    ],
    child: const app.MyApp(),
  ),
);
```

### Supabase Isolation
- Mock `AuthServiceSupabase` to simulate authentication
- Mock repository methods to avoid actual Supabase calls
- Use `Stream.value()` and `Stream.fromIterable()` for real-time updates

### SQLite Isolation
- Mock `SQLiteHelper` for offline cache tests
- Simulate database operations without actual file I/O

## Test Structure

### Arrange-Act-Assert Pattern
```dart
testWidgets('Description', (WidgetTester tester) async {
  // Arrange: Set up mocks and initial state
  when(mockRepository.method()).thenAnswer((_) async => result);
  
  // Act: Perform user actions
  await tester.tap(find.text('Button'));
  await tester.pumpAndSettle();
  
  // Assert: Verify expected outcomes
  expect(find.text('Expected'), findsOneWidget);
  verify(mockRepository.method()).called(1);
});
```

### Widget Testing Helpers
- `tester.pumpWidget()` - Build widget tree
- `tester.pumpAndSettle()` - Wait for animations to complete
- `find.text()`, `find.byIcon()`, `find.byType()` - Widget finders
- `tester.tap()`, `tester.enterText()` - User interactions

## Debugging Tests

### Enable Verbose Logging
```bash
flutter test integration_test --verbose
```

### Take Screenshots on Failure
```dart
await tester.takeException(); // Capture widget tree on error
```

### Print Widget Tree
```dart
debugDumpApp(); // Print entire widget tree
```

### Run Single Test
```dart
testWidgets('Specific test', (tester) async {
  // Test code
}, skip: false); // Remove skip to run only this test
```

## Known Issues & Limitations

1. **Platform-specific tests**: Apple Sign-In tests only run on iOS
2. **Network mocking**: Some tests may require network isolation tools
3. **Image picker**: Image selection tests may require platform channels setup
4. **Real Supabase**: Integration tests use mocks; see E2E tests for real backend

## Contributing

### Adding New Tests
1. Create test file in `integration_test/`
2. Import `integration_test/integration_test.dart`
3. Use `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`
4. Follow existing patterns (Arrange-Act-Assert)
5. Mock external dependencies (Supabase, SQLite, APIs)
6. Add to this README

### Test Guidelines
- ✅ Test user-facing flows, not implementation details
- ✅ Use descriptive test names
- ✅ Mock external services (Supabase, IGDB, etc.)
- ✅ Test both happy path and error cases
- ✅ Keep tests independent (no shared state)
- ❌ Don't test internal widget state
- ❌ Don't test third-party packages

## Related Documentation

- [Flutter Integration Testing](https://docs.flutter.dev/testing/integration-tests)
- [Mockito Documentation](https://pub.dev/packages/mockito)
- [Riverpod Testing Guide](https://riverpod.dev/docs/cookbooks/testing)
- [SquadSync Architecture](./.github/copilot-instructions.md)

## Test Maintenance

### Update Mocks After Model Changes
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Review Tests After Major Refactors
- [ ] Update test expectations after UI changes
- [ ] Regenerate mocks after repository changes
- [ ] Update test data after entity schema changes

### Performance Optimization
- Use `tester.pump()` instead of `pumpAndSettle()` where possible
- Avoid excessive waits with `Duration(seconds: X)`
- Mock heavy operations (image processing, network calls)

---

**Last Updated:** December 12, 2025  
**Test Framework:** `integration_test` + `mockito`  
**Coverage Target:** 80%+ for critical flows
