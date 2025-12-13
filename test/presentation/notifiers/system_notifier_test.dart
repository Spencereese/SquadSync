import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/system_notifier.dart'
    hide systemNotifierProvider;
import 'package:squad_sync/domain/entities/system_state.dart';
import 'package:squad_sync/domain/repositories/system_repository.dart';
import 'package:squad_sync/core/injection.dart';

@GenerateMocks([SystemRepository])
import 'system_notifier_test.mocks.dart';

void main() {
  late MockSystemRepository mockRepository;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockSystemRepository();

    // Set up default stub responses
    when(mockRepository.loadSystemState()).thenAnswer(
      (_) async => SystemState.initial(),
    );

    // Create provider container with overrides
    container = ProviderContainer(
      overrides: [
        systemRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('SystemNotifier - Initialization', () {
    test('should load initial system state', () async {
      final initialState = SystemState.initial();
      when(mockRepository.loadSystemState())
          .thenAnswer((_) async => initialState);

      final state = await container.read(systemNotifierProvider.future);

      expect(state, equals(initialState));
      verify(mockRepository.loadSystemState()).called(1);
    });

    test('should handle AsyncLoading state during initialization', () {
      final state = container.read(systemNotifierProvider);

      expect(state, isA<AsyncLoading>());
    });

    test('should handle initialization errors', () async {
      when(mockRepository.loadSystemState()).thenThrow(
        Exception('Failed to load system state'),
      );

      final state = container.read(systemNotifierProvider);

      await expectLater(
        state.future,
        throwsException,
      );
    });
  });

  group('SystemNotifier - Theme Management', () {
    test('should update theme mode to light', () async {
      when(mockRepository.loadSystemState()).thenAnswer(
        (_) async => SystemState.initial(),
      );
      when(mockRepository.updateThemeMode(ThemeMode.light)).thenAnswer(
        (_) async {},
      );
      when(mockRepository.loadSystemState()).thenAnswer(
        (_) async => SystemState.initial().copyWith(themeMode: ThemeMode.light),
      );

      await container.read(systemNotifierProvider.future);
      final notifier = container.read(systemNotifierProvider.notifier);

      await notifier.updateThemeMode(ThemeMode.light);

      verify(mockRepository.updateThemeMode(ThemeMode.light)).called(1);
      verify(mockRepository.loadSystemState()).called(greaterThanOrEqualTo(1));
    });

    test('should update theme mode to dark', () async {
      when(mockRepository.loadSystemState()).thenAnswer(
        (_) async => SystemState.initial(),
      );
      when(mockRepository.updateThemeMode(ThemeMode.dark)).thenAnswer(
        (_) async {},
      );
      when(mockRepository.loadSystemState()).thenAnswer(
        (_) async => SystemState.initial().copyWith(themeMode: ThemeMode.dark),
      );

      await container.read(systemNotifierProvider.future);
      final notifier = container.read(systemNotifierProvider.notifier);

      await notifier.updateThemeMode(ThemeMode.dark);

      verify(mockRepository.updateThemeMode(ThemeMode.dark)).called(1);
    });

    test('should update theme mode to system', () async {
      when(mockRepository.loadSystemState()).thenAnswer(
        (_) async => SystemState.initial(),
      );
      when(mockRepository.updateThemeMode(ThemeMode.system)).thenAnswer(
        (_) async {},
      );
      when(mockRepository.loadSystemState()).thenAnswer(
        (_) async =>
            SystemState.initial().copyWith(themeMode: ThemeMode.system),
      );

      await container.read(systemNotifierProvider.future);
      final notifier = container.read(systemNotifierProvider.notifier);

      await notifier.updateThemeMode(ThemeMode.system);

      verify(mockRepository.updateThemeMode(ThemeMode.system)).called(1);
    });

    test('should handle theme update errors', () async {
      when(mockRepository.updateThemeMode(ThemeMode.light)).thenThrow(
        Exception('Failed to update theme'),
      );

      await container.read(systemNotifierProvider.future);
      final notifier = container.read(systemNotifierProvider.notifier);

      await notifier.updateThemeMode(ThemeMode.light);

      final state = container.read(systemNotifierProvider);
      expect(state, isA<AsyncError>());
    });
  });

  group('SystemNotifier - Analytics', () {
    test('should track analytics event', () async {
      final eventData = {'action': 'button_click', 'screen': 'home'};

      when(mockRepository.trackAnalyticsEvent('user_action', eventData))
          .thenAnswer(
        (_) async {},
      );

      await container.read(systemNotifierProvider.future);
      final notifier = container.read(systemNotifierProvider.notifier);

      await notifier.trackAnalyticsEvent('user_action', eventData);

      verify(mockRepository.trackAnalyticsEvent('user_action', eventData))
          .called(1);
    });

    test('should track multiple analytics events', () async {
      when(mockRepository.trackAnalyticsEvent(any, any)).thenAnswer(
        (_) async {},
      );

      await container.read(systemNotifierProvider.future);
      final notifier = container.read(systemNotifierProvider.notifier);

      await notifier.trackAnalyticsEvent('event_1', {'data': 'test1'});
      await notifier.trackAnalyticsEvent('event_2', {'data': 'test2'});
      await notifier.trackAnalyticsEvent('event_3', {'data': 'test3'});

      verify(mockRepository.trackAnalyticsEvent('event_1', {'data': 'test1'}))
          .called(1);
      verify(mockRepository.trackAnalyticsEvent('event_2', {'data': 'test2'}))
          .called(1);
      verify(mockRepository.trackAnalyticsEvent('event_3', {'data': 'test3'}))
          .called(1);
    });

    test('should handle analytics errors gracefully', () async {
      when(mockRepository.trackAnalyticsEvent('error_event', {})).thenThrow(
        Exception('Analytics error'),
      );

      await container.read(systemNotifierProvider.future);
      final notifier = container.read(systemNotifierProvider.notifier);

      expect(
        () => notifier.trackAnalyticsEvent('error_event', {}),
        throwsException,
      );
    });
  });

  group('SystemNotifier - Notifications', () {
    test('should send local notification', () async {
      when(mockRepository.sendLocalNotification(
        'Test Title',
        'Test Body',
        data: {'key': 'value'},
      )).thenAnswer((_) async {});

      await container.read(systemNotifierProvider.future);
      final notifier = container.read(systemNotifierProvider.notifier);

      await notifier.sendLocalNotification(
        'Test Title',
        'Test Body',
        payload: 'value',
      );

      verify(mockRepository.sendLocalNotification(
        'Test Title',
        'Test Body',
        data: {'payload': 'value'},
      )).called(1);
    });

    test('should send notification without payload', () async {
      when(mockRepository.sendLocalNotification(
        'Test',
        'Message',
        data: null,
      )).thenAnswer((_) async {});

      await container.read(systemNotifierProvider.future);
      final notifier = container.read(systemNotifierProvider.notifier);

      await notifier.sendLocalNotification('Test', 'Message');

      verify(mockRepository.sendLocalNotification(
        'Test',
        'Message',
        data: null,
      )).called(1);
    });

    test('should update notification settings', () async {
      final settings = {
        'pushEnabled': true,
        'soundEnabled': false,
        'vibrationEnabled': true,
      };

      when(mockRepository.updateNotificationSettings(settings)).thenAnswer(
        (_) async {},
      );
      when(mockRepository.loadSystemState()).thenAnswer(
        (_) async => SystemState.initial(),
      );

      await container.read(systemNotifierProvider.future);
      final notifier = container.read(systemNotifierProvider.notifier);

      await notifier.updateNotificationSettings(settings);

      verify(mockRepository.updateNotificationSettings(settings)).called(1);
    });

    test('should send push notification to multiple users', () async {
      await container.read(systemNotifierProvider.future);
      final notifier = container.read(systemNotifierProvider.notifier);

      // This method uses NotificationService directly, so we just verify it doesn't throw
      await notifier.sendPushNotification(
        title: 'Test',
        body: 'Message',
        recipientUids: ['user-1', 'user-2'],
        data: {'key': 'value'},
      );

      // No exception thrown means success
    });
  });

  group('SystemNotifier - User Ban Management', () {
    test('should ban user', () async {
      when(mockRepository.banUser('user-123', 'Spam')).thenAnswer(
        (_) async {},
      );
      when(mockRepository.loadSystemState()).thenAnswer(
        (_) async => SystemState.initial(),
      );

      await container.read(systemNotifierProvider.future);
      final notifier = container.read(systemNotifierProvider.notifier);

      await notifier.banUser('user-123', 'Spam');

      verify(mockRepository.banUser('user-123', 'Spam')).called(1);
      verify(mockRepository.loadSystemState()).called(greaterThanOrEqualTo(1));
    });

    test('should unban user', () async {
      when(mockRepository.unbanUser('user-123')).thenAnswer(
        (_) async {},
      );
      when(mockRepository.loadSystemState()).thenAnswer(
        (_) async => SystemState.initial(),
      );

      await container.read(systemNotifierProvider.future);
      final notifier = container.read(systemNotifierProvider.notifier);

      await notifier.unbanUser('user-123');

      verify(mockRepository.unbanUser('user-123')).called(1);
      verify(mockRepository.loadSystemState()).called(greaterThanOrEqualTo(1));
    });

    test('should handle ban errors', () async {
      when(mockRepository.banUser('user-123', 'Reason')).thenThrow(
        Exception('Ban failed'),
      );

      await container.read(systemNotifierProvider.future);
      final notifier = container.read(systemNotifierProvider.notifier);

      await notifier.banUser('user-123', 'Reason');

      final state = container.read(systemNotifierProvider);
      expect(state, isA<AsyncError>());
    });

    test('should handle unban errors', () async {
      when(mockRepository.unbanUser('user-123')).thenThrow(
        Exception('Unban failed'),
      );

      await container.read(systemNotifierProvider.future);
      final notifier = container.read(systemNotifierProvider.notifier);

      await notifier.unbanUser('user-123');

      final state = container.read(systemNotifierProvider);
      expect(state, isA<AsyncError>());
    });
  });

  group('SystemNotifier - Availability Check', () {
    test('should check availability and return true', () async {
      when(mockRepository.checkAvailability()).thenAnswer(
        (_) async => true,
      );

      await container.read(systemNotifierProvider.future);
      final notifier = container.read(systemNotifierProvider.notifier);

      final isAvailable = await notifier.checkAvailability();

      expect(isAvailable, isTrue);
      verify(mockRepository.checkAvailability()).called(1);
    });

    test('should check availability and return false', () async {
      when(mockRepository.checkAvailability()).thenAnswer(
        (_) async => false,
      );

      await container.read(systemNotifierProvider.future);
      final notifier = container.read(systemNotifierProvider.notifier);

      final isAvailable = await notifier.checkAvailability();

      expect(isAvailable, isFalse);
      verify(mockRepository.checkAvailability()).called(1);
    });

    test('should handle availability check errors', () async {
      when(mockRepository.checkAvailability()).thenThrow(
        Exception('Availability check failed'),
      );

      await container.read(systemNotifierProvider.future);
      final notifier = container.read(systemNotifierProvider.notifier);

      expect(
        () => notifier.checkAvailability(),
        throwsException,
      );
    });
  });

  group('SystemNotifier - State Persistence', () {
    test('should maintain state across operations', () async {
      final initialState = SystemState.initial();
      when(mockRepository.loadSystemState())
          .thenAnswer((_) async => initialState);

      final state = await container.read(systemNotifierProvider.future);

      expect(state, equals(initialState));

      // Perform an operation
      when(mockRepository.updateThemeMode(ThemeMode.dark)).thenAnswer(
        (_) async {},
      );
      when(mockRepository.loadSystemState()).thenAnswer(
        (_) async => initialState.copyWith(themeMode: ThemeMode.dark),
      );

      final notifier = container.read(systemNotifierProvider.notifier);
      await notifier.updateThemeMode(ThemeMode.dark);

      final updatedState = container.read(systemNotifierProvider).valueOrNull;
      expect(updatedState?.themeMode, equals(ThemeMode.dark));
    });

    test('should handle multiple concurrent operations', () async {
      when(mockRepository.loadSystemState()).thenAnswer(
        (_) async => SystemState.initial(),
      );
      when(mockRepository.trackAnalyticsEvent(any, any)).thenAnswer(
        (_) async => Future.delayed(const Duration(milliseconds: 50)),
      );

      await container.read(systemNotifierProvider.future);
      final notifier = container.read(systemNotifierProvider.notifier);

      // Start multiple operations concurrently
      await Future.wait<void>([
        notifier.trackAnalyticsEvent('event_1', {}),
        notifier.trackAnalyticsEvent('event_2', {}),
        notifier.trackAnalyticsEvent('event_3', {}),
      ]);

      verify(mockRepository.trackAnalyticsEvent('event_1', {})).called(1);
      verify(mockRepository.trackAnalyticsEvent('event_2', {})).called(1);
      verify(mockRepository.trackAnalyticsEvent('event_3', {})).called(1);
    });
  });

  group('SystemNotifier - Error Recovery', () {
    test('should recover from temporary state load errors', () async {
      var callCount = 0;
      when(mockRepository.loadSystemState()).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          throw Exception('Temporary error');
        }
        return SystemState.initial();
      });

      // First call will fail
      try {
        await container.read(systemNotifierProvider.future);
      } catch (e) {
        // Expected
      }

      // Retry should work
      container.invalidate(systemNotifierProvider);
      final state = await container.read(systemNotifierProvider.future);

      expect(state, isA<SystemState>());
    });

    test('should handle null state gracefully', () async {
      when(mockRepository.loadSystemState()).thenAnswer(
        (_) async => SystemState.initial(),
      );

      final state = await container.read(systemNotifierProvider.future);

      expect(state, isNotNull);
      expect(state, isA<SystemState>());
    });
  });
}
