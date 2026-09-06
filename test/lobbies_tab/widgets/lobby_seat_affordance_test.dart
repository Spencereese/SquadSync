import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/deep_link_routes.dart';
import 'package:squad_sync/lobbies_tab/widgets/lobby_seat_affordance.dart';
import 'package:squad_sync/services/lobby_ready_lock.dart';
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
            status: _status(
              chip: LobbySeatChipKind.peacock,
              offerPending: false,
            ),
          ),
        ),
      ),
    );
    expect(find.text('peacock'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LobbySeatStatusChip(
            status: _status(chip: LobbySeatChipKind.peacock),
          ),
        ),
      ),
    );
    expect(find.text('assigned'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LobbySeatStatusChip(
            status: _status(
              chip: LobbySeatChipKind.lock,
              offerPending: false,
              lockRemaining: const Duration(minutes: 3, seconds: 5),
            ),
          ),
        ),
      ),
    );
    expect(find.text('lock 03:05'), findsOneWidget);
  });

  testWidgets('chip shows expired and assigned lock labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LobbySeatStatusChip(
            status: _status(
              chip: LobbySeatChipKind.lock,
              lockRemaining: Duration.zero,
            ),
          ),
        ),
      ),
    );
    expect(find.text('expired'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LobbySeatStatusChip(
            status: _status(
              chip: LobbySeatChipKind.lock,
              lockRemaining: const Duration(minutes: 4, seconds: 59),
            ),
          ),
        ),
      ),
    );
    expect(find.text('assigned 04:59'), findsOneWidget);
  });

  testWidgets('LockTimerReadout shows expired then assigned', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LockTimerReadout(remaining: Duration.zero),
        ),
      ),
    );
    expect(find.byKey(const Key('lock-timer-readout')), findsOneWidget);
    expect(find.text('expired'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LockTimerReadout(
            remaining: Duration(minutes: 5),
            queueAssigned: true,
          ),
        ),
      ),
    );
    expect(find.text('assigned 05:00'), findsOneWidget);
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

  testWidgets('own seated spot shows Ready toggle', (tester) async {
    var toggled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeatedSpotReadyAffordance(
            isReady: false,
            isLocked: false,
            onToggle: () => toggled = true,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('seated-spot-ready-button')), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.byKey(const Key('seated-spot-locked-badge')), findsNothing);

    await tester.tap(find.byKey(const Key('seated-spot-ready-button')));
    await tester.pump();
    expect(toggled, isTrue);
  });

  testWidgets('other seated Locked shows badge without Unlock', (tester) async {
    var toggled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeatedSpotReadyAffordance(
            isReady: true,
            isLocked: true,
            isOwnSeat: false,
            onToggle: () => toggled = true,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('seated-spot-locked-badge')), findsOneWidget);
    expect(find.text('Locked'), findsOneWidget);
    expect(find.byKey(const Key('seated-spot-ready-button')), findsNothing);
    expect(find.byKey(const Key('seated-spot-unlock-button')), findsNothing);

    await tester.tap(find.byKey(const Key('seated-spot-locked-badge')));
    await tester.pump();
    expect(toggled, isFalse);
  });

  testWidgets('own locked seat shows Unlock and tap unlocks', (tester) async {
    var unlocked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeatedSpotReadyAffordance(
            isReady: true,
            isLocked: true,
            onToggle: () => unlocked = true,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('seated-spot-unlock-button')), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
    expect(find.byKey(const Key('seated-spot-ready-button')), findsNothing);

    await tester.tap(find.byKey(const Key('seated-spot-unlock-button')));
    await tester.pump();
    expect(unlocked, isTrue);
  });

  testWidgets('Ready button shows remaining ready-check timeout',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SeatedSpotReadyAffordance(
            isReady: true,
            isLocked: false,
            timeoutRemaining: Duration(seconds: 45),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('seated-spot-ready-button')), findsOneWidget);
    expect(find.text('Ready 00:45'), findsOneWidget);
  });

  testWidgets('timeout expired chip shows Timed out', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SeatedSpotReadyAffordance(
            isReady: false,
            isLocked: false,
            timeoutExpired: true,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('seated-spot-timeout-chip')), findsOneWidget);
    expect(find.text('Timed out'), findsOneWidget);
    expect(find.byKey(const Key('seated-spot-ready-button')), findsNothing);
  });

  testWidgets(
      'Invite / Peacock / Queue stay available for late join while locked',
      (tester) async {
    const locked = LobbyReadyLockSnapshot(
      phase: LobbyReadyLockPhase.locked,
      seatedUids: ['u1', 'u2'],
      readyUids: ['u1', 'u2'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: emptySpotShowsCtas(
            hasOccupant: false,
            allowLateJoin: emptySpotAllowsLateJoin(locked),
          )
              ? EmptySpotCtaBar(
                  onInvite: () {},
                  onPeacock: () {},
                  onQueue: () {},
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
    expect(find.byKey(const Key('empty-spot-cta-bar')), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('Peacock'), findsOneWidget);
    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('Call'), findsNothing);
  });

  test('empty-spot CTA kind is Invite, then Queue, then Peacock', () {
    expect(emptySpotCtaKindFor(), EmptySpotCtaKind.invite);
    expect(
      emptySpotCtaKindFor(queuePending: true),
      EmptySpotCtaKind.queue,
    );
    expect(
      emptySpotCtaKindFor(peacockOffered: true, queuePending: true),
      EmptySpotCtaKind.peacock,
    );
    expect(emptySpotCtaLabel(EmptySpotCtaKind.invite), 'Invite');
    expect(emptySpotCtaLabel(EmptySpotCtaKind.peacock), 'Peacock');
    expect(emptySpotCtaLabel(EmptySpotCtaKind.queue), 'Queue');
    expect(
      emptySpotShowsCtas(hasOccupant: false, allowLateJoin: true),
      isTrue,
    );
    expect(
      emptySpotShowsCtas(hasOccupant: true, allowLateJoin: true),
      isFalse,
    );
  });

  test('empty-spot Queue pending from LFG looking or peacock queued', () {
    expect(
      emptySpotQueuePending(lfgPhase: MatchmakingQueuePhase.looking),
      isTrue,
    );
    expect(
      emptySpotQueuePending(lfgPhase: MatchmakingQueuePhase.matched),
      isTrue,
    );
    expect(
      emptySpotQueuePending(peacockPhase: PeacockAssignmentPhase.queued),
      isTrue,
    );
    expect(emptySpotQueuePending(peacockQueueOccupied: true), isTrue);
    expect(
      emptySpotQueuePending(lfgPhase: MatchmakingQueuePhase.idle),
      isFalse,
    );
  });

  testWidgets('empty-spot CTA bar fires Invite / Peacock / Queue',
      (tester) async {
    var invited = false;
    var peacocked = false;
    var queued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptySpotCtaBar(
            onInvite: () => invited = true,
            onPeacock: () => peacocked = true,
            onQueue: () => queued = true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('empty-spot-invite-button')), findsOneWidget);
    expect(find.byKey(const Key('empty-spot-peacock-button')), findsOneWidget);
    expect(find.byKey(const Key('empty-spot-queue-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('empty-spot-invite-button')));
    await tester.pump();
    expect(invited, isTrue);

    await tester.tap(find.byKey(const Key('empty-spot-peacock-button')));
    await tester.pump();
    expect(peacocked, isTrue);

    await tester.tap(find.byKey(const Key('empty-spot-queue-button')));
    await tester.pump();
    expect(queued, isTrue);
  });

  testWidgets('peacock-offered empty spot emphasizes Peacock over Invite',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptySpotCtaBar(
            primary: EmptySpotCtaKind.peacock,
            onInvite: () {},
            onPeacock: () {},
            onQueue: () {},
          ),
        ),
      ),
    );
    final peacock = tester.widget<ElevatedButton>(
      find.byKey(const Key('empty-spot-peacock-button')),
    );
    final invite = tester.widget<ElevatedButton>(
      find.byKey(const Key('empty-spot-invite-button')),
    );
    expect(peacock.style?.foregroundColor?.resolve({}), Colors.black);
    expect(invite.style?.foregroundColor?.resolve({}), Colors.tealAccent);
  });

  test('empty-spot Invite reuses shareLobbyLink payload', () async {
    String? copied;
    String? shared;
    final result = await shareEmptySpotInvite(
      lobbyId: 'lobby-9',
      copy: (text) async => copied = text,
      share: (text) async => shared = text,
    );
    expect(result.outcome, LobbyShareOutcome.success);
    final payload = result.payload;
    expect(
      payload,
      'codsquadapp://lobby/lobby-9\nhttps://codsquad.app/l/lobby-9',
    );
    expect(copied, payload);
    expect(shared, payload);
    expect(copied, contains(lobbyShareDeepLink(lobbyId: 'lobby-9')));
    expect(copied, contains(lobbyShareHttpsLink(lobbyId: 'lobby-9')));
    for (final line in copied!.split('\n')) {
      expect(locationForDeepLink(line), '/squad?lobby_id=lobby-9');
    }
  });

  testWidgets('other seated Ready shows badge without toggle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SeatedSpotReadyAffordance(
            isReady: true,
            isLocked: false,
            isOwnSeat: false,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('seated-spot-ready-badge')), findsOneWidget);
    expect(find.byKey(const Key('seated-spot-ready-button')), findsNothing);
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
