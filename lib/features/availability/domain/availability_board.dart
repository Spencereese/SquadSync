import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/squad/domain/member.dart';

/// One person on the board. [effect] is computed from a clock.
/// A check-in, when present, is always that person's own.
class PersonAvailability {
  const PersonAvailability({
    required this.userId,
    required this.displayName,
    required this.effect,
    required this.checkIn,
  });

  final String userId;
  final String displayName;
  final AvailabilityEffect effect;
  final StoredCheckIn? checkIn;
}

/// Squad members only. Rows for another squad, or for someone who is not
/// a member, are left off. Nobody is available merely because they have a row
/// that has expired.
class AvailabilityBoard {
  AvailabilityBoard({required this.people, required this.evaluatedAt});

  factory AvailabilityBoard.compose({
    required List<Member> members,
    required List<StoredCheckIn> rows,
    required String squadId,
    required DateTime clock,
  }) {
    final byUser = <String, StoredCheckIn>{};
    for (final row in rows) {
      if (row.squadId != squadId) continue;
      if (!members.any((member) => member.id == row.userId)) continue;
      byUser[row.userId] = row;
    }
    return AvailabilityBoard(
      evaluatedAt: clock.toUtc(),
      people: [
        for (final member in members)
          PersonAvailability(
            userId: member.id,
            displayName: member.displayName,
            checkIn: byUser[member.id],
            effect: effectAt(byUser[member.id], clock),
          ),
      ],
    );
  }

  final List<PersonAvailability> people;
  final DateTime evaluatedAt;

  int get availableNowCount =>
      people.where((person) => countsAsAvailableNow(person.effect)).length;

  int get laterCount => people
      .where((person) => person.effect == AvailabilityEffect.availableLater)
      .length;

  PersonAvailability? person(String userId) {
    for (final person in people) {
      if (person.userId == userId) return person;
    }
    return null;
  }
}

/// Visible sentence for one person. Expired is never worded as available now.
String availabilitySentence(
  PersonAvailability person, {
  required Duration localOffset,
}) {
  final checkIn = person.checkIn;
  switch (person.effect) {
    case AvailabilityEffect.notCheckedIn:
      return 'Not checked in. This is not an unavailable mark.';
    case AvailabilityEffect.unavailable:
      final at = formatLocalDateTime(checkIn!.checkedAt, localOffset);
      return 'Unavailable. Self check-in at $at.';
    case AvailabilityEffect.availableNow:
      final at = formatLocalDateTime(checkIn!.checkedAt, localOffset);
      if (checkIn.kind == CheckInKind.availableLater) {
        final since = formatLocalDateTime(checkIn.until!, localOffset);
        return 'Available since $since. Self check-in at $at. '
            'The 60 minute window started then.';
      }
      final until = formatLocalDateTime(checkIn.until!, localOffset);
      return 'Available now until $until. Self check-in at $at.';
    case AvailabilityEffect.availableLater:
      final until = formatLocalDateTime(checkIn!.until!, localOffset);
      final at = formatLocalDateTime(checkIn.checkedAt, localOffset);
      return 'Available later at $until. Self check-in at $at. '
          'Becomes available then for 60 minutes.';
    case AvailabilityEffect.expired:
      final until = checkIn?.until;
      final when = until == null
          ? 'The check-in has ended'
          : 'Ended ${formatLocalDateTime(until, localOffset)}';
      return '$when. Not available now. Self check-in.';
  }
}
