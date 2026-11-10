import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/spot/data/fake_spot_repository.dart';
import 'package:squadsync/features/spot/domain/spot_call.dart';

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
    expect(spotStatusLine(call: call, clock: start), '5:00 left to join Halo.');
    expect(
      call.phaseAt(start.add(const Duration(minutes: 5))),
      SpotPhase.expired,
    );
    expect(
      spotStatusLine(call: call, clock: start.add(const Duration(minutes: 5))),
      'Join window closed. Starters stay in.',
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
      await repo.lock(callId: call.id);
      expect(
        spotStatusLine(call: repo.call, clock: clock.now()),
        'Locked. 2 in.',
      );
    },
  );
}
