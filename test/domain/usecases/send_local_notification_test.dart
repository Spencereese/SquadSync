import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/system_state.dart';
import 'package:squad_sync/domain/repositories/system_repository.dart';
import 'package:squad_sync/domain/usecases/send_local_notification.dart';

// Mock class for SystemRepository
class MockSystemRepository implements SystemRepository {
  String? _lastNotificationTitle;
  String? _lastNotificationBody;
  Map<String, dynamic>? _lastNotificationData;
  Exception? _sendLocalNotificationException;

  void setSendLocalNotificationException(Exception exception) {
    _sendLocalNotificationException = exception;
  }

  String? get lastNotificationTitle => _lastNotificationTitle;
  String? get lastNotificationBody => _lastNotificationBody;
  Map<String, dynamic>? get lastNotificationData => _lastNotificationData;

  @override
  Future<void> sendLocalNotification(String title, String body, {Map<String, dynamic>? data}) async {
    if (_sendLocalNotificationException != null) {
      throw _sendLocalNotificationException!;
    }
    _lastNotificationTitle = title;
    _lastNotificationBody = body;
    _lastNotificationData = data;
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
  Future<void> updateLastSyncTimestamp(DateTime timestamp) => throw UnimplementedError();

  @override
  Future<void> trackAnalyticsEvent(String event, Map<String, dynamic> data) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getAnalyticsMetrics() => throw UnimplementedError();

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
  late SendLocalNotification usecase;

  setUp(() {
    mockSystemRepository = MockSystemRepository();
    usecase = SendLocalNotification(mockSystemRepository);
  });

  group('SendLocalNotification', () {
    const title = 'Squad Match Starting';
    const body = 'Your Call of Duty match begins in 5 minutes!';
    final data = {
      'squadId': 'squad123',
      'gameName': 'Call of Duty',
      'matchTime': DateTime(2023, 12, 25, 15, 0).toIso8601String(),
    };

    test('should send local notification successfully', () async {
      // Act
      await usecase.call(title, body, data: data);

      // Assert
      expect(mockSystemRepository.lastNotificationTitle, title);
      expect(mockSystemRepository.lastNotificationBody, body);
      expect(mockSystemRepository.lastNotificationData, data);
    });

    test('should send notification without data', () async {
      // Arrange
      const simpleTitle = 'Reminder';
      const simpleBody = 'Don\'t forget your squad meeting';

      // Act
      await usecase.call(simpleTitle, simpleBody);

      // Assert
      expect(mockSystemRepository.lastNotificationTitle, simpleTitle);
      expect(mockSystemRepository.lastNotificationBody, simpleBody);
      expect(mockSystemRepository.lastNotificationData, null);
    });

    test('should send notification with empty data map', () async {
      // Arrange
      const emptyDataTitle = 'System Update';
      const emptyDataBody = 'App updated successfully';
      final emptyData = <String, dynamic>{};

      // Act
      await usecase.call(emptyDataTitle, emptyDataBody, data: emptyData);

      // Assert
      expect(mockSystemRepository.lastNotificationTitle, emptyDataTitle);
      expect(mockSystemRepository.lastNotificationBody, emptyDataBody);
      expect(mockSystemRepository.lastNotificationData, emptyData);
    });

    test('should handle complex notification data', () async {
      // Arrange
      const complexTitle = 'Tournament Invitation';
      const complexBody = 'You\'ve been invited to the Championship Finals';
      final complexData = {
        'tournamentId': 'tourney_789',
        'bracket': 'finals',
        'participants': ['user1', 'user2', 'user3', 'user4'],
        'prize': 1000,
        'metadata': {
          'game': 'Call of Duty',
          'mode': 'Search & Destroy',
          'maxPlayers': 4,
        },
      };

      // Act
      await usecase.call(complexTitle, complexBody, data: complexData);

      // Assert
      expect(mockSystemRepository.lastNotificationTitle, complexTitle);
      expect(mockSystemRepository.lastNotificationBody, complexBody);
      expect(mockSystemRepository.lastNotificationData, complexData);
      expect(mockSystemRepository.lastNotificationData!['metadata']['game'], 'Call of Duty');
    });

    test('should handle repository exceptions', () async {
      // Arrange
      final exception = Exception('Failed to send local notification');
      mockSystemRepository.setSendLocalNotificationException(exception);

      // Act & Assert
      expect(
        () => usecase.call(title, body, data: data),
        throwsA(equals(exception)),
      );
    });

    test('should handle notification permission denied', () async {
      // Arrange
      final permissionException = Exception('Notification permission denied');
      mockSystemRepository.setSendLocalNotificationException(permissionException);

      // Act & Assert
      expect(
        () => usecase.call(title, body),
        throwsA(equals(permissionException)),
      );
    });

    test('should handle platform not supported', () async {
      // Arrange
      final platformException = Exception('Local notifications not supported on this platform');
      mockSystemRepository.setSendLocalNotificationException(platformException);

      // Act & Assert
      expect(
        () => usecase.call(title, body, data: data),
        throwsA(equals(platformException)),
      );
    });

    test('should handle notification service unavailable', () async {
      // Arrange
      final serviceException = Exception('Notification service temporarily unavailable');
      mockSystemRepository.setSendLocalNotificationException(serviceException);

      // Act & Assert
      expect(
        () => usecase.call(title, body),
        throwsA(equals(serviceException)),
      );
    });
  });
}