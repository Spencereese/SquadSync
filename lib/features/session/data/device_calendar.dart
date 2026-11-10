import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/services.dart';
import 'package:squadsync/features/session/domain/session_calendar.dart';

/// Writes one session into the phone calendar. A missing plugin, a denied
/// permission, or no calendar app comes back as a status. It does not throw.
abstract class DeviceCalendar {
  Future<CalendarAddStatus> add(SessionCalendarRequest request);
}

class MemoryDeviceCalendar implements DeviceCalendar {
  SessionCalendarRequest? last;
  CalendarAddStatus next = CalendarAddStatus.added;
  Future<void>? hold;

  @override
  Future<CalendarAddStatus> add(SessionCalendarRequest request) async {
    last = request;
    final pending = hold;
    if (pending != null) await pending;
    return next;
  }
}

class Add2CalendarDevice implements DeviceCalendar {
  @override
  Future<CalendarAddStatus> add(SessionCalendarRequest request) async {
    try {
      final saved = await Add2Calendar.addEvent2Cal(
        Event(
          title: request.title,
          description: request.notes,
          startDate: request.start.toLocal(),
          endDate: request.end.toLocal(),
        ),
      );
      if (saved) return CalendarAddStatus.added;
      // The plugin returns false for a missing calendar, a denial, and a
      // cancel. It does not say which. The sentence covers the two failures.
      return CalendarAddStatus.denied;
    } on MissingPluginException {
      return CalendarAddStatus.unavailable;
    } on PlatformException catch (error) {
      final code = error.code.toLowerCase();
      final message = (error.message ?? '').toLowerCase();
      if (code.contains('permission') ||
          message.contains('permission') ||
          message.contains('denied')) {
        return CalendarAddStatus.denied;
      }
      return CalendarAddStatus.unavailable;
    } catch (_) {
      return CalendarAddStatus.unavailable;
    }
  }
}
