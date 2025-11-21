# Null Safety Guide

This guide documents the null safety patterns and fixes implemented in SquadSync to prevent runtime null errors.

## Fixed Patterns

### ?? Defaults
Use the null-coalescing operator to provide default values for nullable types:
```dart
String displayName = user?.displayName ?? 'Unknown';
int count = data?.length ?? 0;
```

### ?. Safe Access
Use safe navigation to access properties on potentially null objects:
```dart
String? name = user?.profile?.name;
if (user?.isActive == true) { ... }
```

### Required Fields in Models
Ensure model classes have required fields to prevent null values:
```dart
class User {
  final String id; // Required, non-nullable
  final String? displayName; // Optional, nullable
  final int score; // Required, non-nullable

  User({
    required this.id,
    this.displayName,
    required this.score,
  });
}
```

## Safe Helpers

Use the safe helpers in `utils.dart` for common null safety operations:
- `safeString(String? input)`: Returns input ?? ''
- `safeList(List<String?>? list)`: Filters out nulls and returns List<String>

## Best Practices

- Always prefer non-nullable types when possible
- Use `late` for fields that are set after construction but before use
- Add assertions in debug mode for critical null checks
- Test with null values to ensure robustness