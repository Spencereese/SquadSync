# Riverpod Code Generation Guide

This project now supports Riverpod code generation for improved performance and better development experience.

## Setup

The following dependencies have been added to enable code generation:

```yaml
dev_dependencies:
  riverpod_generator: ^2.4.0
  build_runner: ^2.4.8

dependencies:
  riverpod_annotation: ^2.5.1
```

## How to Use Code Generation

### 1. Create Providers with @riverpod

Instead of manually creating providers, use the `@riverpod` annotation:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'my_providers.g.dart';

@riverpod
String userDisplayName(UserDisplayNameRef ref) {
  final userManager = ref.watch(userManagerProvider);
  return userManager.displayName ?? 'Anonymous';
}

@riverpod
Future<List<String>> userGames(UserGamesRef ref) async {
  final userManager = ref.watch(userManagerProvider);
  return userManager.pinnedGames.map((game) => game['name'] as String).toList();
}

@riverpod
String gameStatus(GameStatusRef ref, String gameName) {
  // Parameterized provider (family)
  return 'Playing $gameName';
}
```

### 2. Generate Code

Run the code generation:

```bash
flutter pub run build_runner build
```

Or for watch mode (auto-regenerate on changes):

```bash
flutter pub run build_runner watch
```

### 3. Use Generated Providers

The generated providers are automatically created with the same name as your function:

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = ref.watch(userDisplayNameProvider);
    final gamesAsync = ref.watch(userGamesProvider);
    final gameStatus = ref.watch(gameStatusProvider('Call of Duty'));

    return Column(
      children: [
        Text('Hello, $displayName!'),
        gamesAsync.when(
          data: (games) => Text('Games: ${games.join(', ')}'),
          loading: () => CircularProgressIndicator(),
          error: (error, _) => Text('Error: $error'),
        ),
        Text(gameStatus),
      ],
    );
  }
}
```

## Benefits of Code Generation

1. **Better Performance**: Compile-time provider resolution eliminates runtime lookups
2. **Smaller Bundle Size**: Improved tree-shaking removes unused provider code
3. **Type Safety**: Compile-time guarantees that providers exist and are correctly typed
4. **IDE Support**: Better autocomplete, error detection, and refactoring support
5. **Maintainability**: Less boilerplate code to maintain

## Migration from Manual Providers

### Before (Manual Provider)
```dart
final userDisplayNameProvider = Provider<String>((ref) {
  final userManager = ref.watch(userManagerProvider);
  return userManager.displayName ?? 'Anonymous';
});
```

### After (Generated Provider)
```dart
@riverpod
String userDisplayName(UserDisplayNameRef ref) {
  final userManager = ref.watch(userManagerProvider);
  return userManager.displayName ?? 'Anonymous';
}
```

## Provider Types

### Simple Providers
```dart
@riverpod
String simpleValue(SimpleValueRef ref) => 'Hello World';
```

### Async Providers
```dart
@riverpod
Future<List<String>> asyncData(AsyncDataRef ref) async {
  return await fetchData();
}
```

### Family Providers (Parameterized)
```dart
@riverpod
String itemById(ItemByIdRef ref, String id) {
  return 'Item $id';
}
```

### State Providers
```dart
@riverpod
class Counter extends _$Counter {
  @override
  int build() => 0;

  void increment() => state++;
}
```

## Best Practices

1. **Use @riverpod for all new providers** - It provides better performance and DX
2. **Keep provider functions pure** - They should only depend on other providers
3. **Use meaningful names** - Generated provider names are based on function names
4. **Regenerate after changes** - Run `build_runner build` when you modify provider functions
5. **Watch mode for development** - Use `build_runner watch` during development

## Example Implementation

See `lib/widgets/generated_providers.dart` for a complete example of generated providers in action.