/// A tap or a cold start for one squad message. Anything else is ignored.
class SquadPush {
  const SquadPush({required this.squadId, required this.messageId});

  final String squadId;
  final String messageId;
}

/// Reads the data map a push would deliver. Returns null when it is not a
/// squad message, so a bad payload cannot open a chat.
SquadPush? parseSquadPush(Map<String, Object?> data) {
  if (data['type'] != 'squad_message') return null;
  final squadId = data['squad_id'];
  final messageId = data['message_id'];
  if (squadId is! String || messageId is! String) return null;
  final squad = squadId.trim();
  final message = messageId.trim();
  if (squad.isEmpty || message.isEmpty) return null;
  return SquadPush(squadId: squad, messageId: message);
}

enum SquadPushRoute { openChat, wrongSquad, wait }

/// [openChat] only when the signed-in person is already in that squad.
/// A different squad id does not switch the open chat.
SquadPushRoute routeSquadPush({
  required bool signedIn,
  required String? openSquadId,
  required SquadPush push,
}) {
  if (!signedIn || openSquadId == null || openSquadId.isEmpty) {
    return SquadPushRoute.wait;
  }
  if (openSquadId == push.squadId) return SquadPushRoute.openChat;
  return SquadPushRoute.wrongSquad;
}
