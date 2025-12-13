# Error Handling Service - Quick Reference

**Last Updated**: December 12, 2025  
**Location**: `lib/services/error_handling_service.dart`  
**Status**: ✅ Production Ready

## Overview

Centralized error handling service for SquadSync providing:
- 🎯 User-facing error messages via SnackBar
- 📊 Firebase Analytics error tracking
- 🔄 Automatic retry logic for transient failures
- ⚡ Performance monitoring (>500ms operations logged)
- 📝 Comprehensive logging with Logger package

## Architecture Integration

```
┌────────────────────────────────────────────────────────────┐
│                   Presentation Layer                       │
│  Notifiers (LobbyNotifier, ChatNotifier, UserNotifier)    │
│         ↓ inject via GetIt                                │
│  ErrorHandlingService (singleton)                          │
│         ↓ logs to                                          │
│  Firebase Analytics + Logger                               │
└────────────────────────────────────────────────────────────┘
```

## Setup (Already Complete)

1. **Service Registered in GetIt**: `lib/core/injection.dart`
2. **Provider Available**: `errorHandlingServiceProvider`
3. **Integrated in Notifiers**: LobbyNotifier, ChatNotifier, UserNotifier

## Usage Patterns

### 1. Basic Error Handling

```dart
// In notifiers - inject via GetIt
class MyNotifier extends AsyncNotifier<MyState> {
  late final ErrorHandlingService _errorHandler;
  
  @override
  Future<MyState> build() async {
    _errorHandler = ref.read(errorHandlingServiceProvider);
    return MyState.initial();
  }
  
  Future<void> someOperation() async {
    try {
      await riskyOperation();
    } catch (e, stackTrace) {
      await _errorHandler.handleError(
        context: context, // Optional: for SnackBar
        error: e,
        operation: 'someOperation',
        stackTrace: stackTrace,
      );
    }
  }
}
```

### 2. With Automatic Retry

```dart
// Automatically retries transient failures (network, timeout, 5xx)
final result = await _errorHandler.withRetry(
  operation: () async => await fetchData(),
  operationName: 'fetchData',
  maxAttempts: 3, // Default: 3
);
```

### 3. With Performance Monitoring

```dart
// Logs slow operations (>500ms) to Firebase Analytics
final result = await _errorHandler.withPerformanceMonitoring(
  operation: () async => await expensiveOperation(),
  operationName: 'loadGameData',
  slowThreshold: const Duration(milliseconds: 500),
);
```

### 4. Complete Integration (Recommended)

```dart
// Combines retry + performance monitoring + error handling
final result = await _errorHandler.withRetryAndMonitoring(
  operation: () async => await criticalOperation(),
  operationName: 'fetchCriticalData',
  context: context, // For user feedback
  maxAttempts: 3,
  slowThreshold: const Duration(milliseconds: 500),
);
```

## Error Handling Features

### User-Friendly Messages

Automatically converts technical errors to user-friendly messages:

| Technical Error | User Message |
|----------------|--------------|
| SocketException, network | "Network connection issue. Please check your internet connection." |
| TimeoutException | "Request timed out. Please try again." |
| 401, 403, auth | "Authentication error. Please sign in again." |
| Permission denied | "You don't have permission to perform this action." |
| 404, not found | "The requested resource was not found." |
| 500, 502, 503 | "Server error. Please try again later." |
| Supabase errors | "Database operation failed. Please try again." |
| Default | "An error occurred. Please try again." |

### Retryable Errors

Automatically retries these error types:
- Network errors (socket, connection reset)
- Timeouts
- Rate limiting (429)
- Server errors (500, 502, 503, 504)

**Does NOT retry**:
- Client errors (400, 401, 403, 404)
- Permission errors
- Validation errors

### Analytics Events Logged

1. **Error Events**:
   ```dart
   {
     'error_type': 'Exception',
     'error_message': 'Truncated message (100 chars)',
     'operation': 'operationName',
     'timestamp': '2025-12-12T10:30:00Z'
   }
   ```

2. **Slow Operation Events**:
   ```dart
   {
     'operation': 'loadGameData',
     'duration_ms': 750,
     'threshold_ms': 500,
     'timestamp': '2025-12-12T10:30:00Z'
   }
   ```

## Real-World Examples

### LobbyNotifier Integration

```dart
// lib/presentation/notifiers/lobby_notifier.dart
class LobbyNotifier extends AsyncNotifier<LobbyState> {
  late final ErrorHandlingService _errorHandler;
  
  @override
  Future<LobbyState> build() async {
    _errorHandler = ref.read(errorHandlingServiceProvider);
    return await _loadState();
  }
  
  Future<LobbyState> _loadState() async {
    try {
      // Load with retry and performance monitoring
      return await _errorHandler.withRetryAndMonitoring(
        operation: () => _repository.loadLobbyState(),
        operationName: 'loadLobbyState',
        maxAttempts: 2,
        slowThreshold: const Duration(milliseconds: 500),
      );
    } catch (e, stackTrace) {
      await _errorHandler.handleError(
        error: e,
        operation: 'loadLobbyState',
        stackTrace: stackTrace,
        showSnackBar: false, // Don't show on initial load
      );
      return LobbyState.initial();
    }
  }
}
```

### Repository Pattern

