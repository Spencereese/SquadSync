/// PIN WAVE P2 — Fill PIN "need one" nudge audience.
///
/// Pure-Dart filter: members who have not Sit / Coming / Can't on this pin.
/// UID set/list only — not a send, not FCM. XOR stays planPeacockSelfNotify
/// (one notify pipeline). This file does not invent a second push path.
/// Share-pin-not-chat stays queued.
Iterable<String> fillPinNudgeAudience({
  required Iterable<String> memberUids,
  Iterable<String> sitUids = const [],
  Iterable<String> comingUids = const [],
  Iterable<String> cantUids = const [],
}) {
  final excluded = <String>{};
  for (final raw in [...sitUids, ...comingUids, ...cantUids]) {
    final uid = raw.trim();
    if (uid.isNotEmpty) excluded.add(uid);
  }

  final seen = <String>{};
  final out = <String>[];
  for (final raw in memberUids) {
    final uid = raw.trim();
    if (uid.isEmpty || excluded.contains(uid)) continue;
    if (!seen.add(uid)) continue;
    out.add(uid);
  }
  return out;
}
