/// Who should hear that a chat row was saved, and how unread counts move.
///
/// Mute is per recipient. The sender is never in the list. A missing mute
/// lookup means "not muted" so a failed read does not silence the group.
class ChatMessageNotice {
  const ChatMessageNotice({
    required this.recipients,
    required this.title,
    required this.body,
    required this.payload,
  });

  final List<String> recipients;
  final String title;
  final String body;
  final Map<String, dynamic> payload;
}

ChatMessageNotice? noticeForSavedMessage({
  required List<String> memberUids,
  required String senderId,
  required String chatId,
  required String text,
  Set<String> mutedRecipientIds = const {},
}) {
  final recipients = <String>[];
  for (final id in memberUids) {
    if (id.isEmpty || id == senderId || mutedRecipientIds.contains(id)) {
      continue;
    }
    if (!recipients.contains(id)) recipients.add(id);
  }
  if (recipients.isEmpty || chatId.isEmpty) return null;

  final trimmed = text.trim();
  final preview = trimmed.isEmpty ? 'Sent a message' : trimmed;
  final body = preview.length > 140 ? '${preview.substring(0, 137)}...' : preview;
  return ChatMessageNotice(
    recipients: recipients,
    title: 'New message',
    body: body,
    payload: {
      'type': 'chat',
      'screen': 'chat',
      'chat_group_id': chatId,
    },
  );
}

/// Members whose user_groups row (or squad flag) says this chat is muted.
/// Unknown shapes are ignored so a missing column does not throw.
Set<String> mutedRecipientsFromUserRows({
  required String chatId,
  required List<Map<String, dynamic>> rows,
}) {
  final muted = <String>{};
  for (final row in rows) {
    final uid = row['uid']?.toString() ?? '';
    if (uid.isEmpty) continue;
    if (row['squad_chat_muted'] == true && row['squad_chat_id']?.toString() == chatId) {
      muted.add(uid);
      continue;
    }
    final groups = row['user_groups'];
    if (groups is! List) continue;
    for (final group in groups) {
      if (group is! Map) continue;
      final id = (group['id'] ?? group['chat_id'])?.toString();
      if (id != chatId) continue;
      final enabled = group['notifications_enabled'];
      if (enabled == false) muted.add(uid);
    }
  }
  return muted;
}

Map<String, int> addUnread(
  Map<String, int> counts,
  String chatGroupId,
  int by,
) {
  if (chatGroupId.isEmpty || by <= 0) return counts;
  final next = Map<String, int>.from(counts);
  next[chatGroupId] = (next[chatGroupId] ?? 0) + by;
  return next;
}

/// Opening a group zeros only that group.
Map<String, int> clearUnread(Map<String, int> counts, String chatGroupId) {
  if (!counts.containsKey(chatGroupId)) return counts;
  final next = Map<String, int>.from(counts);
  next[chatGroupId] = 0;
  return next;
}

int incomingFromOthers({
  required List<String> newSenderIds,
  required String? currentUserId,
  required bool threadIsOpen,
}) {
  if (threadIsOpen) return 0;
  var count = 0;
  for (final sender in newSenderIds) {
    if (currentUserId != null && sender == currentUserId) continue;
    count++;
  }
  return count;
}
