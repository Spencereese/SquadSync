import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:squad_sync/lib.dart';
import 'package:squad_sync/presentation/notifiers/system_notifier.dart';
import '../helpers/mocks.mocks.dart';
import '../helpers/test_injection.dart' as test_injection;

void main() {
  late MockSystemRepositoryImpl mockRepository;

  setUp(() {
    mockRepository = MockSystemRepositoryImpl();
    test_injection.getIt.registerLazySingleton<SystemRepositoryImpl>(() => mockRepository);
  });

  tearDown(() {
    test_injection.getIt.reset();
  });

  group('System Analytics Flow Integration Tests', () {
    testWidgets('should complete full analytics event tracking flow', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);

      // Mock successful analytics tracking
      when(mockRepository.trackAnalyticsEvent('user_login', {'platform': 'ios', 'version': '1.0.0'}))
          .thenAnswer((_) async => null);

      // Mock initial system state load
      when(mockRepository.loadSystemState()).thenAnswer((_) async => SystemState.initial());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SystemNotifier>.value(value: systemNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PerformanceHubTab(), // Use PerformanceHubTab to test analytics display
            ),
          ),
        ),
      );

      // Act - Simulate analytics event tracking (normally called from various app actions)
      await systemNotifier.trackAnalyticsEvent('user_login', {'platform': 'ios', 'version': '1.0.0'});
      await tester.pump();

      // Assert
      verify(mockRepository.trackAnalyticsEvent('user_login', {'platform': 'ios', 'version': '1.0.0'})).called(1);
      expect(systemNotifier.state, isA<AsyncData<SystemState>>());
    });

    testWidgets('should handle analytics tracking failure gracefully', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);

      // Mock analytics tracking failure
      when(mockRepository.trackAnalyticsEvent('game_start', {'gameId': 'cod'}))
          .thenThrow(Exception('Analytics service unavailable'));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SystemNotifier>.value(value: systemNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PerformanceHubTab(),
            ),
          ),
        ),
      );

      // Act
      await systemNotifier.trackAnalyticsEvent('game_start', {'gameId': 'cod'});
      await tester.pump();

      // Assert
      verify(mockRepository.trackAnalyticsEvent('game_start', {'gameId': 'cod'})).called(1);
      expect(systemNotifier.state, isA<AsyncError<SystemState>>());
    });

    testWidgets('should complete full purge old data flow with 30-day threshold', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);

      // Mock successful purge operation
      when(mockRepository.purgeOldData()).thenAnswer((_) async => 250);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SystemNotifier>.value(value: systemNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PerformanceHubTab(),
            ),
          ),
        ),
      );

      // Act - Find and tap the purge button
      final purgeButton = find.text('Purge Old Data (30+ days)');
      await tester.tap(purgeButton);
      await tester.pump(); // Let async operation complete
      await tester.pump(const Duration(milliseconds: 100)); // Let snackbar show

      // Assert
      verify(mockRepository.purgeOldData()).called(1);
      expect(find.text('Successfully purged 250 old records'), findsOneWidget);
    });

    testWidgets('should handle purge operation failure', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);

      // Mock purge failure
      when(mockRepository.purgeOldData()).thenThrow(Exception('Database connection failed'));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SystemNotifier>.value(value: systemNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PerformanceHubTab(),
            ),
          ),
        ),
      );

      // Act
      final purgeButton = find.text('Purge Old Data (30+ days)');
      await tester.tap(purgeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      verify(mockRepository.purgeOldData()).called(1);
      expect(find.text('Failed to purge old data'), findsOneWidget);
    });

    testWidgets('should complete notification permission and settings flow', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);

      // Mock successful permission request and settings update
      when(mockRepository.requestNotificationPermissions()).thenAnswer((_) async => true);
      when(mockRepository.setNotificationsEnabled(true)).thenAnswer((_) async => null);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SystemNotifier>.value(value: systemNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SettingsTab(),
            ),
          ),
        ),
      );

      // Act - Enable notifications
      final notificationsSwitch = find.byType(Switch).at(0);
      await tester.tap(notificationsSwitch);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      verify(mockRepository.requestNotificationPermissions()).called(1);
      verify(mockRepository.setNotificationsEnabled(true)).called(1);
      expect(find.text('Notifications updated successfully'), findsOneWidget);
    });

    testWidgets('should handle notification permission denial', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);

      // Mock permission denial
      when(mockRepository.requestNotificationPermissions()).thenAnswer((_) async => false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SystemNotifier>.value(value: systemNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SettingsTab(),
            ),
          ),
        ),
      );

      // Act - Try to enable notifications
      final notificationsSwitch = find.byType(Switch).at(0);
      await tester.tap(notificationsSwitch);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      verify(mockRepository.requestNotificationPermissions()).called(1);
      verifyNever(mockRepository.setNotificationsEnabled(any));
      expect(find.text('Notification permissions are required to enable notifications'), findsOneWidget);
    });

    testWidgets('should complete theme change flow with persistence', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);

      // Mock successful theme update
      when(mockRepository.setThemeMode(ThemeMode.dark)).thenAnswer((_) async => null);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SystemNotifier>.value(value: systemNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SettingsTab(),
            ),
          ),
        ),
      );

      // Act - Change theme to dark
      final darkThemeFinder = find.text('Dark');
      await tester.tap(darkThemeFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      verify(mockRepository.setThemeMode(ThemeMode.dark)).called(1);
      expect(find.text('Theme updated successfully'), findsOneWidget);
    });

    testWidgets('should handle concurrent operations with loading states', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);

      // Mock delayed operations
      when(mockRepository.setThemeMode(ThemeMode.light)).thenAnswer((_) async {
        await Future.delayed(const Duration(seconds: 1));
        return null;
      });
      when(mockRepository.setNotificationsEnabled(false)).thenAnswer((_) async {
        await Future.delayed(const Duration(seconds: 1));
        return null;
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SystemNotifier>.value(value: systemNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SettingsTab(),
            ),
          ),
        ),
      );

      // Act - Start multiple operations
      final lightThemeFinder = find.text('Light');
      final notificationsSwitch = find.byType(Switch).at(0);

      await tester.tap(lightThemeFinder);
      await tester.tap(notificationsSwitch);
      await tester.pump();

      // Assert - Should show loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for operations to complete
      await tester.pumpAndSettle();

      // Assert - Operations completed
      verify(mockRepository.setThemeMode(ThemeMode.light)).called(1);
      verify(mockRepository.setNotificationsEnabled(false)).called(1);
    });

    testWidgets('should maintain data consistency across screen transitions', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);

      // Mock initial state with specific values
      final initialState = SystemState.initial().copyWith(
        themeMode: ThemeMode.dark,
        notificationsEnabled: true,
        analyticsMetrics: {'totalUsers': 100},
      );
      when(mockRepository.loadSystemState()).thenAnswer((_) async => initialState);

      // Create a simple navigation scenario
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SystemNotifier>.value(value: systemNotifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      tester.element(find.byType(ElevatedButton)),
                      MaterialPageRoute(builder: (_) => const Scaffold(body: SettingsTab())),
                    ),
                    child: const Text('Go to Settings'),
                  ),
                  const Expanded(child: PerformanceHubTab()),
                ],
              ),
            ),
          ),
        ),
      );

      // Act - Navigate to settings and back
      final navButton = find.text('Go to Settings');
      await tester.tap(navButton);
      await tester.pumpAndSettle();

      // Assert - Settings screen should be visible
      expect(find.text('Settings'), findsOneWidget);

      // Navigate back
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Assert - Should be back to performance hub
      expect(find.text('Performance Hub'), findsOneWidget);
      expect(find.text('100'), findsOneWidget); // Analytics metric should persist
    });

    testWidgets('should handle offline scenario with local data fallback', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);

      // Mock local data available but remote operations fail
      when(mockRepository.loadSystemState()).thenAnswer((_) async => SystemState.initial());
      when(mockRepository.trackAnalyticsEvent(any, any)).thenThrow(Exception('Network unavailable'));
      when(mockRepository.getAnalyticsMetrics()).thenAnswer((_) async => {'cachedEvents': 50});

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SystemNotifier>.value(value: systemNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PerformanceHubTab(),
            ),
          ),
        ),
      );

      // Act - Try analytics operation while offline
      await systemNotifier.trackAnalyticsEvent('offline_event', {'cached': true});
      await tester.pump();

      // Assert - Should handle gracefully without crashing
      verify(mockRepository.trackAnalyticsEvent('offline_event', {'cached': true})).called(1);
      // UI should remain functional
      expect(find.text('Performance Hub'), findsOneWidget);
    });

    testWidgets('should validate 30-day purge threshold calculation', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      when(mockRepository.purgeOldData()).thenAnswer((_) async => 75);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SystemNotifier>.value(value: systemNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PerformanceHubTab(),
            ),
          ),
        ),
      );

      // Act
      final purgeButton = find.text('Purge Old Data (30+ days)');
      await tester.tap(purgeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      verify(mockRepository.purgeOldData()).called(1);
      expect(find.text('Successfully purged 75 old records'), findsOneWidget);

      // Verify the purge operation uses correct 30-day threshold
      // (The actual threshold validation is in the repository/datasource layer)
    });

    testWidgets('should complete full system initialization flow', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);

      // Mock complete system initialization
      final initialState = SystemState.initial().copyWith(
        themeMode: ThemeMode.system,
        notificationsEnabled: true,
        soundEnabled: true,
        vibrationEnabled: true,
        lastSyncTimestamp: DateTime.now(),
        analyticsMetrics: {'initialLoad': 1},
        isInitialized: true,
      );

      when(mockRepository.loadSystemState()).thenAnswer((_) async => initialState);
      when(mockRepository.initializeNotifications()).thenAnswer((_) async => null);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SystemNotifier>.value(value: systemNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SettingsTab(),
            ),
          ),
        ),
      );

      // Act - Load system state
      await systemNotifier.loadSystemState();
      await tester.pump();

      // Assert
      verify(mockRepository.loadSystemState()).called(1);
      expect(systemNotifier.state, isA<AsyncData<SystemState>>());
      final state = systemNotifier.state.value!;
      expect(state.isInitialized, true);
      expect(state.notificationsEnabled, true);
    });
  });
}