import 'package:freezed_annotation/freezed_annotation.dart';

part 'system_state.freezed.dart';
part 'system_state.g.dart';

@freezed // Disable DiagnosticableTreeMixin - has bugs in Freezed 3.0
class SystemState with _$SystemState {
  const factory SystemState({
    required ThemeMode themeMode,
    required bool notificationsEnabled,
    required bool soundEnabled,
    required bool vibrationEnabled,
    required DateTime? lastSyncTimestamp,
    required Map<String, dynamic> analyticsMetrics,
    required List<Map<String, dynamic>> notifications,
    required List<Map<String, dynamic>> availabilitySlots,
    required Map<String, Map<String, bool>> dailyBanVotes,
    required List<Map<String, dynamic>> bans,
    required bool hasNewNotifications,
    required bool hasNewAvailability,
    required bool isInitialized,
    String? errorMessage,
  }) = _SystemState;

  factory SystemState.fromJson(Map<String, dynamic> json) =>
      _$SystemStateFromJson(json);

  factory SystemState.initial() => SystemState(
        themeMode: ThemeMode.system,
        notificationsEnabled: true,
        soundEnabled: true,
        vibrationEnabled: true,
        lastSyncTimestamp: null,
        analyticsMetrics: {},
        notifications: [],
        availabilitySlots: [],
        dailyBanVotes: {},
        bans: [],
        hasNewNotifications: false,
        hasNewAvailability: false,
        isInitialized: false,
        errorMessage: null,
      );
}

enum ThemeMode {
  system,
  light,
  dark,
}
