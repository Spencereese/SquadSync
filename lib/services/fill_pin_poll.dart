/// PIN WAVE P3A — poll lives on a Fill PIN (lobby id), not a chat message.
///
/// Pure-Dart attach / resolve / detach-on-clear. No chat UI, no Tonight,
/// no notify send path.
class FillPinPoll {
  const FillPinPoll({
    required this.pinId,
    required this.pollId,
  }) : chatMessageId = null;

  /// Lobby / pin id this poll is bound to.
  final String pinId;

  final String pollId;

  /// Always null — this is not a free-floating chat-message poll.
  final String? chatMessageId;
}

final Map<String, FillPinPoll> _byPinId = {};

void resetFillPinPollStore() {
  _byPinId.clear();
}

String? _pinKey(String pinId) {
  final trimmed = pinId.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Bind [pollId] to [pinId] (lobby id). [FillPinPoll.chatMessageId] stays null.
FillPinPoll attachPollToPin({
  required String pinId,
  required String pollId,
}) {
  final pin = pinId.trim();
  final attached = FillPinPoll(
    pinId: pin,
    pollId: pollId.trim(),
  );
  final key = _pinKey(pin);
  if (key != null) {
    _byPinId[key] = attached;
  }
  return attached;
}

/// Attached poll for [pinId] only. Unknown / cleared pins return null.
FillPinPoll? resolvePollForPin(String pinId) {
  final key = _pinKey(pinId);
  if (key == null) return null;
  return _byPinId[key];
}

/// Ending / clearing the pin detaches its poll. Other pins are unchanged.
void detachPollOnPinClear(String pinId) {
  final key = _pinKey(pinId);
  if (key == null) return;
  _byPinId.remove(key);
}
