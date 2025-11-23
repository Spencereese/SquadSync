import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/entities/game.dart';
import 'package:squad_sync/presentation/notifiers/game_notifier.dart';
import 'package:squad_sync/presentation/screens/discovery_screen.dart';

// Mock classes
class MockGameNotifier extends Mock implements GameNotifier {}

void main() {
  late MockGameNotifier mockGameNotifier;

  setUp(() {
    mockGameNotifier = MockGameNotifier();
  });

  final testGames = [
    Game(
      igdbId: 12345,
      name: 'Call of Duty: Modern Warfare',
      slug: 'call-of-duty-modern-warfare',
      coverUrl: 'https://example.com/cod.jpg',
      summary: 'A first-person shooter',
      releaseDate: DateTime(2019, 10, 25),
      genres: ['Shooter', 'Action'],
      platforms: ['PC', 'PlayStation', 'Xbox'],
    ),
    Game(
      igdbId: 67890,
      name: 'FIFA 23',
      slug: 'fifa-23',
      coverUrl: 'https://example.com/fifa.jpg',
      summary: 'A sports game',
      releaseDate: DateTime(2022, 9, 30),
      genres: ['Sports'],
      platforms: ['PC', 'PlayStation', 'Xbox', 'Switch'],
    ),
  ];

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        gameNotifierProvider.overrideWith((ref) => mockGameNotifier),
      ],
      child: const MaterialApp(
        home: DiscoveryScreen(),
      ),
    );
  }

  group('DiscoveryScreen', () {
    testWidgets('should display title and initial loading state', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(const AsyncLoading());

      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.text('Discover Games'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display popular games grid when data is available', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(AsyncData(testGames));

      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.text('Call of Duty: Modern Warfare'), findsOneWidget);
      expect(find.text('FIFA 23'), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('should display game cards with cover images and details', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(AsyncData([testGames.first]));

      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.text('Call of Duty: Modern Warfare'), findsOneWidget);
      expect(find.text('Shooter • Action'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('should handle empty game list', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(const AsyncData([]));

      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.text('No games available'), findsOneWidget);
    });

    testWidgets('should display error state with retry button', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(AsyncError(Exception('Network error'), StackTrace.empty));

      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.text('Failed to load games'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('should call refresh when retry button is pressed', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(AsyncError(Exception('Network error'), StackTrace.empty));
      when(mockGameNotifier.refresh()).thenAnswer((_) async {
        return null;
      });

      // Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // Assert
      verify(mockGameNotifier.refresh()).called(1);
    });

    testWidgets('should show loading indicator during refresh', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(const AsyncLoading());

      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display game genres and platforms in card', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(AsyncData([testGames.first]));

      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.text('Shooter • Action'), findsOneWidget);
      expect(find.text('PC, PlayStation, Xbox'), findsOneWidget);
    });

    testWidgets('should handle games without cover images', (WidgetTester tester) async {
      // Arrange
      final gameWithoutCover = Game(
        igdbId: 11111,
        name: 'Game Without Cover',
        slug: 'game-without-cover',
        summary: 'A game without cover',
        releaseDate: DateTime(2023, 1, 1),
        genres: ['Adventure'],
        platforms: ['PC'],
      );
      when(mockGameNotifier.state).thenReturn(AsyncData([gameWithoutCover]));

      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.text('Game Without Cover'), findsOneWidget);
      expect(find.byIcon(Icons.games), findsOneWidget); // Placeholder icon
    });

    testWidgets('should display release year in game card', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(AsyncData([testGames.first]));

      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.text('2019'), findsOneWidget);
    });

    testWidgets('should handle scrollable grid with many games', (WidgetTester tester) async {
      // Arrange
      final manyGames = List.generate(20, (index) => Game(
        igdbId: index,
        name: 'Game $index',
        slug: 'game-$index',
        summary: 'Game $index description',
        releaseDate: DateTime(2023, 1, 1),
        genres: ['Action'],
        platforms: ['PC'],
      ));
      when(mockGameNotifier.state).thenReturn(AsyncData(manyGames));

      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.text('Game 0'), findsOneWidget);
      expect(find.text('Game 19'), findsOneWidget);
      expect(find.byType(Scrollable), findsOneWidget);
    });

    testWidgets('should show snackbar when game is tapped', (WidgetTester tester) async {
      // Arrange
      when(mockGameNotifier.state).thenReturn(AsyncData([testGames.first]));

      // Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.text('Call of Duty: Modern Warfare'));
      await tester.pump(); // Allow snackbar to show

      // Assert
      expect(find.text('Selected: Call of Duty: Modern Warfare'), findsOneWidget);
    });

    testWidgets('should handle network connectivity changes', (WidgetTester tester) async {
      // Arrange - Start with data
      when(mockGameNotifier.state).thenReturn(AsyncData(testGames));

      // Act - Load initial state
      await tester.pumpWidget(createWidgetUnderTest());

      // Arrange - Change to error state (simulating network loss)
      when(mockGameNotifier.state).thenReturn(AsyncError(Exception('No internet'), StackTrace.empty));
      await tester.pump();

      // Assert
      expect(find.text('Failed to load games'), findsOneWidget);
    });
  });
}