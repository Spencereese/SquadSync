import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/data/datasources/system_local_datasource.dart';
import 'package:squad_sync/data/datasources/system_remote_datasource.dart';
import 'package:squad_sync/data/repositories/system_repository_impl.dart';
import 'package:squad_sync/domain/entities/system_state.dart';
import '../../helpers/mocks.mocks.dart';

void main() {
  late SystemRepositoryImpl repository;
  late MockSystemLocalDataSourceImpl mockLocalDataSource;
  late MockSystemRemoteDataSourceImpl mockRemoteDataSource;

  setUp(() {
    mockLocalDataSource = MockSystemLocalDataSourceImpl();
    mockRemoteDataSource = MockSystemRemoteDataSourceImpl();
    repository = SystemRepositoryImpl(
      mockLocalDataSource,
      mockRemoteDataSource,
    );
  });

  group('SystemRepositoryImpl', () {
    group('loadSystemState', () {
      test('should load system state from local datasource', () async {
        // Arrange
        final expectedState = SystemState.initial().copyWith(
          themeMode: ThemeMode.dark,
          notificationsEnabled: false,
        );
        when(mockLocalDataSource.loadSystemState()).thenAnswer((_) async => expectedState);

        // Act
        final result = await repository.loadSystemState();

        // Assert
        expect(result, expectedState);
        verify(mockLocalDataSource.loadSystemState()).called(1);
        verifyNoMoreInteractions(mockRemoteDataSource);
      });

      test('should throw exception when local datasource fails', () async {
        // Arrange
        when(mockLocalDataSource.loadSystemState()).thenThrow(Exception('Local storage error'));

        // Act & Assert
        expect(
          () => repository.loadSystemState(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('saveSystemState', () {
      test('should save system state to local datasource', () async {
        // Arrange
        final state = SystemState.initial().copyWith(themeMode: ThemeMode.light);
        when(mockLocalDataSource.saveSystemState(state)).thenAnswer((_) async => null);

        // Act
        await repository.saveSystemState(state);

        // Assert
        verify(mockLocalDataSource.saveSystemState(state)).called(1);
        verifyNoMoreInteractions(mockRemoteDataSource);
      });

      test('should throw exception when local datasource fails', () async {
        // Arrange
        final state = SystemState.initial();
        when(mockLocalDataSource.saveSystemState(state)).thenThrow(Exception('Save failed'));

        // Act & Assert
        expect(
          () => repository.saveSystemState(state),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('getThemeMode', () {
      test('should get theme mode from local datasource', () async {
        // Arrange
        when(mockLocalDataSource.getThemeMode()).thenAnswer((_) async => ThemeMode.dark);

        // Act
        final result = await repository.getThemeMode();

        // Assert
        expect(result, ThemeMode.dark);
        verify(mockLocalDataSource.getThemeMode()).called(1);
        verifyNoMoreInteractions(mockRemoteDataSource);
      });
    });

    group('setThemeMode', () {
      test('should set theme mode in local datasource', () async {
        // Arrange
        when(mockLocalDataSource.setThemeMode(ThemeMode.light)).thenAnswer((_) async => null);

        // Act
        await repository.setThemeMode(ThemeMode.light);

        // Assert
        verify(mockLocalDataSource.setThemeMode(ThemeMode.light)).called(1);
        verifyNoMoreInteractions(mockRemoteDataSource);
      });
    });

    group('getNotificationsEnabled', () {
      test('should get notifications enabled from local datasource', () async {
        // Arrange
        when(mockLocalDataSource.getNotificationsEnabled()).thenAnswer((_) async => true);

        // Act
        final result = await repository.getNotificationsEnabled();

        // Assert
        expect(result, true);
        verify(mockLocalDataSource.getNotificationsEnabled()).called(1);
        verifyNoMoreInteractions(mockRemoteDataSource);
      });
    });

    group('setNotificationsEnabled', () {
      test('should set notifications enabled in local datasource', () async {
        // Arrange
        when(mockLocalDataSource.setNotificationsEnabled(false)).thenAnswer((_) async => null);

        // Act
        await repository.setNotificationsEnabled(false);

        // Assert
        verify(mockLocalDataSource.setNotificationsEnabled(false)).called(1);
        verifyNoMoreInteractions(mockRemoteDataSource);
      });
    });

    group('getLastSyncTimestamp', () {
      test('should get last sync timestamp from local datasource', () async {
        // Arrange
        final timestamp = DateTime(2023, 12, 25);
        when(mockLocalDataSource.getLastSyncTimestamp()).thenAnswer((_) async => timestamp);

        // Act
        final result = await repository.getLastSyncTimestamp();

        // Assert
        expect(result, timestamp);
        verify(mockLocalDataSource.getLastSyncTimestamp()).called(1);
        verifyNoMoreInteractions(mockRemoteDataSource);
      });
    });

    group('setLastSyncTimestamp', () {
      test('should set last sync timestamp in local datasource', () async {
        // Arrange
        final timestamp = DateTime(2023, 12, 25);
        when(mockLocalDataSource.setLastSyncTimestamp(timestamp)).thenAnswer((_) async => null);

        // Act
        await repository.setLastSyncTimestamp(timestamp);

        // Assert
        verify(mockLocalDataSource.setLastSyncTimestamp(timestamp)).called(1);
        verifyNoMoreInteractions(mockRemoteDataSource);
      });
    });

    group('getAnalyticsMetrics', () {
      test('should get analytics metrics from local datasource', () async {
        // Arrange
        final metrics = {'totalUsers': 150, 'activeSquads': 25};
        when(mockLocalDataSource.getAnalyticsMetrics()).thenAnswer((_) async => metrics);

        // Act
        final result = await repository.getAnalyticsMetrics();

        // Assert
        expect(result, metrics);
        verify(mockLocalDataSource.getAnalyticsMetrics()).called(1);
        verifyNoMoreInteractions(mockRemoteDataSource);
      });
    });

    group('saveAnalyticsMetrics', () {
      test('should save analytics metrics to local datasource', () async {
        // Arrange
        final metrics = {'totalUsers': 200};
        when(mockLocalDataSource.saveAnalyticsMetrics(metrics)).thenAnswer((_) async => null);

        // Act
        await repository.saveAnalyticsMetrics(metrics);

        // Assert
        verify(mockLocalDataSource.saveAnalyticsMetrics(metrics)).called(1);
        verifyNoMoreInteractions(mockRemoteDataSource);
      });
    });

    group('trackAnalyticsEvent', () {
      test('should track event locally and remotely on success', () async {
        // Arrange
        const eventName = 'user_login';
        final eventData = {'userId': 'user123'};
        final timestamp = DateTime.now();

        when(mockLocalDataSource.getAnalyticsMetrics()).thenAnswer((_) async => {});
        when(mockLocalDataSource.saveAnalyticsMetrics(any)).thenAnswer((_) async => null);
        when(mockRemoteDataSource.insertAnalyticsEvent(eventName, eventData, timestamp))
            .thenAnswer((_) async => null);

        // Act
        await repository.trackAnalyticsEvent(eventName, eventData);

        // Assert
        verify(mockRemoteDataSource.insertAnalyticsEvent(eventName, eventData, any)).called(1);
        verify(mockLocalDataSource.getAnalyticsMetrics()).called(1);
        verify(mockLocalDataSource.saveAnalyticsMetrics(any)).called(1);
      });

      test('should increment local event counter when remote tracking succeeds', () async {
        // Arrange
        const eventName = 'user_login';
        final eventData = {'userId': 'user123'};
        final existingMetrics = {'user_login': 5, 'other_event': 10};

        when(mockLocalDataSource.getAnalyticsMetrics()).thenAnswer((_) async => existingMetrics);
        when(mockLocalDataSource.saveAnalyticsMetrics(any)).thenAnswer((_) async => null);
        when(mockRemoteDataSource.insertAnalyticsEvent(any, any, any)).thenAnswer((_) async => null);

        // Act
        await repository.trackAnalyticsEvent(eventName, eventData);

        // Assert
        verify(mockLocalDataSource.saveAnalyticsMetrics(captureAny)).called(1);
        final capturedMetrics = verify(mockLocalDataSource.saveAnalyticsMetrics(captureAny)).captured.single;
        expect(capturedMetrics['user_login'], 6); // Incremented
        expect(capturedMetrics['other_event'], 10); // Unchanged
      });

      test('should handle remote tracking failure gracefully', () async {
        // Arrange
        const eventName = 'user_login';
        final eventData = {'userId': 'user123'};
        final existingMetrics = {'user_login': 3};

        when(mockLocalDataSource.getAnalyticsMetrics()).thenAnswer((_) async => existingMetrics);
        when(mockLocalDataSource.saveAnalyticsMetrics(any)).thenAnswer((_) async => null);
        when(mockRemoteDataSource.insertAnalyticsEvent(any, any, any))
            .thenThrow(Exception('Network error'));

        // Act
        await repository.trackAnalyticsEvent(eventName, eventData);

        // Assert
        verify(mockRemoteDataSource.insertAnalyticsEvent(any, any, any)).called(1);
        verify(mockLocalDataSource.getAnalyticsMetrics()).called(1);
        verify(mockLocalDataSource.saveAnalyticsMetrics(captureAny)).called(1);
        final capturedMetrics = verify(mockLocalDataSource.saveAnalyticsMetrics(captureAny)).captured.single;
        expect(capturedMetrics['user_login'], 4); // Still incremented despite remote failure
      });
    });

    group('sendLocalNotification', () {
      test('should delegate to remote datasource', () async {
        // Arrange
        const title = 'Test Notification';
        const body = 'Test message';
        const payload = 'test_payload';

        when(mockRemoteDataSource.sendLocalNotification(title, body, payload))
            .thenAnswer((_) async => null);

        // Act
        await repository.sendLocalNotification(title, body, payload);

        // Assert
        verify(mockRemoteDataSource.sendLocalNotification(title, body, payload)).called(1);
        verifyNoMoreInteractions(mockLocalDataSource);
      });
    });

    group('initializeNotifications', () {
      test('should delegate to remote datasource', () async {
        // Arrange
        when(mockRemoteDataSource.initializeNotifications()).thenAnswer((_) async => null);

        // Act
        await repository.initializeNotifications();

        // Assert
        verify(mockRemoteDataSource.initializeNotifications()).called(1);
        verifyNoMoreInteractions(mockLocalDataSource);
      });
    });

    group('requestNotificationPermissions', () {
      test('should delegate to remote datasource', () async {
        // Arrange
        when(mockRemoteDataSource.requestNotificationPermissions()).thenAnswer((_) async => true);

        // Act
        final result = await repository.requestNotificationPermissions();

        // Assert
        expect(result, true);
        verify(mockRemoteDataSource.requestNotificationPermissions()).called(1);
        verifyNoMoreInteractions(mockLocalDataSource);
      });
    });

    group('getFirebaseToken', () {
      test('should delegate to remote datasource', () async {
        // Arrange
        const token = 'fcm_token_123';
        when(mockRemoteDataSource.getFirebaseToken()).thenAnswer((_) async => token);

        // Act
        final result = await repository.getFirebaseToken();

        // Assert
        expect(result, token);
        verify(mockRemoteDataSource.getFirebaseToken()).called(1);
        verifyNoMoreInteractions(mockLocalDataSource);
      });
    });

    group('purgeOldData', () {
      test('should purge old analytics data from remote and update local metrics', () async {
        // Arrange
        final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
        final existingMetrics = {'totalEvents': 1000, 'oldEvents': 500};
        final updatedMetrics = {'totalEvents': 1000, 'oldEvents': 0}; // Simulate purge

        when(mockRemoteDataSource.purgeOldAnalyticsData()).thenAnswer((_) async => 500);
        when(mockLocalDataSource.getAnalyticsMetrics()).thenAnswer((_) async => existingMetrics);
        when(mockLocalDataSource.saveAnalyticsMetrics(updatedMetrics)).thenAnswer((_) async => null);

        // Act
        final result = await repository.purgeOldData();

        // Assert
        expect(result, 500);
        verify(mockRemoteDataSource.purgeOldAnalyticsData()).called(1);
        verify(mockLocalDataSource.getAnalyticsMetrics()).called(1);
        verify(mockLocalDataSource.saveAnalyticsMetrics(updatedMetrics)).called(1);
      });

      test('should handle purge failure gracefully', () async {
        // Arrange
        when(mockRemoteDataSource.purgeOldAnalyticsData()).thenThrow(Exception('Purge failed'));

        // Act & Assert
        expect(
          () => repository.purgeOldData(),
          throwsA(isA<Exception>()),
        );
      });

      test('should return 0 when no data to purge', () async {
        // Arrange
        when(mockRemoteDataSource.purgeOldAnalyticsData()).thenAnswer((_) async => 0);
        when(mockLocalDataSource.getAnalyticsMetrics()).thenAnswer((_) async => {});
        when(mockLocalDataSource.saveAnalyticsMetrics(any)).thenAnswer((_) async => null);

        // Act
        final result = await repository.purgeOldData();

        // Assert
        expect(result, 0);
        verify(mockLocalDataSource.saveAnalyticsMetrics({})).called(1);
      });
    });

    group('getAnalyticsEvents', () {
      test('should delegate to remote datasource', () async {
        // Arrange
        final startDate = DateTime(2023, 12, 1);
        final endDate = DateTime(2023, 12, 31);
        final events = [
          {'event_name': 'login', 'event_data': {}, 'timestamp': DateTime.now()},
        ];

        when(mockRemoteDataSource.getAnalyticsEvents(startDate, endDate))
            .thenAnswer((_) async => events);

        // Act
        final result = await repository.getAnalyticsEvents(startDate, endDate);

        // Assert
        expect(result, events);
        verify(mockRemoteDataSource.getAnalyticsEvents(startDate, endDate)).called(1);
        verifyNoMoreInteractions(mockLocalDataSource);
      });
    });
  });
}