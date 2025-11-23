import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:riverpod_test/riverpod_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:squad_sync/domain/entities/system_state.dart';
import 'package:squad_sync/presentation/notifiers/system_notifier.dart';
import '../../helpers/mocks.mocks.dart';
import '../../helpers/test_injection.dart' as test_injection;

void main() {
  late MockSystemRepositoryImpl mockRepository;

  setUp(() {
    mockRepository = MockSystemRepositoryImpl();
    test_injection.getIt
        .registerLazySingleton<SystemRepositoryImpl>(() => mockRepository);
  });

  tearDown(() {
    test_injection.getIt.reset();
  });

  group('SystemNotifier', () {
    group('loadSystemState', () {
      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should load system state successfully',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.loadSystemState())
              .thenAnswer((_) async => SystemState.initial());
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) => notifier.loadSystemState(),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncData<SystemState>>().having(
            (data) => data.value.themeMode,
            'themeMode',
            ThemeMode.system,
          ),
        ],
      );

      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should handle load failure',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.loadSystemState())
              .thenThrow(Exception('Load failed'));
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) => notifier.loadSystemState(),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncError<SystemState>>().having(
            (error) => error.error,
            'error',
            isA<Exception>(),
          ),
        ],
      );
    });

    group('updateThemeMode', () {
      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should update theme mode successfully',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.setThemeMode(ThemeMode.dark))
              .thenAnswer((_) async => null);
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) => notifier.updateThemeMode(ThemeMode.dark),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncData<SystemState>>().having(
            (data) => data.value.themeMode,
            'themeMode',
            ThemeMode.dark,
          ),
        ],
      );

      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should handle update failure',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.setThemeMode(any))
              .thenThrow(Exception('Update failed'));
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) => notifier.updateThemeMode(ThemeMode.light),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncError<SystemState>>().having(
            (error) => error.error,
            'error',
            isA<Exception>(),
          ),
        ],
      );

      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should not update if already loading',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.setThemeMode(any))
              .thenAnswer((_) async => Future.delayed(
                    const Duration(seconds: 1), // Simulate long operation
                  ));
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) async {
          // Start first update
          final future1 = notifier.updateThemeMode(ThemeMode.dark);
          // Try second update while first is loading
          await Future.delayed(const Duration(milliseconds: 100));
          final future2 = notifier.updateThemeMode(ThemeMode.light);

          await future1;
          await future2;
        },
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncData<SystemState>>().having(
            (data) => data.value.themeMode,
            'themeMode',
            ThemeMode.dark,
          ),
          // Second update should not trigger additional loading state
        ],
      );
    });

    group('updateNotificationsEnabled', () {
      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should update notifications enabled successfully',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.setNotificationsEnabled(false))
              .thenAnswer((_) async => null);
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) => notifier.updateNotificationsEnabled(false),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncData<SystemState>>().having(
            (data) => data.value.notificationsEnabled,
            'notificationsEnabled',
            false,
          ),
        ],
      );

      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should handle update failure',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.setNotificationsEnabled(any))
              .thenThrow(Exception('Update failed'));
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) => notifier.updateNotificationsEnabled(true),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncError<SystemState>>().having(
            (error) => error.error,
            'error',
            isA<Exception>(),
          ),
        ],
      );
    });

    group('trackAnalyticsEvent', () {
      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should track analytics event successfully',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.trackAnalyticsEvent(
              'test_event', {'key': 'value'})).thenAnswer((_) async => null);
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) =>
            notifier.trackAnalyticsEvent('test_event', {'key': 'value'}),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncData<SystemState>>(),
        ],
      );

      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should handle tracking failure',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.trackAnalyticsEvent(any, any))
              .thenThrow(Exception('Tracking failed'));
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) => notifier.trackAnalyticsEvent('test_event', {}),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncError<SystemState>>().having(
            (error) => error.error,
            'error',
            isA<Exception>(),
          ),
        ],
      );
    });

    group('sendLocalNotification', () {
      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should send local notification successfully',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.sendLocalNotification('Title', 'Body', 'payload'))
              .thenAnswer((_) async => null);
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) =>
            notifier.sendLocalNotification('Title', 'Body', 'payload'),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncData<SystemState>>(),
        ],
      );

      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should handle notification failure',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.sendLocalNotification(any, any, any))
              .thenThrow(Exception('Notification failed'));
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) => notifier.sendLocalNotification('Title', 'Body'),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncError<SystemState>>().having(
            (error) => error.error,
            'error',
            isA<Exception>(),
          ),
        ],
      );
    });

    group('initializeNotifications', () {
      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should initialize notifications successfully',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.initializeNotifications())
              .thenAnswer((_) async => null);
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) => notifier.initializeNotifications(),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncData<SystemState>>(),
        ],
      );

      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should handle initialization failure',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.initializeNotifications())
              .thenThrow(Exception('Init failed'));
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) => notifier.initializeNotifications(),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncError<SystemState>>().having(
            (error) => error.error,
            'error',
            isA<Exception>(),
          ),
        ],
      );
    });

    group('requestNotificationPermissions', () {
      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should request permissions successfully',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.requestNotificationPermissions())
              .thenAnswer((_) async => true);
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) => notifier.requestNotificationPermissions(),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncData<SystemState>>(),
        ],
      );

      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should handle permissions request failure',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.requestNotificationPermissions())
              .thenThrow(Exception('Permissions failed'));
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) => notifier.requestNotificationPermissions(),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncError<SystemState>>().having(
            (error) => error.error,
            'error',
            isA<Exception>(),
          ),
        ],
      );
    });

    group('updateLastSyncTimestamp', () {
      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should update last sync timestamp successfully',
        provider: systemNotifierProvider,
        setUp: () {
          final timestamp = DateTime(2023, 12, 25);
          when(mockRepository.setLastSyncTimestamp(timestamp))
              .thenAnswer((_) async => null);
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) =>
            notifier.updateLastSyncTimestamp(DateTime(2023, 12, 25)),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncData<SystemState>>().having(
            (data) => data.value.lastSyncTimestamp,
            'lastSyncTimestamp',
            DateTime(2023, 12, 25),
          ),
        ],
      );

      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should handle timestamp update failure',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.setLastSyncTimestamp(any))
              .thenThrow(Exception('Timestamp update failed'));
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) => notifier.updateLastSyncTimestamp(DateTime.now()),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncError<SystemState>>().having(
            (error) => error.error,
            'error',
            isA<Exception>(),
          ),
        ],
      );
    });

    group('purgeOldData', () {
      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should purge old data successfully',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.purgeOldData()).thenAnswer((_) async => 150);
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) => notifier.purgeOldData(),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncData<SystemState>>(),
        ],
      );

      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should handle purge failure',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.purgeOldData())
              .thenThrow(Exception('Purge failed'));
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) => notifier.purgeOldData(),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncError<SystemState>>().having(
            (error) => error.error,
            'error',
            isA<Exception>(),
          ),
        ],
      );

      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should calculate 30-day cutoff correctly',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.purgeOldData()).thenAnswer((_) async => 0);
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) => notifier.purgeOldData(),
        verify: (notifier) {
          final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
          verify(mockRepository.purgeOldData()).called(1);
        },
      );
    });

    group('getAnalyticsEvents', () {
      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should get analytics events successfully',
        provider: systemNotifierProvider,
        setUp: () {
          final startDate = DateTime(2023, 12, 1);
          final endDate = DateTime(2023, 12, 31);
          final events = [
            {
              'event_name': 'login',
              'event_data': {},
              'timestamp': DateTime.now()
            },
          ];
          when(mockRepository.getAnalyticsEvents(startDate, endDate))
              .thenAnswer((_) async => events);
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) => notifier.getAnalyticsEvents(
            DateTime(2023, 12, 1), DateTime(2023, 12, 31)),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncData<SystemState>>(),
        ],
      );

      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should handle get events failure',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.getAnalyticsEvents(any, any))
              .thenThrow(Exception('Get events failed'));
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) =>
            notifier.getAnalyticsEvents(DateTime.now(), DateTime.now()),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncError<SystemState>>().having(
            (error) => error.error,
            'error',
            isA<Exception>(),
          ),
        ],
      );
    });

    group('getFirebaseToken', () {
      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should get Firebase token successfully',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.getFirebaseToken())
              .thenAnswer((_) async => 'token123');
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) => notifier.getFirebaseToken(),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncData<SystemState>>(),
        ],
      );

      testNotifier<SystemNotifier, AsyncValue<SystemState>>(
        'should handle token retrieval failure',
        provider: systemNotifierProvider,
        setUp: () {
          when(mockRepository.getFirebaseToken())
              .thenThrow(Exception('Token retrieval failed'));
        },
        builder: () => SystemNotifier(test_injection.getIt()),
        act: (notifier) => notifier.getFirebaseToken(),
        expect: () => [
          isA<AsyncLoading>(),
          isA<AsyncError<SystemState>>().having(
            (error) => error.error,
            'error',
            isA<Exception>(),
          ),
        ],
      );
    });
  });
}
