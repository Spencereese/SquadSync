import 'dart:async';
import 'dart:io';

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
import 'package:squad_sync/services/preferred_peacock_games.dart';
import 'package:squad_sync/services/squad_analytics.dart';

import 'lobby_notifier_test.mocks.dart';

/// Slice E reds: friend-visible seated Ready → all-seated Lock chip + one
/// notify; unlock / late-join unlock stay consistent. Mutations only via
/// [reduceLobbyReadyLock] / [lateJoinUnlocks] in lobby_ready_lock.dart.
/// One [_lastReadyLockSnapshot] drives Lock chip, [LobbyLockNotify], and
/// the peacock live-activity façade. Stream / realtime applies with
/// notify:false so the acting client is the sole sender.
///
/// Friend taps (Tonight map / seated spot):
/// - Ready on an Occupied seat
/// - Unlock on a Locked own seat
/// - Sit an empty spot (late join) while Locked
///
/// Loop seams on [LobbyNotifier] (≤3 lib files):
/// `LobbyReadyLockSnapshot? lastReadyLockSnapshot` (the private field
/// exposed), Ready/Lock writes through [reduceLobbyReadyLock], one
/// notify helper from that snapshot. No parallel Ready patch in
/// [LobbyNotifier.applySeatedReady]. No second lock bool on [LobbyState]
/// unless it derives from the snapshot.
Lobby _lobby({
  String id = 'lobby-9',
  String name = 'Tonight',
  String gameName = 'Warzone',
  List<String> memberUids = const ['user-1', 'user-2'],
  List<String?>? spots,
  Map<String, String> statuses = const {},
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
    statuses: statuses,
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

/// Loop seam: public [lastReadyLockSnapshot] (not a second Ready map).
LobbyReadyLockSnapshot? _lastReadyLockSnapshot(LobbyNotifier notifier) {
  final dynamic n = notifier;
  try {
    final value = n.lastReadyLockSnapshot;
    if (value is LobbyReadyLockSnapshot) return value;
    return null;
  } catch (_) {
    return null;
  }
}

String _notifierSource() =>
    File('lib/presentation/notifiers/lobby_notifier.dart').readAsStringSync();

String _readyLockSource() =>
    File('lib/services/lobby_ready_lock.dart').readAsStringSync();

String _lobbyStateSource() =>
    File('lib/domain/entities/lobby_state.dart').readAsStringSync();

/// Ready/Lock write methods. Parallel mutation lives in applySeatedReady
/// today (`patched[uid] = status` then resolve). Loop must reduce.
String _readyLockWriteSource() {
  final src = _notifierSource();
  final start = src.indexOf('Future<SeatedReadyResult?> applySeatedReady');
  final toggle = src.indexOf('Future<SeatedReadyResult?> toggleSeatedReady');
  final reconcile = src.indexOf('Future<SeatedReadyResult?> reconcileReadyLock');
  expect(start, greaterThanOrEqualTo(0), reason: 'applySeatedReady missing');
  expect(toggle, greaterThanOrEqualTo(0), reason: 'toggleSeatedReady missing');
  expect(reconcile, greaterThanOrEqualTo(0), reason: 'reconcileReadyLock missing');
  final from = toggle < start ? toggle : start;
  final timeout = src.indexOf('Future<SeatedReadyResult?> timeoutReadyCheck');
  final afterReconcile = src.indexOf('Duration? readyCheckRemaining');
  final end = afterReconcile > reconcile
      ? afterReconcile
      : (timeout > reconcile ? timeout : src.length);
  return src.substring(from, end);
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
    when(mockRepository.joinLobby(any, any)).thenAnswer((_) async {});
    when(mockRepository.leaveLobby(any, any)).thenAnswer((_) async {});
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

  Future<LobbyNotifier> pumpSeatedLobby({
    Map<String, String> statuses = const {},
    Stream<Lobby?>? stream,
  }) async {
    final seated = _lobby(statuses: statuses);
    when(mockRepository.getLobbyStream(seated.id)).thenAnswer(
      (_) => stream ?? Stream<Lobby?>.value(seated),
    );
    await container.read(lobbyNotifierProvider.future);
    final notifier = container.read(lobbyNotifierProvider.notifier);
    notifier.setSelectedLobbyId(seated.id);
    await Future<void>.delayed(Duration.zero);
    return notifier;
  }

  group('LobbyNotifier - Ready/Lock snapshot pipeline (Slice E)', () {
    test(
      'toggle Ready / lock / unlock / late-join only via reduceLobbyReadyLock',
      () {
        final writes = _readyLockWriteSource();
        expect(
          writes.contains('reduceLobbyReadyLock'),
          isTrue,
          reason: 'applySeatedReady / toggleSeatedReady must reduce through '
              'lobby_ready_lock.dart — no parallel Ready patch on notifier',
        );
        expect(
          writes.contains("patched = Map<String, String>.from(statuses)"),
          isFalse,
          reason: 'Map.from(statuses)..[uid] = Ready is a second mutator; '
              'Loop must call reduceLobbyReadyLock then persist Occupied/Ready',
        );
        expect(
          writes.contains('..[uid] = status'),
          isFalse,
          reason: 'in-place status patch is parallel Ready-state mutation',
        );
        expect(
          _readyLockSource().contains('LobbyReadyLockSnapshot reduceLobbyReadyLock'),
          isTrue,
          reason: 'sole reducer stays in lobby_ready_lock.dart',
        );
      },
    );

    test(
      'lastReadyLockSnapshot drives Lock chip + notify + live-activity',
      () async {
        final sent = <Map<String, dynamic>>[];
        LobbyLockNotify.sendToUsersHook = ({
          required title,
          required body,
          required recipientUids,
          data,
        }) async {
          sent.add({
            'title': title,
            'uids': List<String>.from(recipientUids),
            'type': data?['type'],
          });
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

        expect(result, isNotNull);
        expect(
          result!.justLocked,
          isTrue,
          reason: 'last seated Ready must lock — friends see Lock chip',
        );

        final snap = _lastReadyLockSnapshot(notifier);
        expect(
          snap,
          isNotNull,
          reason: 'Loop seam: LobbyNotifier.lastReadyLockSnapshot must expose '
              '_lastReadyLockSnapshot so chip / notify / live-activity share one '
              'object — not a second resolve on LobbyState',
        );
        expect(snap!.isLocked, isTrue);
        expect(snap.seatedUids, ['user-1', 'user-2']);
        expect(snap.readyUids, ['user-1', 'user-2']);
        expect(
          identical(snap, result.snapshot) ||
              (snap.isLocked == result.snapshot.isLocked &&
                  snap.seatedUids.toString() ==
                      result.snapshot.seatedUids.toString() &&
                  snap.readyUids.toString() ==
                      result.snapshot.readyUids.toString()),
          isTrue,
          reason: 'result.snapshot must be the same lastReadyLockSnapshot',
        );

        final chipLocked = snap.isLocked;
        expect(
          chipLocked,
          isTrue,
          reason: 'Lock chip is lastReadyLockSnapshot.isLocked — Tonight map '
              'must not re-resolve a second lock flag',
        );
        expect(sent, hasLength(1));
        expect(sent.single['type'], kLobbyLockedType);
        expect(
          sent.single['uids'],
          lobbyLockNotifyRecipients(
            seatedUids: snap.seatedUids,
            actorUid: 'user-2',
          ),
          reason: 'notify recipients must come from lastReadyLockSnapshot',
        );
        expect(livePlan, isNotNull);
        expect(livePlan!.payload.isLocked, snap.isLocked);
        expect(
          livePlan!.payload.phase,
          PeacockLockLiveActivityPhase.locked,
          reason: 'live-activity façade must sync from lastReadyLockSnapshot',
        );
        expect(livePlan!.payload.seatedCount, snap.seatedUids.length);
        expect(livePlan!.payload.readyCount, snap.readyUids.length);
      },
    );

    test(
      'notify once per Ready / Lock / unlock / late-join transition',
      () async {
        var sendCount = 0;
        final types = <String>[];
        LobbyLockNotify.sendToUsersHook = ({
          required title,
          required body,
          required recipientUids,
          data,
        }) async {
          sendCount += 1;
          types.add('${data?['type']}');
        };
        PeacockLockLiveActivity.invokeHook = (plan) async {
          if (plan.op == PeacockLockLiveActivityOp.start) return 'act-lock';
          return plan.payload.activityId;
        };

        final notifier = await pumpSeatedLobby();

        await notifier.toggleSeatedReady(
          userId: 'user-1',
          gameName: 'Warzone',
          spotIndex: 0,
        );
        expect(
          sendCount,
          0,
          reason: 'Ready-only (not all seated) is not a Lock transition — '
              'no notify until the Lock chip appears',
        );

        await notifier.toggleSeatedReady(
          userId: 'user-2',
          gameName: 'Warzone',
          spotIndex: 1,
        );
        expect(sendCount, 1, reason: 'all-seated Ready → one lock notify');
        expect(types, [kLobbyLockedType]);

        await notifier.toggleSeatedReady(
          userId: 'user-1',
          gameName: 'Warzone',
          spotIndex: 0,
        );
        expect(sendCount, 2, reason: 'Unlock is one more notify, not a burst');
        expect(types, [kLobbyLockedType, kLobbyUnlockedType]);

        // user-2 is still Ready; last seated Ready re-locks.
        await notifier.toggleSeatedReady(
          userId: 'user-1',
          gameName: 'Warzone',
          spotIndex: 0,
        );
        expect(sendCount, 3, reason: 're-lock is one notify');

        await notifier.assignSpot('lobby-9', 2, 'user-3');
        expect(
          sendCount,
          4,
          reason: 'late-join Occupied unlock is one notify on the acting client',
        );
        expect(types.last, kLobbyUnlockedType);
        expect(
          types.where((t) => t == kLobbyLockedType),
          hasLength(2),
          reason: 'two lock transitions → two lock notifies, not a second pipeline',
        );
      },
    );

    test(
      'stream / realtime applies Ready/Lock with notify:false',
      () async {
        var sendCount = 0;
        LobbyLockNotify.sendToUsersHook = ({
          required title,
          required body,
          required recipientUids,
          data,
        }) async {
          sendCount += 1;
        };
        PeacockLockLiveActivityPlan? livePlan;
        PeacockLockLiveActivity.invokeHook = (plan) async {
          livePlan = plan;
          if (plan.op == PeacockLockLiveActivityOp.start) return 'act-lock';
          return plan.payload.activityId;
        };

        final locked = _lobby(
          statuses: const {'user-1': 'Ready', 'user-2': 'Ready'},
        );
        final lateJoin = locked.copyWith(
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
          _notifierSource().contains(
            'reconcileReadyLock(notify: false, gameName: lobby.gameName)',
          ),
          isTrue,
          reason: 'getLobbyStream listener must apply Ready/Lock with '
              'notify:false — the Ready/unlock writer already sent',
        );

        final afterLock = _lastReadyLockSnapshot(notifier);
        expect(
          afterLock,
          isNotNull,
          reason: 'stream must write lastReadyLockSnapshot (notify:false)',
        );
        expect(afterLock!.isLocked, isTrue);
        expect(
          sendCount,
          0,
          reason: 'stream echo of a Locked lobby must not send a second FCM',
        );
        expect(livePlan, isNotNull);
        expect(livePlan!.payload.isLocked, afterLock.isLocked);

        controller.add(lateJoin);
        await Future<void>.delayed(Duration.zero);

        final afterJoin = _lastReadyLockSnapshot(notifier);
        expect(afterJoin, isNotNull);
        expect(
          afterJoin!.isLocked,
          isFalse,
          reason: 'stream late-join Occupied must unlock via lobby_ready_lock '
              '(lateJoinUnlocks) onto lastReadyLockSnapshot',
        );
        expect(
          sendCount,
          0,
          reason: 'realtime listener stays notify:false on late-join unlock',
        );
        expect(livePlan!.payload.isLocked, afterJoin.isLocked);
      },
    );

    test(
      'LobbyState lock boolean if present derives from lastReadyLockSnapshot',
      () async {
        final stateSrc = _lobbyStateSource();
        final lockBools = RegExp(
          r'\b(bool\s+(isLocked|squadLocked|readyLocked|isSquadLocked)|'
          r'(isLocked|squadLocked|readyLocked|isSquadLocked)\s*=)',
        ).allMatches(stateSrc);
        expect(
          lockBools,
          isEmpty,
          reason: 'do not store a second lock flag on LobbyState; chip reads '
              'lastReadyLockSnapshot.isLocked. If Loop adds a getter it must '
              'derive from the snapshot, not a parallel bool.',
        );

        final notifier = await pumpSeatedLobby(
          statuses: const {'user-1': 'Ready'},
        );
        await notifier.toggleSeatedReady(
          userId: 'user-2',
          gameName: 'Warzone',
          spotIndex: 1,
        );

        final snap = _lastReadyLockSnapshot(notifier);
        expect(snap, isNotNull);
        expect(snap!.isLocked, isTrue);

        final squadState = container.read(lobbyNotifierProvider).value!;
        final resolved = resolveLobbyReadyLockFromState(
          squadState,
          gameName: 'Warzone',
        );
        expect(
          resolved.isLocked,
          snap.isLocked,
          reason: 'any derived LobbyState lock must equal lastReadyLockSnapshot',
        );
        expect(resolved.readyUids, snap.readyUids);
        expect(resolved.seatedUids, snap.seatedUids);

        bool? secondLock;
        final dynamic stateDyn = squadState;
        try {
          secondLock = stateDyn.isLocked as bool?;
        } catch (_) {}
        try {
          secondLock ??= stateDyn.squadLocked as bool?;
        } catch (_) {}
        try {
          secondLock ??= stateDyn.readyLocked as bool?;
        } catch (_) {}
        try {
          secondLock ??= stateDyn.isSquadLocked as bool?;
        } catch (_) {}
        if (secondLock != null) {
          expect(
            secondLock,
            snap.isLocked,
            reason: 'LobbyState lock boolean must derive from '
                'lastReadyLockSnapshot, not a parallel flag',
          );
        }
      },
    );

    test(
      'one notify pipeline — Ready/Lock send is not inlined three ways',
      () {
        final writes = _readyLockWriteSource();
        final sendHits = RegExp(r'LobbyLockNotify\.send').allMatches(writes);
        expect(
          sendHits.length,
          1,
          reason: 'one notify pipeline: apply / timeout / reconcile must call '
              'a single helper that plans from lastReadyLockSnapshot — not '
              'three inlined LobbyLockNotify.send sites',
        );
        expect(
          writes.contains('lastReadyLockSnapshot') ||
              writes.contains('_lastReadyLockSnapshot'),
          isTrue,
        );
      },
    );
  });
}
