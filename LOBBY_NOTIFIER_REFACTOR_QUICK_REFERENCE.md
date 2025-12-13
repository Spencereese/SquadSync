# LobbyNotifier Refactoring - Quick Reference

## Three Notifiers Overview

| Notifier | Lines | Purpose | Key Methods |
|----------|-------|---------|-------------|
| **TimerManagementNotifier** | ~300 | Spot/peacock timers | `startSpotTimer`, `stopSpotTimer`, `processExpiredTimers` |
| **GameStateNotifier** | ~350 | Game selection & IGDB | `setCurrentGame`, `searchGames`, `getPopularGames` |
| **LobbyNotifier** (Core) | ~400 | Lobby coordination | `claimSpot`, `createLobby`, `joinLobby` |

---

## When to Use Which Notifier

### Use TimerManagementNotifier for:
- ✅ Starting/stopping spot timers
- ✅ Checking timer remaining time
- ✅ Processing expired timers
- ✅ Resetting game timers

### Use GameStateNotifier for:
- ✅ Setting current game
- ✅ Searching IGDB games
- ✅ Managing game history
- ✅ Muting/hiding games
- ✅ Offline game access

### Use LobbyNotifier for:
- ✅ Creating/joining/leaving lobbies
- ✅ Claiming/locking/removing spots
- ✅ Peacock queue management
- ✅ Member status updates
- ✅ Display name fetching

---

## Code Examples

### Timer Operations
```dart
// Start a spot timer (5 minutes)
final timerNotifier = ref.read(timerManagementNotifierProvider.notifier);
await timerNotifier.startSpotTimer(lobbyId, gameName, spotIndex, userId, Duration(minutes: 5));

// Check if timer is active
final hasTimer = ref.watch(hasActiveTimerProvider((gameName, userId)));

// Get remaining time
final remaining = ref.watch(spotTimerRemainingProvider((gameName, userId)));
```

### Game Selection
```dart
// Set current game
final gameNotifier = ref.read(gameStateNotifierProvider.notifier);
await gameNotifier.setCurrentGame(gameMap);

// Search for games
final games = await gameNotifier.searchGames('Call of Duty', limit: 10);

// Check if game is muted
final isMuted = ref.watch(isGameMutedProvider('Warzone'));

// Get current game
final currentGame = ref.watch(currentGameProvider);
```

### Lobby Operations
```dart
// Create a lobby
final lobbyNotifier = ref.read(lobbyNotifierProvider.notifier);
final lobbyId = await lobbyNotifier.createLobby(
  chatGroupId: groupId,
  gameName: 'Warzone',
  maxSpots: 8,
  isPublic: false,
);

// Claim a spot (delegates timer to TimerManagementNotifier)
await lobbyNotifier.claimSpot('Warzone', 0);

// Lock a spot (stops timer via TimerManagementNotifier)
await lobbyNotifier.lockSpot('Warzone', 0);
```

---

## Provider Cheat Sheet

### Timer Providers
```dart
// Main notifier
timerManagementNotifierProvider

// Convenience providers
spotTimerRemainingProvider((gameName, userId))
hasActiveTimerProvider((gameName, userId))
```

### Game Providers
```dart
// Main notifier
gameStateNotifierProvider

// Convenience providers
currentGameProvider
isGameMutedProvider(gameName)
gameHistoryProvider
```

### Lobby Providers (Unchanged)
```dart
// Main notifier
lobbyNotifierProvider

// Compatibility providers (still work!)
currentLobbyIdProvider
currentLobbyProvider
```

---

## State Access Patterns

### Efficient Watching (Prevents Unnecessary Rebuilds)
```dart
// ❌ Bad - Rebuilds on any LobbyState change
final lobbyState = ref.watch(lobbyNotifierProvider);

// ✅ Good - Rebuilds only when currentGame changes
final currentGame = ref.watch(currentGameProvider);

// ✅ Good - Rebuilds only for specific timer
final timerRemaining = ref.watch(spotTimerRemainingProvider((game, uid)));
```

