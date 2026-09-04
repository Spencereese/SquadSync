import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';
import 'package:squad_sync/services/availability_on.dart';
import 'package:squad_sync/services/matchmaking_queue_machine.dart';
import 'package:squad_sync/services/presence_badges.dart';
import 'package:squad_sync/widgets/presence_badge_row.dart';

class _SeededLobbyNotifier extends LobbyNotifier {
  _SeededLobbyNotifier(this._state);
  final LobbyState _state;

  @override
  Future<LobbyState> build() async => _state;
}

void main() {
  setUp(() {
    MatchmakingQueueTracker.resetInstance();
    resetAvailabilityOnStore();
  });

  tearDown(() {
    MatchmakingQueueTracker.resetInstance();
    resetAvailabilityOnStore();
  });

  testWidgets('row shows On / Looking / In lobby chips', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PresenceBadgeRow(
            badges: PresenceBadges(
              isOn: true,
              isLooking: true,
              isInLobby: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('presence-badges')), findsOneWidget);
    expect(find.byKey(const Key('presence-badge-on')), findsOneWidget);
    expect(find.byKey(const Key('presence-badge-looking')), findsOneWidget);
    expect(find.byKey(const Key('presence-badge-in-lobby')), findsOneWidget);
    expect(find.text('On'), findsOneWidget);
    expect(find.text('Looking'), findsOneWidget);
    expect(find.text('In lobby'), findsOneWidget);
  });

  testWidgets('row is empty when no badges', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PresenceBadgeRow(badges: PresenceBadges.empty),
        ),
      ),
    );
    expect(find.byKey(const Key('presence-badges')), findsNothing);
    expect(find.text('On'), findsNothing);
  });

  testWidgets('host reads live on / looking / lobby membership',
      (tester) async {
    availabilityOnStore.markOn('u-on');
    MatchmakingQueueTracker.instance.startLooking('u-look');
    final lobby = Lobby.create(
      name: 'Squad',
      gameName: 'Warzone',
      maxSpots: 8,
      createdBy: 'u-in',
    ).copyWith(id: 'lobby-1', memberUids: const ['u-in']);
    final state = LobbyState.initial().copyWith(
      lobbyMemberUids: const ['u-in'],
      currentLobby: lobby,
      userLobbies: {'lobby-1': lobby},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lobbyNotifierProvider.overrideWith(() => _SeededLobbyNotifier(state)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PresenceBadgesHost(userId: 'u-on'),
                PresenceBadgesHost(userId: 'u-look'),
                PresenceBadgesHost(userId: 'u-in'),
                PresenceBadgesHost(userId: 'u-idle'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('On'), findsOneWidget);
    expect(find.text('Looking'), findsOneWidget);
    expect(find.text('In lobby'), findsOneWidget);
    expect(find.byKey(const Key('presence-badge-on')), findsOneWidget);
    expect(find.byKey(const Key('presence-badge-looking')), findsOneWidget);
    expect(find.byKey(const Key('presence-badge-in-lobby')), findsOneWidget);
  });
}
