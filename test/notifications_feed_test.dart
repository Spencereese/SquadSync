import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cod_squad_app/managers/user_manager.dart';

// Mock classes
class MockUserManager extends Mock implements UserManager {}

void main() {
  late UserManager userManager;

  setUp(() {
    userManager = UserManager();
  });

  group('Notifications Feed Tests', () {
    test('Quiet games toggle mutes games correctly', () async {
      final gameSlug = 'cod-mw3';

      // Initially no games muted
      expect(userManager.isGameMuted(gameSlug), false);

      // Mute a game
      await userManager.muteGame(gameSlug);
      expect(userManager.isGameMuted(gameSlug), true);

      // Clear muted games
      await userManager.clearMutedGames();
      expect(userManager.isGameMuted(gameSlug), false);
    });

    test('Multiple games can be muted independently', () async {
      final game1 = 'cod-mw3';
      final game2 = 'fortnite';

      // Mute first game
      await userManager.muteGame(game1);
      expect(userManager.isGameMuted(game1), true);
      expect(userManager.isGameMuted(game2), false);

      // Mute second game
      await userManager.muteGame(game2);
      expect(userManager.isGameMuted(game1), true);
      expect(userManager.isGameMuted(game2), true);

      // Clear all
      await userManager.clearMutedGames();
      expect(userManager.isGameMuted(game1), false);
      expect(userManager.isGameMuted(game2), false);
    });

    test('Muted games set tracks multiple games', () async {
      final games = ['cod-mw3', 'fortnite', 'apex-legends'];

      // Mute all games
      for (final game in games) {
        await userManager.muteGame(game);
      }

      expect(userManager.mutedGames.length, 3);
      expect(userManager.mutedGames.contains('cod-mw3'), true);
      expect(userManager.mutedGames.contains('fortnite'), true);
      expect(userManager.mutedGames.contains('apex-legends'), true);

      // Clear and verify
      await userManager.clearMutedGames();
      expect(userManager.mutedGames.isEmpty, true);
    });
  });
}
