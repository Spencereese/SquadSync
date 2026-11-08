import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/voice_room_screen.dart';

/// Fallback title when the lobby / squad name is missing.
const kDefaultVoiceSquadName = 'Squad Voice';

/// Outcome of [joinVoiceRoom]. Empty lobby id does not push. Already-joined
/// same session is not a second [VoiceRoomScreen]. Dropped session reconnects.
enum VoiceLobbyJoinOutcome {
  opened,
  empty,
  offline,
  alreadyJoined,
  reconnecting,
}

/// Header empty / error / reconnecting. Never a spinner — reconnecting is copy.
enum VoiceLobbyHeaderPhase { ready, empty, error, reconnecting, joined }

const kVoiceLobbyEmptyCopy = 'No lobby selected';
const kVoiceLobbyOfflineCopy = "Couldn't join voice";
const kVoiceLobbyOfflineHint = 'Check your connection and try again.';
const kVoiceLobbyAlreadyJoinedCopy = 'Already in voice';
const kVoiceLobbyReconnectingCopy = 'Reconnecting to voice...';
const kVoiceReconnectToastKey = 'lobby-voice-reconnect-toast';
const kVoiceReconnectToastCooldown = Duration(seconds: 4);

class VoiceLobbyJoinResult {
  const VoiceLobbyJoinResult.opened()
      : outcome = VoiceLobbyJoinOutcome.opened,
        error = null;

  const VoiceLobbyJoinResult.empty()
      : outcome = VoiceLobbyJoinOutcome.empty,
        error = null;

  const VoiceLobbyJoinResult.offline({this.error})
      : outcome = VoiceLobbyJoinOutcome.offline;

  const VoiceLobbyJoinResult.alreadyJoined()
      : outcome = VoiceLobbyJoinOutcome.alreadyJoined,
        error = null;

  const VoiceLobbyJoinResult.reconnecting()
      : outcome = VoiceLobbyJoinOutcome.reconnecting,
        error = null;

  final VoiceLobbyJoinOutcome outcome;
  final Object? error;

  bool get isOpened => outcome == VoiceLobbyJoinOutcome.opened;
  bool get isEmpty => outcome == VoiceLobbyJoinOutcome.empty;
  bool get isOffline => outcome == VoiceLobbyJoinOutcome.offline;
}

Key voiceLobbyJoinFeedbackKey(VoiceLobbyJoinOutcome outcome) {
  switch (outcome) {
    case VoiceLobbyJoinOutcome.opened:
      return const Key('lobby-voice-opened');
    case VoiceLobbyJoinOutcome.empty:
      return const Key('lobby-voice-empty');
    case VoiceLobbyJoinOutcome.offline:
      return const Key('lobby-voice-error');
    case VoiceLobbyJoinOutcome.alreadyJoined:
      return const Key('lobby-voice-already-joined');
    case VoiceLobbyJoinOutcome.reconnecting:
      return const Key(kVoiceReconnectToastKey);
  }
}

Key voiceLobbyHeaderKey(VoiceLobbyHeaderPhase phase) {
  switch (phase) {
    case VoiceLobbyHeaderPhase.ready:
      return const Key('lobby-voice-join');
    case VoiceLobbyHeaderPhase.empty:
      return const Key('lobby-voice-empty');
    case VoiceLobbyHeaderPhase.error:
      return const Key('lobby-voice-error');
    case VoiceLobbyHeaderPhase.reconnecting:
      return const Key('lobby-voice-reconnecting');
    case VoiceLobbyHeaderPhase.joined:
      return const Key('lobby-voice-joined');
  }
}

String voiceLobbyJoinErrorDetail(Object? error) {
  if (error == null) return '';
  final text = error.toString().trim();
  if (text.isEmpty) return '';
  const prefix = 'Exception: ';
  if (text.startsWith(prefix) && text.length > prefix.length) {
    return text.substring(prefix.length);
  }
  return text;
}

String voiceLobbyJoinMessage(VoiceLobbyJoinResult result) {
  switch (result.outcome) {
    case VoiceLobbyJoinOutcome.opened:
      return '';
    case VoiceLobbyJoinOutcome.empty:
      return kVoiceLobbyEmptyCopy;
    case VoiceLobbyJoinOutcome.offline:
      final detail = voiceLobbyJoinErrorDetail(result.error);
      if (detail.isEmpty) return kVoiceLobbyOfflineCopy;
      return '$kVoiceLobbyOfflineCopy: $detail';
    case VoiceLobbyJoinOutcome.alreadyJoined:
      return kVoiceLobbyAlreadyJoinedCopy;
    case VoiceLobbyJoinOutcome.reconnecting:
      return kVoiceLobbyReconnectingCopy;
  }
}

