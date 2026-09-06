import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/session_rating_machine.dart';
import 'package:squad_sync/widgets/last_five_rated_sessions.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: Colors.cyanAccent),
      ),
      home: Scaffold(body: child),
    );
  }

  SessionRatingState rated({
    required int stars,
    String? game,
    String? result,
    DateTime? at,
  }) {
    return reduceSessionRating(
      current: SessionRatingState.unrated,
      event: SessionRatingEvent.rate,
      stars: stars,
      gameName: game,
      result: result,
      ratedAt: at,
    );
  }

  testWidgets('lists last-5 labels newest-first', (tester) async {
    final sessions = [
      rated(
        stars: 5,
        game: 'Warzone',
        result: 'win',
        at: DateTime.utc(2026, 9, 3),
      ),
      rated(
        stars: 2,
        game: 'BF6',
        result: 'loss',
        at: DateTime.utc(2026, 9, 1),
      ),
    ];

    await tester.pumpWidget(
      wrap(LastFiveRatedSessionsList(sessions: sessions)),
    );

    expect(find.byKey(const Key('last-five-rated-sessions')), findsOneWidget);
    expect(find.byKey(const Key('last-five-rated-row-0')), findsOneWidget);
    expect(find.byKey(const Key('last-five-rated-row-1')), findsOneWidget);
    expect(find.text('5★ · Warzone · Win · Sep 3'), findsOneWidget);
    expect(find.text('2★ · BF6 · Loss · Sep 1'), findsOneWidget);
    expect(find.byKey(const Key('last-five-rated-empty')), findsNothing);
  });

  testWidgets('empty list shows no rated sessions yet', (tester) async {
    await tester.pumpWidget(
      wrap(const LastFiveRatedSessionsList(sessions: [])),
    );

    expect(find.byKey(const Key('last-five-rated-empty')), findsOneWidget);
    expect(find.text(kLastFiveRatedEmptyCopy), findsOneWidget);
    expect(find.text(kLastFiveRatedEmptyHint), findsOneWidget);
    expect(find.byKey(const Key('last-five-rated-sessions')), findsNothing);
  });

  testWidgets('row shows Vibes/Comms/Gunny/Wingman + notes from persisted JSON',
      (tester) async {
    final session = reduceSessionRating(
      current: SessionRatingState.unrated,
      event: SessionRatingEvent.rate,
      vibes: 5,
      comms: 4,
      gunny: 3,
      wingman: 2,
      comment: 'clutch',
      gameName: 'Warzone',
      result: 'win',
      ratedAt: DateTime.utc(2026, 9, 5),
    );

    await tester.pumpWidget(
      wrap(LastFiveRatedSessionsList(sessions: [session])),
    );

    expect(find.text('V5 · C4 · G3 · W2'), findsOneWidget);
    expect(find.byKey(const Key('last-five-rated-cats-0')), findsOneWidget);
    expect(find.text('clutch'), findsOneWidget);
    expect(find.byKey(const Key('last-five-rated-notes-0')), findsOneWidget);
  });

  testWidgets('loading does not paint the empty list', (tester) async {
    await tester.pumpWidget(
      wrap(
        const LastFiveRatedSessionsList(
          sessions: [],
          isLoading: true,
        ),
      ),
    );

    expect(find.byKey(const Key('last-five-rated-loading')), findsOneWidget);
    expect(find.text(kLastFiveRatedLoadingCopy), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('last-five-rated-empty')), findsNothing);
    expect(find.byKey(const Key('last-five-rated-error')), findsNothing);
  });

  testWidgets('error state offers retry instead of an empty list',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(
      wrap(
        LastFiveRatedSessionsList(
          sessions: const [],
          errorMessage: kYouSessionHistoryErrorCopy,
          onRetry: () {
            retried = true;
          },
        ),
      ),
    );

    expect(find.byKey(const Key('last-five-rated-error')), findsOneWidget);
    expect(find.text(kYouSessionHistoryErrorCopy), findsOneWidget);
    expect(find.text(kStatsLoadErrorBody), findsOneWidget);
    expect(find.byKey(const Key('last-five-rated-empty')), findsNothing);
    await tester.tap(find.byKey(const Key('last-five-rated-retry')));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('error detail is not painted as an empty list', (tester) async {
    await tester.pumpWidget(
      wrap(
        const LastFiveRatedSessionsList(
          sessions: [],
          errorMessage: kYouSessionHistoryErrorCopy,
          errorDetail: 'offline',
        ),
      ),
    );

    expect(find.byKey(const Key('last-five-rated-error')), findsOneWidget);
    expect(find.byKey(const Key('last-five-rated-error-detail')), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);
    expect(find.byKey(const Key('last-five-rated-empty')), findsNothing);
    expect(find.byKey(const Key('last-five-rated-retry')), findsNothing);
  });

  testWidgets('You surface renders last-5 from match_history notes',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        YouLastFiveRatedSessions(
          sessions: [
            rated(
              stars: 4,
              game: 'Warzone',
              result: 'win',
              at: DateTime.utc(2026, 9, 3),
            ),
          ],
        ),
      ),
    );

    expect(find.byKey(const Key('you-last-five')), findsOneWidget);
    expect(find.text('LAST 5 SESSIONS'), findsOneWidget);
    expect(find.text('4★ · Warzone · Win · Sep 3'), findsOneWidget);
  });

  testWidgets('You surface error offers retry instead of empty last-5',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(
      wrap(
        YouLastFiveRatedSessions(
          sessions: const [],
          errorMessage: kYouSessionHistoryErrorCopy,
          errorDetail: 'offline',
          onRetry: () {
            retried = true;
          },
        ),
      ),
    );

    expect(find.byKey(const Key('you-last-five')), findsOneWidget);
    expect(find.byKey(const Key('last-five-rated-error')), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);
    expect(find.byKey(const Key('last-five-rated-empty')), findsNothing);
    await tester.tap(find.byKey(const Key('last-five-rated-retry')));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('You / last-5 row shows clip marker when notes have a clip',
      (tester) async {
    final withClip = attachClipToRatedSession(
      rated(
        stars: 5,
        game: 'Warzone',
        result: 'win',
        at: DateTime.utc(2026, 9, 5),
      ),
      reduceSessionClip(
        current: SessionClip.empty,
        event: SessionClipEvent.attach,
        clipId: 'clip-1',
        fileName: 'clutch.mp4',
      ),
    );

    await tester.pumpWidget(
      wrap(LastFiveRatedSessionsList(sessions: [withClip])),
    );

    expect(find.text('5★ · Warzone · Win · Sep 5 · Clip'), findsOneWidget);
    expect(find.byKey(const Key('last-five-rated-clip-0')), findsOneWidget);
    expect(find.byIcon(Icons.movie), findsOneWidget);
    expect(find.byKey(const Key('last-five-rated-open-0')), findsOneWidget);
  });

  testWidgets('tapping an openable last-5 clip opens existing media',
      (tester) async {
    SessionClip? opened;
    final withClip = attachClipToRatedSession(
      rated(
        stars: 5,
        game: 'Warzone',
        result: 'win',
        at: DateTime.utc(2026, 9, 5),
      ),
      reduceSessionClip(
        current: SessionClip.empty,
        event: SessionClipEvent.attach,
        clipId: 'clip-1',
        fileName: 'clutch.mp4',
        videoUrl: '/tmp/clutch.mp4',
      ),
    );

    await tester.pumpWidget(
      wrap(
        LastFiveRatedSessionsList(
          sessions: [withClip],
          onOpenClip: (context, clip) async {
            opened = clip;
            return true;
          },
        ),
      ),
    );

    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    await tester.tap(find.byKey(const Key('last-five-rated-open-0')));
    await tester.pump();

    expect(opened?.clipId, 'clip-1');
    expect(opened?.videoUrl, '/tmp/clutch.mp4');
    expect(opened?.fileName, 'clutch.mp4');
  });

  testWidgets('tapping a clip without video_url shows unavailable',
      (tester) async {
    var openCalls = 0;
    final withClip = attachClipToRatedSession(
      rated(
        stars: 4,
        game: 'Warzone',
        result: 'win',
        at: DateTime.utc(2026, 9, 5),
      ),
      reduceSessionClip(
        current: SessionClip.empty,
        event: SessionClipEvent.attach,
        clipId: 'clip-1',
      ),
    );

    await tester.pumpWidget(
      wrap(
        LastFiveRatedSessionsList(
          sessions: [withClip],
          onOpenClip: (context, clip) async {
            openCalls++;
            return false;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('last-five-rated-open-0')));
    await tester.pump();

    expect(openCalls, 1);
    expect(find.byKey(const Key('session-clip-unavailable')), findsOneWidget);
    expect(find.text('Clip media is unavailable'), findsOneWidget);
  });

  testWidgets('You surface tap opens the attached clip', (tester) async {
    SessionClip? opened;
    final withClip = attachClipToRatedSession(
      rated(
        stars: 4,
        game: 'Warzone',
        result: 'win',
        at: DateTime.utc(2026, 9, 3),
      ),
      reduceSessionClip(
        current: SessionClip.empty,
        event: SessionClipEvent.attach,
        clipId: 'clip-you',
        videoUrl: 'https://cdn.example/you.mp4',
      ),
    );

    await tester.pumpWidget(
      wrap(
        YouLastFiveRatedSessions(
          sessions: [withClip],
          onOpenClip: (context, clip) async {
            opened = clip;
            return true;
          },
        ),
      ),
    );

    expect(find.byKey(const Key('you-last-five')), findsOneWidget);
    await tester.tap(find.byKey(const Key('last-five-rated-open-0')));
    await tester.pump();
    expect(opened?.clipId, 'clip-you');
    expect(opened?.videoUrl, 'https://cdn.example/you.mp4');
  });

  testWidgets('rows without a clip are not an open control', (tester) async {
    await tester.pumpWidget(
      wrap(
        LastFiveRatedSessionsList(
          sessions: [
            rated(
              stars: 5,
              game: 'Warzone',
              result: 'win',
              at: DateTime.utc(2026, 9, 3),
            ),
          ],
        ),
      ),
    );

    expect(find.byKey(const Key('last-five-rated-open-0')), findsNothing);
    expect(find.byKey(const Key('last-five-rated-clip-0')), findsNothing);
  });
}
