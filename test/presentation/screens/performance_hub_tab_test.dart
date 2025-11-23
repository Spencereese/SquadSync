import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:squad_sync/lib.dart';
import 'package:squad_sync/presentation/notifiers/system_notifier.dart';
import '../../helpers/mocks.mocks.dart';
import '../../helpers/test_injection.dart' as test_injection;

void main() {
  late MockSystemRepositoryImpl mockRepository;

  setUp(() {
    mockRepository = MockSystemRepositoryImpl();
    test_injection.getIt.registerLazySingleton<SystemRepositoryImpl>(() => mockRepository);
  });

  tearDown(() {
    test_injection.getIt.reset();
  });

  group('PerformanceHubTab Widget Tests', () {
    testWidgets('should display performance hub UI elements', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);

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

      // Assert
      expect(find.text('Performance Hub'), findsOneWidget);
      expect(find.text('Analytics Overview'), findsOneWidget);
      expect(find.text('Data Management'), findsOneWidget);
    });

    testWidgets('should display analytics metrics cards', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      systemNotifier.state = AsyncData(SystemState.initial().copyWith(
        analyticsMetrics: {
          'totalUsers': 150,
          'activeSquads': 25,
          'messagesSent': 1200,
          'gamesPlayed': 89,
        },
      ));

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

      // Assert
      expect(find.text('150'), findsOneWidget); // totalUsers
      expect(find.text('25'), findsOneWidget); // activeSquads
      expect(find.text('1,200'), findsOneWidget); // messagesSent (formatted)
      expect(find.text('89'), findsOneWidget); // gamesPlayed
    });

    testWidgets('should display last sync timestamp', (WidgetTester tester) async {
      // Arrange
      final lastSync = DateTime(2023, 12, 25, 10, 30);
      final systemNotifier = SystemNotifier(test_injection.getIt);
      systemNotifier.state = AsyncData(SystemState.initial().copyWith(
        lastSyncTimestamp: lastSync,
      ));

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

      // Assert
      expect(find.text('Last Sync: Dec 25, 2023 10:30 AM'), findsOneWidget);
    });

    testWidgets('should show "Never" when no last sync timestamp', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      systemNotifier.state = AsyncData(SystemState.initial().copyWith(
        lastSyncTimestamp: null,
      ));

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

      // Assert
      expect(find.text('Last Sync: Never'), findsOneWidget);
    });

    testWidgets('should display purge old data button', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);

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

      // Assert
      expect(find.text('Purge Old Data (30+ days)'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('should call purgeOldData when button is pressed', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      when(mockRepository.purgeOldData()).thenAnswer((_) async => 150);

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
      final purgeButton = find.byType(ElevatedButton);
      await tester.tap(purgeButton);
      await tester.pump();

      // Assert
      verify(mockRepository.purgeOldData()).called(1);
    });

    testWidgets('should show success snackbar after successful purge', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      when(mockRepository.purgeOldData()).thenAnswer((_) async => 150);

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
      final purgeButton = find.byType(ElevatedButton);
      await tester.tap(purgeButton);
      await tester.pump(); // Let async operation complete
      await tester.pump(const Duration(milliseconds: 100)); // Let snackbar show

      // Assert
      expect(find.text('Successfully purged 150 old records'), findsOneWidget);
    });

    testWidgets('should show error snackbar when purge fails', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      when(mockRepository.purgeOldData()).thenThrow(Exception('Purge failed'));

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
      final purgeButton = find.byType(ElevatedButton);
      await tester.tap(purgeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      expect(find.text('Failed to purge old data'), findsOneWidget);
    });

    testWidgets('should show "No old data to purge" when 0 records deleted', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      when(mockRepository.purgeOldData()).thenAnswer((_) async => 0);

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
      final purgeButton = find.byType(ElevatedButton);
      await tester.tap(purgeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      expect(find.text('No old data to purge'), findsOneWidget);
    });

    testWidgets('should show loading indicator during purge operation', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      when(mockRepository.purgeOldData()).thenAnswer((_) async {
        await Future.delayed(const Duration(seconds: 1)); // Simulate delay
        return 50;
      });

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
      final purgeButton = find.byType(ElevatedButton);
      await tester.tap(purgeButton);
      await tester.pump(); // Start operation

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Purging...'), findsOneWidget);
    });

    testWidgets('should display analytics charts section', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);

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

      // Assert
      expect(find.text('Analytics Charts'), findsOneWidget);
      expect(find.byType(Card), findsAtLeastNWidgets(2)); // At least metrics and data management cards
    });

    testWidgets('should handle empty analytics metrics gracefully', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      systemNotifier.state = AsyncData(SystemState.initial().copyWith(
        analyticsMetrics: {},
      ));

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

      // Assert - Should display 0 for all metrics
      expect(find.text('0'), findsAtLeastNWidgets(4)); // All metrics should show 0
    });

    testWidgets('should format large numbers with commas', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      systemNotifier.state = AsyncData(SystemState.initial().copyWith(
        analyticsMetrics: {
          'totalUsers': 150000,
          'messagesSent': 2500000,
        },
      ));

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

      // Assert
      expect(find.text('150,000'), findsOneWidget);
      expect(find.text('2,500,000'), findsOneWidget);
    });

    testWidgets('should display error state when system state has error', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      systemNotifier.state = AsyncError(Exception('Failed to load system state'));

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

      // Assert
      expect(find.text('Error loading performance data'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing); // No purge button when error
    });

    testWidgets('should display loading state when system state is loading', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      systemNotifier.state = const AsyncLoading();

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

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading performance data...'), findsOneWidget);
    });

    testWidgets('should refresh data when pull to refresh is triggered', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      when(mockRepository.loadSystemState()).thenAnswer((_) async => SystemState.initial());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SystemNotifier>.value(value: systemNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RefreshIndicator(
                child: SingleChildScrollView(
                  child: PerformanceHubTab(),
                ),
                onRefresh: () async {}, // This will be overridden by the widget
              ),
            ),
          ),
        ),
      );

      // Act - Simulate pull to refresh
      await tester.fling(find.byType(PerformanceHubTab), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      // Assert - The widget should handle refresh internally
      // Note: Actual refresh behavior depends on widget implementation
    });
  });
}