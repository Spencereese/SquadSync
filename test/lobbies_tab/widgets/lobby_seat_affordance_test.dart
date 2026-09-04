import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/lobbies_tab/widgets/lobby_seat_affordance.dart';
import 'package:squad_sync/services/lobby_seat_status.dart';
import 'package:squad_sync/services/matchmaking_queue_machine.dart';
import 'package:squad_sync/services/peacock_assignment_machine.dart';

LobbySeatStatus _status({
  LobbySeatChipKind chip = LobbySeatChipKind.peacock,
  int? seatIndex = 1,
  bool offerPending = true,
  Duration? lockRemaining,
}) {
  return LobbySeatStatus(
    chip: chip,
    seatIndex: seatIndex,
    offerPending: offerPending,
    lockRemaining: lockRemaining,
  );
}

void main() {
  testWidgets('chip shows seated / peacock / lock mm:ss', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              LobbySeatStatusChip(
                status: _status(
                  chip: LobbySeatChipKind.seated,
                  offerPending: false,
                  seatIndex: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('lobby-seat-status-chip')), findsOneWidget);
    expect(find.text('seated'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LobbySeatStatusChip(
            status: _status(chip: LobbySeatChipKind.peacock),
          ),
        ),
      ),
    );
    expect(find.text('peacock'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LobbySeatStatusChip(
            status: _status(
              chip: LobbySeatChipKind.lock,
              lockRemaining: const Duration(minutes: 3, seconds: 5),
            ),
          ),
        ),
      ),
    );
    expect(find.text('lock 03:05'), findsOneWidget);
  });

  testWidgets('offer banner shows Claim seat N with Accept / Decline',
      (tester) async {
    var accepted = false;
    var declined = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LobbySeatOfferBanner(
            status: _status(seatIndex: 2),
            onAccept: () => accepted = true,
            onDecline: () => declined = true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('lobby-seat-offer-banner')), findsOneWidget);
    expect(find.text('Claim seat 3'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lobby-seat-offer-accept')));
    await tester.pump();
    expect(accepted, isTrue);

    await tester.tap(find.byKey(const Key('lobby-seat-offer-decline')));
    await tester.pump();
    expect(declined, isTrue);
  });

  testWidgets('offer banner hides when not pending', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LobbySeatOfferBanner(
            status: _status(
              chip: LobbySeatChipKind.seated,
              offerPending: false,
            ),
            onAccept: () {},
            onDecline: () {},
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('lobby-seat-offer-banner')), findsNothing);
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets('offered spot pulse wraps the child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OfferedSpotPulse(
          pulse: true,
          child: Text('spot-1'),
        ),
      ),
    );
    expect(find.byKey(const Key('offered-spot-pulse')), findsOneWidget);
    expect(find.text('spot-1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('no pulse key when the spot is not offered', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OfferedSpotPulse(
          pulse: false,
          child: Text('spot-1'),
        ),
      ),
    );
    expect(find.byKey(const Key('offered-spot-pulse')), findsNothing);
    expect(find.text('spot-1'), findsOneWidget);
  });

  test('banner Accept path is joinMatched with handoffToPeacock false', () {
    final peacock = PeacockAssignmentTracker();
    final lfg = MatchmakingQueueTracker(peacock: peacock);
    lfg.startLooking('u1');
    lfg.matchFound('u1', lobbyId: 'lobby-9', notificationId: 'n1');
    peacock.assignSpot('u1', lobbyId: 'lobby-9', notificationId: 'n1');
    final handoff = lfg.joinMatched('u1', handoffToPeacock: false);
    expect(handoff.state.phase, MatchmakingQueuePhase.joined);
    expect(peacock.stateFor('u1').phase, PeacockAssignmentPhase.assigned);
    expect(peacock.stateFor('u1').wouldDoubleNotifySelf, isFalse);
  });
}
