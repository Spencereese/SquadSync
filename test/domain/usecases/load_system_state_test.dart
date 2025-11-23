import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/system_state.dart';
import 'package:squad_sync/domain/repositories/system_repository.dart';
import 'package:squad_sync/domain/usecases/load_system_state.dart';

// Mock class for SystemRepository
class MockSystemRepository implements SystemRepository {
  SystemState? _loadSystemStateResponse;
  Exception? _loadSystemStateException;

  void setLoadSystemStateResponse(SystemState response) {
    _loadSystemStateResponse = response;
    _loadSystemStateException = null;
  }

  void setLoadSystemStateException(Exception exception) {
    _loadSystemStateException = exception;
    _loadSystemStateResponse = null;
  }

  @override
  Future<SystemState> loadSystemState() async {
    if (_loadSystemStateException != null) {
      throw _loadSystemStateException!;
    }
    return _loadSystemStateResponse ?? SystemState.initial();
  }

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
  late LoadSystemState usecase;

  setUp(() {
    mockSystemRepository = MockSystemRepository();
    usecase = LoadSystemState(mockSystemRepository);
  });

  group('LoadSystemState', () {
    final mockSystemState = SystemState(
      themeMode: ThemeMode.dark,
      notificationsEnabled: true,
      soundEnabled: false,
      vibrationEnabled: true,
      lastSyncTimestamp: DateTime(2023, 12, 25, 10, 30),
      analyticsMetrics: {
        'totalUsers': 150,
        'activeSquads': 25,
        'messagesSent': 1200,
      },
      notifications: [
        {
          'id': 'notif1',
          'title': 'New Squad Invite',
          'body': 'You have been invited to join Squad Alpha',
          'timestamp': DateTime(2023, 12, 25, 9, 0).toIso8601String(),
          'read': false,
        },
      ],
      availabilitySlots: [],
      dailyBanVotes: {},
      bans: [],
      hasNewNotifications: true,
      hasNewAvailability: false,
      isInitialized: true,
      errorMessage: null,
    );

    test('should return system state when repository succeeds', () async {
      // Arrange
      mockSystemRepository.setLoadSystemStateResponse(mockSystemState);

      // Act
      final result = await usecase.call();

      // Assert
      expect(result, equals(mockSystemState));
    });

    test('should return initial state when repository returns default', () async {
      // Arrange
      final initialState = SystemState.initial();
      mockSystemRepository.setLoadSystemStateResponse(initialState);

      // Act
      final result = await usecase.call();

      // Assert
      expect(result, equals(initialState));
      expect(result.themeMode, ThemeMode.system);
      expect(result.notificationsEnabled, true);
      expect(result.isInitialized, false);
    });

    test('should propagate repository exceptions', () async {
      // Arrange
      final exception = Exception('Failed to load system state');
      mockSystemRepository.setLoadSystemStateException(exception);

      // Act & Assert
      expect(
        () => usecase.call(),
        throwsA(equals(exception)),
      );
    });

    test('should handle network errors', () async {
      // Arrange
      final networkException = Exception('Network connection failed');
      mockSystemRepository.setLoadSystemStateException(networkException);

      // Act & Assert
      expect(
        () => usecase.call(),
        throwsA(equals(networkException)),
      );
    });

    test('should handle SharedPreferences errors', () async {
      // Arrange
      final prefsException = Exception('SharedPreferences access denied');
      mockSystemRepository.setLoadSystemStateException(prefsException);

      // Act & Assert
      expect(
        () => usecase.call(),
        throwsA(equals(prefsException)),
      );
    });

    test('should handle corrupted data errors', () async {
      // Arrange
      final corruptionException = Exception('Corrupted system state data');
      mockSystemRepository.setLoadSystemStateException(corruptionException);

      // Act & Assert
      expect(
        () => usecase.call(),
        throwsA(equals(corruptionException)),
      );
    });
  });
}