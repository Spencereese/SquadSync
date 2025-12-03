// Commented out - GameNotifier deleted during squad refactor migration
/*
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cod_squad_app/domain/entities/game.dart';
import 'package:cod_squad_app/presentation/notifiers/game_notifier.dart';
import 'package:cod_squad_app/presentation/screens/add_game_screen.dart';

// Mock classes
class MockGameNotifier extends Mock implements GameNotifier {}

void main() {
  late MockGameNotifier mockGameNotifier;

  setUp(() {
    mockGameNotifier = MockGameNotifier();
  });

  final testGame = Game(
    igdbId: 12345,
    name: 'Test Game',
    slug: 'test-game',
    coverUrl: 'https://example.com/cover.jpg',
    summary: 'A test game',
    releaseDate: DateTime(2023, 1, 1),
    genres: ['Action'],
    platforms: ['PC'],
  );

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        gameNotifierProvider.overrideWith((ref) => mockGameNotifier),
      ],
      child: const MaterialApp(
        home: AddGameScreen(),
      ),
    );
  }

  group('AddGameScreen', () {
    testWidgets('should display search field and initial state', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(const AsyncData([]));

      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.text('Add Game'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search for games...'), findsOneWidget);
    });

    testWidgets('should display loading indicator when searching', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(const AsyncLoading());

      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display game list when data is available', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(AsyncData([testGame]));

      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.text('Test Game'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('should display error message when search fails', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(AsyncError(Exception('Search failed'), StackTrace.empty));

      // Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(); // Allow error widget to render

      // Assert
      expect(find.text('Error: Exception: Search failed'), findsOneWidget);
    });

    testWidgets('should call searchGames when text is entered', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(const AsyncData([]));
      when(mockGameNotifier.searchGames(any, limit: anyNamed('limit'))).thenAnswer((_) async {});

      // Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.enterText(find.byType(TextField), 'Call of Duty');
      await tester.pump(const Duration(milliseconds: 500)); // Wait for debounce

      // Assert
      verify(mockGameNotifier.searchGames('Call of Duty', limit: 20)).called(1);
    });

    testWidgets('should debounce search input', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(const AsyncData([]));
      when(mockGameNotifier.searchGames(any, limit: anyNamed('limit'))).thenAnswer((_) async {});

      // Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.enterText(find.byType(TextField), 'C');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), 'Ca');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), 'Cal');
      await tester.pump(const Duration(milliseconds: 600)); // Wait for debounce

      // Assert
      verify(mockGameNotifier.searchGames('Cal', limit: 20)).called(1);
    });

    testWidgets('should display game details in list tile', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(AsyncData([testGame]));

      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.text('Test Game'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);
      expect(find.text('PC'), findsOneWidget);
    });

    testWidgets('should show snackbar when game is selected', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(AsyncData([testGame]));

      // Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.text('Test Game'));
      await tester.pump(); // Allow snackbar to show

      // Assert
      expect(find.text('Game added: Test Game'), findsOneWidget);
    });

    testWidgets('should handle empty search results', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(const AsyncData([]));

      // Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.enterText(find.byType(TextField), 'nonexistent game');
      await tester.pump(const Duration(milliseconds: 500));

      // Assert
      expect(find.text('No games found'), findsOneWidget);
    });

    testWidgets('should clear search when clear button is pressed', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(AsyncData([testGame]));
      when(mockGameNotifier.clearSearch()).thenAnswer((_) async {
        return null;
      });

      // Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      // Assert
      verify(mockGameNotifier.clearSearch()).called(1);
    });
  });
}
*/
