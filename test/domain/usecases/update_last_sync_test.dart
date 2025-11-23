import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/system_state.dart';
import 'package:squad_sync/domain/repositories/system_repository.dart';
import 'package:squad_sync/domain/usecases/update_last_sync.dart';

// Mock class for SystemRepository
class MockSystemRepository implements SystemRepository {
  DateTime? _lastUpdatedTimestamp;
  Exception? _updateLastSyncTimestampException;

  void setUpdateLastSyncTimestampException(Exception exception) {
    _updateLastSyncTimestampException = exception;
  }

  DateTime? get lastUpdatedTimestamp => _lastUpdatedTimestamp;

  @override
  Future<void> updateLastSyncTimestamp(DateTime timestamp) async {
    if (_updateLastSyncTimestampException != null) {
      throw _updateLastSyncTimestampException!;
    }
    _lastUpdatedTimestamp = timestamp;
  }

  @override
  Future<SystemState> loadSystemState() => throw UnimplementedError();

  @override
  Future<void> saveSystemState(SystemState state) => throw UnimplementedError();

  @override
  Future<void> updateThemeMode(ThemeMode themeMode) => throw UnimplementedError();

  @override
  Future<void> updateNotificationSettings(bool enabled) => throw UnimplementedError();

  @override
  Future<void> updateSoundSettings(bool enabled) => throw UnimplementedError();

  @override
  Future<void> updateVibrationSettings(bool enabled) => throw UnimplementedError();

  @override
  Future<void> trackAnalyticsEvent(String event, Map<String, dynamic> data) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getAnalyticsMetrics() => throw UnimplementedError();

  @override
  Future<void> sendLocalNotification(String title, String body, {Map<String, dynamic>? data}) => throw UnimplementedError();

  @override
  Future<void> sendNotificationToUser(String userId, String title, String body, {Map<String, dynamic>? data}) => throw UnimplementedError();

  @override
  Future<void> sendNotificationToSquad(String squadId, String title, String body, {Map<String, dynamic>? data}) => throw UnimplementedError();

  @override
  Future<void> scheduleNotification(DateTime scheduledTime, String title, String body, {Map<String, dynamic>? data}) => throw UnimplementedError();

  @override
  Future<void> addNotification(Map<String, dynamic> notification) => throw UnimplementedError();

  @override
  Future<void> markNotificationsAsRead() => throw UnimplementedError();

  @override
  Future<void> deleteNotification(String notificationId) => throw UnimplementedError();

  @override
  Future<void> addAvailabilitySlot(Map<String, dynamic> slot) => throw UnimplementedError();

  @override
  Future<void> removeAvailabilitySlot(String slotId) => throw UnimplementedError();

  @override
  Future<void> updateAvailabilitySlot(String slotId, Map<String, dynamic> updates) => throw UnimplementedError();

  @override
  Future<void> submitBanVote(String targetUserId, bool vote) => throw UnimplementedError();

  @override
  Future<void> processBanVotes() => throw UnimplementedError();

  @override
  Future<void> clearOldNotifications({Duration? olderThan}) => throw UnimplementedError();

  @override
  Future<void> resetDailyVotes() => throw UnimplementedError();

  @override
  Future<void> purgeOldData({Duration? olderThan}) => throw UnimplementedError();
}

void main() {
  late MockSystemRepository mockSystemRepository;
  late UpdateLastSync usecase;

  setUp(() {
    mockSystemRepository = MockSystemRepository();
    usecase = UpdateLastSync(mockSystemRepository);
  });

  group('UpdateLastSync', () {
    final testTimestamp = DateTime(2023, 12, 25, 10, 30, 45);

    test('should update last sync timestamp successfully', () async {
      // Act
      await usecase.call(testTimestamp);

      // Assert
      expect(mockSystemRepository.lastUpdatedTimestamp, testTimestamp);
    });

    test('should update with current timestamp', () async {
      // Arrange
      final now = DateTime.now();

      // Act
      await usecase.call(now);

      // Assert
      expect(mockSystemRepository.lastUpdatedTimestamp, now);
    });

    test('should update with past timestamp', () async {
      // Arrange
      final pastTimestamp = DateTime(2023, 1, 1, 0, 0, 0);

      // Act
      await usecase.call(pastTimestamp);

      // Assert
      expect(mockSystemRepository.lastUpdatedTimestamp, pastTimestamp);
    });

    test('should update with future timestamp', () async {
      // Arrange
      final futureTimestamp = DateTime(2025, 12, 31, 23, 59, 59);

      // Act
      await usecase.call(futureTimestamp);

      // Assert
      expect(mockSystemRepository.lastUpdatedTimestamp, futureTimestamp);
    });

    test('should handle repository exceptions', () async {
      // Arrange
      final exception = Exception('Failed to update last sync timestamp');
      mockSystemRepository.setUpdateLastSyncTimestampException(exception);

      // Act & Assert
      expect(
        () => usecase.call(testTimestamp),
        throwsA(equals(exception)),
      );
    });

    test('should handle SharedPreferences write errors', () async {
      // Arrange
      final prefsException = Exception('SharedPreferences write failed');
      mockSystemRepository.setUpdateLastSyncTimestampException(prefsException);

      // Act & Assert
      expect(
        () => usecase.call(testTimestamp),
        throwsA(equals(prefsException)),
      );
    });

    test('should handle permission denied errors', () async {
      // Arrange
      final permissionException = Exception('Permission denied to update sync timestamp');
      mockSystemRepository.setUpdateLastSyncTimestampException(permissionException);

      // Act & Assert
      expect(
        () => usecase.call(testTimestamp),
        throwsA(equals(permissionException)),
      );
    });

    test('should handle disk space errors', () async {
      // Arrange
      final diskException = Exception('Insufficient disk space to save timestamp');
      mockSystemRepository.setUpdateLastSyncTimestampException(diskException);

      // Act & Assert
      expect(
        () => usecase.call(testTimestamp),
        throwsA(equals(diskException)),
      );
    });

    test('should handle concurrent modification errors', () async {
      // Arrange
      final concurrentException = Exception('Concurrent modification detected');
      mockSystemRepository.setUpdateLastSyncTimestampException(concurrentException);

      // Act & Assert
      expect(
        () => usecase.call(testTimestamp),
        throwsA(equals(concurrentException)),
      );
    });
  });
}