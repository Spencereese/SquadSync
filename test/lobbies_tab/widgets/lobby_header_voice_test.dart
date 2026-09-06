import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/voice_room_join.dart';
import 'package:squad_sync/lobbies_tab/widgets/lobby_header.dart';
import 'package:squad_sync/screens/voice_room_screen.dart';

Future<void> _pumpVoiceHost(
  WidgetTester tester, {
  String? lobbyId = 'lobby-9',
  String squadName = 'Warzone',
  bool isOffline = false,
  VoiceJoinSession? session,
  Future<void> Function(Widget page)? push,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LobbyVoiceJoinHost(
          lobbyId: lobbyId,
          squadName: squadName,
          isOffline: isOffline,
          session: session,
          push: push,
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    voiceJoinSession.reset();
    voiceReconnectToastGate.reset();
  });
  tearDown(() {
    voiceJoinSession.reset();
    voiceReconnectToastGate.reset();
  });

  testWidgets('lobby header Voice join is present and calls openVoiceRoom',
      (tester) async {
    Widget? page;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LobbyVoiceJoinButton(
            onPressed: () {
              openVoiceRoom(
                roomId: 'lobby-9',
                squadName: 'Warzone',
                push: (widget) async {
                  page = widget;
                  return null;
                },
              );
            },
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('lobby-voice-join')), findsOneWidget);
    expect(find.byIcon(Icons.headset), findsOneWidget);
    expect(find.byTooltip('Join voice'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lobby-voice-join')));
    await tester.pump();

    expect(page, isA<VoiceRoomScreen>());
    final room = page! as VoiceRoomScreen;
    expect(room.roomId, 'lobby-9');
    expect(room.squadName, 'Warzone');
  });

  testWidgets('empty lobby header shows empty copy, not a join',
      (tester) async {
    var pushed = false;
    final session = VoiceJoinSession();
    addTearDown(session.dispose);
    await _pumpVoiceHost(
      tester,
      lobbyId: '',
      session: session,
      push: (_) async => pushed = true,
    );

    expect(find.byKey(const Key('lobby-voice-join')), findsOneWidget);
    expect(find.byKey(const Key('lobby-voice-empty')), findsOneWidget);
    expect(find.byTooltip(kVoiceLobbyEmptyCopy), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byKey(const Key('lobby-voice-join')));
    await tester.pump();

    expect(pushed, isFalse);
    expect(find.text(kVoiceLobbyEmptyCopy), findsWidgets);
    expect(find.text(kVoiceLobbyReconnectingCopy), findsNothing);
  });

  testWidgets('offline lobby header shows error, not a hang or a join',
      (tester) async {
    var pushed = false;
    final session = VoiceJoinSession();
    addTearDown(session.dispose);
    await _pumpVoiceHost(
      tester,
      isOffline: true,
      session: session,
      push: (_) async => pushed = true,
    );

    expect(find.byKey(const Key('lobby-voice-join')), findsOneWidget);
    expect(find.byKey(const Key('lobby-voice-error')), findsOneWidget);
    expect(find.byTooltip(kVoiceLobbyOfflineCopy), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byKey(const Key('lobby-voice-join')));
    await tester.pump();

    expect(pushed, isFalse);
    expect(find.text(kVoiceLobbyOfflineCopy), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('host join opens the room and skips a second tap',
      (tester) async {
    final gate = Completer<void>();
    var pushed = 0;
    Widget? page;
    final session = VoiceJoinSession();
    addTearDown(session.dispose);
    await _pumpVoiceHost(
      tester,
      session: session,
      push: (widget) {
        pushed++;
        page = widget;
        return gate.future;
      },
    );

    await tester.tap(find.byKey(const Key('lobby-voice-join')));
    await tester.pump();
    await tester.pump();

    expect(pushed, 1);
    expect(page, isA<VoiceRoomScreen>());
    expect(find.byKey(const Key('lobby-voice-joined')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byKey(const Key('lobby-voice-join')));
    await tester.pump();

    expect(pushed, 1);
    expect(find.text(kVoiceLobbyAlreadyJoinedCopy), findsWidgets);
  });

  testWidgets('host shows reconnecting toast after drop without a spinner',
      (tester) async {
    final gate = Completer<void>();
    var pushed = 0;
    final session = VoiceJoinSession();
    addTearDown(session.dispose);
    await _pumpVoiceHost(
      tester,
      session: session,
      push: (_) {
        pushed++;
        return gate.future;
      },
    );

    await tester.tap(find.byKey(const Key('lobby-voice-join')));
    await tester.pump();
    await tester.pump();
    expect(pushed, 1);

    session.markDropped();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('lobby-voice-reconnecting')), findsOneWidget);
    expect(find.text(kVoiceLobbyReconnectingCopy), findsWidgets);
    expect(find.byKey(const Key(kVoiceReconnectToastKey)), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byKey(const Key('lobby-voice-join')));
    await tester.pump();
    await tester.pump();

    expect(pushed, 2);
    expect(session.isDropped, isFalse);
    expect(session.isJoined, isTrue);
  });
}
