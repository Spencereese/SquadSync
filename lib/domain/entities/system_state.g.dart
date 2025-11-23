// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SystemStateImpl _$$SystemStateImplFromJson(Map<String, dynamic> json) =>
    _$SystemStateImpl(
      themeMode: $enumDecode(_$ThemeModeEnumMap, json['themeMode']),
      notificationsEnabled: json['notificationsEnabled'] as bool,
      soundEnabled: json['soundEnabled'] as bool,
      vibrationEnabled: json['vibrationEnabled'] as bool,
      lastSyncTimestamp: json['lastSyncTimestamp'] == null
          ? null
          : DateTime.parse(json['lastSyncTimestamp'] as String),
      analyticsMetrics: json['analyticsMetrics'] as Map<String, dynamic>,
      notifications: (json['notifications'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      availabilitySlots: (json['availabilitySlots'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      dailyBanVotes: (json['dailyBanVotes'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Map<String, bool>.from(e as Map)),
      ),
      bans: (json['bans'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      hasNewNotifications: json['hasNewNotifications'] as bool,
      hasNewAvailability: json['hasNewAvailability'] as bool,
      isInitialized: json['isInitialized'] as bool,
      errorMessage: json['errorMessage'] as String?,
    );

Map<String, dynamic> _$$SystemStateImplToJson(_$SystemStateImpl instance) =>
    <String, dynamic>{
      'themeMode': _$ThemeModeEnumMap[instance.themeMode]!,
      'notificationsEnabled': instance.notificationsEnabled,
      'soundEnabled': instance.soundEnabled,
      'vibrationEnabled': instance.vibrationEnabled,
      'lastSyncTimestamp': instance.lastSyncTimestamp?.toIso8601String(),
      'analyticsMetrics': instance.analyticsMetrics,
      'notifications': instance.notifications,
      'availabilitySlots': instance.availabilitySlots,
      'dailyBanVotes': instance.dailyBanVotes,
      'bans': instance.bans,
      'hasNewNotifications': instance.hasNewNotifications,
      'hasNewAvailability': instance.hasNewAvailability,
      'isInitialized': instance.isInitialized,
      'errorMessage': instance.errorMessage,
    };

const _$ThemeModeEnumMap = {
  ThemeMode.system: 'system',
  ThemeMode.light: 'light',
  ThemeMode.dark: 'dark',
};
