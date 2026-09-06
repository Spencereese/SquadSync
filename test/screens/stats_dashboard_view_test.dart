import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/screens/performance_stats_screen.dart';
import 'package:squad_sync/screens/stats_dashboard_data.dart';
import 'package:squad_sync/services/session_rating_machine.dart';
import 'package:squad_sync/services/weekly_squad_board.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: Colors.cyanAccent),
      ),
      home: Scaffold(body: child),
    );
  }

  testWidgets('renders streak bars, win/loss pie, and rating tiles',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const snapshot = StatsDashboardSnapshot(
      memberStreaks: [
        SquadMemberStreak(id: 'u1', label: 'Sam', streak: 4),
        SquadMemberStreak(id: 'u2', label: 'Kit', streak: 1),
      ],
      winLoss: WinLossSummary(wins: 8, losses: 2),
      ratings: RatingSummary(
        dailyAverage: 4.5,
        allTimeAverage: 3.8,
        dailySampleSize: 2,
        allTimeSampleSize: 10,
        vibesAverage: 5,
        commsAverage: 4,
        gunnyAverage: 3,
        wingmanAverage: 2,
        vibesSampleSize: 1,
        commsSampleSize: 1,
        gunnySampleSize: 1,
        wingmanSampleSize: 1,
      ),
      lastFiveRatedSessions: [
        SessionRatingState(
          phase: SessionRatingPhase.rated,
          stars: 5,
          vibes: 5,
          comms: 4,
          gunny: 3,
          wingman: 2,
          comment: 'clutch',
          gameName: 'Warzone',
          result: 'win',
        ),
        SessionRatingState(
          phase: SessionRatingPhase.rated,
          stars: 2,
          gameName: 'BF6',
          result: 'loss',
        ),
      ],
      weeklyBoard: WeeklySquadBoard(
        nightsPlayed: 3,
        lockInRate: 0.67,
        commsAverage: 4.5,
        vibesAverage: 3.8,
        gunnyAverage: 3.0,
        wingmanAverage: 2.0,
        rows: [
          WeeklySquadBoardRow(
            uid: 'u1',
            label: 'Sam',
            nightsPlayed: 3,
            lockInRate: 1,
            commsAverage: 4.5,
            vibesAverage: 4.0,
          ),
        ],
      ),
      community: CommunitySummary(
        complaints: 2,
        bans: 1,
        friends: 4,
        gameAverages: [
          GameRatingAverage(gameName: 'Warzone', average: 4.0, sampleSize: 2),
        ],
      ),
    );

    await tester.pumpWidget(wrap(const StatsDashboardView(snapshot: snapshot)));
    await tester.pump();

    expect(find.text('SQUAD STREAKS'), findsOneWidget);
    expect(find.text('SQUAD WINS / LOSSES'), findsOneWidget);
    expect(find.text('AVERAGE RATINGS'), findsOneWidget);
    expect(find.text('THIS WEEK'), findsOneWidget);
    expect(find.byKey(const Key('stats-weekly-board')), findsOneWidget);
    expect(find.text('NIGHTS'), findsOneWidget);
    expect(find.text('LOCK-IN'), findsOneWidget);
    expect(find.text('COMMS'), findsWidgets);
    expect(find.text('VIBES'), findsWidgets);
    expect(find.text('GUNNY'), findsWidgets);
    expect(find.text('WINGMAN'), findsWidgets);
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('Sam · 3n · 100% · C4.5 · V4.0'), findsOneWidget);
    expect(find.text('LAST 5 SESSIONS'), findsOneWidget);
    expect(find.byKey(const Key('stats-last-five')), findsOneWidget);
    expect(find.text('5★ · Warzone · Win'), findsOneWidget);
    expect(find.text('V5 · C4 · G3 · W2'), findsOneWidget);
    expect(find.text('clutch'), findsOneWidget);
    expect(find.text('2★ · BF6 · Loss'), findsOneWidget);
    expect(find.byKey(const Key('stats-rating-vibes')), findsOneWidget);
    expect(find.byKey(const Key('stats-rating-comms')), findsOneWidget);
    expect(find.byKey(const Key('stats-rating-gunny')), findsOneWidget);
    expect(find.byKey(const Key('stats-rating-wingman')), findsOneWidget);
    expect(find.text('COMMUNITY'), findsOneWidget);
    expect(find.byKey(const Key('stats-community')), findsOneWidget);
    expect(find.text('Complaints'), findsOneWidget);
    expect(find.text('Bans'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Warzone'), findsWidgets);
    expect(find.text('4.0★'), findsWidgets);
    expect(find.byKey(const Key('stats-streaks-chart')), findsOneWidget);
    expect(find.byKey(const Key('stats-win-loss-chart')), findsOneWidget);
    expect(find.byKey(const Key('stats-ratings')), findsOneWidget);
    expect(find.text('Sam'), findsWidgets);
    expect(find.text('Wins 8'), findsOneWidget);
    expect(find.text('Losses 2'), findsOneWidget);
    expect(find.text('80% win rate'), findsOneWidget);
    expect(find.text('DAILY'), findsOneWidget);
    expect(find.text('ALL-TIME'), findsOneWidget);
    expect(find.text('4.5★'), findsOneWidget);
    expect(find.text('3.8★'), findsOneWidget);
  });

  testWidgets('stats last-5 clip tap opens existing media', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SessionClip? opened;
    final withClip = attachClipToRatedSession(
      const SessionRatingState(
        phase: SessionRatingPhase.rated,
        stars: 5,
        gameName: 'Warzone',
        result: 'win',
      ),
      reduceSessionClip(
        current: SessionClip.empty,
        event: SessionClipEvent.attach,
        clipId: 'clip-stats',
        fileName: 'ace.mp4',
        videoUrl: '/tmp/ace.mp4',
      ),
    );
    final snapshot = StatsDashboardSnapshot(
      memberStreaks: const [],
      winLoss: const WinLossSummary(wins: 1),
      ratings: const RatingSummary(allTimeAverage: 5, allTimeSampleSize: 1),
      lastFiveRatedSessions: [withClip],
    );

    await tester.pumpWidget(
      wrap(
        StatsDashboardView(
          snapshot: snapshot,
          onOpenClip: (context, clip) async {
            opened = clip;
            return true;
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('stats-last-five')), findsOneWidget);
    expect(find.byKey(const Key('last-five-rated-open-0')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('last-five-rated-open-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('last-five-rated-open-0')));
    await tester.pump();

    expect(opened?.clipId, 'clip-stats');
    expect(opened?.videoUrl, '/tmp/ace.mp4');
  });

  testWidgets('shows empty hints when snapshot has no data', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const snapshot = StatsDashboardSnapshot(
      memberStreaks: [],
      winLoss: WinLossSummary(),
      ratings: RatingSummary(),
    );

    await tester.pumpWidget(wrap(const StatsDashboardView(snapshot: snapshot)));
    await tester.pump();

    expect(find.text('No squad members to chart yet'), findsOneWidget);
    expect(find.text(kStreaksEmptyHint), findsOneWidget);
    expect(
      find.text('Join a lobby to track wins and losses'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('stats-ratings-empty')), findsOneWidget);
    expect(find.text(kRatingsEmptyHint), findsOneWidget);
    expect(find.text('LAST 5 SESSIONS'), findsOneWidget);
    expect(find.text(kLastFiveRatedEmptyCopy), findsOneWidget);
    expect(find.text(kLastFiveRatedEmptyHint), findsOneWidget);
    expect(find.text('THIS WEEK'), findsOneWidget);
    expect(find.text(kWeeklySquadBoardEmptyCopy), findsOneWidget);
    expect(find.text(kWeeklySquadBoardEmptyHint), findsOneWidget);
  });

  testWidgets('error view shows retry without painting empty W/L',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var retried = false;
    await tester.pumpWidget(
      wrap(
        StatsDashboardErrorView(
          error: Exception('remote history down'),
          onRetry: () {
            retried = true;
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('stats-error')), findsOneWidget);
    expect(find.text(kStatsLoadErrorTitle), findsOneWidget);
    expect(find.text(kStatsLoadErrorBody), findsOneWidget);
    expect(find.byKey(const Key('stats-error-retry')), findsOneWidget);
    expect(find.text('No matches recorded for this lobby yet'), findsNothing);

    await tester.tap(find.byKey(const Key('stats-error-retry')));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('titles W/L as All lobbies when aggregating multiple lobbies',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const snapshot = StatsDashboardSnapshot(
      memberStreaks: [],
      winLoss: WinLossSummary(wins: 3, losses: 1),
      ratings: RatingSummary(),
      statsLobbyIds: ['a', 'b'],
    );

    await tester.pumpWidget(wrap(const StatsDashboardView(snapshot: snapshot)));
    await tester.pump();

    expect(find.text('ALL LOBBIES WINS / LOSSES'), findsOneWidget);
    expect(find.text('SQUAD WINS / LOSSES'), findsNothing);
    expect(find.text('Wins 3'), findsOneWidget);
  });

  testWidgets('empty W/L with a queried lobby offers record/seed actions',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var seeded = false;
    const snapshot = StatsDashboardSnapshot(
      memberStreaks: [],
      winLoss: WinLossSummary(),
      ratings: RatingSummary(),
      statsLobbyIds: ['lobby-1'],
    );

    await tester.pumpWidget(
      wrap(
        StatsDashboardView(
          snapshot: snapshot,
          onRecordWin: () async {},
          onRecordLoss: () async {},
          onSeedSmokeHistory: () async {
            seeded = true;
          },
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('No matches recorded for this lobby yet'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('stats-record-win')), findsOneWidget);
    expect(find.byKey(const Key('stats-record-loss')), findsOneWidget);
    expect(find.byKey(const Key('stats-seed-match-history')), findsOneWidget);

    await tester.tap(find.byKey(const Key('stats-seed-match-history')));
    await tester.pump();
    expect(seeded, isTrue);
  });
}
