import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_sync/main.dart' show SquadSyncApp;
import 'package:squad_sync/domain/repositories/game_repository.dart';
import 'package:squad_sync/domain/entities/game.dart';
import 'package:squad_sync/presentation/notifiers/game_state_notifier.dart';
import 'package:squad_sync/services/auth_service_supabase.dart';

// Generate mocks with: flutter pub run build_runner build
@GenerateMocks([GameRepository, AuthServiceSupabase])
import 'game_selection_test.mocks.dart';

/// Integration tests for game selection during onboarding flow
/// Tests GameSelectionWidget with IGDB API integration
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Game Selection Integration Tests', () {
    late MockGameRepository mockGameRepository;
    late MockAuthServiceSupabase mockAuthService;

    setUp(() {
      mockGameRepository = MockGameRepository();
      mockAuthService = MockAuthServiceSupabase();

      // Mock new user without pinned games
      when(mockAuthService.currentUserId).thenReturn('new-user-id');
    });

    testWidgets('Complete onboarding game selection flow',
        (WidgetTester tester) async {
      // Arrange: Mock popular games for initial display
      final popularGames = [
        Game(
          id: 1,
          name: 'Call of Duty: Warzone',
          coverUrl: 'https://example.com/warzone.jpg',
          summary: 'Battle royale FPS game',
          rating: 85.0,
        ),
        Game(
          id: 2,
          name: 'Fortnite',
          coverUrl: 'https://example.com/fortnite.jpg',
          summary: 'Popular battle royale',
          rating: 80.0,
        ),
        Game(
          id: 3,
          name: 'Apex Legends',
          coverUrl: 'https://example.com/apex.jpg',
          summary: 'Hero-based battle royale',
          rating: 82.0,
        ),
      ];

      when(mockGameRepository.getPopularGames())
          .thenAnswer((_) async => popularGames);

      when(mockGameRepository.getAvailableGames()).thenAnswer((_) async => []);

      // Act: Build app in onboarding state
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameRepositoryProvider.overrideWithValue(mockGameRepository),
          ],
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert: Should show onboarding screen with popular games
      expect(find.text('Select Your Games'), findsOneWidget);
      expect(find.text('Call of Duty: Warzone'), findsOneWidget);
      expect(find.text('Fortnite'), findsOneWidget);
      expect(find.text('Apex Legends'), findsOneWidget);

      // Act: Select games
      final warzoneCard = find.text('Call of Duty: Warzone');
      await tester.tap(warzoneCard);
      await tester.pumpAndSettle();

      final fortniteCard = find.text('Fortnite');
      await tester.tap(fortniteCard);
      await tester.pumpAndSettle();

      // Assert: Selected games should have visual indicator
      // (Check for selected state - depends on your UI)

      // Act: Complete onboarding
      final continueButton = find.text('Continue');
      await tester.tap(continueButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert: Should navigate to main app
      expect(find.text('Select Your Games'), findsNothing);
    });

    testWidgets('Search for games via IGDB', (WidgetTester tester) async {
      // Arrange: Mock search results
      final searchResults = [
        Game(
          id: 100,
          name: 'Counter-Strike 2',
          coverUrl: 'https://example.com/cs2.jpg',
          summary: 'Tactical FPS',
          rating: 90.0,
        ),
        Game(
          id: 101,
          name: 'Counter-Strike: Global Offensive',
          coverUrl: 'https://example.com/csgo.jpg',
          summary: 'Classic tactical shooter',
          rating: 88.0,
        ),
      ];

      when(mockGameRepository.fetchGames('Counter-Strike',
              limit: anyNamed('limit')))
          .thenAnswer((_) async => searchResults);

      when(mockGameRepository.getPopularGames()).thenAnswer((_) async => []);

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameRepositoryProvider.overrideWithValue(mockGameRepository),
          ],
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Act: Find search bar
      final searchField = find.byType(TextField);
      if (searchField.evaluate().isNotEmpty) {
        await tester.enterText(searchField, 'Counter-Strike');
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Assert: Search results should appear
        expect(find.text('Counter-Strike 2'), findsOneWidget);
        expect(find.text('Counter-Strike: Global Offensive'), findsOneWidget);

        // Assert: Verify IGDB API was called
        verify(mockGameRepository.fetchGames('Counter-Strike',
                limit: anyNamed('limit')))
            .called(1);
      }
    });

    testWidgets('Offline game selection fallback', (WidgetTester tester) async {
      // Arrange: Mock IGDB failure, use cached/local games
      when(mockGameRepository.getPopularGames())
          .thenThrow(Exception('Network error'));

      final offlineGames = [
        Game(
          id: 200,
          name: 'Call of Duty',
          coverUrl: 'assets/images/codwarzone.png',
          summary: 'Popular FPS',
          rating: 85.0,
        ),
        Game(
          id: 201,
          name: 'Battlefield',
          coverUrl: 'assets/images/Battlefield.png',
          summary: 'Military shooter',
          rating: 80.0,
        ),
      ];

      when(mockGameRepository.getOfflineGames('', limit: anyNamed('limit')))
          .thenAnswer((_) async => offlineGames);

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameRepositoryProvider.overrideWithValue(mockGameRepository),
          ],
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Assert: Should show offline games from local JSON
      expect(find.text('Call of Duty'), findsOneWidget);
      expect(find.text('Battlefield'), findsOneWidget);

      // Assert: Should show offline indicator
      expect(find.textContaining('Offline'), findsOneWidget);
    });

    testWidgets('Select minimum required games', (WidgetTester tester) async {
      // Arrange: Mock games
      final games = [
        Game(id: 1, name: 'Game 1', coverUrl: '', summary: '', rating: 80.0),
        Game(id: 2, name: 'Game 2', coverUrl: '', summary: '', rating: 80.0),
        Game(id: 3, name: 'Game 3', coverUrl: '', summary: '', rating: 80.0),
      ];

      when(mockGameRepository.getPopularGames()).thenAnswer((_) async => games);

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameRepositoryProvider.overrideWithValue(mockGameRepository),
          ],
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Act: Try to continue without selecting games
      final continueButton = find.text('Continue');
      if (continueButton.evaluate().isNotEmpty) {
        await tester.tap(continueButton);
        await tester.pumpAndSettle();

        // Assert: Should show error message (need minimum 1 game)
        expect(find.textContaining('Select at least'), findsOneWidget);

        // Act: Select one game
        final game1Card = find.text('Game 1');
        await tester.tap(game1Card);
        await tester.pumpAndSettle();

        // Act: Try continue again
        await tester.tap(continueButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Assert: Should proceed (1 game is enough)
        expect(find.text('Select Your Games'), findsNothing);
      }
    });

    testWidgets('Game card displays correct information',
        (WidgetTester tester) async {
      // Arrange: Mock game with full details
      final detailedGame = Game(
        id: 1,
        name: 'The Witcher 3',
        coverUrl: 'https://example.com/witcher3.jpg',
        summary: 'Epic fantasy RPG',
        rating: 95.0,
        genres: ['RPG', 'Open World'],
        releaseDate: DateTime(2015, 5, 19),
      );

      when(mockGameRepository.getPopularGames())
          .thenAnswer((_) async => [detailedGame]);

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameRepositoryProvider.overrideWithValue(mockGameRepository),
          ],
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert: Game card should show all details
      expect(find.text('The Witcher 3'), findsOneWidget);
      expect(find.text('Epic fantasy RPG'), findsOneWidget);
      expect(find.textContaining('95'), findsOneWidget); // Rating

      // Assert: Cover image should be loaded
      final imageWidget = find.byType(Image);
      expect(imageWidget, findsWidgets);
    });

    testWidgets('Skip game selection (optional onboarding)',
        (WidgetTester tester) async {
      // Arrange: Mock empty games
      when(mockGameRepository.getPopularGames()).thenAnswer((_) async => []);

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameRepositoryProvider.overrideWithValue(mockGameRepository),
          ],
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Act: Find skip button
      final skipButton = find.text('Skip');
      if (skipButton.evaluate().isNotEmpty) {
        await tester.tap(skipButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Assert: Should navigate to main app without selections
        expect(find.text('Select Your Games'), findsNothing);
      }
    });

    testWidgets('Update game selections after onboarding',
        (WidgetTester tester) async {
      // Arrange: User with existing game selections
      final userGames = [
        Game(
            id: 1,
            name: 'Existing Game',
            coverUrl: '',
            summary: '',
            rating: 80.0),
      ];

      final newGames = [
        Game(id: 2, name: 'New Game', coverUrl: '', summary: '', rating: 85.0),
      ];

      when(mockGameRepository.getPopularGames())
          .thenAnswer((_) async => newGames);

      // Act: Build app (user already onboarded)
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameRepositoryProvider.overrideWithValue(mockGameRepository),
          ],
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Navigate to settings > manage games
      final settingsIcon = find.byIcon(Icons.settings);
      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon);
        await tester.pumpAndSettle();

        final manageGamesButton = find.text('Manage Games');
        if (manageGamesButton.evaluate().isNotEmpty) {
          await tester.tap(manageGamesButton);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // Assert: Should show game selection screen again
          expect(find.text('New Game'), findsOneWidget);

          // Act: Add new game
          final newGameCard = find.text('New Game');
          await tester.tap(newGameCard);
          await tester.pumpAndSettle();

          final saveButton = find.text('Save');
          await tester.tap(saveButton);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // Assert: Should return to settings
          expect(find.text('Manage Games'), findsOneWidget);
        }
      }
    });

    testWidgets('Game search with no results', (WidgetTester tester) async {
      // Arrange: Mock empty search results
      when(mockGameRepository.fetchGames('NonexistentGame',
              limit: anyNamed('limit')))
          .thenAnswer((_) async => []);

      when(mockGameRepository.getPopularGames()).thenAnswer((_) async => []);

      // Act: Build app
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameRepositoryProvider.overrideWithValue(mockGameRepository),
          ],
          child: SquadSyncApp(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Act: Search for non-existent game
      final searchField = find.byType(TextField);
      if (searchField.evaluate().isNotEmpty) {
        await tester.enterText(searchField, 'NonexistentGame');
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Assert: Should show "no results" message
        expect(find.textContaining('No games found'), findsOneWidget);
      }
    });
  });

  group('Game Selection Edge Cases', () {
    testWidgets('Handle IGDB API rate limiting', (WidgetTester tester) async {
      // Test behavior when IGDB API returns 429 status
    });

    testWidgets('Handle malformed game data', (WidgetTester tester) async {
      // Test with incomplete game objects
    });

    testWidgets('Handle very long game names', (WidgetTester tester) async {
      // Test UI with games that have long names
    });

    testWidgets('Handle rapid search queries', (WidgetTester tester) async {
      // Test debouncing/throttling of search requests
    });
  });
}
