import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/voice_room_join.dart';
import 'package:squad_sync/lobbies_tab/widgets/lobby_header.dart';
import 'package:squad_sync/screens/voice_room_screen.dart';

void main() {
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
}
