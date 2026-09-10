import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/data/repositories/matchmaking_queue_repository.dart';
import 'package:squad_sync/services/matchmaking_queue_machine.dart';
import 'package:squad_sync/services/squad_analytics.dart';
import 'package:squad_sync/widgets/lfg_queue_status_row.dart';

class _MemoryQueueRepo implements MatchmakingQueueRepository {
  _MemoryQueueRepo({this.onFetch});

  final Map<String, MatchmakingQueueEntry> rows =
      <String, MatchmakingQueueEntry>{};
  final StreamController<MatchmakingQueueChange> controller =
      StreamController<MatchmakingQueueChange>.broadcast();
  Future<Map<String, MatchmakingQueueEntry>> Function()? onFetch;

  @override
  Future<void> upsert(String userId, MatchmakingQueueEntry entry) async {
    rows[userId] = entry;
  }

  @override
  Future<void> remove(String userId) async {
    rows.remove(userId);
  }

  @override
  Future<Map<String, MatchmakingQueueEntry>> fetchActive() {
    if (onFetch != null) return onFetch!();
    return Future.value(Map<String, MatchmakingQueueEntry>.from(rows));
  }

  @override
  Stream<MatchmakingQueueChange> watch() => controller.stream;

  @override
  Future<void> dispose() async {
    await controller.close();
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  setUp(() {
    SquadAnalytics.resetTestHooks();
    SquadAnalytics.logHook = (_, __) async {};
  });
  tearDown(SquadAnalytics.resetTestHooks);

  testWidgets('empty copy is arm length with no spinner', (tester) async {
    await tester.pumpWidget(
      _wrap(const LfgQueueStatusRow(view: LfgListView.empty)),
    );

    expect(find.byKey(const Key('lfg-queue-empty')), findsOneWidget);
    expect(find.text(kLfgListEmptyCopy), findsOneWidget);
    expect(find.text(kLfgListEmptyHint), findsOneWidget);
    expect(find.byKey(const Key('lfg-queue-empty-hint')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('lfg-queue-retry')), findsNothing);
  });

  testWidgets('error copy offers Retry and never a spinner', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _wrap(
        LfgQueueStatusRow(
          view: const LfgListView(
            phase: LfgListPhase.error,
            error: 'offline',
          ),
          onRetry: () => retried = true,
        ),
      ),
    );

    expect(find.byKey(const Key('lfg-queue-error')), findsOneWidget);
    expect(find.text(kLfgListErrorCopy), findsOneWidget);
    expect(find.text(kLfgListErrorHint), findsOneWidget);
    expect(find.byKey(const Key('lfg-queue-retry')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byKey(const Key('lfg-queue-retry')));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('stale copy keeps last known queue and Retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _wrap(
        LfgQueueStatusRow(
          view: const LfgListView(
            phase: LfgListPhase.stale,
            lookingUserIds: ['u-look'],
          ),
          onRetry: () => retried = true,
        ),
      ),
    );

    expect(find.byKey(const Key('lfg-queue-stale')), findsOneWidget);
    expect(find.text(kLfgListStaleCopy), findsOneWidget);
    expect(find.text(kLfgListStaleHint), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('last dequeue paints empty copy, not error or spinner',
      (tester) async {
    final tracker = MatchmakingQueueTracker();
    tracker.startLooking('u1');
    tracker.processQueue(lobbyId: 'lobby-9', lobbyHasFreeSeat: true);

    await tester.pumpWidget(
      _wrap(LfgQueueStatusRow(view: resolveLfgListFromTracker(tracker))),
    );

    expect(find.byKey(const Key('lfg-queue-empty')), findsOneWidget);
    expect(find.text(kLfgListEmptyCopy), findsOneWidget);
    expect(find.text(kLfgListEmptyHint), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('lfg-queue-error')), findsNothing);
  });

  testWidgets('dequeue while empty stays empty copy', (tester) async {
    final tracker = MatchmakingQueueTracker();
    expect(tracker.processQueue(lobbyId: 'lobby-9'), isEmpty);

    await tester.pumpWidget(
      _wrap(LfgQueueStatusRow(view: resolveLfgListFromTracker(tracker))),
    );

    expect(find.byKey(const Key('lfg-queue-empty')), findsOneWidget);
    expect(find.text(kLfgListEmptyCopy), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('reconnecting is copy, not a dead spinner', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const LfgQueueStatusRow(
          view: LfgListView(phase: LfgListPhase.loading),
        ),
      ),
    );

    expect(find.byKey(const Key('lfg-queue-reconnecting')), findsOneWidget);
    expect(find.text(kLfgListReconnectingCopy), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('lfg-queue-retry')), findsNothing);
  });

  group('LfgQueueStatusHost', () {
    setUp(() {
      LfgQueueStatusHost.scheduleDisconnectCleanup = false;
      lfgReconnectToastGate.reset();
    });
    tearDown(() {
      lfgReconnectToastGate.reset();
      LfgQueueStatusHost.scheduleDisconnectCleanup = true;
    });

    testWidgets('host shows reconnecting toast without a spinner',
        (tester) async {
      final gate = Completer<Map<String, MatchmakingQueueEntry>>();
      final repo = _MemoryQueueRepo(onFetch: () => gate.future);
      addTearDown(repo.dispose);
      final tracker = MatchmakingQueueTracker(repository: repo);
      addTearDown(tracker.unbindRealtime);
      tracker.markRealtimeDisconnected();
      unawaited(tracker.hydrateFromRepository(force: true));

      await tester.pumpWidget(
        _wrap(LfgQueueStatusHost(tracker: tracker)),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('lfg-queue-reconnecting')),
        findsOneWidget,
      );
      expect(find.text(kLfgListReconnectingCopy), findsWidgets);
      expect(find.byKey(const Key(kLfgReconnectToastKey)), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      gate.complete(const {});
      await tracker.waitForPendingPersists();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
    });

    testWidgets('host empty after disconnect cleanup is empty copy',
        (tester) async {
      LfgQueueStatusHost.scheduleDisconnectCleanup = true;
      final tracker = MatchmakingQueueTracker();
      tracker.applyRemote(
        'u1',
        const MatchmakingQueueEntry(phase: MatchmakingQueuePhase.looking),
      );
      tracker.markRealtimeDisconnected();

      await tester.pumpWidget(
        _wrap(LfgQueueStatusHost(tracker: tracker)),
      );
      await tester.pump();

      expect(find.byKey(const Key('lfg-queue-stale')), findsOneWidget);
      expect(find.text(kLfgListStaleCopy), findsOneWidget);

      await tester.pump(kLfgDisconnectStaleAfter);
      await tester.pump();

      expect(find.byKey(const Key('lfg-queue-empty')), findsOneWidget);
      expect(find.text(kLfgListEmptyCopy), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
