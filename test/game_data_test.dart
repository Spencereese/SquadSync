import 'package:flutter_test/flutter_test.dart';
import '../lib/managers/game_manager.dart';
import '../lib/squad_state.dart';

void main() {
  group('GameManager Tests', () {
    late GameManager gameManager;

    setUp(() {
      gameManager = GameManager();
    });

    test('GameManager initializes correctly', () {
      expect(gameManager, isNotNull);
      expect(gameManager.availableGames, isNotNull);
      expect(gameManager.preferredPeacockGames, isNotNull);
    });

    test('searchGames returns empty list for empty query', () async {
      final result = await gameManager.searchGames('');
      expect(result, isEmpty);
    });

    test('preferred peacock games can be toggled', () {
      const gameName = 'Test Game';
      expect(gameManager.preferredPeacockGames.contains(gameName), isFalse);

      gameManager.togglePreferredPeacockGame(gameName);
      expect(gameManager.preferredPeacockGames.contains(gameName), isTrue);

      gameManager.togglePreferredPeacockGame(gameName);
      expect(gameManager.preferredPeacockGames.contains(gameName), isFalse);
    });
  });

  group('SquadState Peacock Tests', () {
    late SquadState squadState;

    setUp(() {
      squadState = SquadState();
    });

    test('SquadState initializes with peacock properties', () {
      expect(squadState.peacockQueue, isNotNull);
      expect(squadState.peacockTimers, isNotNull);
      expect(squadState.preferredPeacockGames, isNotNull);
    });

    test('getActivePeacockAlerts returns a stream', () {
      final stream = squadState.getActivePeacockAlerts('Test Game');
      expect(stream, isNotNull);
      // Note: We can't easily test the stream content without Firebase setup
    });
  });
}
