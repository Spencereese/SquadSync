# SquadSync Changelog

## Recent Updates

### Timer System Refactoring
- **TimerState Refactored**: Converted `TimerState` from `ChangeNotifier` to `StateNotifier<Map<String, Duration>>` for better Riverpod integration.
- **TimerService Singleton**: Implemented `TimerService` as a singleton with a single periodic `Timer` (5-second intervals) to manage all timers efficiently.
- **Firebase Integration**: Added server-side timer processing via Firebase Cloud Functions (`processTimers` callable) for offline sync and background handling.
- **Provider Updates**: Updated `timerStateProvider` to `StateNotifierProvider` injecting `TimerService`.
- **UI Enhancements**:
  - Updated `SpotTimerDisplay` and `PeacockTimerDisplay` widgets to use `StreamBuilder` for reactive timer updates.
  - Replaced text countdowns with `LinearProgressIndicator` for visual progress bars.
  - Added haptic feedback (`HapticFeedback.lightImpact()`) on timer expiration.
  - Ensured theme compatibility with `Theme.of(context).colorScheme.surfaceContainerHighest`.
- **Code Fixes**:
  - Fixed compilation errors from missing `timerService` parameters.
  - Removed outdated listener calls in `SquadState`.
  - Updated deprecated APIs: `withOpacity` to `withValues`, `surfaceVariant` to `surfaceContainerHighest`.
  - Added `stopAllTimers()` method to `TimerService` for cleanup.

### Unit Tests
- Added comprehensive unit tests in `test/timer_service_test.dart` using `flutter_test`:
  - Timer start and remaining time decrease verification.
  - Expiration callback firing.
  - Timer stopping mid-way.
  - Error handling for non-existent keys.
  - Stream emissions on changes.
- Used `TestWidgetsFlutterBinding` for async test support.
- Tests account for real-time execution with approximate checks for timing.

### Architecture Improvements
- **Hybrid Storage**: Maintained Firestore for real-time chat and SQLite for offline caching.
- **State Management**: Enhanced Provider pattern with focused manager classes (e.g., `SquadManager`, `PeacockManager`).
- **UID-Based System**: Consistent use of Firebase UIDs for user identification with display name caching.
- **Performance Optimizations**: Reduced per-second `notifyListeners` calls by using periodic updates and streams.

### Development Workflow
- **Building & Running**: Flutter app with Firebase emulator support.
- **Testing**: Unit tests for timer logic, integration tests for UI components.
- **Deployment**: Firebase Cloud Functions for server-side timers (critical for background processing).

### Key Files Modified
- `lib/services/timer_service.dart`: Singleton implementation with periodic timer and Firebase integration.
- `lib/managers/timer_state.dart`: StateNotifier for timer state management.
- `lib/providers.dart`: Updated providers for TimerService and TimerState.
- `lib/squad_tab/spot_widgets.dart`: Added `SpotTimerDisplay` with progress bar and haptic feedback.
- `lib/squad_tab/peacock_widgets.dart`: Added `PeacockTimerDisplay` similarly.
- `lib/squad_state.dart`: Removed outdated listeners.
- `test/timer_service_test.dart`: New unit tests for TimerService.

### Dependencies
- Flutter Riverpod for state management.
- Firebase Core, Firestore, Functions for backend integration.
- Fake Async for testing (though real-time tests were used for accuracy).

### Known Issues & Future Improvements
- Timer tests have minor timing sensitivities; consider using a testable clock for deterministic testing.
- Ensure Firebase Cloud Functions are deployed for timer functionality in production.
- Monitor UI performance with stream updates; add caching if needed.

This update improves timer efficiency, UI responsiveness, and code maintainability while maintaining backward compatibility.