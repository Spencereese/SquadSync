import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/fill_pin_group_row_badge.dart';
import 'package:squad_sync/chat/fill_pin_thread_header.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';

/// PIN WAVE P1 Build slice C — live n/max on the My Groups list row.
///
/// Active this-group pin → Warzone 2/4. No pin → no badge.
Lobby _pin({
  required String id,
  required String chatGroupId,
  String gameName = 'Warzone',
  int maxSpots = 4,
  List<String?>? spots,
  List<String>? memberUids,
  bool isActive = true,
  DateTime? createdAt,
}) {
  return Lobby.create(
    name: '$gameName pin',
    gameName: gameName,
    maxSpots: maxSpots,
    createdBy: 'u1',
  ).copyWith(
    id: id,
    chatGroupId: chatGroupId,
    isActive: isActive,
    spots: spots ?? const ['u1', 'u2', null, null],
    memberUids: memberUids ?? const ['u1', 'u2'],
    createdAt: createdAt ?? DateTime(2026, 9, 8),
  );
}

LobbyState _stateWithPin(Lobby lobby, {Map<String, List<String?>>? liveSpots}) {
  return LobbyState.initial().copyWith(
    selectedLobbyId: lobby.id,
    currentLobby: lobby,
    userLobbies: {lobby.id: lobby},
    userLobbyIds: [lobby.id],
    memberDisplayNames: const {
      'u1': 'Alex',
      'u2': 'Chris',
      'u3': 'Dee',
    },
    gameLobbySpots: liveSpots ?? {lobby.gameName: lobby.spots},
  );
}

class _LiveLobbyNotifier extends LobbyNotifier {
  _LiveLobbyNotifier(this._state);
  LobbyState _state;

  @override
  Future<LobbyState> build() async => _state;

  void emit(LobbyState next) {
    _state = next;
    state = AsyncData(next);
  }
}

Future<void> _pumpBadge(
  WidgetTester tester, {
  required LobbyNotifier Function() create,
  String chatGroupId = 'group-1',
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [lobbyNotifierProvider.overrideWith(create)],
      child: MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              const Expanded(child: Text('Squad')),
              FillPinGroupRowBadge(chatGroupId: chatGroupId),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('this-group pin snapshot is game + n/max for the row badge', () {
    final lobby = _pin(id: 'pin-1', chatGroupId: 'group-1');
    final snapshot = resolveFillPinForThread(
      state: _stateWithPin(lobby),
      chatGroupId: 'group-1',
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.gameName, 'Warzone');
    expect(snapshot.seatLabel, '2/4');
  });

  testWidgets('row with this-group pin shows live n/max; no pin hides it',
      (tester) async {
    final lobby = _pin(id: 'pin-1', chatGroupId: 'group-1');
    final notifier = _LiveLobbyNotifier(_stateWithPin(lobby));
    await _pumpBadge(tester, create: () => notifier);
    await tester.pumpAndSettle();

    expect(find.byKey(kFillPinGroupRowBadgeKey), findsOneWidget);
    expect(find.byKey(kFillPinGroupRowBadgeSeatKey), findsOneWidget);
    expect(find.text('Warzone 2/4'), findsOneWidget);
    expect(find.text('Squad'), findsOneWidget);

    notifier.emit(LobbyState.initial());
    await tester.pump();

    expect(find.byKey(kFillPinGroupRowBadgeKey), findsNothing);
    expect(find.text('Warzone 2/4'), findsNothing);
    expect(find.text('Squad'), findsOneWidget);
  });

  testWidgets('other-group pin does not badge this row', (tester) async {
    final other = _pin(id: 'pin-x', chatGroupId: 'group-other');
    final notifier = _LiveLobbyNotifier(_stateWithPin(other));
    await _pumpBadge(tester, create: () => notifier, chatGroupId: 'group-1');
    await tester.pumpAndSettle();

    expect(find.byKey(kFillPinGroupRowBadgeKey), findsNothing);
    expect(find.text('Warzone 2/4'), findsNothing);
  });

  testWidgets('badge seat count follows live spots', (tester) async {
    final lobby = _pin(
      id: 'pin-1',
      chatGroupId: 'group-1',
      spots: const ['u1', null, null, null],
    );
    final notifier = _LiveLobbyNotifier(_stateWithPin(lobby));
    await _pumpBadge(tester, create: () => notifier);
    await tester.pumpAndSettle();
    expect(find.text('Warzone 1/4'), findsOneWidget);

    final sat = lobby.copyWith(spots: const ['u1', 'u2', null, null]);
    notifier.emit(_stateWithPin(sat));
    await tester.pump();

    expect(find.text('Warzone 2/4'), findsOneWidget);
    expect(find.text('Warzone 1/4'), findsNothing);
  });

  test('groups list binds badge; chip + header + forbidden files stay', () {
    final groups = File('lib/chat/chat_groups_screen.dart').readAsStringSync();
    expect(groups.contains('FillPinGroupRowBadge'), isTrue);
    expect(groups.contains('fill_pin_group_row_badge.dart'), isTrue);

    final screen = File('lib/chat/chat_screen.dart').readAsStringSync();
    expect(screen.contains('wrapFillPinThreadHeader'), isTrue);
    expect(screen.contains('bindFillPin'), isTrue);
    expect(screen.contains('onFillPinSuggestionTap'), isTrue);

    expect(
      File('lib/presentation/notifiers/lobby_notifier.dart')
          .readAsStringSync()
          .contains('fill_pin_group_row_badge'),
      isFalse,
    );
    expect(
      File('lib/chat/screens/chat_info_screen.dart')
          .readAsStringSync()
          .contains('fill_pin_group_row_badge'),
      isFalse,
    );
    expect(
      File('lib/chat/message_bubble.dart')
          .readAsStringSync()
          .contains('fill_pin_group_row_badge'),
      isFalse,
    );
  });
}
