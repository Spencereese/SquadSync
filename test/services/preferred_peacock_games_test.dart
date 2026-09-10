import 'package:flutter/foundation.dart';
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

    test(
        'resolvedPreferredPeacockGames uses empty stored prefs over stale state',
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

  group('preferred peacock filter mapper', () {
    test('empty preferred is no-games-selected, not matches', () {
      final result = mapPreferredPeacockFilter(
        preferredPeacockGames: const {},
        offerGameNames: const ['Warzone', 'Fortnite'],
      );
      expect(result.isEmpty, isTrue);
      expect(result.isFailed, isFalse);
      expect(result.isData, isFalse);
      expect(
        result.emptyKind,
        PreferredPeacockFilterEmptyKind.noGamesSelected,
      );
      expect(result.matches, isEmpty);
      expect(
        preferredPeacockFilterMessage(result),
        kPreferredPeacockFilterNoGamesSelectedCopy,
      );
      expect(
        preferredPeacockFilterHint(result),
        kPreferredPeacockFilterNoGamesSelectedHint,
      );
      expect(
        preferredPeacockFilterKey(result),
        const Key('preferred-peacock-games-empty-selected'),
      );
    });

    test('non-empty preferred with no matching offers is no-matches', () {
      final result = mapPreferredPeacockFilter(
        preferredPeacockGames: const {'Warzone'},
        offerGameNames: const ['Fortnite', 'Halo', null, '  '],
      );
      expect(result.isEmpty, isTrue);
      expect(
        result.emptyKind,
        PreferredPeacockFilterEmptyKind.noMatches,
      );
      expect(result.matches, isEmpty);
      expect(
        preferredPeacockFilterMessage(result),
        kPreferredPeacockFilterNoMatchesCopy,
      );
      expect(
        preferredPeacockFilterHint(result),
        kPreferredPeacockFilterNoMatchesHint,
      );
      expect(
        preferredPeacockFilterKey(result),
        const Key('preferred-peacock-games-empty-matches'),
      );
    });

    test('non-empty preferred with no offers is no-matches', () {
      final result = mapPreferredPeacockFilter(
        preferredPeacockGames: const {'Warzone'},
        offerGameNames: const [],
      );
      expect(result.isEmpty, isTrue);
      expect(
        result.emptyKind,
        PreferredPeacockFilterEmptyKind.noMatches,
      );
    });

    test('matching offers are data', () {
      final result = mapPreferredPeacockFilter(
        preferredPeacockGames: const {'Warzone', 'MW2'},
        offerGameNames: const ['fortnite', 'warzone', 'MW2'],
      );
      expect(result.isData, isTrue);
      expect(result.isEmpty, isFalse);
      expect(result.matches, ['warzone', 'MW2']);
      expect(
        preferredPeacockFilterKey(result),
        const Key('preferred-peacock-games'),
      );
    });

    test('persist/load error wins over empty', () {
      final result = mapPreferredPeacockFilter(
        preferredPeacockGames: const {},
        offerGameNames: const [],
        error: Exception('offline'),
      );
      expect(result.isFailed, isTrue);
      expect(result.isEmpty, isFalse);
      expect(preferredPeacockFilterErrorDetail(result.error), 'offline');
      expect(
        preferredPeacockFilterMessage(result),
        kPreferredPeacockFilterErrorCopy,
      );
      expect(
        preferredPeacockFilterHint(result),
        kPreferredPeacockFilterErrorHint,
      );
      expect(
        preferredPeacockFilterKey(result),
        const Key('preferred-peacock-games-error'),
      );
    });

    test('thrown persist is error, not a silent empty', () async {
      final result = await runPreferredPeacockFilter(
        () async => throw Exception('offline'),
        preferredPeacockGames: const {'Warzone'},
        offerGameNames: const ['Warzone'],
      );
      expect(result.isFailed, isTrue);
      expect(result.isData, isFalse);
      expect(preferredPeacockFilterErrorDetail(result.error), 'offline');
      expect(
        preferredPeacockFilterMessage(result),
        kPreferredPeacockFilterErrorCopy,
      );
    });

    test('successful persist with empty preferred is empty', () async {
      var calls = 0;
      final result = await runPreferredPeacockFilter(
        () async {
          calls++;
        },
        preferredPeacockGames: const {},
        offerGameNames: const ['Warzone'],
      );
      expect(result.isEmpty, isTrue);
      expect(
        result.emptyKind,
        PreferredPeacockFilterEmptyKind.noGamesSelected,
      );
      expect(calls, 1);
    });

    test('retry re-runs persist and can succeed', () async {
      var calls = 0;
      Future<void> persist() async {
        calls++;
        if (calls == 1) throw Exception('offline');
      }

      const preferred = {'Warzone'};
      const offers = ['Warzone'];
      final first = await runPreferredPeacockFilter(
        persist,
        preferredPeacockGames: preferred,
        offerGameNames: offers,
      );
      expect(first.isFailed, isTrue);
      expect(calls, 1);

      final second = await retryPreferredPeacockFilter(
        persist,
        preferredPeacockGames: preferred,
        offerGameNames: offers,
      );
      expect(second.isData, isTrue);
      expect(second.matches, ['Warzone']);
      expect(calls, 2);
    });

    test('retry after error can stay error', () async {
      Future<void> persist() async => throw Exception('denied');
      const preferred = {'Warzone'};
      final first = await runPreferredPeacockFilter(
        persist,
        preferredPeacockGames: preferred,
      );
      final second = await retryPreferredPeacockFilter(
        persist,
        preferredPeacockGames: preferred,
      );
      expect(first.isFailed, isTrue);
      expect(second.isFailed, isTrue);
      expect(preferredPeacockFilterErrorDetail(second.error), 'denied');
    });
  });
}
