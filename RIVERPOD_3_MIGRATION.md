# Riverpod 3.0.3 Migration Guide

**Migration Date**: December 12, 2025  
**Version**: riverpod ^3.0.3, flutter_riverpod ^3.0.3  
**Status**: ⚠️ IN PROGRESS

## Overview

Migrated SquadSync from Riverpod 2.5.1 → 3.0.3. This introduces several breaking changes that require code updates.

## Package Updates

### Updated Dependencies

```yaml
# pubspec.yaml
riverpod: ^3.0.3                    # Was: ^2.5.1
flutter_riverpod: ^3.0.3            # Was: ^2.5.1
riverpod_annotation: ^3.0.3         # Was: ^2.5.1
riverpod_generator: ^3.0.3          # Was: ^2.5.1
freezed_annotation: ^3.0.0          # Was: ^2.4.4 (required for Riverpod 3.0)
freezed: ^3.0.0                     # Was: ^2.5.2 (required for Riverpod 3.0)
```

### Removed Dependencies

- `riverpod_test: ^0.1.9` - Not compatible with Riverpod 3.0 yet, use `ProviderContainer.test()` directly
- `twitch_api: ^0.7.0` - Blocked freezed 3.0 upgrade, unused (TwitchService uses direct API)

## Breaking Changes

### 1. Provider Instantiation Syntax

**BEFORE (Riverpod 2.x)**:
```dart
final userNotifierProvider =
    AutoDisposeAsyncNotifierProvider<UserNotifier, AppUser?>(
  () => UserNotifier(),
);
```

**AFTER (Riverpod 3.0)**:
```dart
final userNotifierProvider =
    AutoDisposeAsyncNotifierProvider<UserNotifier, AppUser?>.new(
  UserNotifier.new,
);
```

**Files Updated**: ✅
- [lib/core/injection.dart](lib/core/injection.dart)
- [lib/presentation/notifiers/lobby_notifier.dart](lib/presentation/notifiers/lobby_notifier.dart)
- [lib/presentation/notifiers/user_notifier.dart](lib/presentation/notifiers/user_notifier.dart)
- [lib/presentation/notifiers/game_notifier.dart](lib/presentation/notifiers/game_notifier.dart)
- [lib/presentation/notifiers/chat_notifier.dart](lib/presentation/notifiers/chat_notifier.dart)
- [lib/presentation/notifiers/system_notifier.dart](lib/presentation/notifiers/system_notifier.dart)
- [lib/presentation/notifiers/message_notifier.dart](lib/presentation/notifiers/message_notifier.dart)
- [lib/presentation/notifiers/media_notifier.dart](lib/presentation/notifiers/media_notifier.dart)
- [lib/presentation/notifiers/clip_notifier.dart](lib/presentation/notifiers/clip_notifier.dart)
- [lib/presentation/notifiers/game_state_notifier.dart](lib/presentation/notifiers/game_state_notifier.dart)
- [lib/presentation/notifiers/timer_management_notifier.dart](lib/presentation/notifiers/timer_management_notifier.dart)

### 2. StateNotifier → Notifier Migration

**Legacy `StateNotifier` is deprecated** in Riverpod 3.0. Migrate to `Notifier` or `AutoDisposeNotifier`.

**BEFORE (Riverpod 2.x with legacy import)**:
```dart
import 'package:riverpod/riverpod.dart';

class ChatStateNotifier extends StateNotifier<ChatUIState> {
  ChatStateNotifier() : super(ChatUIState.initial) {
    loadQuickReactionEmojis();
  }
  
  // ... methods
}

final chatStateProvider =
    StateNotifierProvider<ChatStateNotifier, ChatUIState>((ref) {
  return ChatStateNotifier();
});
```

**AFTER (Riverpod 3.0)**:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatStateNotifier extends AutoDisposeNotifier<ChatUIState> {
  @override
  ChatUIState build() {
    Future.microtask(() => loadQuickReactionEmojis());
    return ChatUIState.initial;
  }
  
  // ... methods (no changes)
}

