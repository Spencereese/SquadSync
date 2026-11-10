import 'package:squadsync/features/session/domain/squad_session.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

/// What "Add to calendar" hands the phone. Times stay UTC here. The calendar
/// app shows them in the phone's zone.
class SessionCalendarRequest {
  const SessionCalendarRequest({
    required this.title,
    required this.start,
    required this.end,
    required this.notes,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final String notes;
}

enum CalendarAddStatus { added, unavailable, denied }

/// This squad has no stored name. The notes use the owner's name.
String squadCalendarName(Squad squad) {
  for (final member in squad.members) {
    if (member.id != squad.ownerId) continue;
    final name = member.displayName.trim();
    if (name.isNotEmpty) return "$name's squad";
  }
  return 'SquadSync';
}

/// Title is the game. End is the duration, or the same three-hour window the
/// list uses when no duration was set. The squad name is always in the notes.
SessionCalendarRequest sessionCalendarRequest({
  required SquadSession session,
  required String squadName,
}) {
  final window = session.duration ?? const Duration(hours: 3);
  final extra = session.note?.trim() ?? '';
  final notes = extra.isEmpty ? squadName : '$squadName\n$extra';
  return SessionCalendarRequest(
    title: session.game,
    start: session.startsAt,
    end: session.startsAt.add(window),
    notes: notes,
  );
}

String calendarAddMessage(CalendarAddStatus status) {
  switch (status) {
    case CalendarAddStatus.added:
      return 'Added to your calendar.';
    case CalendarAddStatus.unavailable:
      return "The calendar isn't available on this phone.";
    case CalendarAddStatus.denied:
      return 'Calendar permission was denied.';
  }
}
