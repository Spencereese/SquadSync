import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/availability/data/fake_availability_repository.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/availability/ui/who_can_play_panel.dart';
import 'package:squadsync/features/squad/data/fake_squad_repository.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

const _friend = Member(
  id: 'friend',
  displayName: 'Friend',
  defaultGame: 'Halo',
);

Squad _home() {
  return Squad(
    id: 'squad',
    ownerId: spencer.id,
    members: const [spencer, _friend],
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required FakeAvailabilityRepository repo,
  required SquadClock clock,
  Duration tick = Duration.zero,
  bool demo = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        squadClockProvider.overrideWithValue(clock),
        localOffsetProvider.overrideWithValue(Duration.zero),
        availabilityTickProvider.overrideWithValue(tick),
        availabilityRepositoryProvider.overrideWithValue(repo),
        squadRepositoryProvider.overrideWithValue(
          FakeSquadRepository(seed: _home()),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WhoCanPlayPanel(
              squad: _home(),
              meId: spencer.id,
              demo: demo,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('each section and the empty prompt are on the home board', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 20));
    final repo = FakeAvailabilityRepository(
      clock: clock,
      seed: [
        StoredCheckIn(
          userId: 'friend',
          squadId: 'squad',
          kind: CheckInKind.availableLater,
          checkedAt: DateTime.utc(2026, 11, 8, 19),
          until: DateTime.utc(2026, 11, 8, 22, 30),
        ),
      ],
    );
    await _pump(tester, repo: repo, clock: clock, demo: true);

    expect(find.byKey(const Key('who-demo')), findsOneWidget);
    expect(find.text('0 of 8 available'), findsOneWidget);
    expect(find.byKey(const Key('section-playing')), findsOneWidget);
    expect(find.byKey(const Key('section-available')), findsOneWidget);
    expect(find.byKey(const Key('section-later')), findsOneWidget);
    expect(find.byKey(const Key('section-offline')), findsOneWidget);
    expect(
      find.textContaining('Friend · Maybe later until 10:30 PM'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Does not turn into available now'),
      findsOneWidget,
    );
    expect(find.textContaining('Spencer · Not checked in'), findsOneWidget);
    expect(find.textContaining('Steam'), findsNothing);
    expect(find.textContaining('Xbox'), findsNothing);
    expect(find.textContaining('PlayStation'), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('status-available'))).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('nobody checked in asks you to tap Available', (tester) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 20));
    final repo = FakeAvailabilityRepository(clock: clock);
    await _pump(tester, repo: repo, clock: clock);

    expect(find.byKey(const Key('who-empty')), findsOneWidget);
    expect(find.byKey(const Key('who-summary')), findsOneWidget);
    expect(find.text('0 of 8 available'), findsOneWidget);
    expect(repo.rows, isEmpty);
  });

  testWidgets('a failed load does not show a count', (tester) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 20));
    final repo = FakeAvailabilityRepository(clock: clock, failLoad: true);
    await _pump(tester, repo: repo, clock: clock);

    expect(find.byKey(const Key('who-error')), findsOneWidget);
    expect(find.byKey(const Key('who-summary')), findsNothing);
    expect(find.textContaining('of 8 available'), findsNothing);

    repo.failLoad = false;
    await tester.tap(find.byKey(const Key('who-retry')));
    await tester.pump();
    await tester.pump();

    expect(find.text('0 of 8 available'), findsOneWidget);
  });

  testWidgets('a missing table says availability is not enabled', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 20));
    final repo = FakeAvailabilityRepository(clock: clock, notEnabled: true);
    await _pump(tester, repo: repo, clock: clock);

    expect(find.byKey(const Key('who-disabled')), findsOneWidget);
    expect(find.byKey(const Key('who-summary')), findsNothing);
  });

  testWidgets('the first load shows a spinner instead of a count', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 20));
    final gate = Completer<void>();
    final repo = FakeAvailabilityRepository(clock: clock)
      ..holdLoads = gate.future;
    await _pump(tester, repo: repo, clock: clock);

    expect(find.byKey(const Key('who-loading')), findsOneWidget);
    expect(find.byKey(const Key('who-summary')), findsNothing);

    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('0 of 8 available'), findsOneWidget);
  });

  testWidgets('Available puts me in playing now with the game I typed', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 20));
    final repo = FakeAvailabilityRepository(clock: clock);
    await _pump(tester, repo: repo, clock: clock);

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('status-game')))
          .controller
          ?.text,
      'Call of Duty',
    );
    await tester.tap(find.byKey(const Key('status-available')));
    await tester.pump();
    await tester.pump();

    expect(find.text('1 of 8 available'), findsOneWidget);
    expect(
      find.textContaining(
        'Spencer · until 9:00 PM · Call of Duty · checked in, not detected',
      ),
      findsOneWidget,
    );
    expect(find.text('Available, selected'), findsOneWidget);
  });

  testWidgets("Can't is its own offline line", (tester) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 20));
    final repo = FakeAvailabilityRepository(clock: clock);
    await _pump(tester, repo: repo, clock: clock);

    await tester.tap(find.byKey(const Key('status-cant')));
    await tester.pump();
    await tester.pump();

    expect(find.text('0 of 8 available'), findsOneWidget);
    expect(find.textContaining("Spencer · Can't"), findsOneWidget);
    expect(find.text("Can't, selected"), findsOneWidget);
    expect(find.byKey(const Key('who-empty')), findsNothing);
  });

  testWidgets('a check-in that expires while open becomes last seen', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 20));
    final repo = FakeAvailabilityRepository(clock: clock);
    await _pump(
      tester,
      repo: repo,
      clock: clock,
      tick: const Duration(seconds: 1),
    );
    await tester.tap(find.byKey(const Key('status-available')));
    await tester.pump();
    await tester.pump();
    expect(find.text('1 of 8 available'), findsOneWidget);

    clock.set(DateTime.utc(2026, 11, 8, 21));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('0 of 8 available'), findsOneWidget);
    expect(find.textContaining('Spencer · Last seen'), findsOneWidget);
    expect(find.textContaining('checked in, not detected'), findsNothing);
  });

  testWidgets('a realtime check-in shows up without a restart', (tester) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 20));
    final repo = FakeAvailabilityRepository(clock: clock);
    await _pump(tester, repo: repo, clock: clock);

    repo.store(
      StoredCheckIn(
        userId: 'friend',
        squadId: 'squad',
        kind: CheckInKind.availableNow,
        checkedAt: clock.now(),
        until: clock.now().add(const Duration(minutes: 60)),
      ),
    );
    repo.notify();
    await tester.pump();
    await tester.pump();

    expect(find.text('1 of 8 available'), findsOneWidget);
    expect(
      find.textContaining(
        'Friend · until 9:00 PM · Halo · checked in, not detected',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Maybe later asks for a time', (tester) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 8, 20));
    final repo = FakeAvailabilityRepository(clock: clock);
    await _pump(tester, repo: repo, clock: clock);

    await tester.tap(find.byKey(const Key('status-later')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('later-dialog')), findsOneWidget);
  });
}
