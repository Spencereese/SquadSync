import 'dart:async';

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

class _MutableLobbyNotifier extends LobbyNotifier {
  _MutableLobbyNotifier(this._state);
  LobbyState _state;

  @override
  Future<LobbyState> build() async => _state;

  void replace(LobbyState next) {
    _state = next;
    state = AsyncData(next);
  }
}

Lobby _lobby({required String id, required List<String> members}) {
  return Lobby.create(
    name: 'Squad',
    gameName: 'Warzone',
    maxSpots: 8,
    createdBy: members.first,
  ).copyWith(id: id, memberUids: members);
}

Future<void> _pumpHosts(
  WidgetTester tester, {
  required List<String> userIds,
  LobbyState? lobbyState,
  LobbyNotifier? notifier,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lobbyNotifierProvider.overrideWith(
          () => notifier ??
              _SeededLobbyNotifier(lobbyState ?? LobbyState.initial()),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              for (final uid in userIds) PresenceBadgesHost(userId: uid),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() {
    AvailabilityOnStore.scheduleExpirySweeps = false;
    PresenceBadgesHost.scheduleStaleCleanup = false;
    presenceReconnectToastGate.reset();
    MatchmakingQueueTracker.resetInstance();
    resetAvailabilityOnStore();
  });

  tearDown(() {
    MatchmakingQueueTracker.resetInstance();
    resetAvailabilityOnStore();
    presenceReconnectToastGate.reset();
    PresenceBadgesHost.scheduleStaleCleanup = true;
    AvailabilityOnStore.scheduleExpirySweeps = true;
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
    expect(find.byKey(const Key(kPresenceEmptyStripKey)), findsOneWidget);
    expect(find.text('On'), findsNothing);
    expect(find.text('Offline'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('row shows Offline / Stale / Reconnecting without a spinner',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PresenceBadgeRow(
                badges: PresenceBadges(health: PresenceHealth.offline),
              ),
              PresenceBadgeRow(
                badges: PresenceBadges(
                  isOn: true,
                  health: PresenceHealth.stale,
                ),
              ),
              PresenceBadgeRow(
                badges: PresenceBadges(health: PresenceHealth.reconnecting),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Stale'), findsOneWidget);
    expect(find.text('On'), findsOneWidget);
    expect(find.text('Reconnecting'), findsOneWidget);
    expect(find.byKey(const Key('presence-badge-offline')), findsOneWidget);
    expect(find.byKey(const Key('presence-badge-stale')), findsOneWidget);
    expect(
      find.byKey(const Key('presence-badge-reconnecting')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('host reads live on / looking / lobby membership',
      (tester) async {
    availabilityOnStore.markOn('u-on');
    MatchmakingQueueTracker.instance.startLooking('u-look');
    final lobby = _lobby(id: 'lobby-1', members: const ['u-in']);
    final state = LobbyState.initial().copyWith(
      lobbyMemberUids: const ['u-in'],
      currentLobby: lobby,
      userLobbies: {'lobby-1': lobby},
    );

    await _pumpHosts(
      tester,
      userIds: const ['u-on', 'u-look', 'u-in', 'u-idle'],
      lobbyState: state,
    );

    expect(find.text('On'), findsOneWidget);
    expect(find.text('Looking'), findsOneWidget);
    expect(find.text('In lobby'), findsOneWidget);
    expect(find.byKey(const Key('presence-badge-on')), findsOneWidget);
    expect(find.byKey(const Key('presence-badge-looking')), findsOneWidget);
    expect(find.byKey(const Key('presence-badge-in-lobby')), findsOneWidget);
  });

  testWidgets('host refreshes On / Looking and drops stale windows',
      (tester) async {
    var now = DateTime.utc(2026, 9, 4, 12);
    availabilityOnStore.cancelExpiryTimer();
    availabilityOnStore = AvailabilityOnStore(clock: () => now);

    await _pumpHosts(tester, userIds: const ['u1']);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.byKey(const Key('presence-badge-offline')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    availabilityOnStore.markOn('u1');
    await tester.pump();
    expect(find.text('On'), findsOneWidget);
    expect(find.text('Offline'), findsNothing);

    MatchmakingQueueTracker.instance.startLooking('u1');
    await tester.pump();
    expect(find.text('Looking'), findsOneWidget);

    now = now.add(kAvailabilityOnDuration + const Duration(seconds: 1));
    availabilityOnStore.sweepExpired();
    await tester.pump();
    expect(find.text('On'), findsNothing);
    expect(find.text('Looking'), findsOneWidget);

    MatchmakingQueueTracker.instance.cancelLooking('u1');
    await tester.pump();
    expect(find.text('Looking'), findsNothing);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('host drops In lobby when live membership refreshes',
      (tester) async {
    final live = _lobby(id: 'lobby-1', members: const ['u-in']);
    final empty = _lobby(id: 'lobby-1', members: const ['host']);
    final notifier = _MutableLobbyNotifier(
      LobbyState.initial().copyWith(
        lobbyMemberUids: const ['u-in'],
        currentLobby: live,
        userLobbies: {'lobby-1': live},
      ),
    );

    await _pumpHosts(tester, userIds: const ['u-in'], notifier: notifier);
    expect(find.text('In lobby'), findsOneWidget);

    notifier.replace(
      LobbyState.initial().copyWith(
        lobbyMemberUids: const ['u-in'],
        currentLobby: empty,
        userLobbies: {'lobby-1': live},
      ),
    );
    await tester.pump();
    expect(find.text('In lobby'), findsNothing);
    expect(find.text('Offline'), findsOneWidget);
  });

  testWidgets('host shows Stale copy when lobby load fails, not a spinner',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lobbyNotifierProvider.overrideWith(() => _ErrorLobbyNotifier()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PresenceBadgesHost(userId: 'u1'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Stale'), findsOneWidget);
    expect(find.byKey(const Key('presence-badge-stale')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('host shows reconnecting toast without a spinner',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lobbyNotifierProvider.overrideWith(() => _LoadingLobbyNotifier()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PresenceBadgesHost(userId: 'u1'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Reconnecting'), findsOneWidget);
    expect(
      find.byKey(const Key('presence-badge-reconnecting')),
      findsOneWidget,
    );
    expect(find.text(kPresenceReconnectingCopy), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  });

  testWidgets('host clears stale On after timeout', (tester) async {
    PresenceBadgesHost.scheduleStaleCleanup = true;
    availabilityOnStore.markOn('u1');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lobbyNotifierProvider.overrideWith(() => _ErrorLobbyNotifier()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PresenceBadgesHost(userId: 'u1'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('On'), findsOneWidget);
    expect(find.text('Stale'), findsOneWidget);

    await tester.pump(kPresenceStaleTimeout);
    await tester.pump();
    await tester.pump();

    expect(find.text('On'), findsNothing);
    expect(find.text('Stale'), findsNothing);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('host with empty uid is an empty strip, not Offline',
      (tester) async {
    await _pumpHosts(tester, userIds: const ['', '  ']);

    expect(find.byKey(const Key(kPresenceEmptyStripKey)), findsWidgets);
    expect(find.byKey(const Key('presence-badges')), findsNothing);
    expect(find.text('Offline'), findsNothing);
    expect(find.text('On'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}

class _ErrorLobbyNotifier extends LobbyNotifier {
  @override
  Future<LobbyState> build() async {
    throw Exception('offline');
  }
}

class _LoadingLobbyNotifier extends LobbyNotifier {
  @override
  Future<LobbyState> build() {
    return Completer<LobbyState>().future;
  }
}
