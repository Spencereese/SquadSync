import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_sync/domain/entities/system_state.dart';

abstract class SystemLocalDataSource {
  Future<SystemState> loadSystemState();
  Future<void> saveSystemState(SystemState state);
  Future<ThemeMode> getThemeMode();
  Future<void> setThemeMode(ThemeMode themeMode);
  Future<bool> getNotificationsEnabled();
  Future<void> setNotificationsEnabled(bool enabled);
  Future<bool> getSoundEnabled();
  Future<void> setSoundEnabled(bool enabled);
  Future<bool> getVibrationEnabled();
  Future<void> setVibrationEnabled(bool enabled);
  Future<DateTime?> getLastSyncTimestamp();
  Future<void> setLastSyncTimestamp(DateTime timestamp);
  Future<Map<String, dynamic>> getAnalyticsMetrics();
  Future<void> saveAnalyticsMetrics(Map<String, dynamic> metrics);
}

class SystemLocalDataSourceImpl implements SystemLocalDataSource {
  final SharedPreferences _prefs;

  static const String _themeModeKey = 'theme_mode';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _vibrationEnabledKey = 'vibration_enabled';
  static const String _lastSyncTimestampKey = 'last_sync_timestamp';
  static const String _analyticsMetricsKey = 'analytics_metrics';

  SystemLocalDataSourceImpl(this._prefs);

  @override
  Future<SystemState> loadSystemState() async {
    final themeMode = await getThemeMode();
    final notificationsEnabled = await getNotificationsEnabled();
    final soundEnabled = await getSoundEnabled();
    final vibrationEnabled = await getVibrationEnabled();
    final lastSyncTimestamp = await getLastSyncTimestamp();
    final analyticsMetrics = await getAnalyticsMetrics();

    return SystemState.initial().copyWith(
      themeMode: themeMode,
      notificationsEnabled: notificationsEnabled,
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
      lastSyncTimestamp: lastSyncTimestamp,
      analyticsMetrics: analyticsMetrics,
    );
  }

  @override
  Future<void> saveSystemState(SystemState state) async {
    await setThemeMode(state.themeMode);
    await setNotificationsEnabled(state.notificationsEnabled);
    await setSoundEnabled(state.soundEnabled);
    await setVibrationEnabled(state.vibrationEnabled);
    if (state.lastSyncTimestamp != null) {
      await setLastSyncTimestamp(state.lastSyncTimestamp!);
    }
    await saveAnalyticsMetrics(state.analyticsMetrics);
  }

  @override
  Future<ThemeMode> getThemeMode() async {
    final value = _prefs.getString(_themeModeKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }

  @override
  Future<void> setThemeMode(ThemeMode themeMode) async {
    await _prefs.setString(_themeModeKey, themeMode.name);
  }

  @override
  Future<bool> getNotificationsEnabled() async {
    return _prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_notificationsEnabledKey, enabled);
  }

  @override
  Future<bool> getSoundEnabled() async {
    return _prefs.getBool(_soundEnabledKey) ?? true;
  }

  @override
  Future<void> setSoundEnabled(bool enabled) async {
    await _prefs.setBool(_soundEnabledKey, enabled);
  }

  @override
  Future<bool> getVibrationEnabled() async {
    return _prefs.getBool(_vibrationEnabledKey) ?? true;
  }

  @override
  Future<void> setVibrationEnabled(bool enabled) async {
    await _prefs.setBool(_vibrationEnabledKey, enabled);
  }

  @override
  Future<DateTime?> getLastSyncTimestamp() async {
    final timestamp = _prefs.getString(_lastSyncTimestampKey);
    return timestamp != null ? DateTime.parse(timestamp) : null;
  }

  @override
  Future<void> setLastSyncTimestamp(DateTime timestamp) async {
    await _prefs.setString(_lastSyncTimestampKey, timestamp.toIso8601String());
  }

  @override
  Future<Map<String, dynamic>> getAnalyticsMetrics() async {
    final json = _prefs.getString(_analyticsMetricsKey);
    return json != null ? jsonDecode(json) : {};
  }

  @override
  Future<void> saveAnalyticsMetrics(Map<String, dynamic> metrics) async {
    await _prefs.setString(_analyticsMetricsKey, jsonEncode(metrics));
  }
}