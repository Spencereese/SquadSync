import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/features/availability/domain/availability_board.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/availability/domain/who_can_play.dart';
import 'package:squadsync/features/squad/domain/member.dart';

void main() {
  final clock = DateTime.utc(2026, 11, 8, 20);

  StoredCheckIn row({
    required String id,
    required CheckInKind kind,
    DateTime? until,
    DateTime? checkedAt,
  }) {
    return StoredCheckIn(
      userId: id,
      squadId: 'squad',
      kind: kind,
      checkedAt: checkedAt ?? clock,
      until: until,
    );
  }

  test('sections, the count, and a stale check-in are honest', () {
    const playing = Member(
      id: 'play',
      displayName: 'Play',
      defaultGame: 'Call of Duty',
    );
    const free = Member(id: 'free', displayName: 'Free', defaultGame: ' ');
    const later = Member(
      id: 'later',
      displayName: 'Later',
      defaultGame: 'Halo',
    );
    const cant = Member(id: 'cant', displayName: 'Cant', defaultGame: 'Halo');
    const quiet = Member(
      id: 'quiet',
      displayName: 'Quiet',
      defaultGame: 'Halo',
    );
    const stale = Member(
      id: 'stale',
      displayName: 'Stale',
      defaultGame: 'Halo',
    );
    final members = [playing, free, later, cant, quiet, stale];
    final board = AvailabilityBoard.compose(
      members: members,
      squadId: 'squad',
      clock: clock,
      rows: [
        row(
          id: 'play',
          kind: CheckInKind.availableNow,
          until: clock.add(const Duration(minutes: 30)),
        ),
        row(
          id: 'free',
          kind: CheckInKind.availableNow,
          until: clock.add(const Duration(minutes: 30)),
        ),
        row(
          id: 'later',
          kind: CheckInKind.availableLater,
          until: DateTime.utc(2026, 11, 8, 22, 30),
          checkedAt: clock.subtract(const Duration(hours: 1)),
        ),
        row(id: 'cant', kind: CheckInKind.unavailable),
        row(
          id: 'stale',
          kind: CheckInKind.availableNow,
          until: clock.subtract(const Duration(minutes: 1)),
          checkedAt: DateTime.utc(2026, 11, 8, 18),
        ),
      ],
    );
    final who = WhoCanPlay.group(board: board, members: members);

    expect(who.summary, '2 of 8 available');
    expect(who.playingNow.map((row) => row.userId), ['play']);
    expect(who.available.map((row) => row.userId), ['free']);
    expect(who.maybeLater.map((row) => row.userId), ['later']);
    expect(who.offline.map((row) => row.userId), ['cant', 'quiet', 'stale']);
    expect(who.nobodyCheckedIn, isFalse);
    expect(
      whoStatusLine(who.playingNow.single, localOffset: Duration.zero),
      'until 8:30 PM · Call of Duty · checked in, not detected',
    );
    expect(
      whoStatusLine(who.maybeLater.single, localOffset: Duration.zero),
      'Maybe later from 10:30 PM.',
    );
    expect(
      whoStatusLine(
        who.offline.firstWhere((row) => row.userId == 'stale'),
        localOffset: Duration.zero,
      ),
      'Last seen 7:59 PM',
    );
    expect(
      whoSpokenLine(who.playingNow.single, localOffset: Duration.zero),
      'Play, playing Call of Duty, until 8:30 PM',
    );
    expect(
      whoStatusLine(
        who.offline.firstWhere((row) => row.userId == 'quiet'),
        localOffset: Duration.zero,
      ),
      'Not checked in',
    );
    expect(
      whoStatusLine(
        who.offline.firstWhere((row) => row.userId == 'cant'),
        localOffset: Duration.zero,
      ),
      "Can't",
    );
  });

  test('an available-now check-in becomes last seen when it expires', () {
    const playing = Member(
      id: 'play',
      displayName: 'Play',
      defaultGame: 'Call of Duty',
    );
    final fresh = AvailabilityBoard.compose(
      members: const [playing],
      squadId: 'squad',
      clock: clock,
      rows: [
        row(
          id: 'play',
          kind: CheckInKind.availableNow,
          until: clock.add(const Duration(minutes: 30)),
        ),
      ],
    );
    expect(
      WhoCanPlay.group(board: fresh, members: const [playing]).availableCount,
      1,
    );

    final due = AvailabilityBoard.compose(
      members: const [playing],
      squadId: 'squad',
      clock: clock.add(const Duration(minutes: 30)),
      rows: [
        row(
          id: 'play',
          kind: CheckInKind.availableNow,
          until: clock.add(const Duration(minutes: 30)),
        ),
      ],
    );
    final who = WhoCanPlay.group(board: due, members: const [playing]);
    expect(who.availableCount, 0);
    expect(who.playingNow, isEmpty);
    expect(who.offline.single.person.effect, AvailabilityEffect.expired);
  });

  test('maybe later moves to playing now at the chosen time', () {
    const playing = Member(
      id: 'play',
      displayName: 'Play',
      defaultGame: 'Call of Duty',
    );
    final start = DateTime.utc(2026, 11, 8, 21);
    final stored = StoredCheckIn(
      userId: 'play',
      squadId: 'squad',
      kind: CheckInKind.availableLater,
      checkedAt: DateTime.utc(2026, 11, 8, 18),
      until: start,
    );
    WhoCanPlay at(DateTime clock) {
      return WhoCanPlay.group(
        board: AvailabilityBoard.compose(
          members: const [playing],
          squadId: 'squad',
          clock: clock,
          rows: [stored],
        ),
        members: const [playing],
      );
    }

    final waiting = at(start.subtract(const Duration(minutes: 1)));
    expect(waiting.maybeLater, hasLength(1));
    expect(waiting.availableCount, 0);

    final due = at(start);
    expect(due.playingNow, hasLength(1));
    expect(due.summary, '1 of 8 available');
    expect(
      whoStatusLine(due.playingNow.single, localOffset: Duration.zero),
      'Available since 9:00 PM · Call of Duty · checked in, not detected',
    );

    final ended = at(start.add(availableNowWindow));
    expect(ended.availableCount, 0);
    expect(
      whoStatusLine(ended.offline.single, localOffset: Duration.zero),
      'Last seen 10:00 PM',
    );
  });

  test('nobody checked in is the empty answer', () {
    final board = AvailabilityBoard.compose(
      members: const [spencer],
      squadId: 'squad',
      clock: clock,
      rows: const [],
    );
    final who = WhoCanPlay.group(board: board, members: const [spencer]);
    expect(who.nobodyCheckedIn, isTrue);
    expect(who.summary, '0 of 8 available');
    expect(who.offline.single.person.effect, AvailabilityEffect.notCheckedIn);
  });
}
