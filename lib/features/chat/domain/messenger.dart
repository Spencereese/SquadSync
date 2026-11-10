import 'package:squadsync/features/chat/domain/chat_message.dart';

/// The six reactions the picker offers. Stored as these exact characters.
const List<String> quickReactions = ['👍', '😂', '🔥', '❤️', '😮', '🎮'];

const Map<String, String> reactionSpokenName = {
  '👍': 'thumbs up',
  '😂': 'laughing',
  '🔥': 'fire',
  '❤️': 'heart',
  '😮': 'surprised',
  '🎮': 'game',
};

bool isQuickReaction(String emoji) => quickReactions.contains(emoji);

class MessageReaction {
  const MessageReaction({
    required this.messageId,
    required this.userId,
    required this.emoji,
  });

  final String messageId;
  final String userId;
  final String emoji;
}

class MemberRead {
  const MemberRead({
    required this.userId,
    required this.readAt,
    this.messageId,
  });

  final String userId;
  final DateTime readAt;
  final String? messageId;
}

class ReactionChip {
  const ReactionChip({
    required this.emoji,
    required this.count,
    required this.names,
    required this.mine,
  });

  final String emoji;
  final int count;
  final List<String> names;
  final bool mine;

  String get spoken {
    final what = reactionSpokenName[emoji] ?? 'reaction';
    final who = names.isEmpty ? '' : ', ${names.join(', ')}';
    return '$count $what$who';
  }
}

/// One chip per emoji that someone used, in picker order.
List<ReactionChip> reactionChips({
  required String messageId,
  required List<MessageReaction> reactions,
  required Map<String, String> names,
  required String meId,
}) {
  final chips = <ReactionChip>[];
  for (final emoji in quickReactions) {
    final rows = [
      for (final reaction in reactions)
        if (reaction.messageId == messageId && reaction.emoji == emoji)
          reaction,
    ];
    if (rows.isEmpty) continue;
    chips.add(
      ReactionChip(
        emoji: emoji,
        count: rows.length,
        names: [for (final row in rows) names[row.userId] ?? 'Someone'],
        mine: rows.any((row) => row.userId == meId),
      ),
    );
  }
  return chips;
}

/// Toggle [emoji] for [userId] on [messageId]. Unknown emoji is ignored.
List<MessageReaction> toggleReaction(
  List<MessageReaction> reactions, {
  required String messageId,
  required String userId,
  required String emoji,
}) {
  if (!isQuickReaction(emoji) || messageId.isEmpty || userId.isEmpty) {
    return reactions;
  }
  final exists = reactions.any(
    (row) =>
        row.messageId == messageId &&
        row.userId == userId &&
        row.emoji == emoji,
  );
  if (exists) {
    return [
      for (final row in reactions)
        if (row.messageId != messageId ||
            row.userId != userId ||
            row.emoji != emoji)
          row,
    ];
  }
  return [
    ...reactions,
    MessageReaction(messageId: messageId, userId: userId, emoji: emoji),
  ];
}

/// People other than me whose cursor is on [message] or a later one.
List<String> seenByNames({
  required ChatMessage message,
  required List<ChatMessage> thread,
  required List<MemberRead> reads,
  required Map<String, String> names,
  required String meId,
}) {
  final sorted = sortedThread(thread);
  final at = sorted.indexWhere((row) => row.id == message.id);
  if (at < 0) return const [];
  final who = <String>[];
  for (final read in reads) {
    if (read.userId.isEmpty || read.userId == meId) continue;
    final cursor = read.messageId;
    if (cursor == null || cursor.isEmpty) continue;
    final seenAt = sorted.indexWhere((row) => row.id == cursor);
    if (seenAt >= at) who.add(names[read.userId] ?? 'Someone');
  }
  return who;
}

String seenByLine(List<String> names) {
  if (names.isEmpty) return '';
  return 'Seen by ${names.join(', ')}';
}

/// The oldest message from someone else that is still after [readThroughId].
/// A null cursor means nothing has been read.
String? firstUnreadMessageId({
  required List<ChatMessage> messages,
  required String meId,
  required String? readThroughId,
}) {
  final sorted = sortedThread(messages);
  var after = readThroughId == null || readThroughId.isEmpty;
  for (final message in sorted) {
    if (!after) {
      if (message.id == readThroughId) after = true;
      continue;
    }
    if (message.senderId.isEmpty || message.senderId == meId) continue;
    return message.id;
  }
  return null;
}

/// File 0014 is not on this database. Hide reactions and receipts.
/// Only a missing table or column counts. A permission error that names
/// the table is still an error.
bool messengerTableMissing(String? code, String message) {
  return code == '42P01' ||
      code == 'PGRST205' ||
      code == '42703' ||
      code == 'PGRST204';
}

/// A realtime reaction or read. Deletes are not filtered by squad.
class MessengerEvent {
  const MessengerEvent({
    required this.table,
    required this.deleted,
    this.squadId,
    this.messageId,
    this.userId,
  });

  final String table;
  final bool deleted;
  final String? squadId;
  final String? messageId;
  final String? userId;
}

/// Inserts and updates reload only for this squad. Deletes reload when the
/// row is one this phone already shows, or when the payload named no id.
bool messengerEventReloads(
  MessengerEvent event, {
  required String squadId,
  required Set<String> messageIds,
  required Set<String> memberIds,
}) {
  if (!event.deleted) {
    final rowSquad = event.squadId;
    return rowSquad == null || rowSquad.isEmpty || rowSquad == squadId;
  }
  if (event.table == 'sq8_message_reactions') {
    final id = event.messageId;
    if (id == null || id.isEmpty) return true;
    return messageIds.contains(id);
  }
  final rowSquad = event.squadId;
  if (rowSquad != null && rowSquad.isNotEmpty && rowSquad != squadId) {
    return false;
  }
  final id = event.userId;
  if (id == null || id.isEmpty) return true;
  return memberIds.contains(id);
}

String typingLine(Iterable<String> names) {
  final who = [for (final name in names) name.trim()]
      .where((name) => name.isNotEmpty);
  final list = who.toList();
  if (list.isEmpty) return '';
  if (list.length == 1) return '${list.single} is typing';
  if (list.length == 2) return '${list[0]} and ${list[1]} are typing';
  return '${list.length} people are typing';
}
