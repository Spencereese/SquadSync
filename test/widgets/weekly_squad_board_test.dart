import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/weekly_squad_board.dart';
import 'package:squad_sync/widgets/weekly_squad_board.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: Colors.cyanAccent),
      ),
      home: Scaffold(body: child),
    );
  }

  const board = WeeklySquadBoard(
    nightsPlayed: 3,
    lockInRate: 0.67,
    commsAverage: 4.5,
    vibesAverage: 3.8,
    commsSampleSize: 2,
    vibesSampleSize: 3,
    rows: [
      WeeklySquadBoardRow(
        uid: 'u1',
        label: 'Sam',
        nightsPlayed: 3,
        lockInRate: 1,
        commsAverage: 4.5,
        vibesAverage: 4.0,
      ),
      WeeklySquadBoardRow(
        uid: 'u2',
        label: 'Kit',
        nightsPlayed: 1,
        lockInRate: 0,
        vibesAverage: 3.0,
      ),
    ],
  );

  testWidgets('renders nights, lock-in, comms, vibes, and member rows',
      (tester) async {
    await tester.pumpWidget(wrap(const WeeklySquadBoardView(board: board)));

    expect(find.byKey(const Key('weekly-squad-board')), findsOneWidget);
    expect(find.byKey(const Key('weekly-squad-nights')), findsOneWidget);
    expect(find.byKey(const Key('weekly-squad-lock-in')), findsOneWidget);
    expect(find.byKey(const Key('weekly-squad-comms')), findsOneWidget);
    expect(find.byKey(const Key('weekly-squad-vibes')), findsOneWidget);
    expect(find.text('NIGHTS'), findsOneWidget);
    expect(find.text('LOCK-IN'), findsOneWidget);
    expect(find.text('COMMS'), findsOneWidget);
    expect(find.text('VIBES'), findsOneWidget);
    expect(find.text('GUNNY'), findsOneWidget);
    expect(find.text('WINGMAN'), findsOneWidget);
    expect(find.byKey(const Key('weekly-squad-gunny')), findsOneWidget);
    expect(find.byKey(const Key('weekly-squad-wingman')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('3.8'), findsOneWidget);
    expect(find.byKey(const Key('weekly-squad-row-0')), findsOneWidget);
    expect(find.byKey(const Key('weekly-squad-row-1')), findsOneWidget);
    expect(find.text('Sam · 3n · 100% · C4.5 · V4.0'), findsOneWidget);
    expect(find.text('Kit · 1n · 0% · V3.0'), findsOneWidget);
    expect(find.byKey(const Key('weekly-squad-board-empty')), findsNothing);
  });

  testWidgets('empty board shows no nights this week', (tester) async {
    await tester.pumpWidget(
      wrap(const WeeklySquadBoardView(board: WeeklySquadBoard.empty())),
    );

    expect(find.byKey(const Key('weekly-squad-board-empty')), findsOneWidget);
    expect(find.text(kWeeklySquadBoardEmptyCopy), findsOneWidget);
    expect(find.text(kWeeklySquadBoardEmptyHint), findsOneWidget);
    expect(find.byKey(const Key('weekly-squad-board')), findsNothing);
  });

  testWidgets('error state offers retry instead of an empty board',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(
      wrap(
        WeeklySquadBoardView(
          board: const WeeklySquadBoard.empty(),
          errorMessage: kWeeklySquadBoardErrorCopy,
          onRetry: () {
            retried = true;
          },
        ),
      ),
    );

    expect(find.byKey(const Key('weekly-squad-board-error')), findsOneWidget);
    expect(find.text(kWeeklySquadBoardErrorCopy), findsOneWidget);
    expect(find.byKey(const Key('weekly-squad-board-empty')), findsNothing);
    await tester.tap(find.byKey(const Key('weekly-squad-board-retry')));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('You surface renders weekly board from snapshot', (tester) async {
    await tester.pumpWidget(wrap(const YouWeeklySquadBoard(board: board)));

    expect(find.byKey(const Key('you-weekly-squad-board')), findsOneWidget);
    expect(find.text('THIS WEEK'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('Sam · 3n · 100% · C4.5 · V4.0'), findsOneWidget);
  });
}