String? voiceLobbyJoinHint(VoiceLobbyJoinOutcome outcome) {
  if (outcome == VoiceLobbyJoinOutcome.offline) {
    return kVoiceLobbyOfflineHint;
  }
  return null;
}

String voiceLobbyHeaderMessage(VoiceLobbyHeaderPhase phase) {
  switch (phase) {
    case VoiceLobbyHeaderPhase.ready:
      return 'Join voice';
    case VoiceLobbyHeaderPhase.empty:
      return kVoiceLobbyEmptyCopy;
    case VoiceLobbyHeaderPhase.error:
      return kVoiceLobbyOfflineCopy;
    case VoiceLobbyHeaderPhase.reconnecting:
      return kVoiceLobbyReconnectingCopy;
    case VoiceLobbyHeaderPhase.joined:
      return kVoiceLobbyAlreadyJoinedCopy;
  }
}

/// SnackBar for [joinVoiceRoom] — empty, offline, already-joined, reconnect.
/// Opened is the room itself, not a toast.
SnackBar voiceLobbyJoinSnackBar(VoiceLobbyJoinResult result) {
  final reconnecting = result.outcome == VoiceLobbyJoinOutcome.reconnecting;
  return SnackBar(
    key: reconnecting ? const Key(kVoiceReconnectToastKey) : null,
    content: Text(
      voiceLobbyJoinMessage(result),
      key: reconnecting ? null : voiceLobbyJoinFeedbackKey(result.outcome),
    ),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 2),
  );
}

SnackBar voiceReconnectSnackBar() {
  return const SnackBar(
    key: Key(kVoiceReconnectToastKey),
    content: Text(kVoiceLobbyReconnectingCopy),
    duration: Duration(seconds: 2),
    behavior: SnackBarBehavior.floating,
  );
}

void presentVoiceLobbyJoin(BuildContext context, VoiceLobbyJoinResult result) {
  if (!context.mounted) return;
  if (result.outcome == VoiceLobbyJoinOutcome.opened) return;
  ScaffoldMessenger.of(context).showSnackBar(voiceLobbyJoinSnackBar(result));
}

/// Header empty / error / reconnecting. Empty lobby id wins. Joining a
/// live room is joined (no double-join), not a spinner. Drop is reconnecting.
VoiceLobbyHeaderPhase resolveVoiceLobbyHeaderPhase({
  String? lobbyId,
  bool isOffline = false,
  bool isJoined = false,
  bool isJoining = false,
  bool isDropped = false,
  Object? error,
}) {
  final id = lobbyId?.trim() ?? '';
  if (id.isEmpty) return VoiceLobbyHeaderPhase.empty;
  if (isDropped) return VoiceLobbyHeaderPhase.reconnecting;
  if (error != null || isOffline) return VoiceLobbyHeaderPhase.error;
  if (isJoined || isJoining) return VoiceLobbyHeaderPhase.joined;
  return VoiceLobbyHeaderPhase.ready;
}

/// True when a second join would stack [VoiceRoomScreen]. Dropped sessions
/// reconnect instead. Empty id is empty, not a double-join.
bool wouldDoubleJoinVoice({
  required String roomId,
  String? joinedRoomId,
  bool isJoining = false,
  bool isDropped = false,
}) {
  final id = roomId.trim();
  if (id.isEmpty) return false;
  if (isDropped) return false;
  if (isJoining) return true;
  final joined = joinedRoomId?.trim();
  if (joined == null || joined.isEmpty) return false;
  return true;
}

/// Reconnect after drop is the same room, not a fresh join and not a stack.
bool shouldReconnectVoiceAfterDrop({
  required String roomId,
  String? joinedRoomId,
  required bool isDropped,
}) {
  if (!isDropped) return false;
  final id = roomId.trim();
  if (id.isEmpty) return false;
  return joinedRoomId?.trim() == id;
}

/// Toast on a real voice drop / recovery, not the first join of a live room.
bool shouldShowVoiceReconnectToast({
  VoiceLobbyHeaderPhase? previous,
  required VoiceLobbyHeaderPhase current,
  bool voiceDrop = false,
}) {
  final reconnecting =
      current == VoiceLobbyHeaderPhase.reconnecting || voiceDrop;
  if (!reconnecting) return false;
  if (previous == VoiceLobbyHeaderPhase.reconnecting) return false;
  if (previous == VoiceLobbyHeaderPhase.ready) return false;
  if (previous == VoiceLobbyHeaderPhase.joined) return true;
  if (previous == VoiceLobbyHeaderPhase.error) return true;
  return voiceDrop;
}

