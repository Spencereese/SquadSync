import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/voice_room_join.dart';
import 'package:squad_sync/screens/voice_room_screen.dart';

void main() {
  test('openVoiceRoom pushes VoiceRoomScreen with room id and name', () async {
    Widget? page;
    await openVoiceRoom(
      roomId: 'lobby-9',
      squadName: 'Warzone',
      push: (widget) async {
        page = widget;
        return null;
      },
    );
    expect(page, isA<VoiceRoomScreen>());
    final room = page! as VoiceRoomScreen;
    expect(room.roomId, 'lobby-9');
    expect(room.squadName, 'Warzone');
    expect(room.isHost, isFalse);
  });

  test('openVoiceRoom trims room id and falls back on empty name', () async {
    Widget? page;
    await openVoiceRoom(
      roomId: '  lobby-9  ',
      squadName: '   ',
      isHost: true,
      push: (widget) async {
        page = widget;
        return null;
      },
    );
    final room = page! as VoiceRoomScreen;
    expect(room.roomId, 'lobby-9');
    expect(room.squadName, kDefaultVoiceSquadName);
    expect(room.isHost, isTrue);
  });

  test('openVoiceRoom no-ops on empty room id', () async {
    var pushed = false;
    await openVoiceRoom(
      roomId: '  ',
      squadName: 'Warzone',
      push: (widget) async {
        pushed = true;
        return null;
      },
    );
    expect(pushed, isFalse);
  });
}
