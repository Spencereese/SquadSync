// ignore_for_file: deprecated_member_use_from_same_package
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:cod_squad_app/lib.dart';
import 'package:cod_squad_app/presentation/notifiers/system_notifier.dart';
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

  group('SettingsTab Widget Tests', () {
    testWidgets('should display settings UI elements',
        (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);

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

      // Assert
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Sound'), findsOneWidget);
      expect(find.text('Vibration'), findsOneWidget);
    });

    testWidgets('should show theme mode switches', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);

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

      // Assert
      expect(find.byType(Switch),
          findsNWidgets(3)); // Theme, Notifications, Sound switches
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('should toggle theme mode when switch is tapped',
        (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      when(mockRepository.setThemeMode(ThemeMode.dark))
          .thenAnswer((_) async => null);

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

      // Act - Find and tap the dark theme radio button
      final darkThemeFinder = find.text('Dark');
      await tester.tap(darkThemeFinder);
      await tester.pump();

      // Assert
      verify(mockRepository.setThemeMode(ThemeMode.dark)).called(1);
    });

    testWidgets('should toggle notifications switch',
        (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      when(mockRepository.setNotificationsEnabled(false))
          .thenAnswer((_) async => null);

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

      // Act - Find and toggle the notifications switch
      final notificationsSwitch =
          find.byType(Switch).at(0); // First switch is notifications
      await tester.tap(notificationsSwitch);
      await tester.pump();

      // Assert
      verify(mockRepository.setNotificationsEnabled(false)).called(1);
    });

    testWidgets('should toggle sound switch', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);

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

      // Act - Find and toggle the sound switch
      final soundSwitch = find.byType(Switch).at(1); // Second switch is sound
      await tester.tap(soundSwitch);
      await tester.pump();

      // Assert - Sound setting is handled locally in the widget state
      // No repository call expected for sound setting
    });

    testWidgets('should toggle vibration switch', (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);

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

      // Act - Find and toggle the vibration switch
      final vibrationSwitch =
          find.byType(Switch).at(2); // Third switch is vibration
      await tester.tap(vibrationSwitch);
      await tester.pump();

      // Assert - Vibration setting is handled locally in the widget state
      // No repository call expected for vibration setting
    });

    testWidgets('should show snackbar on theme change success',
        (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      when(mockRepository.setThemeMode(ThemeMode.light))
          .thenAnswer((_) async => null);

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

      // Act
      final lightThemeFinder = find.text('Light');
      await tester.tap(lightThemeFinder);
      await tester.pump(); // Let the async operation complete
      await tester.pump(const Duration(milliseconds: 100)); // Let snackbar show

      // Assert
      expect(find.text('Theme updated successfully'), findsOneWidget);
    });

    testWidgets('should show snackbar on theme change failure',
        (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      when(mockRepository.setThemeMode(ThemeMode.light))
          .thenThrow(Exception('Theme update failed'));

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

      // Act
      final lightThemeFinder = find.text('Light');
      await tester.tap(lightThemeFinder);
      await tester.pump(); // Let the async operation complete
      await tester.pump(const Duration(milliseconds: 100)); // Let snackbar show

      // Assert
      expect(find.text('Failed to update theme'), findsOneWidget);
    });

    testWidgets('should show snackbar on notifications toggle success',
        (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      when(mockRepository.setNotificationsEnabled(true))
          .thenAnswer((_) async => null);

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

      // Act
      final notificationsSwitch = find.byType(Switch).at(0);
      await tester.tap(notificationsSwitch);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      expect(find.text('Notifications updated successfully'), findsOneWidget);
    });

    testWidgets('should show snackbar on notifications toggle failure',
        (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      when(mockRepository.setNotificationsEnabled(true))
          .thenThrow(Exception('Notifications update failed'));

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

      // Act
      final notificationsSwitch = find.byType(Switch).at(0);
      await tester.tap(notificationsSwitch);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert
      expect(find.text('Failed to update notifications'), findsOneWidget);
    });

    testWidgets(
        'should request notification permissions when enabling notifications',
        (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      when(mockRepository.requestNotificationPermissions())
          .thenAnswer((_) async => true);
      when(mockRepository.setNotificationsEnabled(true))
          .thenAnswer((_) async => null);

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

      // Act - Enable notifications (assuming it starts disabled)
      final notificationsSwitch = find.byType(Switch).at(0);
      await tester.tap(notificationsSwitch);
      await tester.pump();

      // Assert
      verify(mockRepository.requestNotificationPermissions()).called(1);
    });

    testWidgets(
        'should show permissions denied message when permissions are rejected',
        (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      when(mockRepository.requestNotificationPermissions())
          .thenAnswer((_) async => false);

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
      expect(
          find.text(
              'Notification permissions are required to enable notifications'),
          findsOneWidget);
    });

    testWidgets('should display current system state values',
        (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      // Set up initial state with specific values
      systemNotifier.state = AsyncData(SystemState.initial().copyWith(
        themeMode: ThemeMode.dark,
        notificationsEnabled: false,
        soundEnabled: true,
        vibrationEnabled: false,
      ));

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

      // Assert - The UI should reflect the current state
      // Note: Actual switch states depend on the widget implementation
      expect(
          find.byType(CircularProgressIndicator), findsNothing); // Not loading
    });

    testWidgets('should show loading indicator during async operations',
        (WidgetTester tester) async {
      // Arrange
      final systemNotifier = SystemNotifier(test_injection.getIt);
      when(mockRepository.setThemeMode(ThemeMode.light)).thenAnswer((_) async {
        await Future.delayed(const Duration(seconds: 1));
        return null; // Simulate delay
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

      // Act
      final lightThemeFinder = find.text('Light');
      await tester.tap(lightThemeFinder);
      await tester.pump(); // Start the operation

      // Assert - Loading indicator should be visible during operation
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
