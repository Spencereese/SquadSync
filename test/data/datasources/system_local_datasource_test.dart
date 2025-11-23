import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_sync/data/datasources/system_local_datasource.dart';
import 'package:squad_sync/domain/entities/system_state.dart';

// Manual mock classes
class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  late SystemLocalDataSourceImpl datasource;
  late MockSharedPreferences mockPrefs;

  setUp(() {
    mockPrefs = MockSharedPreferences();
    datasource = SystemLocalDataSourceImpl(mockPrefs);
  });

  group('SystemLocalDataSourceImpl', () {
    group('loadSystemState', () {
      test('should load complete system state from SharedPreferences', () async {
        // Arrange
        when(mockPrefs.getString('theme_mode')).thenReturn('dark');
        when(mockPrefs.getBool('notifications_enabled')).thenReturn(true);
        when(mockPrefs.getBool('sound_enabled')).thenReturn(false);
        when(mockPrefs.getBool('vibration_enabled')).thenReturn(true);
        when(mockPrefs.getInt('last_sync_timestamp')).thenReturn(1640995200000); // 2022-01-01 00:00:00 UTC
        when(mockPrefs.getString('analytics_metrics')).thenReturn('{"totalUsers":150,"activeSquads":25}');

        // Act
        final result = await datasource.loadSystemState();

        // Assert
        expect(result.themeMode, ThemeMode.dark);
        expect(result.notificationsEnabled, true);
        expect(result.soundEnabled, false);
        expect(result.vibrationEnabled, true);
        expect(result.lastSyncTimestamp, DateTime.fromMillisecondsSinceEpoch(1640995200000));
        expect(result.analyticsMetrics['totalUsers'], 150);
        expect(result.analyticsMetrics['activeSquads'], 25);
      });

      test('should return initial state when SharedPreferences is empty', () async {
        // Arrange
        when(mockPrefs.getString('theme_mode')).thenReturn(null);
        when(mockPrefs.getBool('notifications_enabled')).thenReturn(null);
        when(mockPrefs.getBool('sound_enabled')).thenReturn(null);
        when(mockPrefs.getBool('vibration_enabled')).thenReturn(null);
        when(mockPrefs.getInt('last_sync_timestamp')).thenReturn(null);
        when(mockPrefs.getString('analytics_metrics')).thenReturn(null);

        // Act
        final result = await datasource.loadSystemState();

        // Assert
        expect(result.themeMode, ThemeMode.system);
        expect(result.notificationsEnabled, true);
        expect(result.soundEnabled, true);
        expect(result.vibrationEnabled, true);
        expect(result.lastSyncTimestamp, null);
        expect(result.analyticsMetrics, {});
      });

      test('should handle corrupted analytics metrics JSON', () async {
        // Arrange
        when(mockPrefs.getString('theme_mode')).thenReturn('light');
        when(mockPrefs.getBool('notifications_enabled')).thenReturn(true);
        when(mockPrefs.getBool('sound_enabled')).thenReturn(true);
        when(mockPrefs.getBool('vibration_enabled')).thenReturn(true);
        when(mockPrefs.getInt('last_sync_timestamp')).thenReturn(null);
        when(mockPrefs.getString('analytics_metrics')).thenReturn('invalid json');

        // Act
        final result = await datasource.loadSystemState();

        // Assert
        expect(result.themeMode, ThemeMode.light);
        expect(result.notificationsEnabled, true);
        expect(result.analyticsMetrics, {}); // Should default to empty map
      });
    });

    group('saveSystemState', () {
      test('should save complete system state to SharedPreferences', () async {
        // Arrange
        final state = SystemState(
          themeMode: ThemeMode.dark,
          notificationsEnabled: false,
          soundEnabled: true,
          vibrationEnabled: false,
          lastSyncTimestamp: DateTime(2023, 12, 25, 10, 30),
          analyticsMetrics: {'totalUsers': 200, 'messagesSent': 1500},
          notifications: [],
          availabilitySlots: [],
          dailyBanVotes: {},
          bans: [],
          hasNewNotifications: false,
          hasNewAvailability: false,
          isInitialized: true,
        );

        when(mockPrefs.setString('theme_mode', 'dark')).thenAnswer((_) async => true);
        when(mockPrefs.setBool('notifications_enabled', false)).thenAnswer((_) async => true);
        when(mockPrefs.setBool('sound_enabled', true)).thenAnswer((_) async => true);
        when(mockPrefs.setBool('vibration_enabled', false)).thenAnswer((_) async => true);
        when(mockPrefs.setInt('last_sync_timestamp', 1703500200000)).thenAnswer((_) async => true);
        when(mockPrefs.setString('analytics_metrics', '{"totalUsers":200,"messagesSent":1500}')).thenAnswer((_) async => true);

        // Act
        await datasource.saveSystemState(state);

        // Assert
        verify(mockPrefs.setString('theme_mode', 'dark')).called(1);
        verify(mockPrefs.setBool('notifications_enabled', false)).called(1);
        verify(mockPrefs.setBool('sound_enabled', true)).called(1);
        verify(mockPrefs.setBool('vibration_enabled', false)).called(1);
        verify(mockPrefs.setInt('last_sync_timestamp', 1703500200000)).called(1);
        verify(mockPrefs.setString('analytics_metrics', '{"totalUsers":200,"messagesSent":1500}')).called(1);
      });
    });

    group('getThemeMode', () {
      test('should return ThemeMode.dark when stored as "dark"', () async {
        // Arrange
        when(mockPrefs.getString('theme_mode')).thenReturn('dark');

        // Act
        final result = await datasource.getThemeMode();

        // Assert
        expect(result, ThemeMode.dark);
      });

      test('should return ThemeMode.light when stored as "light"', () async {
        // Arrange
        when(mockPrefs.getString('theme_mode')).thenReturn('light');

        // Act
        final result = await datasource.getThemeMode();

        // Assert
        expect(result, ThemeMode.light);
      });

      test('should return ThemeMode.system when stored as "system"', () async {
        // Arrange
        when(mockPrefs.getString('theme_mode')).thenReturn('system');

        // Act
        final result = await datasource.getThemeMode();

        // Assert
        expect(result, ThemeMode.system);
      });

      test('should return ThemeMode.system for invalid stored value', () async {
        // Arrange
        when(mockPrefs.getString('theme_mode')).thenReturn('invalid');

        // Act
        final result = await datasource.getThemeMode();

        // Assert
        expect(result, ThemeMode.system);
      });

      test('should return ThemeMode.system when no value stored', () async {
        // Arrange
        when(mockPrefs.getString('theme_mode')).thenReturn(null);

        // Act
        final result = await datasource.getThemeMode();

        // Assert
        expect(result, ThemeMode.system);
      });
    });

    group('setThemeMode', () {
      test('should store ThemeMode.dark as "dark"', () async {
        // Arrange
        when(mockPrefs.setString('theme_mode', 'dark')).thenAnswer((_) async => true);

        // Act
        await datasource.setThemeMode(ThemeMode.dark);

        // Assert
        verify(mockPrefs.setString('theme_mode', 'dark')).called(1);
      });

      test('should store ThemeMode.light as "light"', () async {
        // Arrange
        when(mockPrefs.setString('theme_mode', 'light')).thenAnswer((_) async => true);

        // Act
        await datasource.setThemeMode(ThemeMode.light);

        // Assert
        verify(mockPrefs.setString('theme_mode', 'light')).called(1);
      });

      test('should store ThemeMode.system as "system"', () async {
        // Arrange
        when(mockPrefs.setString('theme_mode', 'system')).thenAnswer((_) async => true);

        // Act
        await datasource.setThemeMode(ThemeMode.system);

        // Assert
        verify(mockPrefs.setString('theme_mode', 'system')).called(1);
      });
    });

    group('getNotificationsEnabled', () {
      test('should return true when stored as true', () async {
        // Arrange
        when(mockPrefs.getBool('notifications_enabled')).thenReturn(true);

        // Act
        final result = await datasource.getNotificationsEnabled();

        // Assert
        expect(result, true);
      });

      test('should return false when stored as false', () async {
        // Arrange
        when(mockPrefs.getBool('notifications_enabled')).thenReturn(false);

        // Act
        final result = await datasource.getNotificationsEnabled();

        // Assert
        expect(result, false);
      });

      test('should return true when no value stored (default)', () async {
        // Arrange
        when(mockPrefs.getBool('notifications_enabled')).thenReturn(null);

        // Act
        final result = await datasource.getNotificationsEnabled();

        // Assert
        expect(result, true);
      });
    });

    group('setNotificationsEnabled', () {
      test('should store true value', () async {
        // Arrange
        when(mockPrefs.setBool('notifications_enabled', true)).thenAnswer((_) async => true);

        // Act
        await datasource.setNotificationsEnabled(true);

        // Assert
        verify(mockPrefs.setBool('notifications_enabled', true)).called(1);
      });

      test('should store false value', () async {
        // Arrange
        when(mockPrefs.setBool('notifications_enabled', false)).thenAnswer((_) async => true);

        // Act
        await datasource.setNotificationsEnabled(false);

        // Assert
        verify(mockPrefs.setBool('notifications_enabled', false)).called(1);
      });
    });

    group('getLastSyncTimestamp', () {
      test('should return correct DateTime from milliseconds', () async {
        // Arrange
        final timestamp = DateTime(2023, 12, 25, 10, 30).millisecondsSinceEpoch;
        when(mockPrefs.getInt('last_sync_timestamp')).thenReturn(timestamp);

        // Act
        final result = await datasource.getLastSyncTimestamp();

        // Assert
        expect(result, DateTime(2023, 12, 25, 10, 30));
      });

      test('should return null when no timestamp stored', () async {
        // Arrange
        when(mockPrefs.getInt('last_sync_timestamp')).thenReturn(null);

        // Act
        final result = await datasource.getLastSyncTimestamp();

        // Assert
        expect(result, null);
      });
    });

    group('setLastSyncTimestamp', () {
      test('should store timestamp as milliseconds', () async {
        // Arrange
        final timestamp = DateTime(2023, 12, 25, 10, 30);
        final expectedMillis = timestamp.millisecondsSinceEpoch;
        when(mockPrefs.setInt('last_sync_timestamp', expectedMillis)).thenAnswer((_) async => true);

        // Act
        await datasource.setLastSyncTimestamp(timestamp);

        // Assert
        verify(mockPrefs.setInt('last_sync_timestamp', expectedMillis)).called(1);
      });
    });

    group('getAnalyticsMetrics', () {
      test('should return parsed JSON metrics', () async {
        // Arrange
        const jsonString = '{"totalUsers":150,"activeSquads":25,"messagesSent":1200}';
        when(mockPrefs.getString('analytics_metrics')).thenReturn(jsonString);

        // Act
        final result = await datasource.getAnalyticsMetrics();

        // Assert
        expect(result['totalUsers'], 150);
        expect(result['activeSquads'], 25);
        expect(result['messagesSent'], 1200);
      });

      test('should return empty map when no metrics stored', () async {
        // Arrange
        when(mockPrefs.getString('analytics_metrics')).thenReturn(null);

        // Act
        final result = await datasource.getAnalyticsMetrics();

        // Assert
        expect(result, {});
      });

      test('should return empty map for invalid JSON', () async {
        // Arrange
        when(mockPrefs.getString('analytics_metrics')).thenReturn('invalid json');

        // Act
        final result = await datasource.getAnalyticsMetrics();

        // Assert
        expect(result, {});
      });
    });

    group('saveAnalyticsMetrics', () {
      test('should serialize and store metrics as JSON', () async {
        // Arrange
        final metrics = {'totalUsers': 200, 'messagesSent': 1500, 'gamesPlayed': 89};
        const expectedJson = '{"totalUsers":200,"messagesSent":1500,"gamesPlayed":89}';
        when(mockPrefs.setString('analytics_metrics', expectedJson)).thenAnswer((_) async => true);

        // Act
        await datasource.saveAnalyticsMetrics(metrics);

        // Assert
        verify(mockPrefs.setString('analytics_metrics', expectedJson)).called(1);
      });

      test('should handle empty metrics map', () async {
        // Arrange
        final metrics = <String, dynamic>{};
        const expectedJson = '{}';
        when(mockPrefs.setString('analytics_metrics', expectedJson)).thenAnswer((_) async => true);

        // Act
        await datasource.saveAnalyticsMetrics(metrics);

        // Assert
        verify(mockPrefs.setString('analytics_metrics', expectedJson)).called(1);
      });
    });
  });
}

