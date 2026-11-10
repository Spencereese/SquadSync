import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/features/availability/domain/availability_board.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
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

StoredCheckIn _row({
  required CheckInKind kind,
  required DateTime checkedAt,
  DateTime? until,
  String userId = 'spencer',
  String squadId = 'squad',
}) {
  return StoredCheckIn(
    userId: userId,
    squadId: squadId,
    kind: kind,
    checkedAt: checkedAt,
    until: until,
  );
}

void main() {
  final start = DateTime.utc(2026, 11, 8, 15);

  test('available now expires on the clock and stops counting', () {
    final row = _row(
      kind: CheckInKind.availableNow,
      checkedAt: start,
      until: start.add(availableNowWindow),
    );
    final fresh = AvailabilityBoard.compose(
      members: _squad().members,
      rows: [row],
      squadId: 'squad',
      clock: start.add(const Duration(minutes: 59, seconds: 59)),
    );
    expect(fresh.availableNowCount, 1);
    expect(fresh.person('spencer')!.effect, AvailabilityEffect.availableNow);

    final due = AvailabilityBoard.compose(
      members: _squad().members,
      rows: [row],
      squadId: 'squad',
      clock: start.add(availableNowWindow),
    );
    expect(due.availableNowCount, 0);
    expect(due.person('spencer')!.effect, AvailabilityEffect.expired);
    expect(due.person('friend')!.effect, AvailabilityEffect.notCheckedIn);
    expect(row.kind, CheckInKind.availableNow);
  });

  test('a due later check-in becomes available for 60 minutes', () {
    final until = start.add(const Duration(hours: 4));
    final row = _row(
      kind: CheckInKind.availableLater,
      checkedAt: start,
      until: until,
    );
    final waiting = AvailabilityBoard.compose(
      members: _squad().members,
      rows: [row],
      squadId: 'squad',
      clock: until.subtract(const Duration(seconds: 1)),
    );
    expect(waiting.laterCount, 1);
    expect(waiting.availableNowCount, 0);
    expect(
      waiting.person('spencer')!.effect,
      AvailabilityEffect.availableLater,
    );

    final due = AvailabilityBoard.compose(
      members: _squad().members,
      rows: [row],
      squadId: 'squad',
      clock: until,
    );
    expect(due.laterCount, 0);
    expect(due.availableNowCount, 1);
    expect(due.person('spencer')!.effect, AvailabilityEffect.availableNow);
    expect(row.kind, CheckInKind.availableLater);

    final ended = AvailabilityBoard.compose(
      members: _squad().members,
      rows: [row],
      squadId: 'squad',
      clock: until.add(availableNowWindow),
    );
    expect(ended.availableNowCount, 0);
    expect(ended.person('spencer')!.effect, AvailabilityEffect.expired);
  });

  test('unavailable is not available, and not the same as missing', () {
    final row = _row(
      kind: CheckInKind.unavailable,
      checkedAt: start.subtract(const Duration(days: 2)),
    );
    final board = AvailabilityBoard.compose(
      members: _squad().members,
      rows: [row],
      squadId: 'squad',
      clock: start,
    );
    expect(board.person('spencer')!.effect, AvailabilityEffect.unavailable);
    expect(board.person('friend')!.effect, AvailabilityEffect.notCheckedIn);
    expect(board.availableNowCount, 0);
    expect(
      availabilitySentence(
        board.person('spencer')!,
        localOffset: Duration.zero,
      ),
      'Unavailable. Self check-in at Fri Nov 6, 3:00 PM.',
    );
    expect(
      availabilitySentence(board.person('friend')!, localOffset: Duration.zero),
      'Not checked in. This is not an unavailable mark.',
    );
  });

  test('clearing is a missing row, and a stale row can still expire', () {
    final row = _row(
      kind: CheckInKind.availableNow,
      checkedAt: start,
      until: start.add(availableNowWindow),
    );
    final cached = AvailabilityBoard.compose(
      members: _squad().members,
      rows: [row],
      squadId: 'squad',
      clock: start.add(const Duration(hours: 2)),
    );
    expect(cached.availableNowCount, 0);
    expect(cached.person('spencer')!.effect, AvailabilityEffect.expired);

    final cleared = AvailabilityBoard.compose(
      members: _squad().members,
      rows: const [],
      squadId: 'squad',
      clock: start,
    );
    expect(cleared.person('spencer')!.effect, AvailabilityEffect.notCheckedIn);
    expect(cleared.person('spencer')!.checkIn, isNull);
  });

  test('another squad and a non-member stay off the board', () {
    final board = AvailabilityBoard.compose(
      members: _squad().members,
      rows: [
        _row(
          kind: CheckInKind.availableNow,
          checkedAt: start,
          until: start.add(availableNowWindow),
          userId: 'outsider',
        ),
        _row(
          kind: CheckInKind.availableNow,
          checkedAt: start,
          until: start.add(availableNowWindow),
          squadId: 'other-squad',
        ),
      ],
      squadId: 'squad',
      clock: start,
    );
    expect(board.availableNowCount, 0);
    expect(board.person('spencer')!.effect, AvailabilityEffect.notCheckedIn);
  });

  test('later rejects the past, the next minute, and past 7 days', () {
    expect(
      rejectLater(start, start.add(const Duration(seconds: 30))),
      isNotNull,
    );
    expect(rejectLater(start, start.add(laterMinimumLead)), isNotNull);
    expect(
      rejectLater(
        start,
        start.add(laterMinimumLead).add(const Duration(seconds: 1)),
      ),
      isNull,
    );
    expect(rejectLater(start, start.add(laterMaximumLead)), isNull);
    expect(
      rejectLater(
        start,
        start.add(laterMaximumLead).add(const Duration(seconds: 1)),
      ),
      isNotNull,
    );
  });

  test('local display is the offset, and the stored instant stays UTC', () {
    final utc = DateTime.utc(2026, 11, 8, 20);
    expect(
      formatLocalDateTime(utc, const Duration(hours: -5)),
      'Sun Nov 8, 3:00 PM',
    );
    final picked = localSelectionToUtc(
      localDay: DateTime.utc(2026, 11, 8),
      hour12: 3,
      minute: 0,
      pm: true,
      localOffset: const Duration(hours: -5),
    );
    expect(picked, utc);
    expect(picked.isUtc, isTrue);

    final suggested = suggestLaterUtc(start, Duration.zero);
    expect(suggested, DateTime.utc(2026, 11, 8, 15, 5));
    expect(rejectLater(start, suggested), isNull);
  });
}
