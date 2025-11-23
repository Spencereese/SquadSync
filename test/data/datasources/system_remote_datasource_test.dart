import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:postgres/postgres.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:squad_sync/data/datasources/system_remote_datasource.dart';
import '../../helpers/mocks.mocks.dart';

void main() {
  late SystemRemoteDataSourceImpl datasource;
  late MockPostgreSQLConnection mockPostgres;
  late MockFirebaseMessaging mockFirebaseMessaging;
  late MockFlutterLocalNotificationsPlugin mockNotificationsPlugin;

  setUp(() {
    mockPostgres = MockPostgreSQLConnection();
    mockFirebaseMessaging = MockFirebaseMessaging();
    mockNotificationsPlugin = MockFlutterLocalNotificationsPlugin();
    datasource = SystemRemoteDataSourceImpl(
      mockPostgres,
      mockFirebaseMessaging,
      mockNotificationsPlugin,
    );
  });

  group('SystemRemoteDataSourceImpl', () {
    group('insertAnalyticsEvent', () {
      test('should insert analytics event successfully', () async {
        // Arrange
        const eventName = 'user_login';
        final eventData = {'userId': 'user123', 'platform': 'ios'};
        final timestamp = DateTime(2023, 12, 25, 10, 30);

        when(mockPostgres.execute(
          any,
          parameters: anyNamed('parameters'),
        )).thenAnswer((_) async => Result(count: 1, columnDescriptions: [], rows: []));

        // Act
        await datasource.insertAnalyticsEvent(eventName, eventData, timestamp);

        // Assert
        verify(mockPostgres.execute(
          'INSERT INTO analytics_events (event_name, event_data, timestamp) VALUES (@eventName, @eventData, @timestamp)',
          parameters: {
            'eventName': eventName,
            'eventData': eventData,
            'timestamp': timestamp,
          },
        )).called(1);
      });

      test('should throw exception when database insert fails', () async {
        // Arrange
        const eventName = 'user_login';
        final eventData = {'userId': 'user123'};
        final timestamp = DateTime.now();

        when(mockPostgres.execute(
          any,
          parameters: anyNamed('parameters'),
        )).thenThrow(PostgreSQLException('Connection failed'));

        // Act & Assert
        expect(
          () => datasource.insertAnalyticsEvent(eventName, eventData, timestamp),
          throwsA(isA<PostgreSQLException>()),
        );
      });
    });

    group('getAnalyticsEvents', () {
      test('should retrieve analytics events with date range', () async {
        // Arrange
        final startDate = DateTime(2023, 12, 1);
        final endDate = DateTime(2023, 12, 31);
        final mockRows = [
          ['user_login', {'userId': 'user1'}, DateTime(2023, 12, 15)],
          ['game_started', {'gameId': 'cod'}, DateTime(2023, 12, 20)],
        ];

        when(mockPostgres.query(
          any,
          parameters: anyNamed('parameters'),
        )).thenAnswer((_) async => Result(
          count: 2,
          columnDescriptions: [],
          rows: mockRows,
        ));

        // Act
        final result = await datasource.getAnalyticsEvents(startDate, endDate);

        // Assert
        expect(result.length, 2);
        expect(result[0]['event_name'], 'user_login');
        expect(result[0]['event_data'], {'userId': 'user1'});
        expect(result[1]['event_name'], 'game_started');

        verify(mockPostgres.query(
          'SELECT event_name, event_data, timestamp FROM analytics_events WHERE timestamp >= @startDate AND timestamp <= @endDate ORDER BY timestamp DESC',
          parameters: {
            'startDate': startDate,
            'endDate': endDate,
          },
        )).called(1);
      });

      test('should return empty list when no events found', () async {
        // Arrange
        final startDate = DateTime(2023, 12, 1);
        final endDate = DateTime(2023, 12, 31);

        when(mockPostgres.query(
          any,
          parameters: anyNamed('parameters'),
        )).thenAnswer((_) async => Result(
          count: 0,
          columnDescriptions: [],
          rows: [],
        ));

        // Act
        final result = await datasource.getAnalyticsEvents(startDate, endDate);

        // Assert
        expect(result, isEmpty);
      });
    });

    group('purgeOldAnalyticsData', () {
      test('should purge data older than 30 days', () async {
        // Arrange
        final cutoffDate = DateTime.now().subtract(const Duration(days: 30));

        when(mockPostgres.execute(
          any,
          parameters: anyNamed('parameters'),
        )).thenAnswer((_) async => Result(count: 5, columnDescriptions: [], rows: []));

        // Act
        final deletedCount = await datasource.purgeOldAnalyticsData();

        // Assert
        expect(deletedCount, 5);
        verify(mockPostgres.execute(
          'DELETE FROM analytics_events WHERE timestamp < @cutoffDate',
          parameters: {'cutoffDate': cutoffDate},
        )).called(1);
      });

      test('should return 0 when no data to purge', () async {
        // Arrange
        when(mockPostgres.execute(
          any,
          parameters: anyNamed('parameters'),
        )).thenAnswer((_) async => Result(count: 0, columnDescriptions: [], rows: []));

        // Act
        final deletedCount = await datasource.purgeOldAnalyticsData();

        // Assert
        expect(deletedCount, 0);
      });
    });

    group('getFirebaseToken', () {
      test('should return FCM token when available', () async {
        // Arrange
        const expectedToken = 'fcm_token_123';
        when(mockFirebaseMessaging.getToken()).thenAnswer((_) async => expectedToken);

        // Act
        final result = await datasource.getFirebaseToken();

        // Assert
        expect(result, expectedToken);
      });

      test('should return null when FCM token is not available', () async {
        // Arrange
        when(mockFirebaseMessaging.getToken()).thenAnswer((_) async => null);

        // Act
        final result = await datasource.getFirebaseToken();

        // Assert
        expect(result, null);
      });
    });

    group('requestNotificationPermissions', () {
      test('should request and return permission status', () async {
        // Arrange
        const expectedGranted = true;
        when(mockFirebaseMessaging.requestPermission()).thenAnswer((_) async =>
            const NotificationSettings(granted: true, alert: AppleNotificationSetting.enabled));

        // Act
        final result = await datasource.requestNotificationPermissions();

        // Assert
        expect(result, expectedGranted);
        verify(mockFirebaseMessaging.requestPermission()).called(1);
      });

      test('should return false when permissions denied', () async {
        // Arrange
        when(mockFirebaseMessaging.requestPermission()).thenAnswer((_) async =>
            const NotificationSettings(granted: false, alert: AppleNotificationSetting.disabled));

        // Act
        final result = await datasource.requestNotificationPermissions();

        // Assert
        expect(result, false);
      });
    });

    group('sendLocalNotification', () {
      test('should send local notification with all parameters', () async {
        // Arrange
        const title = 'Test Notification';
        const body = 'This is a test message';
        const payload = 'test_payload';

        when(mockNotificationsPlugin.show(
          any,
          title,
          body,
          any,
          payload: payload,
        )).thenAnswer((_) async => null);

        // Act
        await datasource.sendLocalNotification(title, body, payload);

        // Assert
        verify(mockNotificationsPlugin.show(
          any,
          title,
          body,
          any,
          payload: payload,
        )).called(1);
      });

      test('should send local notification with default payload', () async {
        // Arrange
        const title = 'Test Notification';
        const body = 'This is a test message';

        when(mockNotificationsPlugin.show(
          any,
          title,
          body,
          any,
          payload: any,
        )).thenAnswer((_) async => null);

        // Act
        await datasource.sendLocalNotification(title, body);

        // Assert
        verify(mockNotificationsPlugin.show(
          any,
          title,
          body,
          any,
          payload: null,
        )).called(1);
      });
    });

    group('initializeNotifications', () {
      test('should initialize notifications with proper settings', () async {
        // Arrange
        when(mockNotificationsPlugin.initialize(
          any,
          android: anyNamed('android'),
          iOS: anyNamed('iOS'),
        )).thenAnswer((_) async => true);

        // Act
        await datasource.initializeNotifications();

        // Assert
        verify(mockNotificationsPlugin.initialize(
          any,
          android: anyNamed('android'),
          iOS: anyNamed('iOS'),
        )).called(1);
      });
    });

    group('getNotificationSettings', () {
      test('should return current notification settings', () async {
        // Arrange
        when(mockNotificationsPlugin.getNotificationAppLaunchDetails())
            .thenAnswer((_) async => const NotificationAppLaunchDetails(
                  didNotificationLaunchApp: false,
                  notificationResponse: null,
                ));

        // Act
        final result = await datasource.getNotificationSettings();

        // Assert
        expect(result.didNotificationLaunchApp, false);
        expect(result.notificationResponse, null);
      });
    });

    group('scheduleNotification', () {
      test('should schedule notification with date and payload', () async {
        // Arrange
        const title = 'Scheduled Notification';
        const body = 'This is scheduled';
        final scheduledDate = DateTime.now().add(const Duration(hours: 1));
        const payload = 'scheduled_payload';

        when(mockNotificationsPlugin.zonedSchedule(
          any,
          title,
          body,
          any,
          any,
          androidAllowWhileIdle: anyNamed('androidAllowWhileIdle'),
          payload: payload,
        )).thenAnswer((_) async => null);

        // Act
        await datasource.scheduleNotification(title, body, scheduledDate, payload);

        // Assert
        verify(mockNotificationsPlugin.zonedSchedule(
          any,
          title,
          body,
          any,
          any,
          androidAllowWhileIdle: anyNamed('androidAllowWhileIdle'),
          payload: payload,
        )).called(1);
      });
    });

    group('cancelNotification', () {
      test('should cancel notification by id', () async {
        // Arrange
        const notificationId = 123;

        when(mockNotificationsPlugin.cancel(notificationId)).thenAnswer((_) async => null);

        // Act
        await datasource.cancelNotification(notificationId);

        // Assert
        verify(mockNotificationsPlugin.cancel(notificationId)).called(1);
      });
    });

    group('cancelAllNotifications', () {
      test('should cancel all notifications', () async {
        // Arrange
        when(mockNotificationsPlugin.cancelAll()).thenAnswer((_) async => null);

        // Act
        await datasource.cancelAllNotifications();

        // Assert
        verify(mockNotificationsPlugin.cancelAll()).called(1);
      });
    });
  });
}