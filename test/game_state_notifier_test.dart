import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:squad_sync/presentation/notifiers/game_state_notifier.dart';
import 'package:squad_sync/domain/repositories/game_repository.dart';
import 'package:squad_sync/domain/entities/game.dart';

// Generate mocks with: flutter pub run build_runner build
@GenerateMocks([GameRepository])
import 'game_state_notifier_test.mocks.dart';

void main() {
  group('GameStateNotifier', () {
    late ProviderContainer container;
    late MockGameRepository mockRepository;

    setUp(() {
      mockRepository = MockGameRepository();

      container = ProviderContainer(
        overrides: [
          gameRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('should initialize with empty state', () async {
      when(mockRepository.getAvailableGames()).thenAnswer((_) async => []);
      when(mockRepository.getGameLobbies()).thenAnswer((_) async => {});

      final notifier = container.read(gameStateNotifierProvider.notifier);
      final state = await container.read(gameStateNotifierProvider.future);

      expect(state.currentGame, isNull);
      expect(state.currentGameName, isEmpty);
      expect(state.availableGames, isEmpty);
      expect(state.gameHistory, isEmpty);
      expect(state.gameLobbies, isEmpty);
      expect(state.preferredModes, isEmpty);
      expect(state.mutedGames, isEmpty);
      expect(state.hiddenGames, isEmpty);
      expect(state.isLoading, false);
    });

    test('should set current game', () async {
      // TODO: Implement test for setting current game
      // Test should verify:
      // - currentGame state is updated
      // - currentGameName is updated
      // - Game is added to history
    });

    test('should clear current game', () async {
      // TODO: Implement test for clearing current game
      // Test should verify:
      // - currentGame is set to null
      // - currentGameName is cleared
    });

    test('should search for games via IGDB', () async {
      // TODO: Implement test for game search
      // Test should verify:
      // - Repository fetchGames is called with correct query
      // - isLoading flag is set during search
      // - Results are returned
      // - Error handling for failed searches
    });

    test('should get popular games', () async {
      // TODO: Implement test for popular games
      // Test should verify:
      // - Repository getPopularGames is called
      // - isLoading flag is managed correctly
      // - Games are returned
    });

    test('should get game details by IGDB ID', () async {
      // TODO: Implement test for game details
      // Test should verify:
      // - Repository getGameDetails is called with correct ID
      // - Game details are returned
      // - Null is returned on error
    });

    test('should add game to history', () async {
      // TODO: Implement test for game history
      // Test should verify:
      // - Game is added to front of history
      // - Duplicates are removed
      // - History is limited to 20 games
      // - lastPlayedAt timestamp is added
    });

    test('should update preferred game mode', () async {
      // TODO: Implement test for preferred mode update
      // Test should verify:
      // - preferredModes map is updated
      // - State reflects new mode
    });

    test('should mute/unmute games', () async {
      // TODO: Implement test for game muting
      // Test should verify:
      // - Game is added to mutedGames set
      // - Game is removed from mutedGames set
      // - isGameMuted returns correct value
    });

    test('should hide/unhide games', () async {
      // TODO: Implement test for game hiding
      // Test should verify:
      // - Game is added to hiddenGames set
      // - Game is removed from hiddenGames set
      // - isGameHidden returns correct value
    });

    test('should get cached games for offline support', () async {
      // TODO: Implement test for cached games
      // Test should verify:
      // - Repository getCachedGames is called
      // - Cached games are returned
      // - Empty list on error
    });

    test('should get offline games from local JSON', () async {
      // TODO: Implement test for offline games
      // Test should verify:
      // - Repository getOfflineGames is called with query and limit
      // - Games are returned from local JSON
      // - Empty list on error
    });

    test('should get lobbies for a specific game', () async {
      // TODO: Implement test for game lobbies
      // Test should verify:
      // - Correct lobbies are returned for game
      // - Empty list if no lobbies exist
    });

    test('should refresh game data', () async {
      // TODO: Implement test for game data refresh
      // Test should verify:
      // - Repository methods are called
      // - State is updated with new data
    });

    test('should sync with DiscoveryNotifier', () async {
      // TODO: Implement test for discovery sync
      // Test should verify:
      // - Popular games from discovery are integrated
      // - Available games are updated
    });
  });

  group('Game convenience providers', () {
    test('currentGameProvider should return current game', () async {
      // TODO: Implement test for currentGameProvider
    });

    test('isGameMutedProvider should return muted status', () async {
      // TODO: Implement test for isGameMutedProvider
    });

    test('gameHistoryProvider should return game history', () async {
      // TODO: Implement test for gameHistoryProvider
    });
  });
}
