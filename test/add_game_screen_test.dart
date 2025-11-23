import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/managers/game_manager.dart';
import 'package:squad_sync/screens/add_game_screen.dart';
import 'package:squad_sync/managers/user_manager.dart';
import 'package:squad_sync/providers.dart' as p;
import 'dart:io';

class MockGameManager extends Mock implements GameManager {}

class MockUserManager extends Mock implements UserManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGameManager mockGameManager;
  late MockUserManager mockUserManager;

  setUp(() {
    mockGameManager = MockGameManager();
    mockUserManager = MockUserManager();
  });

  testWidgets('AddGameScreen shows retry button on error and calls retry',
      (WidgetTester tester) async {
    // Arrange
    final errorState = AsyncValue<GameState>.error(
        IgdbException('API Error'), StackTrace.current);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameManagerProvider.overrideWith(() => mockGameManager),
          p.userManagerProvider.overrideWith((ref) => mockUserManager),
        ],
        child: const MaterialApp(home: AddGameScreen()),
      ),
    );

    // Wait for initial load
    await tester.pump();

    // Override the provider to error state
    final container =
        ProviderScope.containerOf(tester.element(find.byType(AddGameScreen)));
    container.invalidate(gameManagerProvider);
    container.read(gameManagerProvider.notifier).state = errorState;

    await tester.pump();

    // Assert retry button is shown
    expect(find.text('Retry'), findsOneWidget);

    // Act
    await tester.tap(find.text('Retry'));
    await tester.pump();

    // Assert retry was called
    verify(mockGameManager.fetchGamesFromIGDB(argThat(isA<String>())))
        .called(1);
  });

  testWidgets('AddGameScreen shows offline banner when using cache',
      (WidgetTester tester) async {
    // Arrange
    final offlineState = AsyncValue<GameState>.data(GameState(games: [
      {'id': 1, 'name': 'Cached Game'}
    ], isOffline: true));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameManagerProvider.overrideWith(() => mockGameManager),
          p.userManagerProvider.overrideWith((ref) => mockUserManager),
        ],
        child: const MaterialApp(home: AddGameScreen()),
      ),
    );

    // Override to offline state
    final container =
        ProviderScope.containerOf(tester.element(find.byType(AddGameScreen)));
    container.invalidate(gameManagerProvider);
    container.read(gameManagerProvider.notifier).state = offlineState;

    await tester.pump();

    // Assert banner is shown
    expect(find.text('Using offline cache'), findsOneWidget);
  });

  testWidgets('AddGameScreen handles SocketException and shows offline banner',
      (WidgetTester tester) async {
    // Arrange
    when(mockGameManager.fetchGamesFromIGDB(argThat(isA<String>())))
        .thenThrow(const SocketException('No internet'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameManagerProvider.overrideWith(() => mockGameManager),
          p.userManagerProvider.overrideWith((ref) => mockUserManager),
        ],
        child: const MaterialApp(home: AddGameScreen()),
      ),
    );

    // Trigger search
    await tester.enterText(find.byType(TextField), 'test');
    await tester.pump();

    // Wait for error
    await tester.pump();

    // Assert error UI is shown
    expect(find.text('API error:'), findsOneWidget);
  });
}
