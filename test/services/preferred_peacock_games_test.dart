import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/services/preferred_peacock_games.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferredPeacockGamesStore.instance.reset();
  });

  tearDown(() {
    PreferredPeacockGamesStore.instance.reset();
  });

  group('peacockOfferAllowed', () {
    test('empty preferred set is unfiltered', () {
      expect(
        peacockOfferAllowed(
          gameName: 'Warzone',
          preferredPeacockGames: const {},
        ),
        isTrue,
      );
      expect(
        peacockOfferAllowed(
          gameName: null,
          preferredPeacockGames: const {},
        ),
        isTrue,
      );
    });

    test('non-empty preferred keeps only matching games', () {
      const preferred = {'Warzone', 'MW2'};
      expect(
        peacockOfferAllowed(
          gameName: 'Warzone',
          preferredPeacockGames: preferred,
        ),
        isTrue,
      );
      expect(
        peacockOfferAllowed(
          gameName: 'Fortnite',
          preferredPeacockGames: preferred,
        ),
        isFalse,
      );
      expect(
        peacockOfferAllowed(
          gameName: null,
          preferredPeacockGames: preferred,
        ),
        isFalse,
      );
      expect(
        peacockOfferAllowed(
          gameName: '  ',
          preferredPeacockGames: preferred,
        ),
        isFalse,
      );
    });
  });

  group('PreferredPeacockGamesStore persist', () {
    test('toggle persists across load', () async {
      final store = PreferredPeacockGamesStore.instance;
      await store.toggle('Warzone');
      expect(store.contains('Warzone'), isTrue);

      store.reset();
      expect(store.contains('Warzone'), isFalse);

      await store.load();
      expect(store.contains('Warzone'), isTrue);
      expect(store.snapshot, {'Warzone'});
    });

    test('toggle off removes and persists', () async {
      final store = PreferredPeacockGamesStore.instance;
      await store.toggle('Warzone');
      await store.toggle('MW2');
      await store.toggle('Warzone');
      expect(store.snapshot, {'MW2'});

      store.reset();
      await store.load();
      expect(store.contains('Warzone'), isFalse);
      expect(store.contains('MW2'), isTrue);
    });

    test('seedIfEmpty copies existing LobbyState field once', () async {
      final store = PreferredPeacockGamesStore.instance;
      await store.seedIfEmpty({'Warzone'});
      expect(store.snapshot, {'Warzone'});
      await store.seedIfEmpty({'MW2'});
      expect(store.snapshot, {'Warzone'});
    });
  });

  group('overlay / choices', () {
    test('overlay copies preferred onto loaded lobby state', () {
      final loaded = LobbyState.initial();
      final next = overlayPreferredPeacockGames(
        loaded,
        preferred: {'Warzone'},
      );
      expect(next.preferredPeacockGames, {'Warzone'});
      expect(loaded.preferredPeacockGames, isEmpty);
    });

    test('choices include available, current, preferred, and lobby games', () {
      final lobby = Lobby.create(
        name: 'Squad',
        gameName: 'MW2',
        maxSpots: 4,
        createdBy: 'u1',
      ).copyWith(id: 'lobby-9');
      final state = LobbyState.initial().copyWith(
        availableGames: [
          {'name': 'Warzone'},
          {'name': 'Fortnite'},
        ],
        currentGame: {'name': 'Battlefield'},
        preferredPeacockGames: {'Halo'},
        userLobbies: {lobby.id: lobby},
      );
      expect(
        preferredPeacockGameChoices(state),
        ['Battlefield', 'Fortnite', 'Halo', 'MW2', 'Warzone'],
      );
    });
  });
}
