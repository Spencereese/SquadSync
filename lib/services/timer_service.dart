import 'dart:async';
import 'dart:ui';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A Riverpod provider for the TimerService singleton.
final timerServiceProvider = Provider<TimerService>((ref) {
  return TimerService();
});

/// TimerService manages multiple timers using a single periodic Timer.
/// It uses Firebase Cloud Functions for server-side expiration handling.
class TimerService {
  static final TimerService _instance = TimerService._();

  factory TimerService() => _instance;

  TimerService._() {
    _startPeriodicTimer();
  }

  final Map<String, DateTime> _expirationTimes = {};
  final Map<String, StreamController<Duration>> _controllers = {};
  final Map<String, Duration> _lastRemaining = {};
  final Map<String, VoidCallback> _onExpireCallbacks = {};
  Timer? _timer;

  /// Starts a timer with the given key, duration, and callback on expiration.
  /// Calls Firebase Cloud Functions to process timers on the server.
  void startTimer(String key, Duration duration, VoidCallback onExpire) {
    if (key.isEmpty) {
      throw ArgumentError('Timer key cannot be empty');
    }
    final expirationTime = DateTime.now().add(duration);
    _expirationTimes[key] = expirationTime;
    _controllers[key] ??= StreamController<Duration>.broadcast();
    _onExpireCallbacks[key] = onExpire;
    _lastRemaining[key] = duration; // Initial remaining time
    _controllers[key]!.add(duration);

    // Call Firebase Cloud Function for server-side handling
    _callProcessTimers();
  }

  /// Stops the timer with the given key.
  /// Calls Firebase Cloud Functions to process timers on the server.
  void stopTimer(String key) {
    if (!_expirationTimes.containsKey(key)) {
      throw ArgumentError('Timer with key "$key" does not exist');
    }
    _expirationTimes.remove(key);
    _controllers[key]?.close();
    _controllers.remove(key);
    _onExpireCallbacks.remove(key);
    _lastRemaining.remove(key);

    // Call Firebase Cloud Function for server-side handling
    _callProcessTimers();
  }

  /// Gets the remaining time for the timer with the given key.
  Duration getRemainingTime(String key) {
    if (!_expirationTimes.containsKey(key)) {
      throw ArgumentError('Timer with key "$key" does not exist');
    }
    final remaining = _expirationTimes[key]!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Returns a stream for observing the remaining time of the timer with the given key.
  Stream<Duration> observeTimer(String key) {
    if (!_controllers.containsKey(key)) {
      throw ArgumentError('Timer with key "$key" does not exist');
    }
    return _controllers[key]!.stream;
  }

  /// Starts the periodic timer that ticks every 5 seconds.
  void _startPeriodicTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), _onTick);
  }

  /// Called on each tick to update remaining times and notify observers.
  void _onTick(Timer timer) {
    final now = DateTime.now();
    for (final key in _expirationTimes.keys.toList()) {
      final expiration = _expirationTimes[key]!;
      final remaining = expiration.difference(now);
      final clampedRemaining = remaining.isNegative ? Duration.zero : remaining;

      // Only notify if the remaining time has changed
      if (_lastRemaining[key] != clampedRemaining) {
        _lastRemaining[key] = clampedRemaining;
        _controllers[key]?.add(clampedRemaining);

        // If expired, call onExpire and stop the timer
        if (clampedRemaining == Duration.zero) {
          _onExpireCallbacks[key]?.call();
          stopTimer(key);
        }
      }
    }
  }

  /// Calls the hypothetical Firebase Cloud Function 'processTimers'.
  Future<void> _callProcessTimers() async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('processTimers');
      await callable.call();
    } catch (e) {
      // Handle error, e.g., log or show user feedback
      // print('Error calling processTimers: $e');
    }
  }

  /// Stops all timers.
  void stopAllTimers() {
    for (final key in _expirationTimes.keys.toList()) {
      _expirationTimes.remove(key);
      _controllers[key]?.close();
      _controllers.remove(key);
      _onExpireCallbacks.remove(key);
      _lastRemaining.remove(key);
    }
    // Call Firebase Cloud Function for server-side handling
    _callProcessTimers();
  }

  /// Disposes the service, canceling the timer and closing all streams.
  void dispose() {
    _timer?.cancel();
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    _expirationTimes.clear();
    _onExpireCallbacks.clear();
    _lastRemaining.clear();
  }
}