```dart
// In repository implementations
class UserRepositoryImpl implements UserRepository {
  final ErrorHandlingService _errorHandler = getIt<ErrorHandlingService>();
  
  @override
  Future<AppUser?> getCurrentUser() async {
    return await _errorHandler.withRetryAndMonitoring(
      operation: () async {
        final user = await _remoteDataSource.getCurrentUser();
        await _localDataSource.cacheUser(user); // Cache for offline
        return user;
      },
      operationName: 'getCurrentUser',
    );
  }
}
```

## Best Practices

### ✅ DO

- Always provide `operation` name for analytics tracking
- Use `withRetryAndMonitoring` for critical operations
- Pass `context` when available for user feedback
- Include `stackTrace` in error handling
- Set `showSnackBar: false` for background operations
- Use performance monitoring for expensive operations (>500ms)

### ❌ DON'T

- Don't retry non-retryable errors (permission, validation)
- Don't show SnackBar for every error (avoid spam)
- Don't block UI with retry logic on non-critical operations
- Don't log sensitive data in error messages
- Don't use for expected business logic (e.g., user not found)

## Configuration

### Retry Configuration

```dart
final result = await _errorHandler.withRetry(
  operation: () => myOperation(),
  operationName: 'myOperation',
  maxAttempts: 3,              // Default: 3
  initialDelay: Duration(seconds: 1), // Default: 1s
);
```

Retry uses exponential backoff:
- Attempt 1: 1s delay
- Attempt 2: ~2s delay (with 25% randomization)
- Attempt 3: ~4s delay
- Max delay: 10s

### Performance Thresholds

```dart
final result = await _errorHandler.withPerformanceMonitoring(
  operation: () => myOperation(),
  operationName: 'myOperation',
  slowThreshold: const Duration(milliseconds: 500), // Default: 500ms
);
```

## Logging

Uses `logger` package with pretty formatting:

```
[I] 10:30:00.123 | UserNotifier: Loading user profile...
[W] 10:30:00.750 | Slow operation detected: loadGameData took 750ms
[E] 10:30:01.000 | Error in fetchData: SocketException: Network unreachable
```

**Log Levels**:
- `_logger.e()`: Errors with full stack trace
- `_logger.w()`: Warnings (slow ops, retries)
- `_logger.i()`: Info (not used in service, use in notifiers)

## Testing

### Mock ErrorHandlingService

```dart
class MockErrorHandlingService extends Mock implements ErrorHandlingService {}

// In tests
final mockErrorHandler = MockErrorHandlingService();
getIt.registerSingleton<ErrorHandlingService>(mockErrorHandler);

when(mockErrorHandler.handleError(
  error: any,
  operation: 'testOperation',
)).thenAnswer((_) async {});
```

### Test Retry Logic

```dart
test('retries transient failures', () async {
  int attempts = 0;
  final result = await errorHandler.withRetry(
    operation: () async {
      attempts++;
      if (attempts < 3) throw SocketException('Network error');
      return 'success';
    },
    operationName: 'testRetry',
  );
  
  expect(result, 'success');
  expect(attempts, 3);
});
```

## Migration Guide

### Before (Old Pattern)

```dart
try {
  await operation();
} catch (e) {
  debugPrint('Error: $e');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('An error occurred')),
  );
}
```

### After (New Pattern)

```dart
try {
  await _errorHandler.withRetryAndMonitoring(
    operation: () => operation(),
    operationName: 'myOperation',
    context: context,
  );
} catch (e, stackTrace) {
  await _errorHandler.handleError(
    context: context,
    error: e,
    operation: 'myOperation',
    stackTrace: stackTrace,
  );
}
```

## Monitoring

### Firebase Analytics Dashboard

Track error patterns:
1. Navigate to Firebase Console → Analytics → Events
2. Filter by `error_occurred` and `slow_operation` events
3. Group by `error_type`, `operation`, or `error_message`

### Key Metrics

- **Error Rate**: Total `error_occurred` events / Total operations
- **Retry Success Rate**: Successful retries / Total retry attempts
- **Slow Operations**: Count of `slow_operation` events by operation name
- **Common Errors**: Group `error_type` to identify patterns

## Troubleshooting

### SnackBar Not Showing

- Ensure `context` is passed and mounted: `if (context.mounted)`
- Check `showSnackBar` parameter (default: true)
- Verify `ScaffoldMessenger` is available in context

### Performance Monitoring Not Working

- Confirm Firebase Analytics initialized in `main.dart`
- Check `firebase_analytics` package in `pubspec.yaml`
- Verify analytics collection enabled: `setAnalyticsCollectionEnabled(true)`

### Retry Not Working

- Check if error is retryable (see Retryable Errors section)
- Verify `maxAttempts` > 1
- Review `_isRetryableError()` logic in service

## Related Files

- **Service Implementation**: `lib/services/error_handling_service.dart`
- **GetIt Registration**: `lib/core/injection.dart`
- **Notifier Integration**: `lib/presentation/notifiers/lobby_notifier.dart`
- **Analytics Init**: `lib/main.dart`

## Future Enhancements

- [ ] Add Sentry integration for error tracking
- [ ] Implement circuit breaker pattern for failing services
- [ ] Add error rate limiting to prevent spam
- [ ] Create error reporting UI for users
- [ ] Add offline error queue for sync on reconnect
