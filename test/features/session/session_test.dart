import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/session/data/session_repository.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/session/data/calendar_export.dart';
import 'package:squadsync/features/session/data/fake_session_repository.dart';
import 'package:squadsync/features/session/domain/session_ics.dart';
import 'package:squadsync/features/session/domain/squad_session.dart';
import 'package:squadsync/features/session/ui/session_list.dart';

SquadSession _session({
  DateTime? startsAt,
  List<SessionRsvp> rsvps = const [],
  String game = 'Halo',
  String? note,
}) {
  return SquadSession(
    id: 'session-1',
    squadId: 'squad',
    creatorId: 'spencer',
    game: game,
    startsAt: startsAt ?? DateTime.utc(2026, 11, 10, 21),
    note: note,
    rsvps: rsvps,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required FakeSessionRepository sessions,
  required MemoryCalendarExport calendar,
  required DateTime clock,
  Duration offset = Duration.zero,
  void Function(String game)? onCall,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(sessions),
        calendarExportProvider.overrideWithValue(calendar),
        squadClockProvider.overrideWithValue(ManualSquadClock(clock)),
        localOffsetProvider.overrideWithValue(offset),
        availabilityTickProvider.overrideWithValue(Duration.zero),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SessionList(
            squadId: 'squad',
            meId: 'spencer',
            ownerId: 'spencer',
            onCallSpot: onCall ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the summary is local and the calendar file stays in UTC', () {
    final session = SquadSession(
      id: 'session-1',
      squadId: 'squad',
      creatorId: 'spencer',
      game: 'Halo, Infinite; night',
      startsAt: DateTime.utc(2026, 11, 11, 3),
      duration: const Duration(minutes: 90),
      note: 'line1\nline2',
      rsvps: const [
        SessionRsvp(userId: 'a', answer: SessionAnswer.rsvpIn),
        SessionRsvp(userId: 'b', answer: SessionAnswer.rsvpIn),
        SessionRsvp(userId: 'c', answer: SessionAnswer.rsvpIn),
        SessionRsvp(userId: 'd', answer: SessionAnswer.rsvpIn),
      ],
    );
    expect(
      sessionSummary(
        session,
        clock: DateTime.utc(2026, 11, 11, 2),
        localOffset: const Duration(hours: -6),
      ),
      'Tonight 9:00 PM · 4 in',
    );
    final ics = sessionIcs(session);
    expect(ics, contains('DTSTART:20261111T030000Z'));
    expect(ics, contains('DTEND:20261111T043000Z'));
    expect(ics, contains('SUMMARY:Halo\\, Infinite\\; night'));
    expect(ics, contains('DESCRIPTION:line1\\nline2'));
    expect(ics, isNot(contains('TZID')));
  });

  testWidgets('who is on lists tonight and an RSVP updates the count', (
    tester,
  ) async {
    final sessions = FakeSessionRepository(
      enabled: true,
      sessions: [_session()],
    );
    await _pump(
      tester,
      sessions: sessions,
      calendar: MemoryCalendarExport(),
      clock: DateTime.utc(2026, 11, 10, 20),
    );
    expect(find.text('Tonight 9:00 PM · 0 in'), findsOneWidget);

    await tester.tap(find.byKey(const Key('session-in-session-1')));
    await tester.pumpAndSettle();
    expect(find.text('Tonight 9:00 PM · 1 in'), findsOneWidget);
    expect(find.byKey(const Key('session-call-session-1')), findsNothing);
  });

  testWidgets(
    'add to calendar shares the ics and the spot opens when it starts',
    (tester) async {
      final calendar = MemoryCalendarExport();
      String? called;
      final sessions = FakeSessionRepository(
        enabled: true,
        sessions: [
          _session(
            game: 'Halo, Infinite',
            note: 'bring mics',
            startsAt: DateTime.utc(2026, 11, 10, 21),
          ),
        ],
      );
      await _pump(
        tester,
        sessions: sessions,
        calendar: calendar,
        clock: DateTime.utc(2026, 11, 10, 21),
        onCall: (game) => called = game,
      );
      await tester.tap(find.byKey(const Key('session-calendar-session-1')));
      await tester.pumpAndSettle();
      expect(calendar.filename, 'squad-session.ics');
      expect(calendar.body, contains('DTSTART:20261110T210000Z'));
      expect(calendar.body, contains('SUMMARY:Halo\\, Infinite'));

      await tester.tap(find.byKey(const Key('session-call-session-1')));
      await tester.pumpAndSettle();
      expect(called, 'Halo, Infinite');
    },
  );

  testWidgets('cancel asks first and only the creator or owner sees it', (
    tester,
  ) async {
    final sessions = FakeSessionRepository(
      enabled: true,
      userId: 'friend',
      ownerId: 'spencer',
      sessions: [
        SquadSession(
          id: 'session-1',
          squadId: 'squad',
          creatorId: 'spencer',
          game: 'Halo',
          startsAt: DateTime.utc(2026, 11, 10, 21),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(sessions),
          calendarExportProvider.overrideWithValue(MemoryCalendarExport()),
          squadClockProvider.overrideWithValue(
            ManualSquadClock(DateTime.utc(2026, 11, 10, 20)),
          ),
          localOffsetProvider.overrideWithValue(Duration.zero),
          availabilityTickProvider.overrideWithValue(Duration.zero),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SessionList(
              squadId: 'squad',
              meId: 'friend',
              ownerId: 'spencer',
              onCallSpot: _ignore,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-cancel-session-1')), findsNothing);

    sessions.userId = 'spencer';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(sessions),
          calendarExportProvider.overrideWithValue(MemoryCalendarExport()),
          squadClockProvider.overrideWithValue(
            ManualSquadClock(DateTime.utc(2026, 11, 10, 20)),
          ),
          localOffsetProvider.overrideWithValue(Duration.zero),
          availabilityTickProvider.overrideWithValue(Duration.zero),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SessionList(
              squadId: 'squad',
              meId: 'spencer',
              ownerId: 'spencer',
              onCallSpot: _ignore,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-cancel-session-1')));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this session?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('session-cancel-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('No sessions scheduled.'), findsOneWidget);
  });

  testWidgets('schedule uses tonight and edit asks before it saves', (
    tester,
  ) async {
    final sessions = FakeSessionRepository(
      enabled: true,
      sessions: [_session()],
    );
    await _pump(
      tester,
      sessions: sessions,
      calendar: MemoryCalendarExport(),
      clock: DateTime.utc(2026, 11, 10, 20),
    );
    await tester.tap(find.byKey(const Key('session-schedule')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-when')), findsOneWidget);
    expect(find.text('Tonight 9:00 PM'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('session-game')), 'Halo');
    await tester.tap(find.byKey(const Key('session-save')));
    await tester.pumpAndSettle();
    expect(sessions.sessions.length, 2);

    await tester.tap(find.byKey(const Key('session-edit-session-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('session-game')), 'MCC');
    await tester.tap(find.byKey(const Key('session-save')));
    await tester.pumpAndSettle();
    expect(find.text('Save these changes?'), findsOneWidget);
    expect(sessions.sessions.first.game, 'Halo');
    await tester.tap(find.byKey(const Key('session-edit-confirm')));
    await tester.pumpAndSettle();
    expect(sessions.sessions.first.game, 'MCC');
  });

  testWidgets('a missing sessions table stays honest', (tester) async {
    await _pump(
      tester,
      sessions: FakeSessionRepository(),
      calendar: MemoryCalendarExport(),
      clock: DateTime.utc(2026, 11, 10, 20),
    );
    expect(find.text('Sessions are not set up yet.'), findsOneWidget);
    expect(find.byKey(const Key('session-schedule')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('an RSVP for another session does not reload this list', () {
    expect(sessionChangeReloads(const SessionChange.squad(), const []), isTrue);
    expect(
      sessionChangeReloads(SessionChange.maybe('session-1'), const [
        'session-1',
      ]),
      isTrue,
    );
    expect(
      sessionChangeReloads(SessionChange.maybe('other'), const ['session-1']),
      isFalse,
    );
    expect(sessionChangeReloads(SessionChange.maybe(null), const []), isTrue);
  });

  testWidgets('a failed session load is an error and not not set up', (
    tester,
  ) async {
    final sessions = FakeSessionRepository(enabled: true)
      ..loadError = const RepositoryFailure('sessions could not be loaded');
    await _pump(
      tester,
      sessions: sessions,
      calendar: MemoryCalendarExport(),
      clock: DateTime.utc(2026, 11, 10, 20),
    );
    expect(find.byKey(const Key('session-error')), findsOneWidget);
    expect(find.text('Sessions are not set up yet.'), findsNothing);
    expect(find.text('No sessions scheduled.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resume reloads the session list', (tester) async {
    final sessions = FakeSessionRepository(
      enabled: true,
      sessions: [_session()],
    );
    await _pump(
      tester,
      sessions: sessions,
      calendar: MemoryCalendarExport(),
      clock: DateTime.utc(2026, 11, 10, 20),
    );
    final loads = sessions.loads;
    final context = tester.element(find.byType(SessionList));
    ProviderScope.containerOf(context)
        .read(sessionRefreshProvider.notifier)
        .bump();
    await tester.pumpAndSettle();
    expect(sessions.loads, loads + 1);
  });
}

void _ignore(String game) {}
