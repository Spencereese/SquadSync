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

    test('matching is case-insensitive', () {
      const preferred = {'Warzone'};
      expect(
        peacockOfferAllowed(
          gameName: 'warzone',
          preferredPeacockGames: preferred,
        ),
        isTrue,
      );
      expect(
        peacockOfferAllowed(
          gameName: 'WARZONE',
          preferredPeacockGames: preferred,
        ),
        isTrue,
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

    test('empty saved prefs are not re-seeded from LobbyState', () async {
      final store = PreferredPeacockGamesStore.instance;
      await store.toggle('Warzone');
      await store.toggle('Warzone');
      expect(store.snapshot, isEmpty);
      expect(store.hasStoredPreference, isTrue);

      store.reset();
      expect(store.contains('Warzone'), isFalse);

      final loaded = LobbyState.initial().copyWith(
        preferredPeacockGames: {'Warzone'},
      );
      final next = await syncPreferredPeacockGames(loaded);
      expect(store.snapshot, isEmpty);
      expect(next.preferredPeacockGames, isEmpty);
    });

    test('sync loads prefs after in-memory reset (app relaunch)', () async {
      final store = PreferredPeacockGamesStore.instance;
      await store.toggle('Warzone');
      store.reset();
      expect(store.contains('Warzone'), isFalse);

      final next = await syncPreferredPeacockGames(LobbyState.initial());
      expect(store.contains('Warzone'), isTrue);
      expect(next.preferredPeacockGames, {'Warzone'});
    });

    test('missing prefs key still seeds from LobbyState', () async {
      final loaded = LobbyState.initial().copyWith(
        preferredPeacockGames: {'MW2'},
      );
      final next = await syncPreferredPeacockGames(loaded);
      expect(PreferredPeacockGamesStore.instance.snapshot, {'MW2'});
      expect(next.preferredPeacockGames, {'MW2'});
    });

    test('resolvedPreferredPeacockGames uses empty stored prefs over stale state',
        () async {
      final store = PreferredPeacockGamesStore.instance;
      await store.replaceAll(const []);
      expect(store.hasStoredPreference, isTrue);
      final resolved = resolvedPreferredPeacockGames(
        LobbyState.initial().copyWith(preferredPeacockGames: {'Warzone'}),
      );
      expect(resolved, isEmpty);
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
