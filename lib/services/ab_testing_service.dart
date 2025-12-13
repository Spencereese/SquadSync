import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A/B Testing Service for routing experiments
///
/// This service manages A/B test variant assignment and tracks navigation
/// events to Firebase Analytics for performance comparison.
class ABTestingService {
  static const String _experimentIdKey = 'ab_test_experiment_id';
  static const String _variantKey = 'ab_test_variant';
  static const String _userIdKey = 'ab_test_user_id';

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final SharedPreferences _prefs;

  ABTestingService(this._prefs);

  /// Initialize A/B testing - call once at app startup
  static Future<ABTestingService> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    return ABTestingService(prefs);
  }

  /// Get or assign user's A/B test variant
  Future<String> getVariant(String userId, String experimentId) async {
    // Check if user already has a variant assigned
    final storedExperimentId = _prefs.getString(_experimentIdKey);
    final storedVariant = _prefs.getString(_variantKey);
    final storedUserId = _prefs.getString(_userIdKey);

    if (storedExperimentId == experimentId &&
        storedUserId == userId &&
        storedVariant != null) {
      return storedVariant;
    }

    // Assign new variant based on user ID hash (50/50 split)
    final hash = userId.hashCode.abs();
    final variant = hash % 2 == 0 ? 'variant_a' : 'variant_b';

    // Store variant assignment
    await _prefs.setString(_experimentIdKey, experimentId);
    await _prefs.setString(_variantKey, variant);
    await _prefs.setString(_userIdKey, userId);

    // Log variant assignment to analytics
    await _analytics.logEvent(
      name: 'ab_test_assigned',
      parameters: {
        'experiment_id': experimentId,
        'variant': variant,
        'user_id': userId,
      },
    );

    return variant;
  }

  /// Track navigation event for A/B testing
  Future<void> trackNavigation(
    String route, {
    String? method,
    Map<String, dynamic>? additionalParams,
  }) async {
    final experimentId = _prefs.getString(_experimentIdKey);
    final variant = _prefs.getString(_variantKey);

    if (experimentId == null || variant == null) {
      return; // No active experiment
    }

    await _analytics.logEvent(
      name: 'navigation_event',
      parameters: {
        'experiment_id': experimentId,
        'variant': variant,
        'route': route,
        'method': method ?? 'unknown',
        'timestamp': DateTime.now().toIso8601String(),
        ...?additionalParams,
      },
    );
  }

  /// Track route timing for performance comparison
  Future<void> trackRouteTiming(
    String route,
    Duration duration,
  ) async {
    final experimentId = _prefs.getString(_experimentIdKey);
    final variant = _prefs.getString(_variantKey);

    if (experimentId == null || variant == null) {
      return;
    }

    await _analytics.logEvent(
      name: 'route_timing',
      parameters: {
        'experiment_id': experimentId,
        'variant': variant,
        'route': route,
        'duration_ms': duration.inMilliseconds,
      },
    );
  }

  /// Track error events for reliability comparison
  Future<void> trackError(
    String route,
    String errorType,
    String errorMessage,
  ) async {
    final experimentId = _prefs.getString(_experimentIdKey);
    final variant = _prefs.getString(_variantKey);

    if (experimentId == null || variant == null) {
      return;
    }

    await _analytics.logEvent(
      name: 'routing_error',
      parameters: {
        'experiment_id': experimentId,
        'variant': variant,
        'route': route,
        'error_type': errorType,
        'error_message': errorMessage,
      },
    );
  }

  /// Track user engagement (time on route)
  Future<void> trackEngagement(
    String route,
    Duration timeSpent,
  ) async {
    final experimentId = _prefs.getString(_experimentIdKey);
    final variant = _prefs.getString(_variantKey);

    if (experimentId == null || variant == null) {
      return;
    }

    await _analytics.logEvent(
      name: 'route_engagement',
      parameters: {
        'experiment_id': experimentId,
        'variant': variant,
        'route': route,
        'time_spent_seconds': timeSpent.inSeconds,
      },
    );
  }

  /// Get current variant (returns null if no active experiment)
  String? getCurrentVariant() {
    return _prefs.getString(_variantKey);
  }

  /// Get current experiment ID
  String? getCurrentExperimentId() {
    return _prefs.getString(_experimentIdKey);
  }

  /// Clear experiment data (useful for testing)
  Future<void> clearExperimentData() async {
    await _prefs.remove(_experimentIdKey);
    await _prefs.remove(_variantKey);
    await _prefs.remove(_userIdKey);
  }

  /// Force set variant (for testing purposes only)
  Future<void> forceSetVariant(String experimentId, String variant) async {
    await _prefs.setString(_experimentIdKey, experimentId);
    await _prefs.setString(_variantKey, variant);
  }
}

/// Route performance tracker for A/B testing
class RoutePerformanceTracker {
  final ABTestingService _abTestService;
  final Map<String, DateTime> _routeStartTimes = {};

  RoutePerformanceTracker(this._abTestService);

  /// Start tracking route navigation
  void startTracking(String route) {
    _routeStartTimes[route] = DateTime.now();
  }

  /// End tracking and log performance
  Future<void> endTracking(String route) async {
    final startTime = _routeStartTimes[route];
    if (startTime == null) return;

    final duration = DateTime.now().difference(startTime);
    await _abTestService.trackRouteTiming(route, duration);

    _routeStartTimes.remove(route);
  }

  /// Track engagement time on route
  Future<void> trackEngagement(String route, DateTime arrivalTime) async {
    final duration = DateTime.now().difference(arrivalTime);
    await _abTestService.trackEngagement(route, duration);
  }
}

/// Example usage in your app:
/// 
/// ```dart
/// // In main.dart initialization
/// final abTestService = await ABTestingService.initialize();
/// final variant = await abTestService.getVariant(userId, 'routing_experiment_v1');
/// 
/// // When navigating
/// await abTestService.trackNavigation('/chat', method: 'deep_link');
/// 
/// // Track timing
/// final tracker = RoutePerformanceTracker(abTestService);
/// tracker.startTracking('/chat');
/// // ... navigation happens ...
/// await tracker.endTracking('/chat');
/// ```
