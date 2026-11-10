/// Who currently has the squad home open. This is not a check-in and not
/// a Steam game.
class AppPresenceBoard {
  const AppPresenceBoard({required this.available, this.here = const {}});

  /// Realtime presence could not be joined. The board draws no dots.
  const AppPresenceBoard.unavailable() : this(available: false);

  final bool available;
  final Set<String> here;

  bool isHere(String userId) => available && here.contains(userId);
}

/// Channel name for in-app presence. Typing stays on `sq8-typing-<squad>`.
String appPresenceTopic(String squadId) => 'sq8-presence-$squadId';

/// User ids carried in presence payloads. Blank ids are ignored.
Set<String> presenceUserIds(Iterable<Map<String, dynamic>> payloads) {
  final ids = <String>{};
  for (final payload in payloads) {
    final id = payload['user_id'];
    if (id is String && id.isNotEmpty) ids.add(id);
  }
  return ids;
}
