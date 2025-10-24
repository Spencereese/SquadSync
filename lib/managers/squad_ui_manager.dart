class SquadUIManager {
  // UI state properties
  Map<String, bool> typing = {};
  bool _tiltEnabled = true;
  bool _hasNewSquadSpot = false;
  bool _hasUnreadMessages = false;

  // Getters
  // ignore: unnecessary_getters_setters
  bool get tiltEnabled => _tiltEnabled;
  // ignore: unnecessary_getters_setters
  bool get hasNewSquadSpot => _hasNewSquadSpot;
  // ignore: unnecessary_getters_setters
  bool get hasUnreadMessages => _hasUnreadMessages;

  // Setters
  // ignore: unnecessary_getters_setters
  set tiltEnabled(bool value) => _tiltEnabled = value;
  // ignore: unnecessary_getters_setters
  set hasNewSquadSpot(bool value) => _hasNewSquadSpot = value;
  // ignore: unnecessary_getters_setters
  set hasUnreadMessages(bool value) => _hasUnreadMessages = value;

  void setNewSquadSpot(bool value, String gameName) {
    _hasNewSquadSpot = value;
  }

  void setHasUnreadMessages(bool value) {
    _hasUnreadMessages = value;
  }

  // UI methods
  void updateTypingStatus(String user, bool isTyping) {
    if (typing[user] != isTyping) {
      typing[user] = isTyping;
    }
  }

  String? getTypingUser() {
    return typing.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .firstOrNull;
  }
}