final chatStateProvider =
    AutoDisposeNotifierProvider<ChatStateNotifier, ChatUIState>.new(
  ChatStateNotifier.new,
);
```

**Files Updated**: ✅
- [lib/chat/chat_state_notifier.dart](lib/chat/chat_state_notifier.dart)

**Key Changes**:
- Replace `StateNotifier<T>` → `AutoDisposeNotifier<T>` or `Notifier<T>`
- Replace constructor with `build()` method
- Use `Future.microtask()` for async initialization in build()
- Replace `StateNotifierProvider` → `AutoDisposeNotifierProvider` or `NotifierProvider`

### 3. AsyncValue.valueOrNull Removed

**BREAKING**: `AsyncValue.valueOrNull` no longer exists in Riverpod 3.0.

**BEFORE (Riverpod 2.x)**:
```dart
final currentState = state.valueOrNull;
if (currentState == null) return;
```

**AFTER (Riverpod 3.0)** - Option 1 (try-catch):
```dart
try {
  final currentState = state.value;  // Throws if loading/error
  // Use currentState
} catch (e) {
  // Handle loading/error case
  return;
}
```

**AFTER (Riverpod 3.0)** - Option 2 (pattern matching):
```dart
final currentState = state.when(
  data: (data) => data,
  loading: () => null,
  error: (_, __) => null,
);
if (currentState == null) return;
```

**AFTER (Riverpod 3.0)** - Option 3 (requireValue with fallback):
```dart
final currentState = state.hasValue 
    ? state.requireValue 
    : MyState.initial();
```

**Files Affected**: ⚠️ **35+ usages found**
- [lib/presentation/notifiers/lobby_notifier.dart](lib/presentation/notifiers/lobby_notifier.dart) - 7 usages
- [lib/presentation/notifiers/timer_management_notifier.dart](lib/presentation/notifiers/timer_management_notifier.dart) - 11 usages
- [lib/presentation/notifiers/game_state_notifier.dart](lib/presentation/notifiers/game_state_notifier.dart) - 15+ usages
- Plus many UI files

### 4. AsyncValue.value Error Handling

In Riverpod 3.0, `AsyncValue.value` **throws** if state is loading or error.

**BEFORE (Riverpod 2.x)**:
```dart
state = AsyncValue.data(
  state.value!.copyWith(currentGame: game),  // Null assertion
);
```

**AFTER (Riverpod 3.0)**:
```dart
state = AsyncValue.data(
  state.requireValue.copyWith(currentGame: game),  // Use requireValue
);
```

### 5. Ref Subclasses Removed

**BREAKING**: Typed `Ref` subclasses removed in Riverpod 3.0. All refs are now just `Ref`.

**BEFORE (Riverpod 2.x)**:
```dart
void myMethod(WidgetRef ref) { ... }  // Specific ref type
```

**AFTER (Riverpod 3.0)**:
```dart
void myMethod(Ref ref) { ... }  // Generic Ref only
```

**Impact**: Minimal - most code already uses generic `Ref`.

### 6. Notifier State Persistence

**NEW BEHAVIOR**: Notifiers are recreated on widget rebuild, potentially losing state.

**Solutions**:

#### Option A: Use `ref.keepAlive()`
```dart
@override
Future<MyState> build() async {
  ref.keepAlive();  // Prevent disposal on widget rebuild
  return await _loadState();
}
```

#### Option B: Persist state to storage
```dart
// Save to SQLite/SharedPreferences on state change
state = newState;
await _repository.saveState(newState);  // Persist
```

**Files Updated**: ⚠️ **TODO**
- Consider adding `ref.keepAlive()` to critical notifiers (LobbyNotifier, UserNotifier)

## Testing Updates

### riverpod_test Package Unavailable

Since `riverpod_test` isn't compatible with Riverpod 3.0 yet, use `ProviderContainer` directly:

**BEFORE (Riverpod 2.x with riverpod_test)**:
```dart
test('notifier test', () async {
  final container = createContainer();
  final notifier = container.read(myNotifierProvider.notifier);
  // ...
});
```

**AFTER (Riverpod 3.0 without riverpod_test)**:
```dart
test('notifier test', () async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  
  final notifier = container.read(myNotifierProvider.notifier);
  // ...
});
```

**Overriding Notifiers**:
```dart
final container = ProviderContainer(
  overrides: [
    myNotifierProvider.overrideWith((ref) => MockNotifier()),
  ],
);
```

## Migration Checklist

- [x] Update pubspec.yaml with Riverpod 3.0.3 packages
- [x] Update freezed to 3.0.0 for compatibility
- [x] Remove incompatible packages (riverpod_test, twitch_api)
- [x] Run `flutter pub get`
- [x] Run `dart run build_runner build --delete-conflicting-outputs`
- [x] Update provider instantiation syntax (`.new` constructor)
- [x] Migrate StateNotifier → Notifier/AutoDisposeNotifier
- [ ] **Replace all `valueOrNull` with Riverpod 3.0 patterns** (35+ usages)
- [ ] **Replace `state.value!` with `state.requireValue`** (many usages)
- [ ] Update test files to use ProviderContainer directly
- [ ] Add `ref.keepAlive()` to critical notifiers if needed
- [ ] Update UI consumers to handle AsyncValue properly
- [ ] Test all async flows (lobby, chat, user, game selection)
- [ ] Performance test with state recreation on rebuilds

## New Features in Riverpod 3.0

### Automatic Retry for Async Notifiers

```dart
@override
Future<MyState> build() async {
  ref.onDispose(() => print('Disposing'));
  
  // Riverpod 3.0 automatically retries on error
  return await _repository.loadState();
}

