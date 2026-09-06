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
import 'package:squad_sync/services/preferred_peacock_games.dart';
import 'package:squad_sync/services/squad_analytics.dart';

import 'lobby_notifier_test.mocks.dart';

/// Slice C reds: assignSpot / joinLobby / leaveSquad / startSpotTimer must
/// optimistic-patch currentLobby, persist the one row, and leave Realtime as
/// source of truth. Success path must not call [LobbyRepository.loadLobbyState]
/// / full `_loadPersistedLobbyState()`. Persist fail keeps the claimed seat
/// and surfaces error + Retry.
///
/// Loop may extract [LobbySeatWriter] from [LobbyNotifier]. Seams:
/// `Object? lastSeatWriteError` and `Future<void> retrySeatWrite()` on the
/// notifier (or the extracted writer). Never persist the literal wipe of a
/// seat just claimed.
Lobby _lobby({
  String id = 'lobby-9',
  String name = 'Tonight',
  String gameName = 'Warzone',
  List<String> memberUids = const ['user-1', 'user-2'],
  List<String?>? spots,
  List<Map<String, dynamic>?>? spotTimers,
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
    spotTimers: spotTimers ?? List<Map<String, dynamic>?>.filled(maxSpots, null),
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

Lobby? _currentLobby(ProviderContainer container) =>
    container.read(lobbyNotifierProvider).valueOrNull?.currentLobby;

void _expectNoFullReload(MockLobbyRepository repo) {
  verifyNever(repo.loadLobbyState());
  verifyNever(repo.saveLobbyState(any));
}

Object? _seatWriteError(LobbyNotifier notifier) {
  final dynamic n = notifier;
  try {
    return n.lastSeatWriteError;
  } catch (_) {
    return null;
  }
}

bool _seatWriteCanRetry(LobbyNotifier notifier) {
  final dynamic n = notifier;
  try {
    return n.retrySeatWrite is Function;
  } catch (_) {
    return false;
  }
}

Future<void> _retrySeatWrite(LobbyNotifier notifier) async {
  final dynamic n = notifier;
  try {
    await n.retrySeatWrite();
  } catch (e) {
    fail(
      'Loop seam: LobbyNotifier.retrySeatWrite() (extractable as '
      'LobbySeatWriter.retry) so friends can tap Retry after persist fail. $e',
    );
  }
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

  Future<LobbyNotifier> pumpOpenLobby({
    Lobby? lobby,
  }) async {
    final seated = lobby ?? _lobby();
    when(mockRepository.getLobbyStream(seated.id)).thenAnswer(
      (_) => Stream<Lobby?>.value(seated),
    );
    await container.read(lobbyNotifierProvider.future);
    final notifier = container.read(lobbyNotifierProvider.notifier);
    notifier.setSelectedLobbyId(seated.id);
    await Future<void>.delayed(Duration.zero);
    expect(
      _currentLobby(container)?.id,
      seated.id,
      reason: 'Realtime seed must land before the seat write',
    );
    clearInteractions(mockRepository);
    return notifier;
  }

  group('LobbySeatWriter - optimistic seat persist (Slice C)', () {
    test(
      'assignSpot patches currentLobby spots without loadLobbyState',
      () async {
        final notifier = await pumpOpenLobby();

        await notifier.assignSpot('lobby-9', 2, 'user-3');

        final lobby = _currentLobby(container);
        expect(lobby, isNotNull);
        expect(
          lobby!.spots[2],
          'user-3',
          reason: 'friends who tap a seat must see themselves sit immediately',
        );
        expect(lobby.spots, ['user-1', 'user-2', 'user-3']);
        verify(mockRepository.assignSpot('lobby-9', 2, 'user-3')).called(1);
        _expectNoFullReload(mockRepository);
      },
    );

    test('joinLobby patches members without loadLobbyState', () async {
      final notifier = await pumpOpenLobby();

      await notifier.joinLobby('lobby-9', 'user-3');

      final lobby = _currentLobby(container);
      expect(lobby, isNotNull);
      expect(
        lobby!.memberUids,
        contains('user-3'),
        reason: 'Join must show the new member without a full lobby reload',
      );
      verify(mockRepository.joinLobby('lobby-9', 'user-3')).called(1);
      _expectNoFullReload(mockRepository);
    });

    test('leaveSquad patches members without loadLobbyState', () async {
      final notifier = await pumpOpenLobby();

      await notifier.leaveSquad('lobby-9', 'user-2');

      final lobby = _currentLobby(container);
      expect(lobby, isNotNull);
      expect(
        lobby!.memberUids,
        isNot(contains('user-2')),
        reason: 'Leave must drop the member without wiping via full reload',
      );
      verify(mockRepository.leaveLobby('lobby-9', 'user-2')).called(1);
      _expectNoFullReload(mockRepository);
    });

    test('startSpotTimer patches spotTimers without loadLobbyState', () async {
      final notifier = await pumpOpenLobby();

      await notifier.startSpotTimer(
        'lobby-9',
        0,
        const Duration(seconds: 30),
      );

      final lobby = _currentLobby(container);
      expect(lobby, isNotNull);
      expect(
        lobby!.spotTimers[0],
        isNotNull,
        reason: 'starting a seat timer must patch currentLobby immediately',
      );
      final duration = lobby.spotTimers[0]!['duration'];
      expect(
        duration,
        anyOf(30, const Duration(seconds: 30).inSeconds),
      );
      verify(mockRepository.startSpotTimer(
        'lobby-9',
        0,
        const Duration(seconds: 30),
      )).called(1);
      _expectNoFullReload(mockRepository);
    });

    test(
      'assignSpot persist fail keeps optimistic seat and surfaces retry',
      () async {
        final notifier = await pumpOpenLobby();
        when(mockRepository.assignSpot(any, any, any))
            .thenThrow(Exception('offline'));

        Object? thrown;
        try {
          await notifier.assignSpot('lobby-9', 2, 'user-3');
        } catch (e) {
          thrown = e;
        }

        final lobby = _currentLobby(container);
        expect(
          lobby,
          isNotNull,
          reason: 'persist fail must not reload-wipe currentLobby',
        );
        expect(
          lobby!.spots[2],
          'user-3',
          reason: 'persist fail must keep the seat just claimed',
        );
        expect(
          thrown,
          isNull,
          reason: 'persist fail marks error + Retry; do not rethrow a wipe',
        );
        expect(
          _seatWriteError(notifier),
          isNotNull,
          reason: 'Loop seam lastSeatWriteError (LobbySeatWriter) so the '
              'map can show Retry instead of wiping the seat',
        );
        expect(_seatWriteCanRetry(notifier), isTrue);

        when(mockRepository.assignSpot(any, any, any)).thenAnswer((_) async {});
        await _retrySeatWrite(notifier);

        expect(_currentLobby(container)?.spots[2], 'user-3');
        expect(_seatWriteError(notifier), isNull);
        verify(mockRepository.assignSpot('lobby-9', 2, 'user-3'))
            .called(greaterThanOrEqualTo(2));
        verifyNever(mockRepository.loadLobbyState());
      },
    );

    test(
      'assignSpot success is one-row persist not dual-write plus full reload',
      () async {
        final notifier = await pumpOpenLobby();

        await notifier.assignSpot('lobby-9', 2, 'user-3');

        verify(mockRepository.assignSpot('lobby-9', 2, 'user-3')).called(1);
        verifyNever(mockRepository.loadLobbyState());
        verifyNever(mockRepository.saveLobbyState(any));
        verifyNever(mockRepository.joinLobby(any, any));
        expect(_currentLobby(container)?.spots[2], 'user-3');
      },
    );
  });
}
