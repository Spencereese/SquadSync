import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/repositories/lobby_repository.dart';
import 'package:flutter/material.dart';
import 'package:squad_sync/core/app_env.dart';
import 'package:squad_sync/core/injection.dart';
import 'package:squad_sync/services/error_handling_service.dart';
import 'package:squad_sync/services/constitution_manager.dart';
import 'package:squad_sync/services/peacock_assignment_machine.dart';

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

class _FakeConstitutionManager extends Fake implements ConstitutionManager {}

class _PassthroughErrorHandler extends Fake implements ErrorHandlingService {
  @override
  Future<T> withRetryAndMonitoring<T>({
    required Future<T> Function() operation,
    required String operationName,
    BuildContext? context,
    int maxAttempts = 3,
    Duration slowThreshold = const Duration(milliseconds: 500),
  }) =>
      operation();

  @override
  Future<T> withRetry<T>({
    required Future<T> Function() operation,
    String? operationName,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) =>
      operation();

  @override
  Future<T> withPerformanceMonitoring<T>({
    required Future<T> Function() operation,
    required String operationName,
    Duration slowThreshold = const Duration(milliseconds: 500),
  }) =>
      operation();

  @override
  Future<void> handleError({
    BuildContext? context,
    required dynamic error,
    String? operation,
    bool showSnackBar = true,
    bool logToAnalytics = true,
    StackTrace? stackTrace,
  }) async {}

  @override
  Future<void> logEvent(
      String eventName, Map<String, dynamic> parameters) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLobbyRepository mockRepository;
  late ProviderContainer container;

  setUp(() {
    // Avoid NotInitializedError from dotenv/AppEnv during notifier init.
    AppEnv.debugReplaceForTest({
      'SUPABASE_URL': 'https://example.supabase.co',
      'SUPABASE_ANON_KEY': 'test-anon-key-for-unit-harness',
    });
    addTearDown(() => AppEnv.debugReplaceForTest({}));

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
    when(mockRepository.processPeacockQueue()).thenAnswer((_) async {});

    PeacockAssignmentTracker.resetInstance();

    container = ProviderContainer(
      overrides: [
        lobbyRepositoryProvider.overrideWithValue(mockRepository),
        errorHandlingServiceProvider.overrideWithValue(
          _PassthroughErrorHandler(),
        ),
        constitutionManagerProvider.overrideWithValue(
          _FakeConstitutionManager(),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    PeacockAssignmentTracker.resetInstance();
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
      expect(
        PeacockAssignmentTracker.instance.stateFor('user-1').phase,
        PeacockAssignmentPhase.queued,
      );
    });

    test('should remove user from peacock queue', () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      await notifier.addToPeacockQueue('user-1', 'Warzone');
      await notifier.removeFromPeacockQueue('user-1');

      verify(mockRepository.removeFromPeacockQueue('user-1')).called(1);
      expect(
        PeacockAssignmentTracker.instance.stateFor('user-1').phase,
        PeacockAssignmentPhase.idle,
      );
    });

    test('processPeacockQueue repo then assignSpot reduces assigned', () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      await notifier.addToPeacockQueue('user-1', 'Warzone');
      final assigned = await notifier.processPeacockQueue(
        assignedUserId: 'user-1',
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        notificationId: 'n1',
      );

      expect(assigned, 'user-1');
      verify(mockRepository.processPeacockQueue()).called(1);
      final state = PeacockAssignmentTracker.instance.stateFor('user-1');
      expect(state.phase, PeacockAssignmentPhase.assigned);
      expect(state.lobbyId, 'lobby-9');
      expect(state.notificationId, 'n1');
    });

    test('processPeacockQueue without uid selects next queued user', () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      await notifier.addToPeacockQueue('user-1', 'Warzone');
      await notifier.addToPeacockQueue('user-2', 'Warzone');
      final assigned = await notifier.processPeacockQueue(lobbyId: 'lobby-9');

      expect(assigned, 'user-1');
      expect(
        PeacockAssignmentTracker.instance.stateFor('user-1').phase,
        PeacockAssignmentPhase.assigned,
      );
      expect(
        PeacockAssignmentTracker.instance.stateFor('user-2').phase,
        PeacockAssignmentPhase.queued,
      );
    });

    test('addToPeacockQueue does not join when repo fails', () async {
      when(mockRepository.addToPeacockQueue(any, any))
          .thenThrow(Exception('queue down'));
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      await expectLater(
        notifier.addToPeacockQueue('user-1', 'Warzone'),
        throwsA(isA<Exception>()),
      );
      expect(
        PeacockAssignmentTracker.instance.stateFor('user-1').phase,
        PeacockAssignmentPhase.idle,
      );
    });

    test('removeFromPeacockQueue stays queued when repo fails', () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      await notifier.addToPeacockQueue('user-1', 'Warzone');
      when(mockRepository.removeFromPeacockQueue(any))
          .thenThrow(Exception('leave down'));

      await expectLater(
        notifier.removeFromPeacockQueue('user-1'),
        throwsA(isA<Exception>()),
      );
      expect(
        PeacockAssignmentTracker.instance.stateFor('user-1').phase,
        PeacockAssignmentPhase.queued,
      );
    });

