/// How long "available now" stays current after the check-in instant.
/// The database stamps the same window. It is not extended by a refresh.
const Duration availableNowWindow = Duration(minutes: 60);

/// "Available later" must be strictly after this lead, and no further out
/// than [laterMaximumLead]. When that instant arrives the row expires.
/// It is not rewritten to "available now".
const Duration laterMinimumLead = Duration(minutes: 1);
const Duration laterMaximumLead = Duration(days: 7);

enum CheckInKind { availableNow, availableLater, unavailable }

/// What squadmates should believe at a clock instant.
/// [expired] is a check-in that no longer counts. It is not "available now"
/// and it is not the same as [notCheckedIn] or [unavailable].
enum AvailabilityEffect {
  availableNow,
  availableLater,
  unavailable,
  expired,
  notCheckedIn,
}

/// One stored check-in. Times are UTC. The phone displays them in local time.
class StoredCheckIn {
  StoredCheckIn({
    required this.userId,
    required this.squadId,
    required this.kind,
    required DateTime checkedAt,
    DateTime? until,
  }) : checkedAt = checkedAt.toUtc(),
       until = until?.toUtc() {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }
    if (squadId.trim().isEmpty) {
      throw ArgumentError.value(squadId, 'squadId', 'must not be empty');
    }
  }

  final String userId;
  final String squadId;
  final CheckInKind kind;
  final DateTime checkedAt;
  final DateTime? until;
}

/// What the person asked to save. The server, not the phone, stamps
/// [StoredCheckIn.checkedAt] and the "available now" deadline.
class CheckInDraft {
  const CheckInDraft.now() : kind = CheckInKind.availableNow, until = null;

  const CheckInDraft.later(DateTime this.until)
    : kind = CheckInKind.availableLater;

  const CheckInDraft.unavailable()
    : kind = CheckInKind.unavailable,
      until = null;

  final CheckInKind kind;
  final DateTime? until;
}

/// Clock the board reads. Tests advance a manual one. The device clock
/// does not decide that someone is available; it only classifies a stored row.
abstract class SquadClock {
  DateTime now();
}

class SystemSquadClock implements SquadClock {
  const SystemSquadClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

class ManualSquadClock implements SquadClock {
  ManualSquadClock(DateTime initial) : _now = initial.toUtc();

  DateTime _now;

  void set(DateTime next) => _now = next.toUtc();

  void advance(Duration by) => _now = _now.add(by);

  @override
  DateTime now() => _now;
}

/// Classifies [row] at [clock]. A missing row is [AvailabilityEffect.notCheckedIn].
/// An explicit unavailable stays unavailable. A passed "now" or "later"
/// instant is [AvailabilityEffect.expired], never available.
AvailabilityEffect effectAt(StoredCheckIn? row, DateTime clock) {
  if (row == null) return AvailabilityEffect.notCheckedIn;
  final at = clock.toUtc();
  switch (row.kind) {
    case CheckInKind.unavailable:
      return AvailabilityEffect.unavailable;
    case CheckInKind.availableNow:
    case CheckInKind.availableLater:
      final until = row.until;
      if (until == null || !at.isBefore(until.toUtc())) {
        return AvailabilityEffect.expired;
      }
      return row.kind == CheckInKind.availableNow
          ? AvailabilityEffect.availableNow
          : AvailabilityEffect.availableLater;
  }
}

bool countsAsAvailableNow(AvailabilityEffect effect) =>
    effect == AvailabilityEffect.availableNow;

/// Null when [until] is a valid later instant. The message is the failure,
/// and nothing should be saved when it is non-null.
String? rejectLater(DateTime clock, DateTime until) {
  final at = clock.toUtc();
  final end = until.toUtc();
  if (!end.isAfter(at.add(laterMinimumLead))) {
    return 'Pick a time at least a minute from now. Nothing was saved.';
  }
  if (end.isAfter(at.add(laterMaximumLead))) {
    return 'Pick a time within the next 7 days. Nothing was saved.';
  }
  return null;
}

/// Next 5-minute local slot that is strictly more than a minute ahead.
DateTime suggestLaterUtc(DateTime clock, Duration localOffset) {
  final earliest = clock.toUtc().add(laterMinimumLead);
  final wall = earliest.add(localOffset);
  final roundedMinute = ((wall.minute + 4) ~/ 5) * 5;
  var local = DateTime.utc(wall.year, wall.month, wall.day, wall.hour);
  if (roundedMinute >= 60) {
    local = local.add(const Duration(hours: 1));
  } else {
    local = local.add(Duration(minutes: roundedMinute));
  }
  var utc = local.subtract(localOffset);
  if (!utc.isAfter(earliest)) {
    utc = utc.add(const Duration(minutes: 5));
  }
  return utc;
}

/// Wall-clock fields at [localOffset] become a UTC instant.
DateTime localSelectionToUtc({
  required DateTime localDay,
  required int hour12,
  required int minute,
  required bool pm,
  required Duration localOffset,
}) {
  if (hour12 < 1 || hour12 > 12) {
    throw ArgumentError.value(hour12, 'hour12', 'must be 1 through 12');
  }
  if (minute < 0 || minute > 59) {
    throw ArgumentError.value(minute, 'minute', 'must be 0 through 59');
  }
  final hour24 = (hour12 % 12) + (pm ? 12 : 0);
  final wall = DateTime.utc(
    localDay.year,
    localDay.month,
    localDay.day,
    hour24,
    minute,
  );
  return wall.subtract(localOffset);
}

String formatLocalDateTime(DateTime utc, Duration offset) {
  final local = utc.toUtc().add(offset);
  final hour24 = local.hour;
  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final suffix = hour24 >= 12 ? 'PM' : 'AM';
  final minute = local.minute.toString().padLeft(2, '0');
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final weekday = weekdays[local.weekday - 1];
  final month = months[local.month - 1];
  return '$weekday $month ${local.day}, $hour:$minute $suffix';
}

/// Date only, for a day picker. [utc] may already be a calendar day.
String formatLocalDay(DateTime utc, Duration offset) {
  final local = utc.toUtc().add(offset);
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[local.weekday - 1]} ${months[local.month - 1]} ${local.day}';
}
