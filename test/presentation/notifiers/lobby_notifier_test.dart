import 'dart:async';

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
import 'package:squad_sync/services/lobby_ready_lock.dart';
import 'package:squad_sync/services/matchmaking_queue_machine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_sync/services/peacock_assignment_machine.dart';
import 'package:squad_sync/services/peacock_lock_live_activity.dart';
import 'package:squad_sync/services/preferred_peacock_games.dart';
import 'package:squad_sync/services/session_rating_machine.dart';
import 'package:squad_sync/services/squad_analytics.dart';

@GenerateMocks([LobbyRepository])
import 'lobby_notifier_test.mocks.dart';

Lobby _lobby({
  String id = 'lobby-1',
  String name = 'Test Lobby',
  String gameName = 'Warzone',
  List<String> memberUids = const ['user-1'],
  List<String?>? spots,
  Map<String, String> statuses = const {},
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
    statuses: statuses,
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
    when(mockRepository.updateMemberStatus(any, any, any))
        .thenAnswer((_) async {});
    when(mockRepository.processPeacockQueue()).thenAnswer((_) async {});
    when(mockRepository.saveLobbyState(any)).thenAnswer((_) async {});

    SharedPreferences.setMockInitialValues({});
    PreferredPeacockGamesStore.instance.reset();
    PeacockAssignmentTracker.resetInstance();
    MatchmakingQueueTracker.resetInstance();
    LobbyLockNotify.resetTestHooks();
    PeacockLockLiveActivity.resetTestHooks();
    SquadAnalytics.resetTestHooks();
    SquadAnalytics.logHook = (_, __) async {};

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
    PreferredPeacockGamesStore.instance.reset();
    PeacockAssignmentTracker.resetInstance();
    MatchmakingQueueTracker.resetInstance();
    LobbyLockNotify.resetTestHooks();
    PeacockLockLiveActivity.resetTestHooks();
    SquadAnalytics.resetTestHooks();
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

    test('lobby stream processQueue matches looking without peacock assign',
        () async {
      MatchmakingQueueTracker.instance.startLooking('user-1');
      final lobby = _lobby(
        id: 'lobby-9',
        spots: [null, null],
      );
      when(mockRepository.getLobbyStream('lobby-9')).thenAnswer(
        (_) => Stream<Lobby?>.value(lobby),
      );
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);
      notifier.setSelectedLobbyId('lobby-9');
      await Future<void>.delayed(Duration.zero);

      final lfg = MatchmakingQueueTracker.instance.stateFor('user-1');
      expect(lfg.phase, MatchmakingQueuePhase.matched);
      expect(lfg.lobbyId, 'lobby-9');
      expect(
        PeacockAssignmentTracker.instance.stateFor('user-1').phase,
        PeacockAssignmentPhase.idle,
      );
      expect(
        PeacockAssignmentTracker.instance.stateFor('user-1').showedLocal,
        isFalse,
      );
      expect(
        PeacockAssignmentTracker.instance.stateFor('user-1').sentFcmToSelf,
        isFalse,
      );
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

    test('togglePreferredPeacockGame persists across notifier rebuild',
        () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      await notifier.togglePreferredPeacockGame('Warzone');
      expect(
        container
            .read(lobbyNotifierProvider)
            .valueOrNull
            ?.preferredPeacockGames,
        {'Warzone'},
      );
      expect(PreferredPeacockGamesStore.instance.snapshot, {'Warzone'});
      verify(mockRepository.saveLobbyState(any)).called(1);

      PreferredPeacockGamesStore.instance.reset();
      expect(PreferredPeacockGamesStore.instance.contains('Warzone'), isFalse);

      container.dispose();
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
      final reloaded = await container.read(lobbyNotifierProvider.future);
      expect(reloaded.preferredPeacockGames, {'Warzone'});
      expect(PreferredPeacockGamesStore.instance.snapshot, {'Warzone'});
    });

    test('togglePreferredPeacockGame persist fail surfaces error and retry',
        () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      when(mockRepository.saveLobbyState(any)).thenThrow(Exception('offline'));
      await notifier.togglePreferredPeacockGame('Warzone');
      expect(PreferredPeacockGamesStore.instance.snapshot, {'Warzone'});
      expect(
        PreferredPeacockGamesStore.instance.lastError.toString(),
        contains('offline'),
      );
      expect(
        mapPreferredPeacockFilter(
          preferredPeacockGames: PreferredPeacockGamesStore.instance.snapshot,
          error: PreferredPeacockGamesStore.instance.lastError,
        ).isFailed,
        isTrue,
      );

      when(mockRepository.saveLobbyState(any)).thenAnswer((_) async {});
      await notifier.retryPreferredPeacockGames();
      expect(PreferredPeacockGamesStore.instance.lastError, isNull);
      expect(PreferredPeacockGamesStore.instance.snapshot, {'Warzone'});
      verify(mockRepository.saveLobbyState(any))
          .called(greaterThanOrEqualTo(1));
    });

    test('processPeacockQueue skips assign when preferred games exclude title',
        () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);
      await notifier.togglePreferredPeacockGame('Warzone');

      await notifier.addToPeacockQueue('user-1', 'Fortnite');
      final assigned = await notifier.processPeacockQueue(
        assignedUserId: 'user-1',
        lobbyId: 'lobby-9',
        gameName: 'Fortnite',
        notificationId: 'n1',
      );

      expect(assigned, isNull);
      expect(
        PeacockAssignmentTracker.instance.stateFor('user-1').phase,
        PeacockAssignmentPhase.queued,
      );
    });

    test('processPeacockQueue assigns when preferred games include title',
        () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);
      await notifier.togglePreferredPeacockGame('Warzone');

      await notifier.addToPeacockQueue('user-1', 'Warzone');
      final assigned = await notifier.processPeacockQueue(
        assignedUserId: 'user-1',
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        notificationId: 'n1',
      );

      expect(assigned, 'user-1');
      expect(
        PeacockAssignmentTracker.instance.stateFor('user-1').phase,
        PeacockAssignmentPhase.assigned,
      );
    });

    test('processPeacockQueue selects next queued user whose game is preferred',
        () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);
      await notifier.togglePreferredPeacockGame('Warzone');

      await notifier.addToPeacockQueue('user-1', 'Fortnite');
      await notifier.addToPeacockQueue('user-2', 'Warzone');
      final assigned = await notifier.processPeacockQueue(lobbyId: 'lobby-9');

      expect(assigned, 'user-2');
      expect(
        PeacockAssignmentTracker.instance.stateFor('user-1').phase,
        PeacockAssignmentPhase.queued,
      );
      expect(
        PeacockAssignmentTracker.instance.stateFor('user-2').phase,
        PeacockAssignmentPhase.assigned,
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

  group('seated Ready / lobby Lock', () {
    Future<LobbyNotifier> pumpSeatedLobby({
      Map<String, String> statuses = const {},
    }) async {
      final lobby = _lobby(
        id: 'lobby-9',
        memberUids: const ['user-1', 'user-2'],
        spots: ['user-1', 'user-2', null],
        statuses: statuses,
      );
      when(mockRepository.getLobbyStream('lobby-9')).thenAnswer(
        (_) => Stream<Lobby?>.value(lobby),
      );
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);
      notifier.setSelectedLobbyId('lobby-9');
      await Future<void>.delayed(Duration.zero);
      return notifier;
    }

    test('toggleSeatedReady writes Ready on the live path', () async {
      final notifier = await pumpSeatedLobby();

      final result = await notifier.toggleSeatedReady(
        userId: 'user-1',
        gameName: 'Warzone',
        spotIndex: 0,
      );

      expect(result, isNotNull);
      expect(result!.snapshot.isReady('user-1'), isTrue);
      expect(result.snapshot.isLocked, isFalse);
      expect(result.justLocked, isFalse);
      verify(mockRepository.updateMemberStatus('lobby-9', 'user-1', 'Ready'))
          .called(1);
    });

    test('all seated Ready locks and notifies seated members', () async {
      List<String>? sentUids;
      Map<String, dynamic>? sentData;
      LobbyLockNotify.sendToUsersHook = ({
        required title,
        required body,
        required recipientUids,
        data,
      }) async {
        sentUids = recipientUids;
        sentData = data;
      };
      PeacockLockLiveActivityPlan? livePlan;
      PeacockLockLiveActivity.invokeHook = (plan) async {
        livePlan = plan;
        return 'act-lock';
      };

      final notifier = await pumpSeatedLobby(
        statuses: const {'user-1': 'Ready'},
      );

      final result = await notifier.toggleSeatedReady(
        userId: 'user-2',
        gameName: 'Warzone',
        spotIndex: 1,
      );

      expect(result!.justLocked, isTrue);
      expect(result.snapshot.isLocked, isTrue);
      expect(result.snackbarMessage, 'Squad locked — go in the game');
      verify(mockRepository.updateMemberStatus('lobby-9', 'user-2', 'Ready'))
          .called(1);
      expect(sentUids, ['user-1']);
      expect(sentData!['type'], kLobbyLockedType);
      expect(sentData!['lobby_id'], 'lobby-9');
      expect(livePlan, isNotNull);
      expect(
        livePlan!.op,
        anyOf(
          PeacockLockLiveActivityOp.start,
          PeacockLockLiveActivityOp.update,
        ),
      );
      expect(livePlan!.payload.phase, PeacockLockLiveActivityPhase.locked);
      expect(livePlan!.payload.lobbyId, 'lobby-9');
    });

    test('toggle when locked unlocks and notifies seated members', () async {
      List<String>? sentUids;
      Map<String, dynamic>? sentData;
      LobbyLockNotify.sendToUsersHook = ({
        required title,
        required body,
        required recipientUids,
        data,
      }) async {
        sentUids = recipientUids;
        sentData = data;
      };

      final notifier = await pumpSeatedLobby(
        statuses: const {'user-1': 'Ready', 'user-2': 'Ready'},
      );

      final result = await notifier.toggleSeatedReady(
        userId: 'user-1',
        gameName: 'Warzone',
        spotIndex: 0,
      );

      expect(result!.justUnlocked, isTrue);
      expect(result.snapshot.isLocked, isFalse);
      expect(result.snackbarMessage, 'Squad unlocked');
      verify(mockRepository.updateMemberStatus('lobby-9', 'user-1', 'Occupied'))
          .called(1);
      expect(sentUids, ['user-2']);
      expect(sentData!['type'], kLobbyUnlockedType);
    });

    test('unlock after lock clears locked on the widget payload mock',
        () async {
      PeacockLockLiveActivityPlan? livePlan;
      PeacockLockLiveActivity.invokeHook = (plan) async {
        livePlan = plan;
        if (plan.op == PeacockLockLiveActivityOp.start) return 'act-lock';
        return plan.payload.activityId;
      };

      final notifier = await pumpSeatedLobby(
        statuses: const {'user-1': 'Ready'},
      );
      await notifier.toggleSeatedReady(
        userId: 'user-2',
        gameName: 'Warzone',
        spotIndex: 1,
      );
      expect(livePlan, isNotNull);
      expect(livePlan!.payload.isLocked, isTrue);
      expect(livePlan!.payload.toChannelArgs()['locked'], isTrue);

      final result = await notifier.toggleSeatedReady(
        userId: 'user-1',
        gameName: 'Warzone',
        spotIndex: 0,
      );

      expect(result!.justUnlocked, isTrue);
      expect(livePlan!.payload.isLocked, isFalse);
      expect(livePlan!.payload.phase, PeacockLockLiveActivityPhase.ready);
      expect(livePlan!.payload.toChannelArgs()['locked'], isFalse);
      expect(livePlan!.payload.toChannelArgs()['phase'], 'ready');
    });

    test('timeoutReadyCheck clears Ready and notifies seated', () async {
      List<String>? sentUids;
      Map<String, dynamic>? sentData;
      LobbyLockNotify.sendToUsersHook = ({
        required title,
        required body,
        required recipientUids,
        data,
      }) async {
        sentUids = recipientUids;
        sentData = data;
      };

      final notifier = await pumpSeatedLobby();
      await notifier.toggleSeatedReady(
        userId: 'user-1',
        gameName: 'Warzone',
        spotIndex: 0,
      );
      reset(mockRepository);
      when(mockRepository.updateMemberStatus(any, any, any))
          .thenAnswer((_) async {});

      final result = await notifier.timeoutReadyCheck(
        now: DateTime.now().add(kReadyCheckTimeout),
      );

      expect(result!.timedOut, isTrue);
      expect(result.snapshot.readyUids, isEmpty);
      expect(result.snackbarMessage, 'Ready check timed out');
      verify(mockRepository.updateMemberStatus('lobby-9', 'user-1', 'Occupied'))
          .called(1);
      expect(sentData!['type'], kLobbyReadyTimeoutType);
      expect(sentUids, isNotEmpty);
    });

    test('late join seated Occupied unlocks a locked lobby', () async {
      List<String>? sentUids;
      Map<String, dynamic>? sentData;
      LobbyLockNotify.sendToUsersHook = ({
        required title,
        required body,
        required recipientUids,
        data,
      }) async {
        sentUids = recipientUids;
        sentData = data;
      };

      final locked = _lobby(
        id: 'lobby-9',
        memberUids: const ['user-1', 'user-2'],
        spots: ['user-1', 'user-2', null],
        statuses: const {'user-1': 'Ready', 'user-2': 'Ready'},
      );
      final withJoin = locked.copyWith(
        memberUids: const ['user-1', 'user-2', 'user-3'],
        spots: ['user-1', 'user-2', 'user-3'],
      );
      final controller = StreamController<Lobby?>.broadcast();
      addTearDown(controller.close);
      when(mockRepository.getLobbyStream('lobby-9')).thenAnswer(
        (_) => controller.stream,
      );

      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);
      notifier.setSelectedLobbyId('lobby-9');
      controller.add(locked);
      await Future<void>.delayed(Duration.zero);

      expect(
        resolveLobbyReadyLockFromState(
          container.read(lobbyNotifierProvider).value!,
          gameName: 'Warzone',
        ).isLocked,
        isTrue,
      );

      when(mockRepository.loadLobbyState()).thenAnswer((_) async {
        final current = container.read(lobbyNotifierProvider).value!;
        return current.copyWith(
          currentLobby: withJoin,
          gameLobbySpots: {'Warzone': withJoin.spots},
          gameStatuses: {'Warzone': withJoin.statuses},
        );
      });

      await notifier.assignSpot('lobby-9', 2, 'user-3');

      final snap = resolveLobbyReadyLockFromState(
        container.read(lobbyNotifierProvider).value!,
        gameName: 'Warzone',
      );
      expect(snap.isLocked, isFalse);
      expect(snap.seatedUids, ['user-1', 'user-2', 'user-3']);
      expect(sentUids, ['user-1', 'user-2']);
      expect(sentData!['type'], kLobbyUnlockedType);
    });

    test('empty lobby lock is denied and does not write Ready', () async {
      final lobby = _lobby(
        id: 'lobby-9',
        memberUids: const ['user-1'],
        spots: [null, null, null],
      );
      when(mockRepository.getLobbyStream('lobby-9')).thenAnswer(
        (_) => Stream<Lobby?>.value(lobby),
      );
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);
      notifier.setSelectedLobbyId('lobby-9');
      await Future<void>.delayed(Duration.zero);

      final result = await notifier.applySeatedReady(
        userId: 'user-1',
        ready: true,
        gameName: 'Warzone',
      );

      expect(result, isNotNull);
      expect(result!.isDenied, isTrue);
      expect(result.denied, LobbyReadyLockDeniedReason.emptyLobby);
      expect(result.justLocked, isFalse);
      expect(result.snapshot.isLocked, isFalse);
      expect(result.snackbarMessage, kLobbyLockDeniedEmptyCopy);
      verifyNever(mockRepository.updateMemberStatus(any, any, any));
    });

    test('not seated Ready is denied with clear copy', () async {
      final notifier = await pumpSeatedLobby();

      final result = await notifier.toggleSeatedReady(
        userId: 'user-9',
        gameName: 'Warzone',
        spotIndex: 0,
      );

      expect(result!.denied, LobbyReadyLockDeniedReason.notSeated);
      expect(result.snackbarMessage, kLobbyLockDeniedNotSeatedCopy);
      expect(result.justLocked, isFalse);
      verifyNever(mockRepository.updateMemberStatus(any, any, any));
    });

    test('Ready persist fail is error and does not lock', () async {
      when(mockRepository.updateMemberStatus(any, any, any))
          .thenThrow(Exception('denied'));
      final notifier = await pumpSeatedLobby(
        statuses: const {'user-1': 'Ready'},
      );

      await expectLater(
        notifier.toggleSeatedReady(
          userId: 'user-2',
          gameName: 'Warzone',
          spotIndex: 1,
        ),
        throwsA(isA<Exception>()),
      );

      final snap = resolveLobbyReadyLockFromState(
        container.read(lobbyNotifierProvider).value!,
        gameName: 'Warzone',
      );
      expect(snap.isLocked, isFalse);
      expect(snap.isReady('user-2'), isFalse);
    });

    test('lock notify fire fail still locks and is error not success', () async {
      LobbyLockNotify.sendToUsersHook = ({
        required title,
        required body,
        required recipientUids,
        data,
      }) async {
        throw Exception('offline');
      };

      final notifier = await pumpSeatedLobby(
        statuses: const {'user-1': 'Ready'},
      );

      final result = await notifier.toggleSeatedReady(
        userId: 'user-2',
        gameName: 'Warzone',
        spotIndex: 1,
      );

      expect(result!.justLocked, isTrue);
      expect(result.snapshot.isLocked, isTrue);
      expect(result.notifyFailed, isTrue);
      expect(lobbyLockNotifyErrorDetail(result.notifyError), 'offline');
      expect(LobbyLockNotify.lastResult?.isFailed, isTrue);
      expect(LobbyLockNotify.lastResult?.sent, isFalse);
      verify(mockRepository.updateMemberStatus('lobby-9', 'user-2', 'Ready'))
          .called(1);
    });

    test('elapsed timeout then last Ready does not keep prior Ready', () async {
      final notifier = await pumpSeatedLobby();
      await notifier.toggleSeatedReady(
        userId: 'user-1',
        gameName: 'Warzone',
        spotIndex: 0,
      );
      reset(mockRepository);
      when(mockRepository.updateMemberStatus(any, any, any))
          .thenAnswer((_) async {});

      final timed = await notifier.timeoutReadyCheck(
        now: DateTime.now().add(kReadyCheckTimeout),
      );
      expect(timed!.timedOut, isTrue);
      expect(timed.snapshot.readyUids, isEmpty);

      final last = await notifier.toggleSeatedReady(
        userId: 'user-2',
        gameName: 'Warzone',
        spotIndex: 1,
      );
      expect(last!.justLocked, isFalse);
      expect(last.snapshot.isLocked, isFalse);
      expect(last.snapshot.isReady('user-2'), isTrue);
      expect(last.snapshot.isReady('user-1'), isFalse);
    });

    test('timeout after lock is a no-op (lock wins the race)', () async {
      final notifier = await pumpSeatedLobby(
        statuses: const {'user-1': 'Ready'},
      );
      final locked = await notifier.toggleSeatedReady(
        userId: 'user-2',
        gameName: 'Warzone',
        spotIndex: 1,
      );
      expect(locked!.justLocked, isTrue);
      reset(mockRepository);
      when(mockRepository.updateMemberStatus(any, any, any))
          .thenAnswer((_) async {});

      final timed = await notifier.timeoutReadyCheck(
        now: DateTime.now().add(kReadyCheckTimeout),
      );
      expect(timed!.timedOut, isFalse);
      expect(timed.changed, isFalse);
      expect(timed.snapshot.isLocked, isTrue);
      verifyNever(mockRepository.updateMemberStatus(any, any, any));
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

  group('LobbyNotifier - Session ratings', () {
    test('recordWin encodes rating into match_history notes', () async {
      final lobby = _lobby(id: 'lobby-1', memberUids: const ['user-1', 'u2']);
      when(mockRepository.recordMatchResult(
        lobbyId: anyNamed('lobbyId'),
        gameName: anyNamed('gameName'),
        result: anyNamed('result'),
        playerUids: anyNamed('playerUids'),
        notes: anyNamed('notes'),
      )).thenAnswer((_) async {});

      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);
      notifier.state = AsyncData(
        (notifier.state.value ?? LobbyState.initial()).copyWith(
          userLobbies: {'lobby-1': lobby},
        ),
      );
      final rated = reduceSessionRating(
        current: SessionRatingState.unrated,
        event: SessionRatingEvent.rate,
        stars: 4,
        raterUid: 'user-1',
        ratedAt: DateTime.utc(2026, 9, 3, 18),
      );

      await notifier.recordWin('lobby-1', sessionRating: rated);

      final captured = verify(mockRepository.recordMatchResult(
        lobbyId: 'lobby-1',
        gameName: 'Warzone',
        result: 'win',
        playerUids: ['user-1', 'u2'],
        notes: captureAnyNamed('notes'),
      )).captured;
      expect(captured, isNotEmpty);
      final notes = captured.single as String?;
      expect(notes, isNotNull);
      final decoded = decodeSessionRatingFromNotes(notes);
      expect(decoded?.stars, 4);
      expect(decoded?.raterUid, 'user-1');
      expect(decoded?.result, 'win');

      final history = container.read(lobbyNotifierProvider).valueOrNull;
      expect(history?.gameHistory, isNotEmpty);
      expect(
        sessionRatingFromMatchRow(history!.gameHistory.first)?.stars,
        4,
      );
    });

    test('recordWin encodes attached clip alongside session_rating notes',
        () async {
      final lobby = _lobby(id: 'lobby-1', memberUids: const ['user-1', 'u2']);
      when(mockRepository.recordMatchResult(
        lobbyId: anyNamed('lobbyId'),
        gameName: anyNamed('gameName'),
        result: anyNamed('result'),
        playerUids: anyNamed('playerUids'),
        notes: anyNamed('notes'),
      )).thenAnswer((_) async {});

      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);
      notifier.state = AsyncData(
        (notifier.state.value ?? LobbyState.initial()).copyWith(
          userLobbies: {'lobby-1': lobby},
        ),
      );
      final rated = attachClipToRatedSession(
        reduceSessionRating(
          current: SessionRatingState.unrated,
          event: SessionRatingEvent.rate,
          stars: 5,
          raterUid: 'user-1',
          ratedAt: DateTime.utc(2026, 9, 5, 18),
        ),
        reduceSessionClip(
          current: SessionClip.empty,
          event: SessionClipEvent.attach,
          clipId: 'clip-1',
          fileName: 'clutch.mp4',
          attachedAt: DateTime.utc(2026, 9, 5, 18, 1),
        ),
      );

      await notifier.recordWin('lobby-1', sessionRating: rated);

      final captured = verify(mockRepository.recordMatchResult(
        lobbyId: 'lobby-1',
        gameName: 'Warzone',
        result: 'win',
        playerUids: ['user-1', 'u2'],
        notes: captureAnyNamed('notes'),
      )).captured;
      final notes = captured.single as String?;
      expect(notes, isNotNull);
      expect(decodeSessionRatingFromNotes(notes)?.stars, 5);
      expect(decodeSessionClipFromNotes(notes)?.clipId, 'clip-1');
      expect(decodeSessionClipFromNotes(notes)?.fileName, 'clutch.mp4');

      final history = container.read(lobbyNotifierProvider).valueOrNull;
      expect(
        sessionRatingFromMatchRow(history!.gameHistory.first)?.hasClip,
        isTrue,
      );
    });

    test('recordWin encodes Vibes/Comms/Gunny/Wingman + notes', () async {
      final lobby = _lobby(id: 'lobby-1', memberUids: const ['user-1', 'u2']);
      when(mockRepository.recordMatchResult(
        lobbyId: anyNamed('lobbyId'),
        gameName: anyNamed('gameName'),
        result: anyNamed('result'),
        playerUids: anyNamed('playerUids'),
        notes: anyNamed('notes'),
      )).thenAnswer((_) async {});

      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);
      notifier.state = AsyncData(
        (notifier.state.value ?? LobbyState.initial()).copyWith(
          userLobbies: {'lobby-1': lobby},
        ),
      );
      final rated = reduceSessionRating(
        current: SessionRatingState.unrated,
        event: SessionRatingEvent.rate,
        vibes: 5,
        comms: 4,
        gunny: 3,
        wingman: 5,
        comment: 'locked in',
        raterUid: 'user-1',
        ratedAt: DateTime.utc(2026, 9, 5, 18),
      );

      await notifier.recordWin('lobby-1', sessionRating: rated);

      final captured = verify(mockRepository.recordMatchResult(
        lobbyId: 'lobby-1',
        gameName: 'Warzone',
        result: 'win',
        playerUids: ['user-1', 'u2'],
        notes: captureAnyNamed('notes'),
      )).captured;
      final decoded = decodeSessionRatingFromNotes(captured.single as String?);
      expect(decoded?.vibes, 5);
      expect(decoded?.comms, 4);
      expect(decoded?.gunny, 3);
      expect(decoded?.wingman, 5);
      expect(decoded?.comment, 'locked in');
      expect(decoded?.stars, 4);

      final history = container.read(lobbyNotifierProvider).valueOrNull;
      expect(history?.gameHistory, hasLength(1));
      expect(
        sessionRatingFromMatchRow(history!.gameHistory.first)?.vibes,
        5,
      );
    });

    test('second recordWin updates in-memory history instead of duplicating',
        () async {
      final lobby = _lobby(id: 'lobby-1', memberUids: const ['user-1']);
      when(mockRepository.recordMatchResult(
        lobbyId: anyNamed('lobbyId'),
        gameName: anyNamed('gameName'),
        result: anyNamed('result'),
        playerUids: anyNamed('playerUids'),
        notes: anyNamed('notes'),
      )).thenAnswer((_) async {});

      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);
      notifier.state = AsyncData(
        (notifier.state.value ?? LobbyState.initial()).copyWith(
          userLobbies: {'lobby-1': lobby},
        ),
      );

      await notifier.recordWin(
        'lobby-1',
        sessionRating: reduceSessionRating(
          current: SessionRatingState.unrated,
          event: SessionRatingEvent.rate,
          vibes: 2,
          raterUid: 'user-1',
          ratedAt: DateTime.utc(2026, 9, 5, 18),
        ),
      );
      await notifier.recordLoss(
        'lobby-1',
        sessionRating: reduceSessionRating(
          current: SessionRatingState.unrated,
          event: SessionRatingEvent.rate,
          vibes: 5,
          comms: 5,
          comment: 'comeback',
          raterUid: 'user-1',
          ratedAt: DateTime.utc(2026, 9, 5, 18, 1),
        ),
      );

      verify(mockRepository.recordMatchResult(
        lobbyId: anyNamed('lobbyId'),
        gameName: anyNamed('gameName'),
        result: anyNamed('result'),
        playerUids: anyNamed('playerUids'),
        notes: anyNamed('notes'),
      )).called(2);

      final history = container.read(lobbyNotifierProvider).valueOrNull;
      expect(history?.gameHistory, hasLength(1));
      expect(history?.gameHistory.first['result'], 'loss');
      final decoded = sessionRatingFromMatchRow(history!.gameHistory.first);
      expect(decoded?.vibes, 5);
      expect(decoded?.comms, 5);
      expect(decoded?.comment, 'comeback');
    });

    test('recordLoss skip leaves notes null', () async {
      final lobby = _lobby(id: 'lobby-1');
      when(mockRepository.recordMatchResult(
        lobbyId: anyNamed('lobbyId'),
        gameName: anyNamed('gameName'),
        result: anyNamed('result'),
        playerUids: anyNamed('playerUids'),
        notes: anyNamed('notes'),
      )).thenAnswer((_) async {});

      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);
      notifier.state = AsyncData(
        (notifier.state.value ?? LobbyState.initial()).copyWith(
          userLobbies: {'lobby-1': lobby},
        ),
      );
      final skipped = reduceSessionRating(
        current: SessionRatingState.unrated,
        event: SessionRatingEvent.skip,
      );

      await notifier.recordLoss('lobby-1', sessionRating: skipped);

      verify(mockRepository.recordMatchResult(
        lobbyId: 'lobby-1',
        gameName: 'Warzone',
        result: 'loss',
        playerUids: ['user-1'],
        notes: null,
      )).called(1);
    });
  });

  group('core-loop analytics (mocked)', () {
    late List<({String name, Map<String, Object> params})> logged;

    setUp(() {
      logged = SquadAnalytics.captureLogs();
    });

    Future<void> flushAnalytics() => Future<void>.delayed(Duration.zero);

    void expectNoPii() {
      for (final event in logged) {
        for (final key in event.params.keys) {
          expect(
            isAnalyticsPiiKey(key),
            isFalse,
            reason: '${event.name}.$key',
          );
        }
      }
    }

    Future<LobbyNotifier> pumpSeatedLobby({
      Map<String, String> statuses = const {},
    }) async {
      final lobby = _lobby(
        id: 'lobby-9',
        memberUids: const ['user-1', 'user-2'],
        spots: ['user-1', 'user-2', null],
        statuses: statuses,
      );
      when(mockRepository.getLobbyStream('lobby-9')).thenAnswer(
        (_) => Stream<Lobby?>.value(lobby),
      );
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);
      notifier.setSelectedLobbyId('lobby-9');
      await Future<void>.delayed(Duration.zero);
      return notifier;
    }

    test('joinLobby fires lobby_join with source and game only', () async {
      when(mockRepository.loadLobbyState()).thenAnswer(
        (_) async => LobbyState.initial().copyWith(
          currentGame: const {'name': 'Warzone'},
        ),
      );
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      await notifier.joinLobby('lobby-9', 'user-1');
      await flushAnalytics();

      expect(logged.map((e) => e.name), [kAnalyticsLobbyJoin]);
      expect(logged.single.params, {
        'source': 'code',
        'game_name': 'Warzone',
      });
      expectNoPii();
      verify(mockRepository.joinLobby('lobby-9', 'user-1')).called(1);
    });

    test('processPeacockQueue fires peacock_offer without ids', () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      await notifier.addToPeacockQueue('user-1', 'Warzone');
      await notifier.processPeacockQueue(
        assignedUserId: 'user-1',
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        notificationId: 'n1',
      );
      await flushAnalytics();

      final offers =
          logged.where((e) => e.name == kAnalyticsPeacockOffer).toList();
      expect(offers, hasLength(1));
      expect(offers.single.params['source'], 'peacock_queue');
      expect(offers.single.params['game_name'], 'Warzone');
      expect(offers.single.params.containsKey('lobby_id'), isFalse);
      expect(offers.single.params.containsKey('notification_id'), isFalse);
      expect(offers.single.params.containsKey('user_id'), isFalse);
      expectNoPii();
    });

    test('preferred-game skip does not fire peacock_offer', () async {
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);
      await notifier.togglePreferredPeacockGame('Warzone');

      await notifier.addToPeacockQueue('user-1', 'Fortnite');
      final assigned = await notifier.processPeacockQueue(
        assignedUserId: 'user-1',
        lobbyId: 'lobby-9',
        gameName: 'Fortnite',
        notificationId: 'n1',
      );
      await flushAnalytics();

      expect(assigned, isNull);
      expect(
        logged.where((e) => e.name == kAnalyticsPeacockOffer),
        isEmpty,
      );
    });

    test('assignPeacockSpot fires peacock_offer with seat_index', () async {
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

      await notifier.assignPeacockSpot(
        userId: 'user-1',
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        notificationId: 'n1',
      );
      await flushAnalytics();

      final offers =
          logged.where((e) => e.name == kAnalyticsPeacockOffer).toList();
      expect(offers, hasLength(1));
      expect(offers.single.params, {
        'source': 'peacock_queue',
        'game_name': 'Warzone',
        'seat_index': 1,
      });
      expectNoPii();
    });

    test('toggleSeatedReady fires ready_check', () async {
      final notifier = await pumpSeatedLobby();

      await notifier.toggleSeatedReady(
        userId: 'user-1',
        gameName: 'Warzone',
        spotIndex: 0,
      );
      await flushAnalytics();

      expect(logged.map((e) => e.name), [kAnalyticsReadyCheck]);
      expect(logged.single.params['outcome'], 'ready');
      expect(logged.single.params['seated_count'], 2);
      expect(logged.single.params['ready_count'], 1);
      expectNoPii();
    });

    test('all seated Ready fires ready_check locked and peacock_lock',
        () async {
      final notifier = await pumpSeatedLobby(
        statuses: const {'user-1': 'Ready'},
      );

      await notifier.toggleSeatedReady(
        userId: 'user-2',
        gameName: 'Warzone',
        spotIndex: 1,
      );
      await flushAnalytics();

      expect(logged.map((e) => e.name), [
        kAnalyticsReadyCheck,
        kAnalyticsPeacockLock,
      ]);
      expect(logged[0].params['outcome'], 'locked');
      expect(logged[0].params['seated_count'], 2);
      expect(logged[0].params['ready_count'], 2);
      expect(logged[1].params, {
        'seated_count': 2,
        'ready_count': 2,
      });
      expectNoPii();
    });

    test('timeoutReadyCheck fires ready_check timeout', () async {
      final notifier = await pumpSeatedLobby();
      await notifier.toggleSeatedReady(
        userId: 'user-1',
        gameName: 'Warzone',
        spotIndex: 0,
      );
      await flushAnalytics();
      logged.clear();

      await notifier.timeoutReadyCheck(
        now: DateTime.now().add(kReadyCheckTimeout),
      );
      await flushAnalytics();

      expect(logged.map((e) => e.name), [kAnalyticsReadyCheck]);
      expect(logged.single.params['outcome'], 'timeout');
      expect(logged.single.params.containsKey('lobby_id'), isFalse);
      expectNoPii();
    });

    test('recordWin fires session_rate without rater or lobby id', () async {
      final lobby = _lobby(id: 'lobby-1', memberUids: const ['user-1', 'u2']);
      when(mockRepository.recordMatchResult(
        lobbyId: anyNamed('lobbyId'),
        gameName: anyNamed('gameName'),
        result: anyNamed('result'),
        playerUids: anyNamed('playerUids'),
        notes: anyNamed('notes'),
      )).thenAnswer((_) async {});
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);
      notifier.state = AsyncData(
        (notifier.state.value ?? LobbyState.initial()).copyWith(
          userLobbies: {'lobby-1': lobby},
        ),
      );
      final rated = reduceSessionRating(
        current: SessionRatingState.unrated,
        event: SessionRatingEvent.rate,
        stars: 4,
        raterUid: 'user-1',
        comment: 'locked in',
        ratedAt: DateTime.utc(2026, 9, 3, 18),
      );

      await notifier.recordWin('lobby-1', sessionRating: rated);
      await flushAnalytics();

      expect(logged.map((e) => e.name), [kAnalyticsSessionRate]);
      expect(logged.single.params, {
        'stars': 4,
        'result': 'win',
        'skipped': 0,
      });
      expect(logged.single.params.containsKey('rater_uid'), isFalse);
      expect(logged.single.params.containsKey('lobby_id'), isFalse);
      expect(logged.single.params.containsKey('comment'), isFalse);
      expectNoPii();
    });

    test('recordLoss skip fires session_rate skipped', () async {
      final lobby = _lobby(id: 'lobby-1');
      when(mockRepository.recordMatchResult(
        lobbyId: anyNamed('lobbyId'),
        gameName: anyNamed('gameName'),
        result: anyNamed('result'),
        playerUids: anyNamed('playerUids'),
        notes: anyNamed('notes'),
      )).thenAnswer((_) async {});
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);
      notifier.state = AsyncData(
        (notifier.state.value ?? LobbyState.initial()).copyWith(
          userLobbies: {'lobby-1': lobby},
        ),
      );

      await notifier.recordLoss(
        'lobby-1',
        sessionRating: reduceSessionRating(
          current: SessionRatingState.unrated,
          event: SessionRatingEvent.skip,
        ),
      );
      await flushAnalytics();

      expect(logged.map((e) => e.name), [kAnalyticsSessionRate]);
      expect(logged.single.params, {
        'result': 'loss',
        'skipped': 1,
      });
      expectNoPii();
    });

    test('lock-in fire fail still locks and is error not success', () async {
      SquadAnalytics.logHook = (_, __) async => throw Exception('offline');
      final notifier = await pumpSeatedLobby(
        statuses: const {'user-1': 'Ready'},
      );

      final result = await notifier.toggleSeatedReady(
        userId: 'user-2',
        gameName: 'Warzone',
        spotIndex: 1,
      );
      await flushAnalytics();

      expect(result?.justLocked, isTrue);
      expect(result?.snapshot.isLocked, isTrue);
      expect(SquadAnalytics.lastResult?.isFailed, isTrue);
      expect(SquadAnalytics.lastResult?.isSuccess, isFalse);
      expect(
        analyticsFireErrorDetail(SquadAnalytics.lastResult?.error),
        'offline',
      );
    });

    test('peacock join fire fail still assigns and is error not success',
        () async {
      SquadAnalytics.logHook = (_, __) async => throw Exception('denied');
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      await notifier.addToPeacockQueue('user-1', 'Warzone');
      final assigned = await notifier.processPeacockQueue(
        assignedUserId: 'user-1',
        lobbyId: 'lobby-9',
        gameName: 'Warzone',
        notificationId: 'n1',
      );
      await flushAnalytics();

      expect(assigned, isNotNull);
      expect(SquadAnalytics.lastResult?.isFailed, isTrue);
      expect(SquadAnalytics.lastResult?.name, kAnalyticsPeacockOffer);
      expect(
        analyticsFireErrorDetail(SquadAnalytics.lastResult?.error),
        'denied',
      );
    });

    test('rating submit fire fail still persists and is error not success',
        () async {
      SquadAnalytics.logHook = (_, __) async => throw Exception('offline');
      final lobby = _lobby(id: 'lobby-1', memberUids: const ['user-1', 'u2']);
      when(mockRepository.recordMatchResult(
        lobbyId: anyNamed('lobbyId'),
        gameName: anyNamed('gameName'),
        result: anyNamed('result'),
        playerUids: anyNamed('playerUids'),
        notes: anyNamed('notes'),
      )).thenAnswer((_) async {});
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);
      notifier.state = AsyncData(
        (notifier.state.value ?? LobbyState.initial()).copyWith(
          userLobbies: {'lobby-1': lobby},
        ),
      );
      final rated = reduceSessionRating(
        current: SessionRatingState.unrated,
        event: SessionRatingEvent.rate,
        stars: 4,
        raterUid: 'user-1',
        ratedAt: DateTime.utc(2026, 9, 3, 18),
      );

      await notifier.recordWin('lobby-1', sessionRating: rated);
      await flushAnalytics();

      verify(mockRepository.recordMatchResult(
        lobbyId: 'lobby-1',
        gameName: 'Warzone',
        result: 'win',
        playerUids: ['user-1', 'u2'],
        notes: anyNamed('notes'),
      )).called(1);
      expect(SquadAnalytics.lastResult?.isFailed, isTrue);
      expect(SquadAnalytics.lastResult?.name, kAnalyticsSessionRate);
      expect(
        analyticsFireErrorDetail(SquadAnalytics.lastResult?.error),
        'offline',
      );
    });
  });

  group('LobbyNotifier - createLobby from chat', () {
    const creatorUid = 'creator-1';
    const friendUid = 'friend-2';
    const otherFriendUid = 'friend-3';
    const chatGroupId = 'chat-friday';
    const createdLobbyId = 'lobby-from-chat';

    Lobby repoLobby({required String name, String boundChatGroupId = ''}) {
      return _lobby(
        id: createdLobbyId,
        name: name,
        gameName: 'Warzone',
        memberUids: const [creatorUid, friendUid, otherFriendUid],
        chatGroupId: boundChatGroupId,
      );
    }

    void stubCreateLobby() {
      when(mockRepository.createLobby(any, any, any)).thenAnswer((inv) async {
        return repoLobby(name: inv.positionalArguments[0] as String);
      });
    }

    test('createLobby with chatGroupId persists / binds and selects+subscribes',
        () async {
      stubCreateLobby();
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      final lobbyId = await notifier.createLobby(
        chatGroupId: chatGroupId,
        gameName: 'Warzone',
        maxSpots: 8,
      );

      expect(lobbyId, createdLobbyId);
      final state = container.read(lobbyNotifierProvider).valueOrNull;
      final bound = state?.currentLobby ?? state?.userLobbies[createdLobbyId];
      expect(
        bound?.chatGroupId,
        chatGroupId,
        reason: 'createLobby must persist/bind chat_group_id on the lobby',
      );
      expect(
        state?.selectedLobbyId,
        createdLobbyId,
        reason: 'creator must land on the new lobby (selects)',
      );
      verify(mockRepository.getLobbyStream(createdLobbyId))
          .called(greaterThanOrEqualTo(1));
    });

    test('createLobby with empty chatGroupId still creates', () async {
      stubCreateLobby();
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      final lobbyId = await notifier.createLobby(
        chatGroupId: '',
        gameName: 'Warzone',
        maxSpots: 8,
      );

      expect(lobbyId, isNotEmpty);
      expect(lobbyId, createdLobbyId);
      verify(mockRepository.createLobby(any, 'Warzone', 8)).called(1);
    });

    test('createLobby notify excludes the creator', () async {
      List<String>? sentUids;
      Map<String, dynamic>? sentData;
      LobbyLockNotify.sendToUsersHook = ({
        required title,
        required body,
        required recipientUids,
        data,
      }) async {
        sentUids = List<String>.from(recipientUids);
        sentData = data == null ? null : Map<String, dynamic>.from(data);
      };
      stubCreateLobby();
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      await notifier.createLobby(
        chatGroupId: chatGroupId,
        gameName: 'Warzone',
        maxSpots: 8,
      );

      expect(
        sentUids,
        isNotNull,
        reason: 'lobby-created notify must fire for chat members',
      );
      expect(
        sentUids,
        contains(friendUid),
        reason: 'friends in the chat group must be notified',
      );
      expect(
        sentUids,
        isNot(contains(creatorUid)),
        reason: 'creator must not receive lobby_created (no FCM-to-self)',
      );
      expect(sentData?['type'], 'lobby_created');
      expect(sentData?['chat_group_id'], chatGroupId);
      expect(sentData?['lobby_id'], createdLobbyId);
    });

    test('createLobby name is not literal Lobby when game+group provided',
        () async {
      stubCreateLobby();
      await container.read(lobbyNotifierProvider.future);
      final notifier = container.read(lobbyNotifierProvider.notifier);

      await notifier.createLobby(
        chatGroupId: chatGroupId,
        gameName: 'Warzone',
        maxSpots: 8,
      );

      final captured = verify(
        mockRepository.createLobby(captureAny, 'Warzone', 8),
      ).captured;
      expect(captured, isNotEmpty);
      final name = captured.single as String;
      expect(
        name,
        isNot(equals('Lobby')),
        reason: 'hardcoded Lobby is not a friend-visible name',
      );
      expect(name.toLowerCase(), isNot(equals('lobby')));
      expect(
        name,
        contains('Warzone'),
        reason: 'name must include the game (game+group, truncated)',
      );
    });
  });

  group('LobbyNotifier - display names id/uid', () {
    const selfKey = 'self-auth-uuid';
    const memberKey = 'member-auth-uuid';

    Future<LobbyNotifier> readyNotifier() async {
      await container.read(lobbyNotifierProvider.future);
      return container.read(lobbyNotifierProvider.notifier);
    }

    void clearDisplayNameCache(LobbyNotifier notifier) {
      final current = notifier.state.valueOrNull ?? LobbyState.initial();
      notifier.state = AsyncData(
        current.copyWith(memberDisplayNames: <String, String>{}),
      );
    }

    /// Loop seam on [LobbyNotifier] (instance):
    /// `Future<Map<String, dynamic>?> Function(String column, String value)?
    ///     debugUsersLookup`
    /// `String? debugCurrentUserId`
    ///
    /// `_fetchDisplayNamesForMembers` / `updateLobbyMembers` must try
    /// `users.id` first, then `users.uid`. Never persist the literal
    /// `Unknown User` for the current user when either column returns a row.
    bool bindUsersLookup(
      LobbyNotifier notifier,
      _UsersTable table, {
      String? currentUserId,
    }) {
      var bound = false;
      try {
        (notifier as dynamic).debugUsersLookup = table.lookup;
        bound = true;
      } catch (_) {}
      if (currentUserId != null) {
        try {
          (notifier as dynamic).debugCurrentUserId = currentUserId;
        } catch (_) {}
      }
      return bound;
    }

    Future<String> nameAfterLookup(
      LobbyNotifier notifier,
      String key, {
      required Future<void> Function(List<String> keys) run,
    }) async {
      clearDisplayNameCache(notifier);
      await run([key]);
      return notifier.getDisplayNameForUid(key);
    }

    test('lookup prefers users.id when that column path works', () async {
      final notifier = await readyNotifier();
      final table = _UsersTable([
        {
          'id': memberKey,
          'uid': 'legacy-other',
          'display_name': 'FromId',
        },
        {
          'id': 'legacy-other-id',
          'uid': memberKey,
          'display_name': 'FromUid',
        },
      ]);
      bindUsersLookup(notifier, table);

      Future<void> expectIdWins(
        Future<void> Function(List<String> keys) run,
      ) async {
        table.columnsTried.clear();
        final name = await nameAfterLookup(notifier, memberKey, run: run);
        expect(
          name,
          'FromId',
          reason: 'users.id must win when that column path returns a row',
        );
        expect(
          name,
          isNot(equals('FromUid')),
          reason: 'uid leftover must not win over a working id row',
        );
        expect(
          table.columnsTried.isEmpty ? null : table.columnsTried.first,
          'id',
          reason: 'first users eq column must be id',
        );
      }

      await expectIdWins(notifier.fetchDisplayNamesForUids);
      await expectIdWins(notifier.updateLobbyMembers);
    });

    test('falls back to uid if id miss', () async {
      final notifier = await readyNotifier();
      final table = _UsersTable([
        {
          'id': 'not-the-member',
          'uid': memberKey,
          'display_name': 'FromUid',
        },
      ]);
      bindUsersLookup(notifier, table);

      Future<void> expectUidFallback(
        Future<void> Function(List<String> keys) run,
      ) async {
        table.columnsTried.clear();
        final name = await nameAfterLookup(notifier, memberKey, run: run);
        expect(
          name,
          'FromUid',
          reason: 'id miss must fall back to users.uid',
        );
        expect(
          table.columnsTried,
          containsAllInOrder(['id', 'uid']),
          reason: 'lookup must try id first, then uid',
        );
      }

      await expectUidFallback(notifier.fetchDisplayNamesForUids);
      await expectUidFallback(notifier.updateLobbyMembers);
    });

    test(
      'current user never resolves to literal Unknown User when a row exists under id or uid',
      () async {
        final notifier = await readyNotifier();

        Future<void> expectSelfNamed({
          required List<Map<String, dynamic>> rows,
          required String expected,
        }) async {
          final table = _UsersTable(rows);
          bindUsersLookup(notifier, table, currentUserId: selfKey);
          for (final run in [
            notifier.fetchDisplayNamesForUids,
            notifier.updateLobbyMembers,
          ]) {
            table.columnsTried.clear();
            final name = await nameAfterLookup(notifier, selfKey, run: run);
            expect(
              name,
              isNot(equals('Unknown User')),
              reason:
                  'self must not stay Unknown User when users.id or users.uid has a row',
            );
            expect(name, expected);
          }
        }

        await expectSelfNamed(
          rows: [
            {'id': selfKey, 'display_name': 'Alex'},
          ],
          expected: 'Alex',
        );
        await expectSelfNamed(
          rows: [
            {'uid': selfKey, 'display_name': 'AlexUid'},
          ],
          expected: 'AlexUid',
        );
      },
    );
  });
}

/// In-memory users rows for Slice B id-then-uid lookup. No live SQL.
class _UsersTable {
  _UsersTable(this.rows);

  final List<Map<String, dynamic>> rows;
  final List<String> columnsTried = [];

  Future<Map<String, dynamic>?> lookup(String column, String value) async {
    columnsTried.add(column);
    for (final row in rows) {
      if (row[column]?.toString() == value) {
        return Map<String, dynamic>.from(row);
      }
    }
    return null;
  }
}
