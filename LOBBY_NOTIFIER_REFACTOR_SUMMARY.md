# LobbyNotifier Refactoring Summary

## Overview
Successfully refactored the oversized LobbyNotifier (1,013 lines) into three focused notifiers to improve maintainability, testability, and separation of concerns.

## Architecture Changes

### 1. TimerManagementNotifier (~300 lines)
**File:** `lib/presentation/notifiers/timer_management_notifier.dart`

**Responsibilities:**
- Spot timer orchestration (claim timers, expiration)
- Peacock queue timer management
- Timer persistence via LobbyRepository
- Real-time timer state subscriptions from Supabase
- Client-side timer processing coordination with server-side pg_cron

**Key Features:**
- `TimerManagementState` with Freezed immutability
- `startSpotTimer()` - Initiates 5-minute claim timers
- `stopSpotTimer()` - Cancels active timers
- `processExpiredTimers()` - Hybrid client-server timer processing
- `resetTimersForGame()` - Bulk timer cleanup
- Real-time subscriptions: `subscribeToLobbyTimers()`, `subscribeToPeacockTimers()`

**Providers:**
- `timerManagementNotifierProvider` - Main AutoDisposeAsyncNotifier
- `spotTimerRemainingProvider` - Family provider for timer countdown
- `hasActiveTimerProvider` - Boolean checker for active timers

### 2. GameStateNotifier (~350 lines)
**File:** `lib/presentation/notifiers/game_state_notifier.dart`

**Responsibilities:**
- Current game selection and tracking
- IGDB API integration (search, popular games, game details)
- Game history management (last 20 played)
- Offline support (cached games, local JSON fallback)
- Game preferences (mute, hide, preferred modes)
- Integration with DiscoveryNotifier for filters/popular games

**Key Features:**
- `GameSelectionState` with Freezed immutability
- `setCurrentGame()` - Updates current game across both notifiers
- `searchGames()` - IGDB search with offline fallback
- `getPopularGames()` - Trending games from IGDB
- `muteGame()` / `hideGame()` - User preferences
- `getCachedGames()` / `getOfflineGames()` - Offline-first support

**Providers:**
- `gameStateNotifierProvider` - Main AutoDisposeAsyncNotifier
- `currentGameProvider` - Convenience provider for current game
- `isGameMutedProvider` - Family provider for mute status
- `gameHistoryProvider` - Recent games list

### 3. Refactored LobbyNotifier (Core ~400 lines)
**File:** `lib/presentation/notifiers/lobby_notifier.dart` (updated)

**Retained Responsibilities:**
- Lobby coordination (create, join, leave)
- Spot management (claim, lock, remove)
- Member status tracking
- Peacock queue handling
- Current lobby real-time subscriptions
- User lobby memberships tracking
- Display name caching

**Delegated to Other Notifiers:**
- Timer operations → `TimerManagementNotifier`
- Game selection → `GameStateNotifier`

**Key Integration Points:**
```dart
// Timer delegation
final timerNotifier = ref.read(timerManagementNotifierProvider.notifier);
await timerNotifier.startSpotTimer(...);

// Game state sync
final gameStateNotifier = ref.read(gameStateNotifierProvider.notifier);
await gameStateNotifier.setCurrentGame(game);
```

## Migration Guide for Consumers

### No Breaking Changes
Existing consumers of `lobbyNotifierProvider` require **no updates** because:
- Provider name remains the same
- Public API methods unchanged
- LobbyState structure preserved
- Compatibility providers maintained

### Optional: Use New Providers Directly

**Timer-related UI:**
```dart
// Before
final timerState = ref.watch(lobbyNotifierProvider.select(
  (state) => state.value?.spotTimerStates
));

// After (more efficient)
final timerRemaining = ref.watch(spotTimerRemainingProvider((gameName, userId)));
final hasActiveTimer = ref.watch(hasActiveTimerProvider((gameName, userId)));
```

**Game selection UI:**
```dart
// Before
final currentGame = ref.watch(lobbyNotifierProvider.select(
  (state) => state.value?.currentGame
));

// After (more efficient)
final currentGame = ref.watch(currentGameProvider);
final isMuted = ref.watch(isGameMutedProvider(gameName));
```

## Testing