// Access retry in UI:
final state = ref.watch(myNotifierProvider);
if (state.hasError) {
  ref.invalidate(myNotifierProvider);  // Trigger retry
}
```

### Pause/Resume Providers

```dart
// Pause updates during offline mode
final chatNotifier = ref.read(chatNotifierProvider.notifier);
ref.listen(connectivityProvider, (previous, next) {
  if (next.isOffline) {
    ref.pause(chatNotifierProvider);  // Stop updates
  } else {
    ref.resume(chatNotifierProvider);  // Resume
  }
});
```

### Selective Rebuilds with `select()`

```dart
// Only rebuild when selectedLobbyId changes
final lobbyId = ref.watch(
  lobbyNotifierProvider.select((state) => state.value?.selectedLobbyId),
);
```

## Common Errors & Solutions

### Error: "The function 'AutoDisposeAsyncNotifierProvider' isn't defined"

**Cause**: Using old constructor syntax  
**Fix**: Use `.new` constructor syntax (see Breaking Change #1)

### Error: "Undefined name 'state'"

**Cause**: StateNotifier migrated to Notifier without updating methods  
**Fix**: Ensure `build()` method exists and returns state

### Error: "The getter 'valueOrNull' isn't defined"

**Cause**: Riverpod 3.0 removed `valueOrNull`  
**Fix**: Use `state.requireValue` or pattern matching (see Breaking Change #3)

### Error: "Classes can only extend other classes"

**Cause**: Importing wrong Riverpod package or old code gen  
**Fix**: 
1. Run `dart run build_runner clean`
2. Run `dart run build_runner build --delete-conflicting-outputs`
3. Ensure `import 'package:flutter_riverpod/flutter_riverpod.dart';`

## Related Documentation

- [Riverpod 3.0 Migration Guide](https://riverpod.dev/docs/migration/from_riverpod_2_to_3)
- [AsyncNotifier Documentation](https://riverpod.dev/docs/concepts/why_riverpod)
- [Testing with Riverpod 3.0](https://riverpod.dev/docs/cookbooks/testing)

## Status Summary

**Completed**:
- ✅ Package updates and dependency resolution
- ✅ Provider instantiation syntax migration
- ✅ StateNotifier → Notifier migration
- ✅ Supabase getClaims() API fixes

**In Progress**:
- ⚠️ Replacing `valueOrNull` with Riverpod 3.0 patterns (35+ files)
- ⚠️ Replacing `state.value!` with `state.requireValue`

**Pending**:
- ⏸️ Test file updates for ProviderContainer API
- ⏸️ Adding `ref.keepAlive()` to critical notifiers
- ⏸️ Performance testing with state recreation

## Next Steps

1. **Search and replace `valueOrNull`**: Use pattern `state.hasValue ? state.requireValue : FallbackState.initial()`
2. **Search and replace `state.value!`**: Use `state.requireValue` instead
3. **Update tests**: Remove riverpod_test imports, use ProviderContainer
4. **Test critical flows**: Lobby management, chat real-time, user auth
5. **Document new patterns**: Create code snippets for team reference
