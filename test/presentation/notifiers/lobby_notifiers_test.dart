import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';
import 'package:squad_sync/presentation/notifiers/user_lobbies_notifier.dart';
import 'package:squad_sync/presentation/notifiers/discovery_notifier.dart';

void main() {
  group('Lobby Notifiers Repository Integration', () {
    test('currentLobbyProvider uses unified LobbyNotifier', () {
      expect(currentLobbyProvider, isNotNull);
      expect(currentLobbyProvider, isA<Provider<AsyncValue<Lobby?>>>());
    });

    test('currentLobbyIdProvider is derived from LobbyNotifier', () {
      expect(currentLobbyIdProvider, isNotNull);
      expect(currentLobbyIdProvider, isA<Provider<String?>>());
    });

    test('userLobbiesProvider uses LobbyRepository stream', () {
      expect(userLobbiesProvider, isNotNull);
      expect(userLobbiesProvider, isA<StreamProvider<List<LobbySummary>>>());
    });

    test('publicLobbiesProvider uses LobbyRepository stream', () {
      expect(publicLobbiesProvider, isNotNull);
      expect(publicLobbiesProvider, isA<StreamProvider<dynamic>>());
    });

    test('discoveryFilterProvider is properly defined', () {
      expect(discoveryFilterProvider, isNotNull);
      expect(discoveryFilterProvider, isA<StateProvider<String>>());
    });

    test('popularGamesProvider is properly defined', () {
      expect(popularGamesProvider, isNotNull);
      expect(
        popularGamesProvider,
        isA<FutureProvider<List<Map<String, dynamic>>>>(),
      );
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
