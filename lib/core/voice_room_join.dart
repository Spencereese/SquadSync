import 'package:flutter/material.dart';

import '../screens/voice_room_screen.dart';

/// Fallback title when the lobby / squad name is missing.
const kDefaultVoiceSquadName = 'Squad Voice';

/// Existing [VoiceRoomScreen] entry. Live path: lobby header, chat-info,
/// lobby More, chat app bar. Tests inject [push]. Does not restyle the room.
Future<T?> openVoiceRoom<T extends Object?>({
  required String roomId,
  String squadName = kDefaultVoiceSquadName,
  bool isHost = false,
  Color? themeColor,
  BuildContext? context,
  Future<T?> Function(Widget page)? push,
}) {
  final id = roomId.trim();
  if (id.isEmpty) return Future<T?>.value(null);

  final name = squadName.trim();
  final page = VoiceRoomScreen(
    roomId: id,
    squadName: name.isEmpty ? kDefaultVoiceSquadName : name,
    isHost: isHost,
    themeColor: themeColor,
  );
  if (push != null) return push(page);
  final ctx = context;
  if (ctx == null) return Future<T?>.value(null);
  return Navigator.of(ctx).push<T>(
    MaterialPageRoute<T>(builder: (_) => page),
  );
}
