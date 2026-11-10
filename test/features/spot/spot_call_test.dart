import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/app.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/spot/data/fake_spot_repository.dart';
import 'package:squadsync/features/spot/data/spot_repository.dart';
import 'package:squadsync/features/spot/domain/spot_call.dart';
import 'package:squadsync/features/spot/ui/spot_strip.dart';
import 'package:squadsync/features/squad/domain/member.dart';

void main() {
  test('an open call counts down and then closes for non-starters', () {
    final start = DateTime.utc(2026, 11, 10, 20);
    final call = SpotCall(
      id: 'spot',
      squadId: 'squad',
      callerId: 'spencer',
      game: 'Halo',
      startsAt: start,
      calledAt: start,
      joinUntil: start.add(const Duration(minutes: 5)),
      rsvps: const [
        SpotRsvp(userId: 'starter', response: SpotAnswer.rsvpIn, starter: true),
      ],
    );
    expect(call.phaseAt(start), SpotPhase.open);
    expect(
      spotStatusLine(call: call, clock: start),
      '5:00 left to join Halo. Called just now.',
    );
    expect(
      call.phaseAt(start.add(const Duration(minutes: 5))),
      SpotPhase.expired,
    );
    expect(
      spotStatusLine(call: call, clock: start.add(const Duration(minutes: 5))),
      'Join window closed. Starters stay in. Called 5m ago.',
    );
    expect(spotStatusLine(call: null, clock: start), 'No spot called.');
  });

  test(
    'the fake window is five minutes and a late non-starter is refused',
    () async {
      final clock = ManualSquadClock(DateTime.utc(2026, 11, 10, 20));
      final repo = FakeSpotRepository(clock: clock, userId: 'late')
        ..starters.add('starter');
      final call = await repo.callSpot(
        squadId: 'squad',
        game: 'Halo',
        startsAt: clock.now(),
      );
      expect(
        call.joinUntil.difference(call.calledAt),
        const Duration(minutes: 5),
      );
      expect(call.starter('starter'), isTrue);
      clock.advance(const Duration(minutes: 5));
      expect(
        repo.rsvp(callId: call.id, answer: SpotAnswer.rsvpIn),
        throwsA(isA<Exception>()),
      );
      repo.userId = 'starter';
      await repo.rsvp(callId: call.id, answer: SpotAnswer.rsvpIn);
      repo.userId = 'late';
      await repo.lock(callId: call.id);
      expect(
        spotStatusLine(call: repo.call, clock: clock.now()),
        'Locked. 2 in. Called 5m ago.',
      );
    },
  );

  test(
    'a locked call blocks the next one until six hours have passed',
    () async {
      final clock = ManualSquadClock(DateTime.utc(2026, 11, 10, 20));
      final repo = FakeSpotRepository(clock: clock);
      final call = await repo.callSpot(
        squadId: 'squad',
        game: 'Halo',
        startsAt: clock.now(),
      );
      await repo.lock(callId: call.id);
      expect(
        repo.callSpot(squadId: 'squad', game: 'Next', startsAt: clock.now()),
        throwsA(
          isA<RepositoryFailure>().having(
            (error) => error.code,
            'code',
            'spot_already_open',
          ),
        ),
      );
      clock.advance(spotLockMax);
      final next = await repo.callSpot(
        squadId: 'squad',
        game: 'Next',
        startsAt: clock.now(),
      );
      expect(next.game, 'Next');
      expect(next.phaseAt(clock.now()), SpotPhase.open);
    },
  );

  test('cancel is the caller before lock, and end is after lock', () async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 10, 20));
    final repo = FakeSpotRepository(
      clock: clock,
      userId: 'alex',
      ownerId: 'spencer',
    );
    final call = await repo.callSpot(
      squadId: 'squad',
      game: 'Halo',
      startsAt: clock.now(),
    );
    repo.userId = 'spencer';
    expect(
      repo.cancel(callId: call.id),
      throwsA(
        isA<RepositoryFailure>().having(
          (error) => error.message,
          'message',
          'Only the caller can cancel this spot.',
        ),
      ),
    );
    repo.userId = 'alex';
    await repo.cancel(callId: call.id);
    expect(repo.call, isNull);

    final locked = await repo.callSpot(
      squadId: 'squad',
      game: 'Halo',
      startsAt: clock.now(),
    );
    await repo.lock(callId: locked.id);
    expect(
      repo.cancel(callId: locked.id),
      throwsA(
        isA<RepositoryFailure>().having(
          (error) => error.code,
          'code',
          'spot_locked',
        ),
      ),
    );
    repo.userId = 'friend';
    expect(
      repo.end(callId: locked.id),
      throwsA(
        isA<RepositoryFailure>().having(
          (error) => error.code,
          'code',
          'spot_not_caller',
        ),
      ),
    );
    repo.userId = 'spencer';
    await repo.end(callId: locked.id);
    expect(repo.call, isNull);
  });

  test(
    'every spot refusal has a sentence, and deletes match the local call',
    () {
      const codes = [
        'spot_full',
        'spot_join_closed',
        'spot_locked',
        'spot_already_open',
        'spot_not_caller',
        'spot_not_member',
        'spot_not_locked',
        'spot_signed_out',
        'spot_game_blank',
        'spot_missing',
        'spot_closed',
        'spot_response',
      ];
      for (final code in codes) {
        expect(spotErrorMessage(code), isNot(contains(code)));
        expect(spotErrorCode(code), code);
      }
      expect(
        spotErrorMessage('spot_not_caller', action: 'cancel'),
        'Only the caller can cancel this spot.',
      );
      expect(spotRsvpClosedByServer('spot_full'), isTrue);
      expect(spotRsvpClosedByServer('spot_join_closed'), isTrue);
      expect(spotRsvpClosedByServer('spot_game_blank'), isFalse);

      expect(
        reloadAfterSpotEvent(
          knownCallId: 'spot',
          change: const SpotChange(deletedCallId: 'other'),
        ),
        isFalse,
      );
      expect(
        reloadAfterSpotEvent(
          knownCallId: 'spot',
          change: const SpotChange(deletedCallId: 'spot'),
        ),
        isTrue,
      );
      expect(
        reloadAfterSpotEvent(
          knownCallId: 'spot',
          change: const SpotChange(deletedCallId: ''),
        ),
        isTrue,
      );
      expect(
        reloadAfterSpotEvent(
          knownCallId: 'spot',
          change: const SpotChange(rsvpCallId: 'other'),
        ),
        isFalse,
      );
      expect(
        reloadAfterSpotEvent(knownCallId: null, change: const SpotChange()),
        isTrue,
      );
    },
  );

  testWidgets('an open call counts down and a full server disables RSVP', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 10, 20));
    final spots = _FullOnIn(clock: clock);
    await _pumpStrip(tester, spots);

    await tester.tap(find.byKey(const Key('spot-call')));
    await tester.pumpAndSettle();
    expect(find.textContaining('5:00 left to join Halo.'), findsOneWidget);
    expect(find.textContaining('Called just now.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('spot-in'))).onPressed,
      isNotNull,
    );
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('spot-out'))).onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('spot-in')));
    await tester.pumpAndSettle();
    expect(find.text('This spot is full.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('spot-in'))).onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('spot-out'))).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('lock shows who is in, then End asks before it closes', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 10, 20));
    final spots = FakeSpotRepository(clock: clock);
    final call = await spots.callSpot(
      squadId: 'squad',
      game: 'Halo',
      startsAt: clock.now(),
    );
    await spots.lock(callId: call.id);
    await _pumpStrip(tester, spots);

    expect(find.textContaining('Locked. 1 in.'), findsOneWidget);
    expect(find.bySemanticsLabel('In: Spencer'), findsOneWidget);
    expect(find.text('Spencer'), findsWidgets);
    expect(find.byKey(const Key('spot-in')), findsNothing);
    expect(find.byKey(const Key('spot-end')), findsOneWidget);

    await tester.tap(find.byKey(const Key('spot-end')));
    await tester.pumpAndSettle();
    expect(find.text('End this spot?'), findsOneWidget);
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Locked. 1 in.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('spot-end')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('spot-end-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('No spot called.'), findsOneWidget);
    expect(spots.call, isNull);
  });

  testWidgets('cancel asks the caller and leaves the spot when kept', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 10, 20));
    final spots = FakeSpotRepository(clock: clock);
    await spots.callSpot(squadId: 'squad', game: 'Halo', startsAt: clock.now());
    await _pumpStrip(tester, spots);

    expect(find.byKey(const Key('spot-cancel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('spot-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this spot?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('spot-cancel-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('No spot called.'), findsOneWidget);
  });

  testWidgets('a delete for another call stays, and this call reloads', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 10, 20));
    final spots = FakeSpotRepository(clock: clock);
    final call = await spots.callSpot(
      squadId: 'squad',
      game: 'Halo',
      startsAt: clock.now(),
    );
    await _pumpStrip(tester, spots);
    expect(find.textContaining('to join Halo'), findsOneWidget);

    spots.deliver(const SpotChange(deletedCallId: 'other-squad-call'));
    spots.deliver(const SpotChange(rsvpCallId: 'other-squad-call'));
    await tester.pumpAndSettle();
    expect(find.textContaining('to join Halo'), findsOneWidget);

    spots.call = null;
    spots.deliver(SpotChange(deletedCallId: call.id));
    await tester.pumpAndSettle();
    expect(find.text('No spot called.'), findsOneWidget);
  });

  testWidgets('pull to refresh and resume load a spot realtime missed', (
    tester,
  ) async {
    final clock = ManualSquadClock(DateTime.utc(2026, 11, 10, 20));
    final spots = FakeSpotRepository(clock: clock);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          spotRepositoryProvider.overrideWithValue(spots),
          squadClockProvider.overrideWithValue(clock),
          availabilityTickProvider.overrideWithValue(Duration.zero),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No spot called.'), findsOneWidget);

    await spots.callSpot(squadId: 'squad', game: 'Halo', startsAt: clock.now());
    final refresh = tester.widget<RefreshIndicator>(
      find.byKey(const Key('refresh-chat')),
    );
    await refresh.onRefresh();
    await tester.pumpAndSettle();
    expect(find.textContaining('to join Halo'), findsOneWidget);

    await spots.lock(callId: spots.call!.id);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.textContaining('Locked.'), findsOneWidget);
    expect(find.byKey(const Key('spot-end')), findsOneWidget);
  });
}

Future<void> _pumpStrip(WidgetTester tester, FakeSpotRepository spots) async {
  await tester.binding.setSurfaceSize(const Size(402, 874));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        spotRepositoryProvider.overrideWithValue(spots),
        squadClockProvider.overrideWithValue(spots.clock),
        availabilityTickProvider.overrideWithValue(Duration.zero),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SpotStrip(
              squadId: 'squad',
              meId: 'spencer',
              canLock: true,
              members: [spencer],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FullOnIn extends FakeSpotRepository {
  _FullOnIn({required super.clock});

  @override
  Future<void> rsvp({
    required String callId,
    required SpotAnswer answer,
  }) async {
    if (answer == SpotAnswer.rsvpIn) {
      throw RepositoryFailure(spotErrorMessage('spot_full'), code: 'spot_full');
    }
    await super.rsvp(callId: callId, answer: answer);
  }
}
