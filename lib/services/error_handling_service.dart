import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:logger/logger.dart';
import 'package:retry/retry.dart';
import 'dart:async';

/// Centralized error handling service for SquadSync
///
/// Provides unified error handling with:
/// - User-facing error messages via SnackBar
/// - Analytics logging for error tracking
/// - Automatic retry logic for transient failures
/// - Performance monitoring for slow operations (>500ms)
///
/// Usage (with GetIt):
/// ```dart
/// final errorHandler = getIt<ErrorHandlingService>();
/// try {
///   await someOperation();
/// } catch (e) {
///   await errorHandler.handleError(
///     context: context,
///     error: e,
///     operation: 'fetchUserData',
///   );
/// }
/// ```
class ErrorHandlingService {
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Handle an error with user feedback, logging, and analytics
  ///
  /// - [context]: BuildContext for showing SnackBar (optional, but recommended)
  /// - [error]: The error/exception to handle
  /// - [operation]: Name of the operation that failed (for analytics)
  /// - [showSnackBar]: Whether to show user-facing error message (default: true)
  /// - [logToAnalytics]: Whether to log to Firebase Analytics (default: true)
  Future<void> handleError({
    BuildContext? context,
    required dynamic error,
    String? operation,
    bool showSnackBar = true,
    bool logToAnalytics = true,
    StackTrace? stackTrace,
  }) async {
    // Extract error message
    final errorMessage = _extractErrorMessage(error);
    final userMessage = _getUserFriendlyMessage(error);

    // Log to console with logger
    _logger.e(
      'Error in ${operation ?? 'unknown operation'}: $errorMessage',
      error: error,
      stackTrace: stackTrace,
    );

    // Log to Firebase Analytics
    if (logToAnalytics) {
      try {
        await _analytics.logEvent(
          name: 'error_occurred',
          parameters: {
            'error_type': error.runtimeType.toString(),
            'error_message': errorMessage.substring(
                0, errorMessage.length > 100 ? 100 : errorMessage.length),
            'operation': operation ?? 'unknown',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      } catch (e) {
        _logger.w('Failed to log error to analytics: $e');
      }
    }

    // Show user-facing error message
    if (showSnackBar && context != null && context.mounted) {
      _showErrorSnackBar(context, userMessage, operation);
    }
  }

  /// Execute an operation with automatic retry logic
  ///
  /// Retries transient failures up to 3 times with exponential backoff
  ///
  /// Usage:
  /// ```dart
  /// final result = await errorHandler.withRetry(
  ///   operation: () async => await fetchData(),
  ///   operationName: 'fetchData',
  /// );
  /// ```
  Future<T> withRetry<T>({
    required Future<T> Function() operation,
    String? operationName,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    final r = RetryOptions(
      maxAttempts: maxAttempts,
      delayFactor: initialDelay,
      randomizationFactor: 0.25,
      maxDelay: const Duration(seconds: 10),
    );

    try {
      return await r.retry(
        operation,
        retryIf: (e) => _isRetryableError(e),
        onRetry: (e) {
          _logger.w('Retrying ${operationName ?? 'operation'} after error: $e');
        },
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Failed ${operationName ?? 'operation'} after $maxAttempts attempts',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Execute an operation with performance monitoring
  ///
  /// Logs operations that take longer than 500ms to Firebase Analytics
  ///
  /// Usage:
  /// ```dart
  /// final result = await errorHandler.withPerformanceMonitoring(
  ///   operation: () async => await expensiveOperation(),
  ///   operationName: 'loadGameData',
  /// );
  /// ```
  Future<T> withPerformanceMonitoring<T>({
    required Future<T> Function() operation,
    required String operationName,
    Duration slowThreshold = const Duration(milliseconds: 500),
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await operation();
      stopwatch.stop();

      final duration = stopwatch.elapsedMilliseconds;

      // Log slow operations to analytics
      if (stopwatch.elapsed > slowThreshold) {
        _logger.w('Slow operation detected: $operationName took ${duration}ms');

        await _analytics.logEvent(
          name: 'slow_operation',
          parameters: {
            'operation': operationName,
            'duration_ms': duration,
            'threshold_ms': slowThreshold.inMilliseconds,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      _logger.e(
        'Operation failed: $operationName after ${stopwatch.elapsedMilliseconds}ms',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Combine retry logic with performance monitoring
  ///
  /// Best practice for critical async operations
  ///
  /// Usage:
  /// ```dart
  /// final result = await errorHandler.withRetryAndMonitoring(
  ///   operation: () async => await criticalOperation(),
  ///   operationName: 'fetchCriticalData',
  ///   context: context,
  /// );
  /// ```
  Future<T> withRetryAndMonitoring<T>({
    required Future<T> Function() operation,
    required String operationName,
    BuildContext? context,
    int maxAttempts = 3,
    Duration slowThreshold = const Duration(milliseconds: 500),
  }) async {
    try {
      return await withPerformanceMonitoring(
        operation: () => withRetry(
          operation: operation,
          operationName: operationName,
          maxAttempts: maxAttempts,
        ),
        operationName: operationName,
        slowThreshold: slowThreshold,
      );
    } catch (e, stackTrace) {
      await handleError(
        context: context,
        error: e,
        operation: operationName,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Private helper methods

  String _extractErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString();
    } else if (error is Error) {
      return error.toString();
    } else {
      return error?.toString() ?? 'Unknown error';
    }
  }

  String _getUserFriendlyMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection')) {
      return 'Network connection issue. Please check your internet connection.';
    }

    // Timeout errors
    if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    // Authentication errors
    if (errorString.contains('auth') ||
        errorString.contains('unauthorized') ||
        errorString.contains('403')) {
      return 'Authentication error. Please sign in again.';
    }

    // Permission errors
    if (errorString.contains('permission') ||
        errorString.contains('forbidden') ||
        errorString.contains('denied')) {
      return 'You don\'t have permission to perform this action.';
    }

    // Not found errors
    if (errorString.contains('not found') || errorString.contains('404')) {
      return 'The requested resource was not found.';
    }

    // Server errors
    if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503')) {
      return 'Server error. Please try again later.';
    }

    // Supabase-specific errors
    if (errorString.contains('supabase')) {
      return 'Database operation failed. Please try again.';
    }

    // Generic fallback
    return 'An error occurred. Please try again.';
  }

  bool _isRetryableError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Retry transient network errors
    if (errorString.contains('socket') ||
        errorString.contains('timeout') ||
        errorString.contains('connection reset') ||
        errorString.contains('connection refused')) {
      return true;
    }

    // Retry rate limiting (429)
    if (errorString.contains('429') || errorString.contains('rate limit')) {
      return true;
    }

    // Retry server errors (5xx)
    if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504')) {
      return true;
    }

    // Don't retry client errors (4xx) except rate limiting
    return false;
  }

  void _showErrorSnackBar(
    BuildContext context,
    String message,
    String? operation,
  ) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 4),
        action: operation != null
            ? SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              )
            : null,
      ),
    );
  }

  /// Log a non-error event for analytics
  Future<void> logEvent(
      String eventName, Map<String, dynamic> parameters) async {
    try {
      await _analytics.logEvent(
        name: eventName,
        parameters: parameters.cast<String, Object>(),
      );
    } catch (e) {
      _logger.w('Failed to log event to analytics: $e');
    }
  }
}
