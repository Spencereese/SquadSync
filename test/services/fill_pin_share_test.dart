import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/fill_pin_thread_header.dart';
import 'package:squad_sync/core/deep_link_routes.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';
import 'package:squad_sync/services/fill_pin_live_activity.dart';
import 'package:squad_sync/services/fill_pin_share.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

/// PIN WAVE P2 — SHARE PIN ≠ SHARE CHAT HISTORY.
///
/// Share-sheet payload is this Fill PIN only: game + n/max + sit-here
/// deep link. Recipients open the thread/pin. They do not get a dump of
/// prior chat. Pin stays in THIS group (share-to-other-group / public
/// is P3).
void main() {
  const history = <String>[
    'hey you coming tonight?',
    'lol last night was wild we went 2/4',
    'Alex: sit 3 then we ran it',
    'Chris: wait I need one more',
  ];

  setUp(resetFillPinShareHooks);
  tearDown(resetFillPinShareHooks);

  group('fillPinSharePayload is pin-scoped', () {
    test('payload is game + n/max + sit-here link, not chat history', () {
      final payload = fillPinSharePayload(
        chatGroupId: 'group-1',
        gameName: 'Warzone',
        seated: 2,
        maxSpots: 4,
        pinId: 'pin-1',
        lobbyId: 'pin-1',
      );

      expect(payload, contains('Warzone'));
      expect(payload, contains('2/4'));
      expect(payload, contains(kFillPinShareSitHereSuffix));
      expect(
        payload,
        contains(
          fillPinShareSitHereLink(
            chatGroupId: 'group-1',
            pinId: 'pin-1',
            lobbyId: 'pin-1',
          ),
        ),
      );

      for (final line in history) {
        expect(
          payload.contains(line),
          isFalse,
          reason: 'Share pin must not dump chat history: "$line"',
        );
      }
    });

    test('sit-here link matches Live Activity deep link and opens thread', () {
      final shareLink = fillPinShareSitHereLink(
        chatGroupId: 'group-1',
        pinId: 'pin-1',
        lobbyId: 'pin-1',
      );
      final liveLink = fillPinDeepLink(
        chatGroupId: 'group-1',
        pinId: 'pin-1',
        lobbyId: 'pin-1',
      );
      expect(shareLink, liveLink);
      expect(locationForDeepLink(shareLink), '/chat/group-1');
    });

    test('empty thread does not invent a pin payload', () {
      expect(
        fillPinSharePayload(
          chatGroupId: '   ',
          gameName: 'Warzone',
          seated: 1,
          maxSpots: 4,
        ),
        isEmpty,
      );
    });

    test('preview stub is cheap Warzone n/max · sit here (OG title is P3)', () {
      expect(
        fillPinSharePreviewTitle(
          gameName: 'Warzone',
          seated: 2,
          maxSpots: 4,
        ),
        'Warzone 2/4 · sit here',
      );
    });
  });

  group('shareFillPin sheet uses pin payload only', () {
    test('injected share receives pin text and excludes message history',
        () async {
      String? shared;
      final payload = fillPinSharePayload(
        chatGroupId: 'group-1',
        gameName: 'Warzone',
        seated: 2,
        maxSpots: 4,
        pinId: 'pin-1',
        lobbyId: 'pin-1',
      );

      await shareFillPin(
        payload: payload,
        share: (text) async => shared = text,
      );

      expect(shared, payload);
      expect(shared, contains('Warzone 2/4 · sit here'));
      expect(shared, contains('codsquadapp://chat/group-1'));
      for (final line in history) {
        expect(shared!.contains(line), isFalse);
      }
    });

    test('empty payload does not open the sheet', () async {
      var opened = false;
      await shareFillPin(
        payload: '   ',
        share: (_) async => opened = true,
      );
      expect(opened, isFalse);
    });
  });

  group('header share tap — friends share the pin', () {
    testWidgets('Share pin emits pin payload, not thread message bodies',
        (tester) async {
      String? shared;
      fillPinShareOverride = (text) async => shared = text;

      final lobby = Lobby.create(
        name: 'Warzone pin',
        gameName: 'Warzone',
        maxSpots: 4,
        createdBy: 'u1',
      ).copyWith(
        id: 'pin-1',
        chatGroupId: 'group-1',
        isActive: true,
        spots: const ['u1', 'u2', null, null],
        memberUids: const ['u1', 'u2'],
      );
      final notifier = _LiveLobbyNotifier(
        LobbyState.initial().copyWith(
          selectedLobbyId: lobby.id,
          currentLobby: lobby,
          userLobbies: {lobby.id: lobby},
          userLobbyIds: [lobby.id],
          memberDisplayNames: const {'u1': 'Alex', 'u2': 'Chris'},
          gameLobbySpots: {lobby.gameName: lobby.spots},
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [lobbyNotifierProvider.overrideWith(() => notifier)],
          child: MaterialApp(
            home: Scaffold(
              body: wrapFillPinThreadHeader(
                chatGroupId: 'group-1',
                child: const Text('hey you coming tonight?'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(kFillPinShareKey), findsOneWidget);
      expect(find.text('hey you coming tonight?'), findsOneWidget);

      await tester.tap(find.byKey(kFillPinShareKey));
      await tester.pump();

      expect(shared, isNotNull);
      expect(shared, contains('Warzone 2/4 · sit here'));
      expect(shared, contains(fillPinShareSitHereLink(
        chatGroupId: 'group-1',
        pinId: 'pin-1',
        lobbyId: 'pin-1',
      )));
      expect(shared!.contains('hey you coming tonight?'), isFalse);
    });
  });

  group('lease + XOR + no history pipeline', () {
    test('helper does not import or concatenate message history', () {
      final src = File('lib/services/fill_pin_share.dart').readAsStringSync();
      expect(src.contains('fillPinSharePayload'), isTrue);
      expect(src.contains('fillPinShareSitHereLink'), isTrue);
      expect(src.contains('shareFillPin'), isTrue);
      expect(src.contains('message_data'), isFalse);
      expect(src.contains('MessageData'), isFalse);
      expect(src.contains('messages.map'), isFalse);
      expect(src.contains('chat_screen'), isFalse);
      expect(src.contains('sendNotificationToUsers'), isFalse);
      expect(src.contains('FirebaseMessaging'), isFalse);
    });

    test('header wires Share pin without restyling bubbles', () {
      final header =
          File('lib/chat/fill_pin_thread_header.dart').readAsStringSync();
      expect(header.contains('fill_pin_share.dart'), isTrue);
      expect(header.contains('kFillPinShareKey'), isTrue);
      expect(header.contains('fillPinSharePayload'), isTrue);
      expect(header.contains('shareFillPin'), isTrue);

      expect(
        File('lib/chat/message_bubble.dart')
            .readAsStringSync()
            .contains('fill_pin_share'),
        isFalse,
      );
      expect(
        File('lib/chat/screens/chat_info_screen.dart')
            .readAsStringSync()
            .contains('fill_pin_share'),
        isFalse,
      );
      expect(
        File('lib/presentation/notifiers/lobby_notifier.dart')
            .readAsStringSync()
            .contains('fill_pin_share'),
        isFalse,
      );
    });

    test('XOR stays planPeacockSelfNotify', () {
      expect(
        planPeacockSelfNotify(
          notificationId: 'n1',
          currentUid: 'u1',
          isForeground: true,
          locallyPresentedIds: {},
        ).wouldDoubleNotifySelf,
        isFalse,
      );
      final src = File('lib/services/fill_pin_share.dart').readAsStringSync();
      expect(src.contains('peacock_self_notify.dart'), isFalse);
      expect(src.contains('NotificationService'), isFalse);
      expect(src.contains('FirebaseMessaging'), isFalse);
      expect(src.contains('sendNotificationToUsers'), isFalse);
    });
  });
}

class _LiveLobbyNotifier extends LobbyNotifier {
  _LiveLobbyNotifier(this._state);
  final LobbyState _state;

  @override
  Future<LobbyState> build() async => _state;
}
