import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/screens/performance_stats_screen.dart';
import 'package:squad_sync/screens/stats_dashboard_data.dart';

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
    expect(find.text('COMMUNITY'), findsOneWidget);
    expect(find.byKey(const Key('stats-community')), findsOneWidget);
    expect(find.text('Complaints'), findsOneWidget);
    expect(find.text('Bans'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Warzone'), findsOneWidget);
    expect(find.text('4.0★'), findsOneWidget);
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
    expect(
      find.text('Join a lobby to track wins and losses'),
      findsOneWidget,
    );
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('No ratings yet'), findsNWidgets(2));
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
