# SquadSync Test Suite

Comprehensive test coverage for the SquadSync Flutter application targeting 60%+ code coverage.

## Test Structure

### Unit Tests - Notifiers (`test/presentation/notifiers/`)

Tests for all 9 core Riverpod notifiers using `mockito` and `riverpod_test`:

1. **LobbyNotifier** (`lobby_notifier_test.dart`)
   - Initialization and state loading
   - Lobby selection and management
   - Spot claiming and releasing
   - Timer management (start, cancel)
   - Peacock queue operations
   - User lobbies tracking
   - Error handling

2. **GameNotifier** (`game_notifier_test.dart`)
   - Game initialization
   - Game search (with deduplication)
   - Game details fetching
   - Cache fallback handling
   - Available games and lobbies loading

3. **ChatNotifier** (`chat_notifier_test.dart`)
   - Chat initialization
   - Chat group selection and management
   - Chat groups loading and creation
   - Online users tracking
   - Different chat types (lobby, direct, group)
   - Error handling

4. **UserNotifier** (`user_notifier_test.dart`)
   - User profile loading
   - Display name and profile image updates
   - Pinned games management
   - Friends management (add, remove)
   - Notification settings
   - Block/unblock users
   - User groups management
   - State persistence and error recovery

5. **SystemNotifier** (`system_notifier_test.dart`)
   - System state initialization
   - Theme management (light, dark, system)
   - Analytics event tracking
   - Local and push notifications
   - Notification settings
   - User ban/unban management
   - Availability checking

6. **MessageNotifier** (`message_notifier_test.dart`)
   - Message initialization and streaming
   - Sending text and media messages
   - Optimistic UI updates
   - Message reactions (add, remove)
   - Typing indicators
   - Reply functionality
   - Message deletion
   - Message syncing
   - Real-time updates
   - State management per chat group

### Widget Tests (`test/presentation/widgets/`)

1. **ChatScreen** (`chat_screen_test.dart`)
   - Widget structure and layout
   - Message input and sending
   - Message display from stream
   - Different chat types support
   - User interactions (focus, scroll, menu)
   - Error handling
   - Lifecycle management
   - Accessibility

2. **OnboardingFlow** (`onboarding_flow_test.dart`)
   - Widget structure
   - Page navigation (swipe, skip, next)
   - Welcome page
   - Authentication page
   - Profile setup (display name, avatar)
   - Game selection
   - Completion flow
   - State management
   - UI elements (indicators, animations)
   - Accessibility
   - Error handling and validation

### Integration Tests (`test/integration/`)

1. **Message Sending Flow** (`message_sending_integration_test.dart`)
   - End-to-end text message sending
   - Multiple sequential messages
   - Message display in chat
   - Send failure handling
   - Media attachment sending
   - Typing indicators
   - Reply to messages
   - Input clearing after send
   - Auto-scroll to new messages

## Running Tests

### All Tests
```bash
flutter test
```

### Specific Test File
```bash
flutter test test/presentation/notifiers/lobby_notifier_test.dart
```

### With Coverage
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Integration Tests
```bash
flutter test integration_test/
```

## Test Patterns Used

### Mockito for Mocking
All repository and service dependencies are mocked using `@GenerateMocks` annotation:

```dart
@GenerateMocks([LobbyRepository, TimerServiceNotifier, AuthServiceSupabase])
import 'lobby_notifier_test.mocks.dart';
```

### Riverpod Container for Testing
Tests use `ProviderContainer` with overrides to inject mocks:

```dart
container = ProviderContainer(
  overrides: [
    lobbyRepositoryProvider.overrideWithValue(mockRepository),
    timerServiceProvider.overrideWith((ref) => mockTimerService),
  ],
);
```

### AsyncValue State Testing
Tests verify `AsyncLoading`, `AsyncData`, and `AsyncError` states:

```dart
test('should handle AsyncLoading state', () {
  final state = container.read(lobbyNotifierProvider);
  expect(state, isA<AsyncLoading>());
});
```

### Stream Testing
Message streams are tested using `StreamController` for controlled emissions:

```dart
final messagesController = StreamController<List<Map<String, dynamic>>>();
when(mockRepository.getMessagesStream(any, any))
    .thenAnswer((_) => messagesController.stream);
```

### Widget Testing with ProviderScope
Widget tests wrap widgets in `ProviderScope` for Riverpod integration:

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      chatRepositoryProvider.overrideWithValue(mockRepository),
    ],
    child: MaterialApp(home: ChatScreen(...)),
  ),
);
```

## Mock Files

Mock implementations are generated in `test/mocks/`:
- `mock_repositories.dart` - Central mock generation file

Generated `.mocks.dart` files are created by build_runner and should not be edited manually.

## Coverage Goals

- **Overall**: 60%+ code coverage
- **Notifiers**: 80%+ (core business logic)
- **Widgets**: 60%+ (UI components)
- **Integration**: Key user flows covered

## Key Testing Principles

1. **Mock External Dependencies**: All Firebase, Supabase, and network calls are mocked
2. **Test State Transitions**: Verify AsyncValue states (loading, data, error)
3. **Test Error Handling**: Ensure graceful error recovery
4. **Test User Interactions**: Simulate taps, swipes, and text input
5. **Test Real-time Updates**: Use StreamControllers for message/lobby updates
6. **Test Lifecycle**: Verify proper initialization and disposal
7. **Test Accessibility**: Check semantic labels and keyboard navigation

## Dependencies

Required test dependencies in `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.4
  riverpod_test: ^0.1.9
  build_runner: ^2.4.8
  integration_test:
    sdk: flutter
```

## Continuous Integration

Tests should be run in CI/CD pipeline:

```yaml
# Example GitHub Actions
- name: Run tests
  run: flutter test --coverage
  
- name: Check coverage
  run: |
    flutter test --coverage
    lcov --summary coverage/lcov.info
```

## Troubleshooting

### Mock Generation Fails
```bash
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### Tests Timeout
Increase timeout in test:
```dart
testWidgets('test name', (tester) async {
  // ...
}, timeout: const Timeout(Duration(minutes: 2)));
```

### Provider Not Found
Ensure all required providers are overridden in test ProviderScope.

### Async State Issues
Use `await tester.pumpAndSettle()` to wait for all animations and async operations.

## Next Steps

1. Add more edge case tests
2. Increase coverage for repository implementations
3. Add performance tests for large message lists
4. Add golden tests for UI consistency
5. Add E2E tests with Firebase emulator
