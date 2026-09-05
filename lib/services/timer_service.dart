import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_service.dart';
import 'auth_service_supabase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../chat/sqlite_helper.dart';
import '../presentation/notifiers/lobby_notifier.dart' as ln;
import '../core/injection.dart' as di;

/// Timer data structure for persistence
class TimerData {
  final String key;
  final DateTime expirationTime;
  final String type; // 'spot' or 'peacock'
  final String? gameName; // For game-scoped timers
  final String? userId; // For UID-based timers

  TimerData({
    required this.key,
    required this.expirationTime,
    required this.type,
    this.gameName,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'expirationTime': expirationTime.toIso8601String(),
      'type': type,
      'gameName': gameName,
      'userId': userId,
    };
  }

  factory TimerData.fromMap(Map<String, dynamic> map) {
    return TimerData(
      key: map['key'],
      expirationTime: DateTime.parse(map['expirationTime']),
      type: map['type'],
      gameName: map['gameName'],
      userId: map['userId'],
    );
  }
}

/// Priority queue item for timer expirations
class TimerExpiration implements Comparable<TimerExpiration> {
  final String key;
  final DateTime expirationTime;
  final VoidCallback onExpire;

  TimerExpiration(this.key, this.expirationTime, this.onExpire);

  @override
  int compareTo(TimerExpiration other) {
    return expirationTime.compareTo(other.expirationTime);
  }
}

/// TimerOrchestrator manages a single periodic timer with priority queue
class TimerOrchestrator {
  static final TimerOrchestrator _instance = TimerOrchestrator._();
  factory TimerOrchestrator() => _instance;

  TimerOrchestrator._();

  Timer? _timer;
  final List<TimerExpiration> _expirationQueue = [];
  final Map<String, TimerExpiration> _activeTimers = {};
  final Map<String, StreamController<Duration>> _controllers = {};
  final Map<String, Duration> _lastRemaining = {};
  bool _hasActiveTimers = false;

  /// Starts the orchestrator with 1-second intervals
  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  /// Stops the orchestrator
  void stop() {
    _timer?.cancel();
    _timer = null;
    _expirationQueue.clear();
    _activeTimers.clear();
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    _lastRemaining.clear();
    _hasActiveTimers = false;
  }

  /// Adds a timer to the orchestrator
  void addTimer(String key, Duration duration, VoidCallback onExpire) {
    final expirationTime = DateTime.now().add(duration);
    final expiration = TimerExpiration(key, expirationTime, onExpire);

    // Remove existing timer if present
    removeTimer(key);

    _activeTimers[key] = expiration;
    _expirationQueue.add(expiration);
    _expirationQueue.sort(); // Sort by expiration time
    _controllers[key] ??= StreamController<Duration>.broadcast();
    _lastRemaining[key] = duration;
    _controllers[key]!.add(duration);
    _updateActiveTimersFlag();
  }

  /// Removes a timer from the orchestrator
  void removeTimer(String key) {
    final existing = _activeTimers.remove(key);
    if (existing != null) {
      _expirationQueue.remove(existing);
    }
    _controllers[key]?.close();
    _controllers.remove(key);
    _lastRemaining.remove(key);
    _updateActiveTimersFlag();
  }

  /// Gets remaining time for a timer
  Duration getRemainingTime(String key) {
    final expiration = _activeTimers[key];
    if (expiration == null) return Duration.zero;
    final remaining = expiration.expirationTime.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Observes timer updates
  Stream<Duration> observeTimer(String key) {
    if (!_controllers.containsKey(key)) {
      return Stream.value(Duration.zero);
    }
    return _controllers[key]!.stream;
  }

  /// Processes tick with batch updates and conditional notifications
  void _onTick(Timer timer) {
    if (!_hasActiveTimers) return;

    final now = DateTime.now();
    final expiredKeys = <String>[];
    final changedKeys = <String>[];

    // Process expirations
    while (_expirationQueue.isNotEmpty) {
      final next = _expirationQueue.first;
      if (next.expirationTime.isAfter(now)) break;

      _expirationQueue.removeAt(0);
      expiredKeys.add(next.key);
      next.onExpire();
    }

    // Clean up expired timers
    for (final key in expiredKeys) {
      _activeTimers.remove(key);
      _controllers[key]?.close();
      _controllers.remove(key);
      _lastRemaining.remove(key);
    }

    // Update remaining times for active timers
    for (final entry in _activeTimers.entries) {
      final key = entry.key;
      final expiration = entry.value;
      final remaining = expiration.expirationTime.difference(now);
      final clampedRemaining = remaining.isNegative ? Duration.zero : remaining;

      if (_lastRemaining[key] != clampedRemaining) {
        _lastRemaining[key] = clampedRemaining;
        _controllers[key]?.add(clampedRemaining);
        changedKeys.add(key);
      }
    }

    _updateActiveTimersFlag();

    // Only notify if there were changes and we still have active timers
    if (changedKeys.isNotEmpty && _hasActiveTimers) {
      // Debounced notification - could be extended with actual debouncing
      _notifyListeners();
    }
  }

  void _updateActiveTimersFlag() {
    _hasActiveTimers = _activeTimers.isNotEmpty;
  }

  void _notifyListeners() {
    // Placeholder for global notifications - integrate with your state management
  }

  /// Gets all active timer keys
  Set<String> getActiveTimerKeys() => _activeTimers.keys.toSet();

  /// Checks if there are active timers
  bool hasActiveTimers() => _hasActiveTimers;
}

/// A Riverpod provider for the TimerService.
final timerServiceProvider =
    StateNotifierProvider<TimerServiceNotifier, AsyncValue<void>>((ref) {
  // TODO: Migrate to Supabase for timer sync
  final sqliteHelper = di.getIt<SQLiteHelper>();
  return TimerServiceNotifier(ref, sqliteHelper);
});

/// SQLite helper provider
final sqliteHelperProvider = Provider<SQLiteHelper>((ref) => SQLiteHelper());

/// TimerService manages timers with offline caching and Cloud Function fallbacks.
/// Uses TimerOrchestrator for efficient batch processing.
class TimerServiceNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final SQLiteHelper _sqliteHelper;
  final TimerOrchestrator _orchestrator = TimerOrchestrator();
  SharedPreferences? _prefs;
  final bool _isOfflineMode = false;

