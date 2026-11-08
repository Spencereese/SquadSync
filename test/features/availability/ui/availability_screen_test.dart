import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/app.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/availability/data/fake_availability_repository.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/availability/ui/availability_screen.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

const _friend = Member(
  id: 'friend',
  displayName: 'Friend',
  defaultGame: 'Call of Duty',
);

Squad _squad() {
  return Squad(
    id: 'squad',
    ownerId: spencer.id,
    members: const [spencer, _friend],
  );
}

Future<void> _open(
  WidgetTester tester, {
  required FakeAvailabilityRepository repo,
  required SquadClock clock,
  Duration tick = Duration.zero,
  bool demo = false,
  String meId = 'spencer',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        squadClockProvider.overrideWithValue(clock),
        localOffsetProvider.overrideWithValue(Duration.zero),
        availabilityTickProvider.overrideWithValue(tick),
        availabilityRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: AvailabilityScreen(squad: _squad(), meId: meId, demo: demo),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('opening the board does not check anyone in', (tester) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 15));
    final repo = FakeAvailabilityRepository(clock: clock);
    await _open(tester, repo: repo, clock: clock);

    expect(find.text('0 available now'), findsOneWidget);
    expect(find.text('0 available later'), findsOneWidget);
    expect(
      find.text('Not checked in. This is not an unavailable mark.'),
      findsNWidgets(2),
    );
    expect(find.textContaining('Available now until'), findsNothing);
    expect(repo.rows, isEmpty);
    expect(
      find.text('Being in the app is not the same as being available.'),
      findsOneWidget,
    );
  });

  testWidgets('a failed load is not a zero count, and retry shows the board', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 15));
    final repo = FakeAvailabilityRepository(clock: clock, failLoad: true);
    await _open(tester, repo: repo, clock: clock);

    expect(find.byKey(const Key('available-now-count')), findsNothing);
    expect(find.text('Could not load check-ins.'), findsOneWidget);

    repo.failLoad = false;
    await tester.tap(find.byKey(const Key('availability-retry')));
    await tester.pump();
    await tester.pump();

    expect(find.text('0 available now'), findsOneWidget);
    expect(find.byKey(const Key('availability-error')), findsNothing);
  });

  testWidgets('the first load shows a spinner instead of a count', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 15));
    final gate = Completer<void>();
    final repo = FakeAvailabilityRepository(clock: clock)
      ..holdLoads = gate.future;
    await _open(tester, repo: repo, clock: clock);

    expect(find.byKey(const Key('availability-loading')), findsOneWidget);
    expect(find.byKey(const Key('available-now-count')), findsNothing);

    gate.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text('0 available now'), findsOneWidget);
  });

  testWidgets('a missing table says the feature is not enabled', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 15));
    final repo = FakeAvailabilityRepository(clock: clock, notEnabled: true);
    await _open(tester, repo: repo, clock: clock);

    expect(find.byKey(const Key('availability-disabled')), findsOneWidget);
    expect(find.byKey(const Key('available-now-count')), findsNothing);
    expect(find.byKey(const Key('availability-demo')), findsNothing);
    expect(find.byKey(const Key('check-in-now')), findsNothing);
    expect(repo.rows, isEmpty);
  });

  testWidgets('save failure stays unchecked and retry saves the same choice', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 15));
    final repo = FakeAvailabilityRepository(clock: clock, failSave: true);
    await _open(tester, repo: repo, clock: clock);

    await tester.tap(find.byKey(const Key('check-in-now')));
    await tester.pump();
    await tester.pump();

    expect(repo.rows, isEmpty);
    expect(find.text('0 available now'), findsOneWidget);
    expect(
      find.text('Could not save your check-in. Nothing was saved.'),
      findsOneWidget,
    );

    repo.failSave = false;
    await tester.tap(find.byKey(const Key('availability-retry')));
    await tester.pump();
    await tester.pump();

    expect(repo.rows, hasLength(1));
    expect(find.text('1 available now'), findsOneWidget);
    expect(
      find.textContaining('Available now until Sun Nov 8, 4:00 PM'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Self check-in at Sun Nov 8, 3:00 PM'),
      findsOneWidget,
    );
  });

  testWidgets('unavailable and clear are different from not checked in', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 15));
    final repo = FakeAvailabilityRepository(clock: clock);
    await _open(tester, repo: repo, clock: clock);

    await tester.tap(find.byKey(const Key('check-in-unavailable')));
    await tester.pump();
    await tester.pump();

    expect(find.text('0 available now'), findsOneWidget);
    expect(
      find.text('Unavailable. Self check-in at Sun Nov 8, 3:00 PM.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('check-in-clear')));
    await tester.pump();
    await tester.pump();

    expect(repo.rows, isEmpty);
    expect(
      find.text('Not checked in. This is not an unavailable mark.'),
      findsNWidgets(2),
    );
    expect(find.textContaining('Unavailable. Self check-in'), findsNothing);
  });

  testWidgets(
    'available later uses the chosen time and does not count as now',
    (tester) async {
      final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 15));
      final repo = FakeAvailabilityRepository(clock: clock);
      await _open(tester, repo: repo, clock: clock);

      await tester.tap(find.byKey(const Key('check-in-later')));
      await tester.pumpAndSettle();
      expect(find.text('Sun Nov 8, 3:05 PM'), findsOneWidget);

      await tester.tap(find.byKey(const Key('later-hour')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('later-hour-4')).last);
      await tester.pumpAndSettle();
      expect(find.text('Sun Nov 8, 4:05 PM'), findsOneWidget);

      await tester.tap(find.byKey(const Key('later-save')));
      await tester.pump();
      await tester.pump();

      expect(find.text('0 available now'), findsOneWidget);
      expect(find.text('1 available later'), findsOneWidget);
      expect(
        find.textContaining('Available later at Sun Nov 8, 4:05 PM'),
        findsOneWidget,
      );
      expect(repo.rows.single.until, DateTime.utc(2026, 11, 8, 16, 5));
      expect(repo.rows.single.kind, CheckInKind.availableLater);
    },
  );

  testWidgets('an open board drops a stale now without a refresh', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 15));
    final repo = FakeAvailabilityRepository(
      clock: clock,
      seed: [
        StoredCheckIn(
          userId: 'spencer',
          squadId: 'squad',
          kind: CheckInKind.availableNow,
          checkedAt: clock.now(),
          until: clock.now().add(availableNowWindow),
        ),
      ],
    );
    await _open(
      tester,
      repo: repo,
      clock: clock,
      tick: const Duration(milliseconds: 50),
    );
    expect(find.text('1 available now'), findsOneWidget);

    clock.advance(availableNowWindow);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('0 available now'), findsOneWidget);
    expect(find.textContaining('Not available now'), findsOneWidget);
    expect(find.textContaining('Available now until'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('resume expires a now check-in that aged while away', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 15));
    final repo = FakeAvailabilityRepository(
      clock: clock,
      seed: [
        StoredCheckIn(
          userId: 'friend',
          squadId: 'squad',
          kind: CheckInKind.availableLater,
          checkedAt: clock.now(),
          until: clock.now().add(const Duration(hours: 2)),
        ),
      ],
    );
    await _open(tester, repo: repo, clock: clock);
    expect(find.text('1 available later'), findsOneWidget);
    expect(find.text('0 available now'), findsOneWidget);

    clock.advance(const Duration(hours: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('0 available later'), findsOneWidget);
    expect(find.text('0 available now'), findsOneWidget);
    expect(find.textContaining('Not available now'), findsOneWidget);
  });

  testWidgets('a failed refresh stays visible and can still expire', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 15));
    final repo = FakeAvailabilityRepository(
      clock: clock,
      seed: [
        StoredCheckIn(
          userId: 'spencer',
          squadId: 'squad',
          kind: CheckInKind.availableNow,
          checkedAt: clock.now(),
          until: clock.now().add(availableNowWindow),
        ),
      ],
    );
    await _open(tester, repo: repo, clock: clock);
    expect(find.text('1 available now'), findsOneWidget);

    repo.failLoad = true;
    await tester.tap(find.byKey(const Key('availability-refresh')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('availability-stale')), findsOneWidget);
    expect(find.text('1 available now'), findsOneWidget);

    clock.advance(availableNowWindow);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.byKey(const Key('availability-stale')), findsOneWidget);
    expect(find.text('0 available now'), findsOneWidget);
    expect(find.textContaining('Not available now'), findsOneWidget);
  });

  testWidgets('the demo board is labeled and is not a live sync', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [availabilityTickProvider.overrideWithValue(Duration.zero)],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-availability')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('availability-demo')), findsOneWidget);
    expect(
      find.text('Demo. Not connected. Check-ins stay on this phone.'),
      findsOneWidget,
    );
    expect(find.text('0 available now'), findsOneWidget);
    expect(find.byKey(const Key('availability-disabled')), findsNothing);
    expect(find.textContaining('Available now until'), findsNothing);
  });
}
