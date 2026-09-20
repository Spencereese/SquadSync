import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_sync/core/app_env.dart';
import 'package:squad_sync/core/injection.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';
import 'package:squad_sync/services/constitution_manager.dart';
import 'package:squad_sync/services/error_handling_service.dart';
import 'package:squad_sync/services/lobby_ready_lock.dart';
import 'package:squad_sync/services/matchmaking_queue_machine.dart';
import 'package:squad_sync/services/peacock_assignment_machine.dart';
import 'package:squad_sync/services/peacock_lock_live_activity.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';
import 'package:squad_sync/services/preferred_peacock_games.dart';
import 'package:squad_sync/services/squad_analytics.dart';

import 'lobby_notifier_test.mocks.dart';

/// Slice D reds: friend-visible add/remove peacock + Claim / Accept / Decline
/// must use [PeacockAssignmentTracker] / [reducePeacockAssignment] with a real
/// [PeacockAssignmentState.gameName]. Not the empty-name stub. Not
/// [MatchmakingQueueMachine] as a second peacock queue. XOR stays
/// [planPeacockSelfNotify] (one notify path).
///
/// Friend taps (lobbies tab / peacock card / offer banner):
/// - addToPeacock(member) / removeFromPeacock(member)
/// - Claim seat / Accept / Decline
///
/// Loop seams on [LobbyNotifier] (≤3 lib files): wire those aliases through
/// the existing peacock assignment machine. Optional thin
/// acceptPeacock / declinePeacock aliases may call assign / expire.
Lobby _lobby({
  String id = 'lobby-9',
  String name = 'Tonight',
  String gameName = 'Warzone',
  List<String> memberUids = const ['user-1', 'user-2'],
  List<String?>? spots,
}) {
  final maxSpots = spots?.length ?? 3;
  return Lobby.create(
    name: name,
    gameName: gameName,
    maxSpots: maxSpots,
    createdBy: memberUids.first,
  ).copyWith(
    id: id,
    memberUids: memberUids,
    spots: spots ?? ['user-1', 'user-2', null],
    spotTimers: List<Map<String, dynamic>?>.filled(maxSpots, null),
    chatGroupId: 'chat-9',
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

PeacockAssignmentState _peacock(String userId) =>
    PeacockAssignmentTracker.instance.stateFor(userId);

MatchmakingQueueEntry _lfg(String userId) =>
    MatchmakingQueueTracker.instance.stateFor(userId);

void _expectNoSecondQueue(String userId) {
  expect(
    _lfg(userId).phase,
    MatchmakingQueuePhase.idle,
    reason: 'peacock aliases must not create a MatchmakingQueueMachine '
        'second queue',
  );
  expect(
    MatchmakingQueueTracker.instance.snapshot.containsKey(userId),
    isFalse,
    reason: 'no LFG row for a peacock add/remove/claim',
  );
}

/// Friend-visible Accept. Loop may add acceptPeacock / acceptPeacockSpot
/// as a thin alias over assignPeacockSpot (single reducePeacockAssignment).
Future<void> _friendAccept(
  LobbyNotifier notifier, {
  required String userId,
  required String lobbyId,
  required String gameName,
  String? notificationId,
}) async {
  final dynamic n = notifier;
  final attempts = <Future<void> Function()>[
    () => n.acceptPeacock(
          userId: userId,
          lobbyId: lobbyId,
          gameName: gameName,
          notificationId: notificationId,
        ),
    () => n.acceptPeacockSpot(
          userId: userId,
          lobbyId: lobbyId,
          gameName: gameName,
          notificationId: notificationId,
        ),
    () => n.acceptPeacock(lobbyId, userId, gameName),
  ];
  Object? last;
  for (final attempt in attempts) {
    try {
      await attempt();
      return;
    } catch (e) {
      last = e;
    }
  }
  fail(
    'Loop seam: LobbyNotifier.acceptPeacock / acceptPeacockSpot must call '
    'reducePeacockAssignment (assignSpot) with gameName. Last: $last',
  );
}

/// Friend-visible Decline. Loop may add declinePeacock / declinePeacockSpot
/// as a thin alias over expirePeacockAssignment (single reduce).
void _friendDecline(LobbyNotifier notifier, String userId) {
  final dynamic n = notifier;
  final attempts = <void Function()>[
    () => n.declinePeacock(userId),
    () => n.declinePeacockSpot(userId),
    () => n.declinePeacock(userId: userId),
  ];
  Object? last;
  for (final attempt in attempts) {
    try {
      attempt();
      return;
    } catch (e) {
      last = e;
    }
  }
  fail(
    'Loop seam: LobbyNotifier.declinePeacock / declinePeacockSpot must call '
    'reducePeacockAssignment (expire). Last: $last',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLobbyRepository mockRepository;
  late ProviderContainer container;

  setUp(() {
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

  Future<LobbyNotifier> pumpOpenLobby({Lobby? lobby}) async {
    final seated = lobby ?? _lobby();
    when(mockRepository.getLobbyStream(seated.id)).thenAnswer(
      (_) => Stream<Lobby?>.value(seated),
    );
    await container.read(lobbyNotifierProvider.future);
    final notifier = container.read(lobbyNotifierProvider.notifier);
    notifier.setSelectedLobbyId(seated.id);
    await Future<void>.delayed(Duration.zero);
    final current = notifier.state.valueOrNull ?? LobbyState.initial();
    notifier.state = AsyncData(
      current.copyWith(
        currentLobby: seated,
        selectedLobbyId: seated.id,
        currentGame: {'name': seated.gameName},
      ),
    );
    return notifier;
  }

  group('LobbyNotifier - friend-visible peacock aliases (Slice D)', () {
    test(
      'addToPeacock goes through PeacockAssignmentTracker with lobby gameName',
      () async {
        final notifier = await pumpOpenLobby();

        await notifier.addToPeacock('user-1');

        final peacock = _peacock('user-1');
        expect(
          peacock.phase,
          PeacockAssignmentPhase.queued,
          reason: 'addToPeacock must join via PeacockAssignmentMachine '
              '(joinQueue), not a stub no-op',
        );
        expect(
          peacock.gameName,
          'Warzone',
          reason: 'friend tap addToPeacock(member) must carry the lobby '
              'gameName — empty-string stub is not an alias',
        );
        verify(mockRepository.addToPeacockQueue('user-1', 'Warzone')).called(1);
        _expectNoSecondQueue('user-1');
      },
    );

    test(
      'removeFromPeacock leaves via PeacockAssignmentTracker not MatchmakingQueue',
      () async {
        final notifier = await pumpOpenLobby();
        await notifier.addToPeacockQueue('user-1', 'Warzone');
        expect(_peacock('user-1').phase, PeacockAssignmentPhase.queued);

        // Friend tap: removeFromPeacock(member) — first arg is the uid.
        await notifier.removeFromPeacock('user-1');

        expect(
          _peacock('user-1').phase,
          PeacockAssignmentPhase.idle,
          reason: 'removeFromPeacock(member) must leaveQueue / expire on '
              'PeacockAssignmentMachine; a gameName-first no-op is not '
              'the friend-visible alias',
        );
        verify(mockRepository.removeFromPeacockQueue('user-1')).called(1);
        _expectNoSecondQueue('user-1');
      },
    );

    test(
      'Claim / Accept / Decline call reducePeacockAssignment (sole reducer)',
      () async {
        final notifier = await pumpOpenLobby();

        await notifier.claimPeacockSpot('lobby-9', 'user-1', 'Warzone');

        var peacock = _peacock('user-1');
        expect(
          peacock.phase,
          PeacockAssignmentPhase.assigned,
          reason: 'Claim (claimPeacockSpot) must reduce assignSpot — not '
              'a joinQueue stub',
        );
        expect(peacock.gameName, 'Warzone');
        expect(peacock.lobbyId, 'lobby-9');
        expect(peacock.wouldDoubleNotifySelf, isFalse);
        _expectNoSecondQueue('user-1');

        _friendDecline(notifier, 'user-1');
        expect(
          _peacock('user-1').phase,
          PeacockAssignmentPhase.idle,
          reason: 'Decline must reduce expire via reducePeacockAssignment',
        );
        expect(_peacock('user-1').wouldDoubleNotifySelf, isFalse);
        _expectNoSecondQueue('user-1');

        await _friendAccept(
          notifier,
          userId: 'user-1',
          lobbyId: 'lobby-9',
          gameName: 'Warzone',
          notificationId: 'n1',
        );
        peacock = _peacock('user-1');
        expect(
          peacock.phase,
          PeacockAssignmentPhase.assigned,
          reason: 'Accept must reduce assignSpot (sole reducer)',
        );
        expect(peacock.gameName, 'Warzone');
        expect(peacock.lobbyId, 'lobby-9');
        expect(peacock.wouldDoubleNotifySelf, isFalse);
        _expectNoSecondQueue('user-1');
      },
    );

    test(
      'planPeacockSelfNotify XOR preserved — no dual self-notify path',
      () async {
        final notifier = await pumpOpenLobby();

        await notifier.claimPeacockSpot('lobby-9', 'user-1', 'Warzone');
        expect(
          _peacock('user-1').phase,
          PeacockAssignmentPhase.assigned,
          reason: 'Claim must assign before notify so XOR can run on the '
              'peacock machine, not a second presenter',
        );

        final foreground = PeacockAssignmentTracker.instance.notifySelf(
          'user-1',
          isForeground: true,
          currentUid: 'user-1',
          notificationId: 'n1',
        );
        expect(foreground.state.phase, PeacockAssignmentPhase.notified);
        expect(foreground.plan.showLocal, isTrue);
        expect(foreground.plan.sendFcmToSelf, isFalse);
        expect(foreground.state.wouldDoubleNotifySelf, isFalse);
        expect(foreground.plan.wouldDoubleNotifySelf, isFalse);

        final again = planPeacockSelfNotify(
          notificationId: 'n1',
          currentUid: 'user-1',
          isForeground: false,
          locallyPresentedIds: {'n1'},
        );
        expect(again.showLocal, isFalse);
        expect(again.sendFcmToSelf, isFalse);
        expect(again.wouldDoubleNotifySelf, isFalse);

        final background = PeacockAssignmentTracker.instance.notifySelf(
          'user-1',
          isForeground: false,
          currentUid: 'user-1',
          notificationId: 'n1',
        );
        expect(background.plan.sendFcmToSelf, isFalse);
        expect(background.state.wouldDoubleNotifySelf, isFalse);
        _expectNoSecondQueue('user-1');
      },
    );

    test(
      'no second queue created for peacock aliases',
      () async {
        final notifier = await pumpOpenLobby();

        await notifier.addToPeacock('user-1');
        await notifier.removeFromPeacock('user-1');
        await notifier.addToPeacock('user-1');
        await notifier.claimPeacockSpot('lobby-9', 'user-1', 'Warzone');

        expect(
          MatchmakingQueueTracker.instance.snapshot,
          isEmpty,
          reason: 'peacock must not allocate a MatchmakingQueueMachine row',
        );
        expect(
          _lfg('user-1').phase,
          MatchmakingQueuePhase.idle,
        );
        expect(
          _peacock('user-1').phase,
          PeacockAssignmentPhase.assigned,
          reason: 'Claim still belongs on PeacockAssignmentTracker',
        );
        expect(_peacock('user-1').gameName, 'Warzone');
      },
    );
  });
}