  // Debouncing for UI updates
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 100);

  // Interpolation support
  final Map<String, Duration> _interpolatedRemaining = {};

  TimerServiceNotifier(this._ref, this._sqliteHelper)
      : super(const AsyncValue.data(null)) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = const AsyncValue.loading();
    try {
      _prefs = await SharedPreferences.getInstance();
      _orchestrator.start();
      await _loadPersistedTimers();
      await _syncWithSupabase();
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Starts a spot timer with game-scoped data
  Future<void> startSpotTimer(
      String gameName, String userId, Duration duration) async {
    final key = 'spot_${gameName}_$userId';
    await _startTimer(key, duration, () => _onSpotTimerExpire(gameName, userId),
        type: 'spot', gameName: gameName, userId: userId);
  }

  /// Starts a peacock timer
  Future<void> startPeacockTimer(String userId, Duration duration) async {
    final key = 'peacock_$userId';
    await _startTimer(key, duration, () => _onPeacockTimerExpire(userId),
        type: 'peacock', userId: userId);
  }

  /// Internal timer start with persistence
  Future<void> _startTimer(
    String key,
    Duration duration,
    VoidCallback onExpire, {
    required String type,
    String? gameName,
    String? userId,
  }) async {
    _orchestrator.addTimer(key, duration, onExpire);

    final timerData = TimerData(
      key: key,
      expirationTime: DateTime.now().add(duration),
      type: type,
      gameName: gameName,
      userId: userId,
    );

    await _persistTimer(timerData);
    await _syncWithCloudFunctions();
  }

  /// Stops a timer
  Future<void> stopTimer(String key) async {
    _orchestrator.removeTimer(key);
    await _removePersistedTimer(key);
    await _syncWithCloudFunctions();
  }

  /// Gets remaining time with interpolation support
  Duration getRemainingTime(String key, {bool interpolate = false}) {
    final remaining = _orchestrator.getRemainingTime(key);
    if (interpolate) {
      // Simple interpolation - could be enhanced with more sophisticated algorithms
      final lastInterpolated = _interpolatedRemaining[key] ?? remaining;
      final interpolated = Duration(
        milliseconds:
            (remaining.inMilliseconds + lastInterpolated.inMilliseconds) ~/ 2,
      );
      _interpolatedRemaining[key] = interpolated;
      return interpolated;
    }
    return remaining;
  }

  /// Observes timer with debounced UI updates
  Stream<Duration> observeTimer(String key) {
    return _orchestrator.observeTimer(key).transform(
      StreamTransformer<Duration, Duration>.fromHandlers(
        handleData: (data, sink) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(_debounceDuration, () {
            sink.add(data);
          });
        },
      ),
    );
  }

  /// Spot timer expiration handler.
  ///
  /// Display-only: local persist cleanup. Server
  /// [process_expired_timers] frees the spot and assigns the next queue
  /// uid. Do not removeSpot here.
  void _onSpotTimerExpire(String gameName, String userId) {
    _removePersistedTimer('spot_${gameName}_$userId');
  }

  /// Peacock timer expiration handler.
  ///
  /// Display-only: expire the tracker so the chip can read expired.
  /// Server [process_expired_timers] still assigns.
  void _onPeacockTimerExpire(String userId) {
    try {
      final lobbyNotifier = _ref.read(ln.lobbyNotifierProvider.notifier);
      lobbyNotifier.expirePeacockAssignment(userId);
    } catch (_) {
      // Tracker expire is best-effort display.
    }
    _removePersistedTimer('peacock_$userId');
  }

  /// Persists timer to SQLite and SharedPreferences
  Future<void> _persistTimer(TimerData timerData) async {
    try {
      final db = await _sqliteHelper.database;
      await db.insert(
        'timers',
        {
          'key': timerData.key,
          'data': jsonEncode(timerData.toMap()),
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Also cache in SharedPreferences for quick access
      final timers = _prefs?.getStringList('active_timers') ?? [];
      timers.add(timerData.key);
      await _prefs?.setStringList('active_timers', timers);
      await _prefs?.setString(
          'timer_${timerData.key}', jsonEncode(timerData.toMap()));
    } catch (e) {
      // Fallback to SharedPreferences only
      final timers = _prefs?.getStringList('active_timers') ?? [];
      timers.add(timerData.key);
      await _prefs?.setStringList('active_timers', timers);
      await _prefs?.setString(
          'timer_${timerData.key}', jsonEncode(timerData.toMap()));
    }
  }

  /// Removes persisted timer
  Future<void> _removePersistedTimer(String key) async {
    try {
      final db = await _sqliteHelper.database;
      await db.delete('timers', where: 'key = ?', whereArgs: [key]);
    } catch (e) {
      // SQLite failed, continue with SharedPreferences cleanup
    }

    final timers = _prefs?.getStringList('active_timers') ?? [];
    timers.remove(key);
    await _prefs?.setStringList('active_timers', timers);
    await _prefs?.remove('timer_$key');
    _interpolatedRemaining.remove(key);
  }

  /// Loads persisted timers on startup
  Future<void> _loadPersistedTimers() async {
    final timerKeys = _prefs?.getStringList('active_timers') ?? [];
    final now = DateTime.now();

    for (final key in timerKeys) {
      final timerJson = _prefs?.getString('timer_$key');
      if (timerJson != null) {
        try {
          final timerData = TimerData.fromMap(jsonDecode(timerJson));
          if (timerData.expirationTime.isAfter(now)) {
            final remaining = timerData.expirationTime.difference(now);
            if (timerData.type == 'spot') {
              await startSpotTimer(
                  timerData.gameName!, timerData.userId!, remaining);
            } else if (timerData.type == 'peacock') {
              await startPeacockTimer(timerData.userId!, remaining);
            }
          } else {
            await _removePersistedTimer(key);
          }
        } catch (e) {
          await _removePersistedTimer(key);
        }
      }
    }
  }

  /// Syncs with Supabase Realtime for cross-device consistency
  Future<void> _syncWithSupabase() async {
    try {
      final user = AuthServiceSupabase().currentUserId;
      if (user == null) {
        debugPrint('[TimerService] No user authenticated for Supabase sync');
        return;
      }

      // Get active timers
      final activeTimers = _orchestrator.getActiveTimerKeys();
      final timerDataList = <Map<String, dynamic>>[];

      for (final key in activeTimers) {
        final remaining = _orchestrator.getRemainingTime(key);
        final timerJson = _prefs?.getString('timer_$key');
        if (timerJson != null) {
          try {
            final timerData = TimerData.fromMap(jsonDecode(timerJson));
            timerDataList.add({
              'key': key,
              'user_id': user,
              'expiration_time': timerData.expirationTime.toIso8601String(),
              'type': timerData.type,
              'game_name': timerData.gameName,
              'target_user_id': timerData.userId,
              'remaining_seconds': remaining.inSeconds,
            });
          } catch (e) {
            debugPrint('[TimerService] Error parsing timer $key: $e');
          }
        }
      }

      // Upsert timers to Supabase
      if (timerDataList.isNotEmpty) {
        await supabase.from('active_timers').upsert(timerDataList);
        debugPrint(
            '[TimerService] Synced ${timerDataList.length} timers to Supabase');
      }
    } catch (e) {
      debugPrint('[TimerService] Supabase sync error: $e');
    }
  }

  /// Calls Supabase Edge Functions with local fallback
  Future<void> _syncWithCloudFunctions() async {
    if (_isOfflineMode || kDebugMode) {
      // Dev fallback: process timers locally
      await _processTimersLocally();
      return;
    }

    try {
      // Call Supabase Edge Function for timer processing
      await supabase.functions.invoke('process-timers');
      debugPrint('[TimerService] Synced with Supabase Edge Functions');
    } catch (e) {
      debugPrint(
          '[TimerService] Edge Function call failed, processing locally: $e');
      // Fallback to local processing
      await _processTimersLocally();
    }
  }

  /// Local timer processing fallback
  Future<void> _processTimersLocally() async {
    // Implement local timer expiration logic
    // This would mirror the Cloud Function logic
  }

  @override
  void dispose() {
    _orchestrator.stop();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