### Test Stubs Created
1. `test/timer_management_notifier_test.dart` - 10+ test cases
2. `test/game_state_notifier_test.dart` - 12+ test cases  
3. `test/lobby_notifier_test.dart` - 15+ test cases

### Test Coverage Areas
- Spot timer lifecycle (start, stop, expire)
- Game search and selection
- Lobby creation with notifications
- Real-time subscription handling
- Error handling and edge cases
- Offline-first patterns

### Running Tests
```bash
# Generate mocks
flutter pub run build_runner build

# Run all tests
flutter test

# Run specific notifier tests
flutter test test/timer_management_notifier_test.dart
flutter test test/game_state_notifier_test.dart
flutter test test/lobby_notifier_test.dart
```

## Benefits

### Maintainability
- **Smaller files:** Each notifier ~300-400 lines vs original 1,013 lines
- **Single responsibility:** Clear separation of concerns
- **Easier debugging:** Isolated state changes per notifier

### Testability
- **Focused tests:** Each notifier tested independently
- **Mockable dependencies:** Clean DI via Riverpod providers
- **Faster test execution:** Smaller surface area per test suite

### Performance
- **Selective rebuilds:** Consumers watch only needed state
- **Reduced re-renders:** Family providers for granular subscriptions
- **Optimized queries:** Direct access to specialized notifiers

### Developer Experience
- **Clear ownership:** Timer logic in TimerManagementNotifier, game logic in GameStateNotifier
- **Discoverability:** IDE autocomplete shows focused APIs
- **Onboarding:** New developers see organized architecture

## Real-time Supabase Streams Maintained

### Current Lobby Stream
```dart
_repository.getLobbyStream(lobbyId).listen((lobby) {
  // Updates currentLobby in LobbyState
});
```

### User Lobbies Stream
```dart
_repository.getUserLobbiesStream(userId).listen((lobbies) {
  // Updates userLobbies, userLobbyIds, memberDisplayNames
});
```

### Timer State Streams
```dart
_repository.getSpotTimerStates(lobbyId).listen((timers) {
  // Updates spotTimerStates in TimerManagementState
});
```

## SQLite Offline Cache

- **Timer persistence:** LobbyLocalDataSource handles SQLite timer storage
- **Offline-first pattern:** Repository layer abstracts local/remote data
- **OfflineFirstMixin:** Retained in LobbyNotifier for connectivity handling

## Server-Side Timer Processing

**No changes required** - Supabase pg_cron runs automatically:
- `process_expired_timers()` every 30 seconds
- `process_expired_queue()` every 30 seconds
- Client-side `processExpiredTimers()` triggers on-demand checks

## Next Steps

1. **Implement test cases** - Fill in TODOs in test stubs
2. **Monitor performance** - Track rebuild counts with Riverpod Inspector
3. **Optimize selectors** - Add more family providers for granular UI updates
4. **Document workflows** - Add sequence diagrams for spot claiming, timer expiration
5. **Consider extraction** - If LobbyNotifier grows again, extract peacock queue logic

## Files Modified

### Created
- `lib/presentation/notifiers/timer_management_notifier.dart`
- `lib/presentation/notifiers/game_state_notifier.dart`
- `test/timer_management_notifier_test.dart`
- `test/game_state_notifier_test.dart`
- `test/lobby_notifier_test.dart`

### Modified
- `lib/presentation/notifiers/lobby_notifier.dart` (refactored to delegate)

### Unchanged
- `lib/screens/lobby_tab_screen.dart` (consumers)
- `lib/lobbies_tab/*.dart` (UI components)
- `lib/domain/entities/lobby_state.dart` (state structure)
- `lib/domain/repositories/lobby_repository.dart` (repository interface)

## Compatibility

- ✅ No breaking changes to existing UI code
- ✅ LobbyState structure preserved
- ✅ All provider names backward compatible
- ✅ Offline-first patterns maintained
- ✅ Real-time subscriptions preserved
- ✅ Server-side timers unaffected

## Rollback Plan

If issues arise:
1. Revert `lobby_notifier.dart` to pre-refactor version
2. Remove new notifier files (timer_management_notifier, game_state_notifier)
3. Run `flutter pub run build_runner build --delete-conflicting-outputs`
4. Hot restart app

Original file preserved in git history: commit before this refactor.
