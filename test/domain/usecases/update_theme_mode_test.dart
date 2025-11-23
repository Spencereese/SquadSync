import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/system_state.dart';
import 'package:squad_sync/domain/repositories/system_repository.dart';
import 'package:squad_sync/domain/usecases/update_theme_mode.dart';

// Mock class for SystemRepository
class MockSystemRepository implements SystemRepository {
  ThemeMode? _lastUpdatedThemeMode;
  Exception? _updateThemeModeException;

  void setUpdateThemeModeException(Exception exception) {
    _updateThemeModeException = exception;
  }

  ThemeMode? get lastUpdatedThemeMode => _lastUpdatedThemeMode;

  @override
  Future<void> updateThemeMode(ThemeMode themeMode) async {
    if (_updateThemeModeException != null) {
      throw _updateThemeModeException!;
    }
    _lastUpdatedThemeMode = themeMode;
  }

  @override
  Future<SystemState> loadSystemState() => throw UnimplementedError();

  @override
  Future<void> saveSystemState(SystemState state) => throw UnimplementedError();

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
  late UpdateThemeMode usecase;

  setUp(() {
    mockSystemRepository = MockSystemRepository();
    usecase = UpdateThemeMode(mockSystemRepository);
  });

  group('UpdateThemeMode', () {
    test('should update theme mode to dark successfully', () async {
      // Act
      await usecase.call(ThemeMode.dark);

      // Assert
      expect(mockSystemRepository.lastUpdatedThemeMode, ThemeMode.dark);
    });

    test('should update theme mode to light successfully', () async {
      // Act
      await usecase.call(ThemeMode.light);

      // Assert
      expect(mockSystemRepository.lastUpdatedThemeMode, ThemeMode.light);
    });

    test('should update theme mode to system successfully', () async {
      // Act
      await usecase.call(ThemeMode.system);

      // Assert
      expect(mockSystemRepository.lastUpdatedThemeMode, ThemeMode.system);
    });

    test('should handle repository exceptions', () async {
      // Arrange
      final exception = Exception('Failed to update theme mode');
      mockSystemRepository.setUpdateThemeModeException(exception);

      // Act & Assert
      expect(
        () => usecase.call(ThemeMode.dark),
        throwsA(equals(exception)),
      );
    });

    test('should handle SharedPreferences write errors', () async {
      // Arrange
      final prefsException = Exception('SharedPreferences write failed');
      mockSystemRepository.setUpdateThemeModeException(prefsException);

      // Act & Assert
      expect(
        () => usecase.call(ThemeMode.light),
        throwsA(equals(prefsException)),
      );
    });

    test('should handle permission denied errors', () async {
      // Arrange
      final permissionException = Exception('Permission denied to update settings');
      mockSystemRepository.setUpdateThemeModeException(permissionException);

      // Act & Assert
      expect(
        () => usecase.call(ThemeMode.system),
        throwsA(equals(permissionException)),
      );
    });

    test('should handle all ThemeMode enum values', () async {
      // Test all enum values
      for (final themeMode in ThemeMode.values) {
        // Reset mock
        mockSystemRepository = MockSystemRepository();
        usecase = UpdateThemeMode(mockSystemRepository);

        // Act
        await usecase.call(themeMode);

        // Assert
        expect(mockSystemRepository.lastUpdatedThemeMode, themeMode);
      }
    });
  });
}