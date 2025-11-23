import 'package:squad_sync/domain/entities/system_state.dart';

abstract class SystemRepository {
  Future<SystemState> loadSystemState();
  Future<void> saveSystemState(SystemState state);
  Future<void> updateThemeMode(ThemeMode themeMode);
  Future<void> updateNotificationSettings(Map<String, bool> settings);
  Future<void> banUser(String userId, String reason);
  Future<void> unbanUser(String userId);
  Future<bool> checkAvailability();
  Future<void> updateSoundSettings(bool enabled);
  Future<void> updateVibrationSettings(bool enabled);
  Future<void> updateLastSyncTimestamp(DateTime timestamp);
  Future<void> trackAnalyticsEvent(String event, Map<String, dynamic> data);
  Future<Map<String, dynamic>> getAnalyticsMetrics();
  Future<void> sendLocalNotification(String title, String body,
      {Map<String, dynamic>? data});
  Future<void> sendNotificationToUser(String userId, String title, String body,
      {Map<String, dynamic>? data});
  Future<void> sendNotificationToSquad(
      String squadId, String title, String body,
      {Map<String, dynamic>? data});
  Future<void> scheduleNotification(
      DateTime scheduledTime, String title, String body,
      {Map<String, dynamic>? data});
  Future<void> addNotification(Map<String, dynamic> notification);
  Future<void> markNotificationsAsRead();
  Future<void> deleteNotification(String notificationId);
  Future<void> addAvailabilitySlot(Map<String, dynamic> slot);
  Future<void> removeAvailabilitySlot(String slotId);
  Future<void> updateAvailabilitySlot(
      String slotId, Map<String, dynamic> updates);
  Future<void> submitBanVote(String targetUserId, bool vote);
  Future<void> processBanVotes();
  Future<void> clearOldNotifications({Duration? olderThan});
  Future<void> resetDailyVotes();
  Future<void> purgeOldData({Duration? olderThan});
}
