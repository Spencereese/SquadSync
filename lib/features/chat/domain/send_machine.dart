import 'package:squadsync/features/chat/domain/chat_message.dart';

/// The repository inserted this client id.
class SendConfirmed extends SendOutcome {
  const SendConfirmed(this.messageId);

  final String messageId;

  @override
  bool operator ==(Object other) =>
      other is SendConfirmed && other.messageId == messageId;

  @override
  int get hashCode => messageId.hashCode;
}

/// The id was already stored. A unique conflict means the row is there.
class SendConflict extends SendOutcome {
  const SendConflict(this.messageId);

  final String messageId;

  @override
  bool operator ==(Object other) =>
      other is SendConflict && other.messageId == messageId;

  @override
  int get hashCode => messageId.hashCode;
}

class SendFailed extends SendOutcome {
  const SendFailed();
}

sealed class SendOutcome {
  const SendOutcome();
}

/// Sent only when the repository names this same client id.
/// A duplicate-insert conflict counts. A different id does not.
bool outcomeConfirms(SendOutcome outcome, String clientId) {
  if (clientId.isEmpty) return false;
  return switch (outcome) {
    SendConfirmed(:final messageId) => messageId == clientId,
    SendConflict(:final messageId) => messageId == clientId,
    SendFailed() => false,
  };
}

/// The on-screen thread. One row per id. Newest last.
class ChatThread {
  ChatThread(Iterable<ChatMessage> input)
    : messages = List<ChatMessage>.unmodifiable(sortedThread(input));

  final List<ChatMessage> messages;

  /// Append one sending row. The id must be new.
  ChatThread start(ChatMessage outgoing) {
    if (outgoing.id.isEmpty) {
      throw ArgumentError.value(
        outgoing.id,
        'outgoing.id',
        'must not be empty',
      );
    }
    if (outgoing.delivery != Delivery.sending) {
      throw ArgumentError('an outgoing row starts as sending');
    }
    if (messages.any((message) => message.id == outgoing.id)) {
      throw StateError('id ${outgoing.id} is already in the thread');
    }
    return ChatThread([...messages, outgoing]);
  }

  /// Flip [clientId] to sent or failed. Does not add or rename a row.
  /// A later failure must not demote a row an echo already confirmed.
  ChatThread apply(String clientId, SendOutcome outcome) {
    final confirmed = outcomeConfirms(outcome, clientId);
    return ChatThread([
      for (final message in messages)
        if (message.id != clientId)
          message
        else if (!confirmed && message.delivery == Delivery.sent)
          message
        else
          message.copyWith(
            delivery: confirmed ? Delivery.sent : Delivery.failed,
          ),
    ]);
  }

  /// Failed becomes sending again. The id does not change.
  /// Any other state is left alone.
  ChatThread retry(String clientId) {
    return ChatThread([
      for (final message in messages)
        if (message.id == clientId && message.delivery == Delivery.failed)
          message.copyWith(delivery: Delivery.sending)
        else
          message,
    ]);
  }

  /// A realtime echo with an id already on screen confirms that row.
  /// It does not insert a second bubble. Local sending or failed rows the
  /// server has not echoed stay in the list.
  ChatThread mergeEcho(Iterable<ChatMessage> remote, {required String meId}) {
    final byId = <String, ChatMessage>{
      for (final message in messages)
        if (message.id.isNotEmpty) message.id: message,
    };
    for (final incoming in remote) {
      if (incoming.id.isEmpty) continue;
      final existing = byId[incoming.id];
      byId[incoming.id] = existing == null
          ? _echoRow(incoming, meId)
          : _confirm(existing, incoming, meId);
    }
    return ChatThread(byId.values);
  }
}

ChatMessage _echoRow(ChatMessage incoming, String meId) {
  if (incoming.senderId == meId) {
    return ChatMessage(
      id: incoming.id,
      chatId: incoming.chatId,
      senderId: incoming.senderId,
      text: incoming.text,
      sentAt: incoming.sentAt,
      delivery: Delivery.sent,
    );
  }
  return ChatMessage(
    id: incoming.id,
    chatId: incoming.chatId,
    senderId: incoming.senderId,
    text: incoming.text,
    sentAt: incoming.sentAt,
  );
}

ChatMessage _confirm(ChatMessage local, ChatMessage remote, String meId) {
  final mine =
      local.delivery != null ||
      local.senderId == meId ||
      remote.senderId == meId;
  return ChatMessage(
    id: local.id,
    chatId: remote.chatId.isEmpty ? local.chatId : remote.chatId,
    senderId: remote.senderId.isEmpty ? local.senderId : remote.senderId,
    text: remote.text,
    sentAt: remote.sentAt,
    delivery: mine ? Delivery.sent : null,
  );
}
