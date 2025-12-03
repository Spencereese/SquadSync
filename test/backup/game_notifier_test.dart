// Commented out - GameNotifier deleted during squad refactor migration
/*
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:cod_squad_app/providers/game_notifier.dart';
import 'package:cod_squad_app/providers/service_providers.dart';
import 'test_setup.dart';
import 'test_utils.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockIgdbAuthService mockIgdbAuthService;

  setUp(() async {
    await TestSetup.initializeFirebase();
    mockIgdbAuthService = MockIgdbAuthService();

    // Mock IGDB service responses
    when(mockIgdbAuthService.searchGames(any)).thenAnswer((_) async => [
          {
            'name': 'Warzone',
            'maxSpots': 4,
            'imageUrl': 'https://example.com/warzone.jpg'
          },
          {
            'name': 'Modern Warfare',
            'maxSpots': 4,
            'imageUrl': 'https://example.com/mw.jpg'
          },
        ]);

    container = ProviderContainer(
      overrides: [
        igdbAuthServiceProvider.overrideWithValue(mockIgdbAuthService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    TestSetup.tearDown();
  });

  group('GameNotifier', () {
    test('initial state should be correct', () async {
      final state = await container.read(gameNotifierProvider.future);

      expect(state.currentGame, isNull);
      expect(state.availableGames, isEmpty);
      expect(state.gameHistory, isEmpty);
      expect(state.gameLobbies, isEmpty);
      expect(state.onboardingFlow, isNull);
      expect(state.isInitialized, isTrue);
      expect(state.errorMessage, isNull);
    });

    test('searchGames should filter local games', () async {
      final notifier = container.read(gameNotifierProvider.notifier);
      final initialGames = [
        {'name': 'Warzone'},
        {'name': 'Modern Warfare'},
        {'name': 'Call of Duty'},
      ];

      // Set initial state with games
      final initialState = GameState.initial().copyWith(
        availableGames: initialGames,
        isInitialized: true,
      );
      container.read(gameNotifierProvider.notifier).state =
          AsyncValue.data(initialState);

      // Act
      await notifier.searchGames('war');

      // Assert
      final state = container.read(gameNotifierProvider).value!;
      expect(state.availableGames.length, 1);
      expect(state.availableGames[0]['name'], 'Warzone');
      expect(state.errorMessage, isNull);
    });

    test('searchGames should handle empty query', () async {
      final notifier = container.read(gameNotifierProvider.notifier);
      final initialGames = [
        {'name': 'Warzone'},
        {'name': 'Modern Warfare'},
      ];

      final initialState = GameState.initial().copyWith(
        availableGames: initialGames,
        isInitialized: true,
      );
      container.read(gameNotifierProvider.notifier).state =
          AsyncValue.data(initialState);

      // Act
      await notifier.searchGames('');

      // Assert
      final state = container.read(gameNotifierProvider).value!;
      expect(state.availableGames, initialGames);
      expect(state.errorMessage, isNull);
    });

    test('selectGame should update current game', () async {
      final gameData = {'id': 1, 'name': 'Warzone', 'maxSpots': 4};
      final notifier = container.read(gameNotifierProvider.notifier);

      // Act
      await notifier.selectGame(gameData);

      // Assert
      final state = container.read(gameNotifierProvider).value!;
      expect(state.currentGame, gameData);
      expect(state.errorMessage, isNull);
    });

    test('pinGame should add to game history', () async {
      final gameData = {'id': 1, 'name': 'Warzone'};
      final notifier = container.read(gameNotifierProvider.notifier);

      // Act
      await notifier.pinGame(gameData);

      // Assert
      final state = container.read(gameNotifierProvider).value!;
      expect(state.gameHistory.length, 1);
      expect(state.gameHistory[0]['name'], 'Warzone');
      expect(state.errorMessage, isNull);
    });

    test('unpinGame should remove from game history', () async {
      final gameData = {'id': 1, 'name': 'Warzone'};
      final notifier = container.read(gameNotifierProvider.notifier);

      // First pin the game
      await notifier.pinGame(gameData);
      expect(container.read(gameNotifierProvider).value!.gameHistory.length, 1);

      // Act
      await notifier.unpinGame('Warzone');

      // Assert
      final state = container.read(gameNotifierProvider).value!;
      expect(state.gameHistory, isEmpty);
      expect(state.errorMessage, isNull);
    });

    test('createLobby should add lobby to game lobbies', () async {
      final gameName = 'Warzone';
      final settings = {'maxPlayers': 4, 'isPublic': true};
      final notifier = container.read(gameNotifierProvider.notifier);

      // Act
      await notifier.createLobby(gameName, settings);

      // Assert
      final state = container.read(gameNotifierProvider).value!;
      expect(state.gameLobbies.containsKey(gameName), isTrue);
      expect(state.gameLobbies[gameName]!.length, 1);
      expect(state.errorMessage, isNull);
    });

    test('joinLobby should update lobby participants', () async {
      final gameName = 'Warzone';
      final lobbyId = 'lobby1';
      final settings = {'maxPlayers': 4, 'isPublic': true};
      final notifier = container.read(gameNotifierProvider.notifier);

      // First create a lobby
      await notifier.createLobby(gameName, settings);

      // Act
      await notifier.joinLobby(lobbyId);

      // Assert
      final state = container.read(gameNotifierProvider).value!;
      expect(state.gameLobbies[gameName]![0]['participants'],
          contains('current_user'));
      expect(state.errorMessage, isNull);
    });

    test('leaveLobby should remove from lobby participants', () async {
      final gameName = 'Warzone';
      final lobbyId = 'lobby1';
      final settings = {'maxPlayers': 4, 'isPublic': true};
      final notifier = container.read(gameNotifierProvider.notifier);

      // Create and join lobby
      await notifier.createLobby(gameName, settings);
      await notifier.joinLobby(lobbyId);

      // Act
      await notifier.leaveLobby(lobbyId);

      // Assert
      final state = container.read(gameNotifierProvider).value!;
      expect(state.gameLobbies[gameName]![0]['participants'],
          isNot(contains('current_user')));
      expect(state.errorMessage, isNull);
    });

    test('addToGameHistory should add entry to history', () async {
      final gameEntry = {'name': 'Warzone', 'playedAt': DateTime.now()};
      final notifier = container.read(gameNotifierProvider.notifier);

      // Act
      await notifier.addToGameHistory(gameEntry);

      // Assert
      final state = container.read(gameNotifierProvider).value!;
      expect(state.gameHistory.length, 1);
      expect(state.gameHistory[0]['name'], 'Warzone');
      expect(state.errorMessage, isNull);
    });

    test('completeOnboardingStep should update onboarding flow', () async {
      final stepData = {'step': 'game_selection', 'completed': true};
      final notifier = container.read(gameNotifierProvider.notifier);

      // Act
      await notifier.completeOnboardingStep('game_selection', stepData);

      // Assert
      final state = container.read(gameNotifierProvider).value!;
      expect(state.onboardingFlow, isNotNull);
      expect(state.onboardingFlow!['game_selection'], stepData);
      expect(state.errorMessage, isNull);
    });

    test('should handle empty game lists', () async {
      final notifier = container.read(gameNotifierProvider.notifier);

      // Act
      await notifier.searchGames('nonexistent');

      // Assert
      final state = container.read(gameNotifierProvider).value!;
      expect(state.availableGames, isEmpty);
      expect(state.errorMessage, isNull);
    });

    test('should handle case insensitive search', () async {
      final notifier = container.read(gameNotifierProvider.notifier);
      final initialGames = [
        {'name': 'Warzone'},
        {'name': 'MODERN WARFARE'},
      ];

      final initialState = GameState.initial().copyWith(
        availableGames: initialGames,
        isInitialized: true,
      );
      container.read(gameNotifierProvider.notifier).state =
          AsyncValue.data(initialState);

      // Act
      await notifier.searchGames('warzone');

      // Assert
      final state = container.read(gameNotifierProvider).value!;
      expect(state.availableGames.length, 2);
    });

    test('should handle special characters in search', () async {
      final notifier = container.read(gameNotifierProvider.notifier);
      final initialGames = [
        {'name': 'Call of Duty: Warzone'},
        {'name': 'Call of Duty Modern Warfare'},
      ];

      final initialState = GameState.initial().copyWith(
        availableGames: initialGames,
        isInitialized: true,
      );
      container.read(gameNotifierProvider.notifier).state =
          AsyncValue.data(initialState);

      // Act
      await notifier.searchGames('Call of Duty');

      // Assert
      final state = container.read(gameNotifierProvider).value!;
      expect(state.availableGames.length, 2);
    });
  });
}
*/