    test('processPeacockQueue does not assign when repo fails', () async {
      when(mockRepository.processPeacockQueue())
          .thenThrow(Exception('process down'));
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      await notifier.addToPeacockQueue('user-1', 'Warzone');
      await expectLater(
        notifier.processPeacockQueue(assignedUserId: 'user-1'),
        throwsA(isA<Exception>()),
      );
      expect(
        PeacockAssignmentTracker.instance.stateFor('user-1').phase,
        PeacockAssignmentPhase.queued,
      );
    });

    test('assignPeacockSpot claims next free seat then reduces assigned',
        () async {
      final lobby = _lobby(
        id: 'lobby-9',
        spots: ['taken', null, null],
      );
      when(mockRepository.getLobbyStream('lobby-9')).thenAnswer(
        (_) => Stream<Lobby?>.value(lobby),
      );
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);
      notifier.setSelectedLobbyId('lobby-9');
      await Future<void>.delayed(Duration.zero);
      expect(notifier.nextFreeSpotIndex(lobbyId: 'lobby-9'), 1);

      final claimed = await notifier.assignPeacockSpot(
        userId: 'user-1',
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        notificationId: 'n1',
      );

      expect(claimed, 1);
      verify(mockRepository.assignSpot('lobby-9', 1, 'user-1')).called(1);
      final peacock = PeacockAssignmentTracker.instance.stateFor('user-1');
      expect(peacock.phase, PeacockAssignmentPhase.assigned);
      expect(peacock.lobbyId, 'lobby-9');
      expect(peacock.notificationId, 'n1');
    });

    test('assignPeacockSpot uses explicit spotIndex', () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      final claimed = await notifier.assignPeacockSpot(
        userId: 'user-1',
        lobbyId: 'lobby-9',
        spotIndex: 2,
      );

      expect(claimed, 2);
      verify(mockRepository.assignSpot('lobby-9', 2, 'user-1')).called(1);
      expect(
        PeacockAssignmentTracker.instance.stateFor('user-1').phase,
        PeacockAssignmentPhase.assigned,
      );
    });

    test('assignPeacockSpot without resolvable seat is phase-only handoff',
        () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      final claimed = await notifier.assignPeacockSpot(
        userId: 'user-1',
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
      );

      expect(claimed, isNull);
      verifyNever(mockRepository.assignSpot(any, any, any));
      expect(
        PeacockAssignmentTracker.instance.stateFor('user-1').phase,
        PeacockAssignmentPhase.assigned,
      );
    });

    test('assignPeacockSpot does not reduce when repo assign fails', () async {
      when(mockRepository.assignSpot(any, any, any))
          .thenThrow(Exception('seat down'));
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      await expectLater(
        notifier.assignPeacockSpot(
          userId: 'user-1',
          lobbyId: 'lobby-9',
          spotIndex: 0,
        ),
        throwsA(isA<Exception>()),
      );
      expect(
        PeacockAssignmentTracker.instance.stateFor('user-1').phase,
        PeacockAssignmentPhase.idle,
      );
    });

    test('expirePeacockAssignment returns idle', () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      await notifier.addToPeacockQueue('user-1', 'Warzone');
      await notifier.processPeacockQueue(
        assignedUserId: 'user-1',
        lobbyId: 'lobby-9',
      );
      notifier.expirePeacockAssignment('user-1');

      expect(
        PeacockAssignmentTracker.instance.stateFor('user-1').phase,
        PeacockAssignmentPhase.idle,
      );
    });
  });

  group('resolveNextFreeSpotIndex', () {
    test('returns first empty seat', () {
      expect(
        resolveNextFreeSpotIndex(spots: ['taken', null, null]),
        1,
      );
    });

    test('reuses the user existing seat', () {
      expect(
        resolveNextFreeSpotIndex(
          spots: ['other', 'user-1', null],
          userId: 'user-1',
        ),
        1,
      );
      expect(
        resolveNextFreeSpotIndex(
          spots: ['user-1_calling', null],
          userId: 'user-1',
        ),
        0,
      );
    });

    test('extends when spots are shorter than maxSpots', () {
      expect(
        resolveNextFreeSpotIndex(spots: ['a', 'b'], maxSpots: 4),
        2,
      );
    });

    test('returns null when full or unknown', () {
      expect(resolveNextFreeSpotIndex(), isNull);
      expect(
        resolveNextFreeSpotIndex(spots: ['a', 'b'], maxSpots: 2),
        isNull,
      );
    });

    test('prefers currentLobby then userLobbies then game spots', () {
      final lobby = _lobby(
        id: 'lobby-9',
        spots: ['taken', null],
        chatGroupId: 'chat-9',
      );
      final fromCurrent = resolveNextFreeSpotFromLobbyState(
        state: LobbyState.initial().copyWith(currentLobby: lobby),
        lobbyId: 'lobby-9',
      );
      expect(fromCurrent, 1);

      final fromUser = resolveNextFreeSpotFromLobbyState(
        state: LobbyState.initial().copyWith(
          userLobbies: {'lobby-9': lobby},
        ),
        lobbyId: 'chat-9',
      );
      expect(fromUser, 1);

      final fromGame = resolveNextFreeSpotFromLobbyState(
        state: LobbyState.initial().copyWith(
          gameLobbySpots: {
            'Warzone': ['x', 'y', null],
          },
        ),
        lobbyId: 'missing',
        gameName: 'Warzone',
      );
      expect(fromGame, 2);
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
      expect(notifier.nextFreeSpotIndex(lobbyId: 'missing'), isNull);
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
