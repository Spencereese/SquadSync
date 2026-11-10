import 'package:squadsync/features/availability/domain/check_in.dart';

/// A scheduled session. [startsAt] is UTC. The phone only adds [localOffset]
/// when it draws the clock.
class SquadSession {
  SquadSession({
    required this.id,
    required this.squadId,
    required this.creatorId,
    required this.game,
    required DateTime startsAt,
    this.duration,
    this.note,
    DateTime? cancelledAt,
    this.rsvps = const [],
  }) : startsAt = startsAt.toUtc(),
       cancelledAt = cancelledAt?.toUtc();

  final String id;
  final String squadId;
  final String creatorId;
  final String game;
  final DateTime startsAt;
  final Duration? duration;
  final String? note;
  final DateTime? cancelledAt;
  final List<SessionRsvp> rsvps;

  int get inCount =>
      rsvps.where((row) => row.answer == SessionAnswer.rsvpIn).length;

  bool answerOf(String userId, SessionAnswer answer) {
    for (final row in rsvps) {
      if (row.userId == userId) return row.answer == answer;
    }
    return false;
  }
}

enum SessionAnswer { rsvpIn, maybe, out }

class SessionRsvp {
  const SessionRsvp({required this.userId, required this.answer});

  final String userId;
  final SessionAnswer answer;
}

/// Still on the list until it is cancelled or its window has passed.
/// No duration means the window is three hours after the start, long enough
/// to call the spot, then the row leaves the upcoming list.
bool sessionIsUpcoming(SquadSession session, DateTime clock) {
  if (session.cancelledAt != null) return false;
  final window = session.duration ?? const Duration(hours: 3);
  return clock.toUtc().isBefore(session.startsAt.add(window));
}

bool sessionCanCallSpot(SquadSession session, DateTime clock) {
  final now = clock.toUtc();
  return sessionIsUpcoming(session, now) && !now.isBefore(session.startsAt);
}

/// `Tonight 9:00 PM · 4 in`. Tonight is the same local calendar day.
String sessionSummary(
  SquadSession session, {
  required DateTime clock,
  required Duration localOffset,
}) {
  final when = sessionWhen(
    session.startsAt,
    clock: clock,
    localOffset: localOffset,
  );
  return '$when · ${session.inCount} in';
}

String sessionWhen(
  DateTime startsAt, {
  required DateTime clock,
  required Duration localOffset,
}) {
  final localStart = startsAt.toUtc().add(localOffset);
  final localNow = clock.toUtc().add(localOffset);
  final startDay = DateTime(localStart.year, localStart.month, localStart.day);
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final time = formatLocalClock(startsAt, localOffset);
  if (startDay == today) return 'Tonight $time';
  if (startDay == today.add(const Duration(days: 1))) return 'Tomorrow $time';
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${weekdays[localStart.weekday - 1]} $time';
}

/// Default start is 9:00 PM local, today if that is still ahead, otherwise tomorrow.
DateTime defaultSessionStart(DateTime clock, Duration localOffset) {
  final local = clock.toUtc().add(localOffset);
  var wall = DateTime.utc(local.year, local.month, local.day, 21);
  if (!wall.isAfter(local)) {
    wall = wall.add(const Duration(days: 1));
  }
  return wall.subtract(localOffset);
}
