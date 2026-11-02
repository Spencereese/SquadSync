import '../domain/entities/message.dart';

/// Client-only send state. Stored on [Message.metadata] so a row can keep
/// one id from the moment the user hits send until the server has that row.
/// Server history has no key and is treated as already confirmed.
const String kDeliveryStatusKey = 'delivery_status';

enum OutboundDelivery { sending, sent, failed }

OutboundDelivery outboundDeliveryOf(Message message) {
  return outboundDeliveryFromRaw(message.metadata?[kDeliveryStatusKey]);
}

OutboundDelivery outboundDeliveryFromMap(Map<String, dynamic> data) {
  final top = data[kDeliveryStatusKey];
  if (top != null) return outboundDeliveryFromRaw(top);
  final metadata = data['metadata'];
  if (metadata is Map) {
    return outboundDeliveryFromRaw(metadata[kDeliveryStatusKey]);
  }
  return OutboundDelivery.sent;
}

OutboundDelivery outboundDeliveryFromRaw(Object? raw) {
  if (raw is OutboundDelivery) return raw;
  switch (raw?.toString()) {
    case 'sending':
      return OutboundDelivery.sending;
    case 'failed':
      return OutboundDelivery.failed;
    case 'sent':
      return OutboundDelivery.sent;
    default:
      return OutboundDelivery.sent;
  }
}

Message withDelivery(Message message, OutboundDelivery delivery) {
  final metadata = Map<String, dynamic>.from(message.metadata ?? const {});
  metadata[kDeliveryStatusKey] = delivery.name;
  return message.copyWith(metadata: metadata);
}

/// A send is confirmed only when the insert (or a duplicate-row conflict)
/// names this same client id. An offline queue result is not confirmation.
bool isServerConfirmed({
  required bool success,
  required bool isOffline,
  required String? messageId,
  required String clientId,
}) {
  return success &&
      !isOffline &&
      clientId.isNotEmpty &&
      messageId == clientId;
}

int compareMessagesByTime(Message a, Message b) {
  final byTime = a.timestamp.compareTo(b.timestamp);
  if (byTime != 0) return byTime;
  return a.id.compareTo(b.id);
}

List<Message> sortThread(List<Message> messages) {
  final copy = List<Message>.of(messages);
  copy.sort(compareMessagesByTime);
  return copy;
}

/// Append one sending bubble. Same id if it is already on screen.
List<Message> appendSending(List<Message> messages, Message sending) {
  final next = <Message>[];
  var replaced = false;
  for (final message in messages) {
    if (message.id == sending.id) {
      next.add(withDelivery(sending, OutboundDelivery.sending));
      replaced = true;
    } else {
      next.add(message);
    }
  }
  if (!replaced) {
    next.add(withDelivery(sending, OutboundDelivery.sending));
  }
  return sortThread(next);
}

/// Flip [clientId] to sent or failed. Does not add or rename a row.
/// A later failure must not demote a row the server echo already confirmed.
List<Message> applySendResult({
  required List<Message> messages,
  required String clientId,
  required bool confirmed,
}) {
  return messages.map((message) {
    if (message.id != clientId) return message;
    if (!confirmed && outboundDeliveryOf(message) == OutboundDelivery.sent) {
      return message;
    }
    return withDelivery(
      message,
      confirmed ? OutboundDelivery.sent : OutboundDelivery.failed,
    );
  }).toList();
}

/// Failed → sending, same id. No-op unless the row is actually failed.
List<Message> markRetrying({
  required List<Message> messages,
  required String clientId,
}) {
  return messages.map((message) {
    if (message.id != clientId) return message;
    if (outboundDeliveryOf(message) != OutboundDelivery.failed) {
      return message;
    }
    return withDelivery(message, OutboundDelivery.sending);
  }).toList();
}

Message? messageById(List<Message> messages, String id) {
  for (final message in messages) {
    if (message.id == id) return message;
  }
  return null;
}

/// One row per id. A realtime echo of the client id confirms that row
/// instead of inserting a second bubble. Local sending/failed rows the
/// server has not echoed stay on screen.
List<Message> mergeRemoteEcho({
  required List<Message> local,
  required List<Message> remote,
}) {
  final localById = <String, Message>{
    for (final message in local) message.id: message,
  };
  final seen = <String>{};
  final merged = <Message>[];

  for (final remoteMessage in remote) {
    if (remoteMessage.id.isEmpty || !seen.add(remoteMessage.id)) continue;
    final existing = localById[remoteMessage.id];
    if (existing == null) {
      merged.add(remoteMessage);
      continue;
    }
    merged.add(_confirmWithRemote(existing, remoteMessage));
  }

  for (final localMessage in local) {
    if (localMessage.id.isEmpty || seen.contains(localMessage.id)) continue;
    merged.add(localMessage);
  }

  return sortThread(merged);
}

Message _confirmWithRemote(Message local, Message remote) {
  final metadata = Map<String, dynamic>.from(remote.metadata ?? const {});
  final localMetadata = local.metadata ?? const {};
  for (final entry in localMetadata.entries) {
    metadata.putIfAbsent(entry.key, () => entry.value);
  }
  metadata[kDeliveryStatusKey] = OutboundDelivery.sent.name;
  return remote.copyWith(id: local.id, metadata: metadata);
}

bool sameThreadSnapshot(List<Message> a, List<Message> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) return false;
    if (a[i].text != b[i].text) return false;
    if (outboundDeliveryOf(a[i]) != outboundDeliveryOf(b[i])) return false;
    final aReactions = a[i].reactions;
    final bReactions = b[i].reactions;
    if (aReactions == null && bReactions == null) continue;
    if (aReactions == null || bReactions == null) return false;
    if (aReactions.length != bReactions.length) return false;
    for (final key in aReactions.keys) {
      if (aReactions[key] != bReactions[key]) return false;
    }
  }
  return true;
}
