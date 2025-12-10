import 'package:squad_sync/domain/entities/system_state.dart';
import '../../services/auth_service_supabase.dart';
import 'package:squad_sync/domain/repositories/system_repository.dart';
import 'package:squad_sync/data/datasources/system_local_datasource.dart';
import 'package:squad_sync/data/datasources/system_remote_datasource.dart';

class SystemRepositoryImpl implements SystemRepository {
  final SystemLocalDataSource _localDataSource;
  final SystemRemoteDataSource _remoteDataSource;
  final AuthServiceSupabase _authService = AuthServiceSupabase();

  SystemRepositoryImpl(
    this._localDataSource,
    this._remoteDataSource,
  );

  @override
  Future<SystemState> loadSystemState() async {
    final user = _authService.currentUser;
    if (user == null) {
      return _localDataSource.loadSystemState();
    }

    try {
      final localState = await _localDataSource.loadSystemState();
      final notifications = await _remoteDataSource.getNotifications(user.id);
      final availabilitySlots =
          await _remoteDataSource.getAvailabilitySlots(user.id);
      final dailyBanVotes = await _remoteDataSource.getDailyBanVotes();
      final bans = await _remoteDataSource.getBans(user.id);

      return localState.copyWith(
        notifications: notifications,
        availabilitySlots: availabilitySlots,
        dailyBanVotes: dailyBanVotes,
        bans: bans,
        isInitialized: true,
      );
    } catch (e) {
      // Fallback to local state if remote fails
      return (await _localDataSource.loadSystemState()).copyWith(
        errorMessage: e.toString(),
        isInitialized: true,
      );
    }
  }

  @override
  Future<void> saveSystemState(SystemState state) async {
    await _localDataSource.saveSystemState(state);
  }

  @override
  Future<void> updateThemeMode(ThemeMode themeMode) async {
    await _localDataSource.setThemeMode(themeMode);
  }

  @override
  Future<void> updateNotificationSettings(Map<String, bool> settings) async {
    // For now, just use the main notification setting
    final enabled = settings['enabled'] ?? true;
    await _localDataSource.setNotificationsEnabled(enabled);
  }

  @override
  Future<void> updateSoundSettings(bool enabled) async {
    await _localDataSource.setSoundEnabled(enabled);
  }

  @override
  Future<void> updateVibrationSettings(bool enabled) async {
    await _localDataSource.setVibrationEnabled(enabled);
  }

  @override
  Future<void> updateLastSyncTimestamp(DateTime timestamp) async {
    await _localDataSource.setLastSyncTimestamp(timestamp);
  }

  @override
  Future<void> trackAnalyticsEvent(
      String event, Map<String, dynamic> data) async {
    await _remoteDataSource.sendAnalyticsEvent(event, data);

    // Update local metrics
    final currentMetrics = await _localDataSource.getAnalyticsMetrics();
    final eventCount = (currentMetrics[event] as int?) ?? 0;
    currentMetrics[event] = eventCount + 1;
    await _localDataSource.saveAnalyticsMetrics(currentMetrics);
  }

  @override
  Future<Map<String, dynamic>> getAnalyticsMetrics() async {
    final localMetrics = await _localDataSource.getAnalyticsMetrics();
    final remoteMetrics = await _remoteDataSource.getAnalyticsMetrics();
    return {...localMetrics, ...remoteMetrics};
  }

  @override
  Future<void> sendLocalNotification(String title, String body,
      {Map<String, dynamic>? data}) async {
    await _remoteDataSource.sendLocalNotification(title, body, data: data);
  }

  @override
  Future<void> sendNotificationToUser(String userId, String title, String body,
      {Map<String, dynamic>? data}) async {
    await _remoteDataSource.addNotification(userId, {
      'title': title,
      'body': body,
      'data': data,
    });
  }

  @override
  Future<void> sendNotificationToSquad(
      String squadId, String title, String body,
      {Map<String, dynamic>? data}) async {
    // This would need to get squad members and send to each
    // For now, just send to the current user as an example
    final user = _authService.currentUser;
    if (user != null) {
      await sendNotificationToUser(user.id, title, body, data: data);
    }
  }

  @override
  Future<void> scheduleNotification(
      DateTime scheduledTime, String title, String body,
      {Map<String, dynamic>? data}) async {
    await _remoteDataSource
        .scheduleLocalNotification(scheduledTime, title, body, data: data);
  }

  @override
  Future<void> addNotification(Map<String, dynamic> notification) async {
    final user = _authService.currentUser;
    if (user != null) {
      await _remoteDataSource.addNotification(user.id, notification);
    }
  }

  @override
  Future<void> markNotificationsAsRead() async {
    final user = _authService.currentUser;
    if (user != null) {
      await _remoteDataSource.markNotificationsAsRead(user.id);
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    await _remoteDataSource.deleteNotification(notificationId);
  }

  @override
  Future<void> addAvailabilitySlot(Map<String, dynamic> slot) async {
    final user = _authService.currentUser;
    if (user != null) {
      await _remoteDataSource.addAvailabilitySlot(user.id, slot);
    }
  }

  @override
  Future<void> removeAvailabilitySlot(String slotId) async {
    await _remoteDataSource.removeAvailabilitySlot(slotId);
  }

  @override
  Future<void> updateAvailabilitySlot(
      String slotId, Map<String, dynamic> updates) async {
    await _remoteDataSource.updateAvailabilitySlot(slotId, updates);
  }

  @override
  Future<void> submitBanVote(String targetUserId, bool vote) async {
    final user = _authService.currentUser;
    if (user != null) {
      await _remoteDataSource.submitBanVote(user.id, targetUserId, vote);
    }
  }

  @override
  Future<void> processBanVotes() async {
    // Implementation for processing ban votes
    // This would typically involve checking vote counts and applying bans
  }

  @override
  Future<void> clearOldNotifications({Duration? olderThan}) async {
    await _remoteDataSource.clearOldNotifications(olderThan: olderThan);
  }

  @override
  Future<void> resetDailyVotes() async {
    await _remoteDataSource.resetDailyVotes();
  }

  @override
  Future<void> purgeOldData({Duration? olderThan}) async {
    await _remoteDataSource.purgeOldData(olderThan: olderThan);
  }

  @override
  Future<void> banUser(String userId, String reason) async {
    await _remoteDataSource.banUser(userId, reason);
  }

  @override
  Future<void> unbanUser(String userId) async {
    await _remoteDataSource.unbanUser(userId);
  }

  @override
  Future<bool> checkAvailability() async {
    return await _remoteDataSource.checkAvailability();
  }
}