### Reading Without Watching
```dart
// Use .notifier.method() for actions
final lobbyNotifier = ref.read(lobbyNotifierProvider.notifier);
await lobbyNotifier.claimSpot(gameName, spotIndex);

// Use .read() for one-time value access
final timerNotifier = ref.read(timerManagementNotifierProvider.notifier);
final remaining = timerNotifier.getSpotTimerRemaining(gameName, userId);
```

---

## Common Workflows

### Claiming a Spot (Full Flow)
```dart
// 1. Claim spot via LobbyNotifier
await ref.read(lobbyNotifierProvider.notifier).claimSpot(gameName, spotIndex);

// 2. LobbyNotifier internally calls:
//    - _repository.assignSpot() (updates Supabase)
//    - timerNotifier.startSpotTimer() (starts 5min timer)
//    - NotificationService.sendNotificationToUsers() (notifies members)

// 3. UI updates automatically via:
//    - LobbyState.gameLobbySpots (spot assignment)
//    - TimerManagementState.spotTimerStates (timer countdown)
```

### Locking a Spot (Full Flow)
```dart
// 1. Lock spot via LobbyNotifier
await ref.read(lobbyNotifierProvider.notifier).lockSpot(gameName, spotIndex);

// 2. LobbyNotifier internally calls:
//    - timerNotifier.stopSpotTimer() (cancels timer)
//    - _repository.updateMemberStatus() (sets "Ready")

// 3. UI updates automatically via:
//    - LobbyState.gameStatuses (status change)
//    - TimerManagementState.spotTimerStates (timer removed)
```

---

## Migration Checklist

- [x] TimerManagementNotifier created
- [x] GameStateNotifier created
- [x] LobbyNotifier refactored to delegate
- [x] Freezed models generated (`build_runner build`)
- [x] Test stubs created (3 files)
- [x] No breaking changes to consumers
- [ ] Implement full test coverage
- [ ] Monitor performance with Riverpod Inspector
- [ ] Add integration tests for full workflows

---

## Debugging Tips

### Check Timer State
```dart
final timerState = ref.watch(timerManagementNotifierProvider);
timerState.whenData((state) {
  debugPrint('Spot timers: ${state.spotTimerStates}');
  debugPrint('Peacock timers: ${state.peacockTimerStates}');
});
```

### Check Game State
```dart
final gameState = ref.watch(gameStateNotifierProvider);
gameState.whenData((state) {
  debugPrint('Current game: ${state.currentGame}');
  debugPrint('Muted games: ${state.mutedGames}');
});
```

### Check Lobby State
```dart
final lobbyState = ref.watch(lobbyNotifierProvider);
lobbyState.whenData((state) {
  debugPrint('Selected lobby: ${state.selectedLobbyId}');
  debugPrint('Peacock queue: ${state.peacockQueue}');
});
```

---

## Performance Tips

1. **Use family providers** for granular subscriptions
2. **Use .select()** to watch specific fields
3. **Avoid .watch()** in async operations (use .read())
4. **Batch state updates** in notifiers
5. **Use AutoDispose** for short-lived screens

---

## Common Errors & Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| "Provider was disposed" | Screen popped while async op running | Check `mounted` before setState |
| "Timer not found" | Timer key mismatch | Verify `spot_${gameName}_${userId}` format |
| "Game not set" | currentGame is null | Check if game was set via setCurrentGame() |
| "Notifier not initialized" | Watching before build() completes | Use AsyncValue.when() to handle loading |

---

## Related Files

- **Notifiers:** `lib/presentation/notifiers/`
- **Entities:** `lib/domain/entities/lobby_state.dart`
- **Repository:** `lib/domain/repositories/lobby_repository.dart`
- **Tests:** `test/timer_management_notifier_test.dart`, etc.
- **Summary:** `LOBBY_NOTIFIER_REFACTOR_SUMMARY.md`
