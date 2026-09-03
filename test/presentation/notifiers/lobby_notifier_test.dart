import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/repositories/lobby_repository.dart';
import 'package:squad_sync/core/injection.dart';

@GenerateMocks([LobbyRepository])
import 'lobby_notifier_test.mocks.dart';

Lobby _lobby({
  String id = 'lobby-1',
  String name = 'Test Lobby',
  String gameName = 'Warzone',
  List<String> memberUids = const ['user-1'],
  List<String?>? spots,
  String chatGroupId = 'chat-1',
}) {
  final maxSpots = spots?.length ?? 5;
  return Lobby.create(
    name: name,
    gameName: gameName,
    maxSpots: maxSpots,
    createdBy: memberUids.first,
  ).copyWith(
    id: id,
    memberUids: memberUids,
    spots: spots ?? List<String?>.filled(maxSpots, null),
    chatGroupId: chatGroupId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLobbyRepository mockRepository;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockLobbyRepository();

    when(mockRepository.loadLobbyState()).thenAnswer(
      (_) async => LobbyState.initial(),
    );
    when(mockRepository.getUserLobbiesStream(any)).thenAnswer(
      (_) => Stream<List<Lobby>>.value(const []),
    );
    when(mockRepository.getLobbyStream(any)).thenAnswer(
      (_) => Stream<Lobby?>.value(null),
    );
    when(mockRepository.addToPeacockQueue(any, any)).thenAnswer((_) async {});
    when(mockRepository.removeFromPeacockQueue(any)).thenAnswer((_) async {});
    when(mockRepository.startSpotTimer(any, any, any)).thenAnswer((_) async {});
    when(mockRepository.cancelSpotTimer(any, any)).thenAnswer((_) async {});
    when(mockRepository.assignSpot(any, any, any)).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        lobbyRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('LobbyNotifier - Initialization', () {
    test('should load initial state successfully', () async {
      final state = await container.read(lobbyNotifierProvider.future);

      expect(state, isA<LobbyState>());
      expect(state.isInitialized, isTrue);
      expect(state.currentLobby, isNull);
      expect(state.selectedLobbyId, isNull);
    });

    test('should handle AsyncLoading state during initialization', () {
      final state = container.read(lobbyNotifierProvider);

      expect(state, isA<AsyncLoading<LobbyState>>());
    });

    test('should handle error during initialization and return initial state',
        () async {
      when(mockRepository.loadLobbyState()).thenThrow(
        Exception('Failed to load lobby state'),
      );

      final state = await container.read(lobbyNotifierProvider.future);

      expect(state, isA<LobbyState>());
      expect(state.currentLobby, isNull);
    });
  });

  group('LobbyNotifier - Lobby Selection', () {
    test('should select lobby and update selectedLobbyId', () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      notifier.setSelectedLobbyId('lobby-1');

      final state = container.read(lobbyNotifierProvider).valueOrNull;
      expect(state?.selectedLobbyId, 'lobby-1');
      expect(container.read(currentLobbyIdProvider), 'lobby-1');
    });

    test('should clear selected lobby', () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      notifier.setSelectedLobbyId('lobby-1');
      notifier.setSelectedLobbyId(null);

      final state = container.read(lobbyNotifierProvider).valueOrNull;
      expect(state?.selectedLobbyId, isNull);
      expect(container.read(currentLobbyIdProvider), isNull);
    });
  });

  group('LobbyNotifier - Spot Management', () {
    test('claimSpot completes without a signed-in user', () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      await notifier.claimSpot('Warzone', 0);

      verifyNever(mockRepository.assignSpot(any, any, any));
    });

    test('should assign spot via repository', () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      await notifier.assignSpot('lobby-1', 0, 'user-1');

      verify(mockRepository.assignSpot('lobby-1', 0, 'user-1')).called(1);
    });
  });

  group('LobbyNotifier - Timer Management', () {
    test('should start spot timer via repository', () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      await notifier.startSpotTimer(
        'lobby-1',
        0,
        const Duration(seconds: 30),
      );

      verify(mockRepository.startSpotTimer(
        'lobby-1',
        0,
        const Duration(seconds: 30),
      )).called(1);
    });
  });

  group('LobbyNotifier - Peacock Queue', () {
    test('should add user to peacock queue', () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      await notifier.addToPeacockQueue('user-1', 'Warzone');

      verify(mockRepository.addToPeacockQueue('user-1', 'Warzone')).called(1);
    });

    test('should remove user from peacock queue', () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      await notifier.removeFromPeacockQueue('user-1');

      verify(mockRepository.removeFromPeacockQueue('user-1')).called(1);
    });
  });

  group('LobbyNotifier - Helpers', () {
    test('empty state helpers', () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      expect(notifier.getDisplayNameForUid('missing'), 'Unknown User');
      expect(notifier.getSquadSpots('Warzone'), isEmpty);
      expect(notifier.isUserInSquad('user-1', null), isFalse);
      expect(notifier.getActiveSquadMembersCount(null), 0);
      expect(notifier.getSquadHealthStatus(null), 'unknown');
      expect(notifier.getSquadHealthStatus('missing'), 'empty');
    });
  });

  group('LobbyNotifier - Compatibility providers', () {
    test('currentLobbyProvider is a derived Provider', () async {
      await container.read(lobbyNotifierProvider.future);

      expect(currentLobbyProvider, isA<Provider<AsyncValue<Lobby?>>>());
      final current = container.read(currentLobbyProvider);
      expect(current, isA<AsyncData<Lobby?>>());
      expect(current.value, isNull);
    });
  });

  group('Lobby fixture', () {
    test('Lobby.create matches current entity fields', () {
      final lobby = _lobby(spots: ['user-1', null, null, null, null]);
      expect(lobby.gameName, 'Warzone');
      expect(lobby.spots.first, 'user-1');
      expect(lobby.maxSpots, 5);
    });
  });
}
