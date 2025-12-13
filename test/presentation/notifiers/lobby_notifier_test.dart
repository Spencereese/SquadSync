import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/repositories/lobby_repository.dart';
import 'package:squad_sync/services/timer_service.dart';
import 'package:squad_sync/services/auth_service_supabase.dart';
import 'package:squad_sync/core/injection.dart';

@GenerateMocks([LobbyRepository, TimerServiceNotifier, AuthServiceSupabase])
import 'lobby_notifier_test.mocks.dart';

void main() {
  late MockLobbyRepository mockRepository;
  late MockTimerServiceNotifier mockTimerService;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockLobbyRepository();
    mockTimerService = MockTimerServiceNotifier();

    // Set up default stub responses
    when(mockRepository.loadLobbyState()).thenAnswer(
      (_) async => LobbyState.initial(),
    );

    when(mockRepository.getUserLobbiesStream(any)).thenAnswer(
      (_) => Stream.value([]),
    );

    // Create provider container with overrides
    container = ProviderContainer(
      overrides: [
        lobbyRepositoryProvider.overrideWithValue(mockRepository),
        timerServiceProvider.overrideWith((ref) => mockTimerService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('LobbyNotifier - Initialization', () {
    test('should load initial state successfully', () async {
      final initialState = LobbyState.initial();
      when(mockRepository.loadLobbyState())
          .thenAnswer((_) async => initialState);

      final notifier = container.read(lobbyNotifierProvider.notifier);
      final state = await container.read(lobbyNotifierProvider.future);

      expect(state, equals(initialState));
      verify(mockRepository.loadLobbyState()).called(1);
    });

    test('should handle AsyncLoading state during initialization', () {
      final notifier = container.read(lobbyNotifierProvider.notifier);
      final state = container.read(lobbyNotifierProvider);

      expect(state, isA<AsyncLoading>());
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

    test('should handle timeout during initialization', () async {
      when(mockRepository.loadLobbyState()).thenAnswer(
        (_) => Future.delayed(
            const Duration(seconds: 15), () => LobbyState.initial()),
      );

      final state = await container.read(lobbyNotifierProvider.future);

      expect(state, isA<LobbyState>());
      expect(state.currentLobby, isNull);
    });
  });

  group('LobbyNotifier - Lobby Selection', () {
    test('should select lobby and update state', () async {
      final testLobby = Lobby(
        id: 'lobby-1',
        name: 'Test Lobby',
        gameSlug: 'test-game',
        memberUids: ['user-1'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        spots: [],
        chatGroupId: 'chat-1',
      );

      when(mockRepository.loadLobbyState()).thenAnswer(
        (_) async => LobbyState.initial(),
      );

      when(mockRepository.getLobbyStream('lobby-1')).thenAnswer(
        (_) => Stream.value(testLobby),
      );

      final notifier = container.read(lobbyNotifierProvider.notifier);
      await container.read(lobbyNotifierProvider.future);

      await notifier.selectLobby('lobby-1');

      final state = container.read(lobbyNotifierProvider).valueOrNull;
      expect(state?.currentLobbyId, equals('lobby-1'));
    });

    test('should clear selected lobby', () async {
      when(mockRepository.loadLobbyState()).thenAnswer(
        (_) async => LobbyState.initial().copyWith(currentLobbyId: 'lobby-1'),
      );

      final notifier = container.read(lobbyNotifierProvider.notifier);
      await container.read(lobbyNotifierProvider.future);

      await notifier.clearSelectedLobby();

      final state = container.read(lobbyNotifierProvider).valueOrNull;
      expect(state?.currentLobbyId, isNull);
      expect(state?.currentLobby, isNull);
    });
  });

  group('LobbyNotifier - Spot Management', () {
    test('should claim spot successfully', () async {
      final initialState = LobbyState.initial().copyWith(
        currentLobbyId: 'lobby-1',
        currentLobby: Lobby(
          id: 'lobby-1',
          name: 'Test Lobby',
          gameSlug: 'test-game',
          memberUids: ['user-1'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          spots: List.filled(5, null),
          chatGroupId: 'chat-1',
        ),
      );

      when(mockRepository.loadLobbyState())
          .thenAnswer((_) async => initialState);
      when(mockRepository.claimSpot('lobby-1', 0, 'user-1'))
          .thenAnswer((_) async {});

      final notifier = container.read(lobbyNotifierProvider.notifier);
      await container.read(lobbyNotifierProvider.future);

      await notifier.claimSpot(0);

      verify(mockRepository.claimSpot('lobby-1', 0, any)).called(1);
    });

    test('should release spot successfully', () async {
      final initialState = LobbyState.initial().copyWith(
        currentLobbyId: 'lobby-1',
        currentLobby: Lobby(
          id: 'lobby-1',
          name: 'Test Lobby',
          gameSlug: 'test-game',
          memberUids: ['user-1'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          spots: ['user-1', null, null, null, null],
          chatGroupId: 'chat-1',
        ),
      );

      when(mockRepository.loadLobbyState())
          .thenAnswer((_) async => initialState);
      when(mockRepository.releaseSpot('lobby-1', 0)).thenAnswer((_) async {});

      final notifier = container.read(lobbyNotifierProvider.notifier);
      await container.read(lobbyNotifierProvider.future);

      await notifier.releaseSpot(0);

      verify(mockRepository.releaseSpot('lobby-1', 0)).called(1);
    });

    test('should handle claim spot error', () async {
      final initialState = LobbyState.initial().copyWith(
        currentLobbyId: 'lobby-1',
        currentLobby: Lobby(
          id: 'lobby-1',
          name: 'Test Lobby',
          gameSlug: 'test-game',
          memberUids: ['user-1'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          spots: List.filled(5, null),
          chatGroupId: 'chat-1',
        ),
      );

      when(mockRepository.loadLobbyState())
          .thenAnswer((_) async => initialState);
      when(mockRepository.claimSpot('lobby-1', 0, 'user-1')).thenThrow(
        Exception('Spot already claimed'),
      );

      final notifier = container.read(lobbyNotifierProvider.notifier);
      await container.read(lobbyNotifierProvider.future);

      expect(
        () => notifier.claimSpot(0),
        throwsException,
      );
    });
  });

  group('LobbyNotifier - Timer Management', () {
    test('should start timer for spot', () async {
      final initialState = LobbyState.initial().copyWith(
        currentLobbyId: 'lobby-1',
      );

      when(mockRepository.loadLobbyState())
          .thenAnswer((_) async => initialState);
      when(mockRepository.startTimer('lobby-1', 0, 30))
          .thenAnswer((_) async {});

      final notifier = container.read(lobbyNotifierProvider.notifier);
      await container.read(lobbyNotifierProvider.future);

      await notifier.startTimer(0, 30);

      verify(mockRepository.startTimer('lobby-1', 0, 30)).called(1);
    });

    test('should cancel timer for spot', () async {
      final initialState = LobbyState.initial().copyWith(
        currentLobbyId: 'lobby-1',
      );

      when(mockRepository.loadLobbyState())
          .thenAnswer((_) async => initialState);
      when(mockRepository.cancelTimer('lobby-1', 0)).thenAnswer((_) async {});

      final notifier = container.read(lobbyNotifierProvider.notifier);
      await container.read(lobbyNotifierProvider.future);

      await notifier.cancelTimer(0);

      verify(mockRepository.cancelTimer('lobby-1', 0)).called(1);
    });
  });

  group('LobbyNotifier - Peacock Queue', () {
    test('should add user to peacock queue', () async {
      final initialState = LobbyState.initial().copyWith(
        currentLobbyId: 'lobby-1',
      );

      when(mockRepository.loadLobbyState())
          .thenAnswer((_) async => initialState);
      when(mockRepository.addToPeacockQueue('lobby-1', 'user-1'))
          .thenAnswer((_) async {});

      final notifier = container.read(lobbyNotifierProvider.notifier);
      await container.read(lobbyNotifierProvider.future);

      await notifier.addToPeacockQueue();

      verify(mockRepository.addToPeacockQueue('lobby-1', any)).called(1);
    });

    test('should remove user from peacock queue', () async {
      final initialState = LobbyState.initial().copyWith(
        currentLobbyId: 'lobby-1',
      );

      when(mockRepository.loadLobbyState())
          .thenAnswer((_) async => initialState);
      when(mockRepository.removeFromPeacockQueue('lobby-1', 'user-1'))
          .thenAnswer((_) async {});

      final notifier = container.read(lobbyNotifierProvider.notifier);
      await container.read(lobbyNotifierProvider.future);

      await notifier.removeFromPeacockQueue();

      verify(mockRepository.removeFromPeacockQueue('lobby-1', any)).called(1);
    });
  });

  group('LobbyNotifier - User Lobbies', () {
    test('should load user lobbies', () async {
      final testLobbies = [
        Lobby(
          id: 'lobby-1',
          name: 'Lobby 1',
          gameSlug: 'game-1',
          memberUids: ['user-1'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          spots: [],
          chatGroupId: 'chat-1',
        ),
        Lobby(
          id: 'lobby-2',
          name: 'Lobby 2',
          gameSlug: 'game-2',
          memberUids: ['user-1'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          spots: [],
          chatGroupId: 'chat-2',
        ),
      ];

      when(mockRepository.loadLobbyState()).thenAnswer(
        (_) async => LobbyState.initial(),
      );

      when(mockRepository.getUserLobbiesStream('user-1')).thenAnswer(
        (_) => Stream.value(testLobbies),
      );

      final notifier = container.read(lobbyNotifierProvider.notifier);
      await container.read(lobbyNotifierProvider.future);

      // State should eventually contain user lobbies via stream
      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(lobbyNotifierProvider).valueOrNull;
      expect(state, isNotNull);
    });
  });

  group('LobbyNotifier - Error Handling', () {
    test('should handle repository errors gracefully', () async {
      when(mockRepository.loadLobbyState()).thenThrow(
        Exception('Repository error'),
      );

      final state = await container.read(lobbyNotifierProvider.future);

      expect(state, isA<LobbyState>());
      expect(state.currentLobby, isNull);
    });

    test('should handle stream errors', () async {
      when(mockRepository.loadLobbyState()).thenAnswer(
        (_) async => LobbyState.initial(),
      );

      when(mockRepository.getUserLobbiesStream(any)).thenAnswer(
        (_) => Stream.error(Exception('Stream error')),
      );

      final notifier = container.read(lobbyNotifierProvider.notifier);
      final state = await container.read(lobbyNotifierProvider.future);

      expect(state, isA<LobbyState>());
    });
  });
}
