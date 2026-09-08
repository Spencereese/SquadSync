import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/fill_pin_thread_header.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';

/// PIN WAVE P1 Build slice B — Fill PIN header on the thread.
///
/// Open group thread with an active this-group pin shows game + n/max
/// (+ who sat). No pin → no header. Live seat count follows lobby state.
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

class _FixedLobbyNotifier extends LobbyNotifier {
  _FixedLobbyNotifier(this._state);
  final LobbyState _state;

  @override
  Future<LobbyState> build() async => _state;
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

Future<void> _pumpHeader(
  WidgetTester tester, {
  required LobbyNotifier Function() create,
  String? chatGroupId = 'group-1',
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [lobbyNotifierProvider.overrideWith(create)],
      child: MaterialApp(
        home: Scaffold(
          body: wrapFillPinThreadHeader(
            chatGroupId: chatGroupId,
            child: const Text('messages'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('this-group active pin resolves game + n/max + seated names', () {
    final lobby = _pin(id: 'pin-1', chatGroupId: 'group-1');
    final snapshot = resolveFillPinForThread(
      state: _stateWithPin(lobby),
      chatGroupId: 'group-1',
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.gameName, 'Warzone');
    expect(snapshot.seated, 2);
    expect(snapshot.maxSpots, 4);
    expect(snapshot.seatLabel, '2/4');
    expect(snapshot.seatedUids, ['u1', 'u2']);
    expect(snapshot.seatedNames, 'Alex, Chris');
    expect(snapshot.comingCountdown, isNull);
  });

  test('other-group / inactive / missing pin resolves to null', () {
    final other = _pin(id: 'pin-x', chatGroupId: 'group-other');
    expect(
      resolveFillPinForThread(
        state: _stateWithPin(other),
        chatGroupId: 'group-1',
      ),
      isNull,
    );

    final dead = _pin(id: 'pin-dead', chatGroupId: 'group-1', isActive: false);
    expect(
      resolveFillPinForThread(
        state: _stateWithPin(dead),
        chatGroupId: 'group-1',
      ),
      isNull,
    );

    expect(
      resolveFillPinForThread(
        state: LobbyState.initial(),
        chatGroupId: 'group-1',
      ),
      isNull,
    );
    expect(
      resolveFillPinForThread(
        state: _stateWithPin(_pin(id: 'pin-1', chatGroupId: 'group-1')),
        chatGroupId: '',
      ),
      isNull,
    );
  });

  test('live gameLobbySpots win over stale lobby.spots for selected pin', () {
    final lobby = _pin(
      id: 'pin-1',
      chatGroupId: 'group-1',
      spots: const ['u1', null, null, null],
    );
    final snapshot = resolveFillPinForThread(
      state: _stateWithPin(
        lobby,
        liveSpots: {
          'Warzone': ['u1', 'u2', 'u3', null],
        },
      ),
      chatGroupId: 'group-1',
    );

    expect(snapshot!.seatLabel, '3/4');
    expect(snapshot.seatedUids, ['u1', 'u2', 'u3']);
    expect(snapshot.seatedNames, 'Alex, Chris, Dee');
  });

  testWidgets('thread with this-group pin shows header; no pin hides it',
      (tester) async {
    final lobby = _pin(id: 'pin-1', chatGroupId: 'group-1');
    await _pumpHeader(
      tester,
      create: () => _FixedLobbyNotifier(_stateWithPin(lobby)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(kFillPinThreadHeaderKey), findsOneWidget);
    expect(find.text('Warzone'), findsOneWidget);
    expect(find.text('2/4'), findsOneWidget);
    expect(find.text('Alex, Chris'), findsOneWidget);
    expect(find.text('messages'), findsOneWidget);

    await _pumpHeader(
      tester,
      create: () => _FixedLobbyNotifier(LobbyState.initial()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(kFillPinThreadHeaderKey), findsNothing);
    expect(find.text('Warzone'), findsNothing);
    expect(find.text('2/4'), findsNothing);
    expect(find.text('messages'), findsOneWidget);
  });

  testWidgets('header seat count follows live spots', (tester) async {
    final lobby = _pin(
      id: 'pin-1',
      chatGroupId: 'group-1',
      spots: const ['u1', null, null, null],
    );
    final notifier = _LiveLobbyNotifier(_stateWithPin(lobby));
    await _pumpHeader(tester, create: () => notifier);
    await tester.pumpAndSettle();
    expect(find.text('1/4'), findsOneWidget);

    final sat = lobby.copyWith(spots: const ['u1', 'u2', null, null]);
    notifier.emit(_stateWithPin(sat));
    await tester.pump();

    expect(find.text('2/4'), findsOneWidget);
    expect(find.text('Alex, Chris'), findsOneWidget);
    expect(find.text('1/4'), findsNothing);
  });

  test('chat_screen binds header; chip create path and forbidden files stay',
      () {
    final screen = File('lib/chat/chat_screen.dart').readAsStringSync();
    expect(screen.contains('wrapFillPinThreadHeader'), isTrue);
    expect(screen.contains('threadChatGroupId'), isTrue);
    expect(screen.contains('bindFillPin'), isTrue);
    expect(screen.contains('onFillPinSuggestionTap'), isTrue);

    final header = File('lib/chat/fill_pin_thread_header.dart').readAsStringSync();
    expect(header.contains('resolveFillPinForThread'), isTrue);
    expect(header.contains('comingCountdown'), isTrue);

    expect(
      File('lib/presentation/notifiers/lobby_notifier.dart')
          .readAsStringSync()
          .contains('fill_pin_thread_header'),
      isFalse,
    );
    expect(
      File('lib/chat/screens/chat_info_screen.dart')
          .readAsStringSync()
          .contains('fill_pin_thread_header'),
      isFalse,
    );
    expect(
      File('lib/chat/message_bubble.dart')
          .readAsStringSync()
          .contains('fill_pin_thread_header'),
      isFalse,
    );
  });
}
