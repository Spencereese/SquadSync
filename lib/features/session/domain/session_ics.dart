import 'package:squadsync/features/session/domain/squad_session.dart';

/// A calendar file for one session. Times are UTC (`Z`) because the session
/// is a timestamptz. The calendar app turns that instant into the phone's zone.
/// No calendar permission is required to share the text.
String sessionIcs(SquadSession session) {
  final start = _stamp(session.startsAt);
  final end = session.duration == null
      ? null
      : _stamp(session.startsAt.add(session.duration!));
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//SquadSync//session//EN',
    'CALSCALE:GREGORIAN',
    'BEGIN:VEVENT',
    'UID:${_escape(session.id)}@squadsync',
    'DTSTAMP:$start',
    'DTSTART:$start',
    if (end != null) 'DTEND:$end',
    'SUMMARY:${_escape(session.game)}',
    if (session.note != null && session.note!.trim().isNotEmpty)
      'DESCRIPTION:${_escape(session.note!.trim())}',
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  return '${lines.join('\r\n')}\r\n';
}

String _stamp(DateTime utc) {
  final z = utc.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${z.year}${two(z.month)}${two(z.day)}T${two(z.hour)}${two(z.minute)}${two(z.second)}Z';
}

/// RFC 5545 text escaping. Commas, semicolons, backslashes, and newlines.
String _escape(String value) {
  return value
      .replaceAll('\\', '\\\\')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\n', '\\n')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,');
}