/// One toast per reconnect cycle across header / chat Voice taps.
class VoiceReconnectToastGate {
  DateTime? _lastShownAt;

  bool claim({
    required DateTime now,
    Duration cooldown = kVoiceReconnectToastCooldown,
  }) {
    final last = _lastShownAt;
    if (last != null && now.difference(last) < cooldown) return false;
    _lastShownAt = now;
    return true;
  }

  void reset() => _lastShownAt = null;
}

final voiceReconnectToastGate = VoiceReconnectToastGate();

/// In-memory join gate. Not a table. Survives across header / chat Voice
/// taps so the same lobby cannot stack two [VoiceRoomScreen]s.
class VoiceJoinSession extends ChangeNotifier {
  String? _joinedRoomId;
  bool _isJoining = false;
  bool _isDropped = false;

  String? get joinedRoomId => _joinedRoomId;
  bool get isJoining => _isJoining;
  bool get isDropped => _isDropped;

  bool get isJoined =>
      _joinedRoomId != null &&
      _joinedRoomId!.isNotEmpty &&
      !_isDropped &&
      !_isJoining;

  void markJoining(String roomId) {
    _joinedRoomId = roomId.trim();
    _isJoining = true;
    _isDropped = false;
    notifyListeners();
  }

  void markJoined(String roomId) {
    _joinedRoomId = roomId.trim();
    _isJoining = false;
    _isDropped = false;
    notifyListeners();
  }

  void markDropped() {
    if (_joinedRoomId == null || _joinedRoomId!.isEmpty) return;
    _isJoining = false;
    _isDropped = true;
    notifyListeners();
  }

  void markLeft() {
    _joinedRoomId = null;
    _isJoining = false;
    _isDropped = false;
    notifyListeners();
  }

  void reset() => markLeft();
}

final voiceJoinSession = VoiceJoinSession();

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

/// Gated live path for Voice join. Empty / whitespace lobby id is
/// [VoiceLobbyJoinOutcome.empty] — no push. Offline is error, not a hang.
/// Already joined (or joining) is not a second room. Dropped same-room
/// join reconnects.
Future<VoiceLobbyJoinResult> joinVoiceRoom({
  String? roomId,
  String squadName = kDefaultVoiceSquadName,
  bool isHost = false,
  Color? themeColor,
  BuildContext? context,
  Future<void> Function(Widget page)? push,
  VoiceJoinSession? session,
  bool isOffline = false,
  bool clearOnRouteDone = true,
}) async {
  final id = roomId?.trim() ?? '';
  if (id.isEmpty) {
    return const VoiceLobbyJoinResult.empty();
  }

  final sess = session ?? voiceJoinSession;

  if (isOffline && !sess.isDropped) {
    return const VoiceLobbyJoinResult.offline();
  }

  if (wouldDoubleJoinVoice(
    roomId: id,
    joinedRoomId: sess.joinedRoomId,
    isJoining: sess.isJoining,
    isDropped: sess.isDropped,
  )) {
    return const VoiceLobbyJoinResult.alreadyJoined();
  }

  final reconnect = shouldReconnectVoiceAfterDrop(
    roomId: id,
    joinedRoomId: sess.joinedRoomId,
    isDropped: sess.isDropped,
  );

  if (push == null && context == null) {
    return const VoiceLobbyJoinResult.empty();
  }

  sess.markJoining(id);
  try {
    final future = openVoiceRoom<void>(
      roomId: id,
      squadName: squadName,
      isHost: isHost,
      themeColor: themeColor,
      context: context,
      push: push,
    );
    sess.markJoined(id);
    if (clearOnRouteDone) {
      unawaited(future.then<void>((_) {
        if (sess.joinedRoomId == id && !sess.isJoining && !sess.isDropped) {
          sess.markLeft();
        }
      }, onError: (_) {
        if (sess.joinedRoomId == id) sess.markDropped();
      }));
    }
    if (reconnect) return const VoiceLobbyJoinResult.reconnecting();
    return const VoiceLobbyJoinResult.opened();
  } catch (e) {
    sess.markDropped();
    return VoiceLobbyJoinResult.offline(error: e);
  }
}
