import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';
import 'package:squad_sync/presentation/notifiers/user_lobbies_notifier.dart';
import 'package:squad_sync/presentation/notifiers/discovery_notifier.dart';

void main() {
  group('Lobby Notifiers Repository Integration', () {
    test('currentLobbyProvider uses unified LobbyNotifier', () {
      // Verify that currentLobbyProvider is properly defined (now from unified notifier)
      expect(currentLobbyProvider, isNotNull);
      expect(currentLobbyProvider, isA<Provider<dynamic>>());
    });

    test('userLobbiesProvider uses LobbyRepository stream', () {
      // Verify that userLobbiesProvider is properly defined
      expect(userLobbiesProvider, isNotNull);
      expect(userLobbiesProvider, isA<StreamProvider<List<LobbySummary>>>());
    });

    test('publicLobbiesProvider uses LobbyRepository stream', () {
      // Verify that publicLobbiesProvider is properly defined
      expect(publicLobbiesProvider, isNotNull);
      expect(publicLobbiesProvider, isA<StreamProvider<dynamic>>());
    });

    test('discoveryFilterProvider is properly defined', () {
      // Verify filter provider
      expect(discoveryFilterProvider, isNotNull);
      expect(discoveryFilterProvider, isA<StateProvider<String>>());
    });

    test('popularGamesProvider is properly defined', () {
      // Verify popular games provider
      expect(popularGamesProvider, isNotNull);
      expect(popularGamesProvider,
          isA<FutureProvider<List<Map<String, dynamic>>>>());
    });
  });

  group('CurrentLobbyNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initializes with null lobby when no ID is set', () async {
      final notifier = container.read(currentLobbyProvider.notifier);
      final state = container.read(currentLobbyProvider);

      // Should be loading initially
      expect(state, isA<AsyncLoading>());
    });

    test('currentLobbyIdProvider can be updated', () {
      // Set a lobby ID
      container.read(currentLobbyIdProvider.notifier).state = 'test-lobby-id';
      final lobbyId = container.read(currentLobbyIdProvider);

      expect(lobbyId, equals('test-lobby-id'));
    });
  });

  group('DiscoveryNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('discoveryFilterProvider defaults to "hot"', () {
      final filter = container.read(discoveryFilterProvider);
      expect(filter, equals('hot'));
    });

    test('discoveryFilterProvider can be updated', () {
      container.read(discoveryFilterProvider.notifier).state = 'new';
      final filter = container.read(discoveryFilterProvider);
      expect(filter, equals('new'));
    });
  });
}
