import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/system_state.dart';
import 'package:squad_sync/domain/repositories/system_repository.dart';
import 'package:squad_sync/domain/usecases/track_analytics_event.dart';

// Mock class for SystemRepository
class MockSystemRepository implements SystemRepository {
  String? _lastTrackedEvent;
  Map<String, dynamic>? _lastTrackedData;
  Exception? _trackAnalyticsEventException;

  void setTrackAnalyticsEventException(Exception exception) {
    _trackAnalyticsEventException = exception;
  }

  String? get lastTrackedEvent => _lastTrackedEvent;
  Map<String, dynamic>? get lastTrackedData => _lastTrackedData;

  @override
  Future<void> trackAnalyticsEvent(String event, Map<String, dynamic> data) async {
    if (_trackAnalyticsEventException != null) {
      throw _trackAnalyticsEventException!;
    }
    _lastTrackedEvent = event;
    _lastTrackedData = data;
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
  late TrackAnalyticsEvent usecase;

  setUp(() {
    mockSystemRepository = MockSystemRepository();
    usecase = TrackAnalyticsEvent(mockSystemRepository);
  });

  group('TrackAnalyticsEvent', () {
    const eventName = 'user_login';
    final eventData = {
      'userId': 'user123',
      'timestamp': DateTime(2023, 12, 25, 10, 30).toIso8601String(),
      'platform': 'ios',
      'version': '1.2.3',
    };

    test('should track analytics event successfully', () async {
      // Act
      await usecase.call(eventName, eventData);

      // Assert
      expect(mockSystemRepository.lastTrackedEvent, eventName);
      expect(mockSystemRepository.lastTrackedData, eventData);
    });

    test('should track event with empty data map', () async {
      // Arrange
      const emptyEvent = 'app_open';
      final emptyData = <String, dynamic>{};

      // Act
      await usecase.call(emptyEvent, emptyData);

      // Assert
      expect(mockSystemRepository.lastTrackedEvent, emptyEvent);
      expect(mockSystemRepository.lastTrackedData, emptyData);
    });

    test('should track complex event data', () async {
      // Arrange
      const complexEvent = 'game_session';
      final complexData = {
        'sessionId': 'session_456',
        'gameName': 'Call of Duty',
        'duration': 1800, // 30 minutes in seconds
        'players': ['user1', 'user2', 'user3'],
        'result': 'victory',
        'metadata': {
          'map': 'Warzone',
          'mode': 'Battle Royale',
          'kills': 12,
          'deaths': 3,
        },
      };

      // Act
      await usecase.call(complexEvent, complexData);

      // Assert
      expect(mockSystemRepository.lastTrackedEvent, complexEvent);
      expect(mockSystemRepository.lastTrackedData, complexData);
      expect(mockSystemRepository.lastTrackedData!['metadata']['kills'], 12);
    });

    test('should handle repository exceptions', () async {
      // Arrange
      final exception = Exception('Failed to track analytics event');
      mockSystemRepository.setTrackAnalyticsEventException(exception);

      // Act & Assert
      expect(
        () => usecase.call(eventName, eventData),
        throwsA(equals(exception)),
      );
    });

    test('should handle PostgreSQL connection errors', () async {
      // Arrange
      final dbException = Exception('PostgreSQL connection failed');
      mockSystemRepository.setTrackAnalyticsEventException(dbException);

      // Act & Assert
      expect(
        () => usecase.call(eventName, eventData),
        throwsA(equals(dbException)),
      );
    });

    test('should handle analytics service unavailable', () async {
      // Arrange
      final serviceException = Exception('Analytics service temporarily unavailable');
      mockSystemRepository.setTrackAnalyticsEventException(serviceException);

      // Act & Assert
      expect(
        () => usecase.call(eventName, eventData),
        throwsA(equals(serviceException)),
      );
    });

    test('should handle network timeout', () async {
      // Arrange
      final timeoutException = Exception('Network timeout during analytics tracking');
      mockSystemRepository.setTrackAnalyticsEventException(timeoutException);

      // Act & Assert
      expect(
        () => usecase.call(eventName, eventData),
        throwsA(equals(timeoutException)),
      );
    });

    test('should handle invalid event data', () async {
      // Arrange
      final validationException = Exception('Invalid analytics event data format');
      mockSystemRepository.setTrackAnalyticsEventException(validationException);

      // Act & Assert
      expect(
        () => usecase.call(eventName, eventData),
        throwsA(equals(validationException)),
      );
    });
  });
}