import 'package:flutter/foundation.dart';

import '../domain/entities/message.dart';

/// Messages for the open thread. Prefer the owner (MessageNotifier)
/// map; fall back to ChatNotifier only when the owner has no key yet.
List<Message> messagesForOpenThread({
  required String? threadId,
  required Map<String, List<Message>> ownerMessages,
  Map<String, List<Message>> fallback = const {},
}) {
  if (threadId == null || threadId.isEmpty) return const [];
  if (ownerMessages.containsKey(threadId)) {
    return ownerMessages[threadId]!;
  }
  return fallback[threadId] ?? const [];
}

/// Larger page wins. A smaller remote never beats a larger cache.
/// Equal length: merge by id so extra cached ids are not clobbered.
List<Message> preferRemoteMessagePage({
  required List<Message> cached,
  required List<Message> remote,
}) {
  if (remote.length > cached.length) return remote;
  if (cached.length > remote.length) return cached;
  if (remote.isEmpty) return cached;
  return mergeMessagePages(cached: cached, remote: remote);
}

/// Overlay remote onto cache by id. Cache-only ids survive.
List<Message> mergeMessagePages({
  required List<Message> cached,
  required List<Message> remote,
}) {
  if (remote.isEmpty) return cached;
  if (cached.isEmpty) return remote;
  final byId = <String, Message>{};
  for (final message in cached) {
    byId[message.id] = message;
  }
  for (final message in remote) {
    byId[message.id] = message;
  }
  return byId.values.toList();
}

/// Among lobby/widget/squad ids, use the thread that actually has history.
/// Example: 1766267555951 (1 row) vs 1766270568521 (46) → live thread.
/// Does not invent messages. Server rows are not written.
String? preferChatIdWithHistory({
  required List<String?> candidates,
  Map<String, int> historyCounts = const {},
}) {
  final ids = <String>[];
  for (final id in candidates) {
    if (id != null && id.isNotEmpty && !ids.contains(id)) {
      ids.add(id);
    }
  }
  if (ids.isEmpty) return null;
  if (ids.length == 1) return ids.first;
  if (historyCounts.values.any((count) => count > 0)) {
    var best = ids.first;
    var bestCount = historyCounts[best] ?? 0;
    for (final id in ids.skip(1)) {
      final count = historyCounts[id] ?? 0;
      if (count > bestCount) {
        best = id;
        bestCount = count;
      }
    }
    return best;
  }
  return ids.first;
}

/// PostgREST may return `chat_id` as int or String for epoch ids.
bool sameChatId(Object? left, Object? right) {
  if (left == null || right == null) return false;
  return left.toString() == right.toString();
}

/// `is_deleted` is often NULL/0 on older rows. Only explicit true is gone.
bool isLiveChatMessageRow(Map<String, dynamic> row) {
  final deleted = row['is_deleted'];
  if (deleted == true ||
      deleted == 1 ||
      deleted == 'true' ||
      deleted == '1' ||
      deleted == 't') {
    return false;
  }
  return true;
}

String chatRowId(Map<String, dynamic> row) {
  final id = row['id'];
  if (id != null && id.toString().isNotEmpty) return id.toString();
  final stamp = row['created_at'] ?? row['timestamp'] ?? '';
  final text = row['text'] ?? '';
  return 'row_${stamp}_$text';
}

/// Keep every live row. Wrong-thread / explicit delete only.
/// 19e7d1f smoke: raw=46 with deleted id bcbbe08b-… → Got 45 is correct.
Message? parseLiveChatMessage(
  Map<String, dynamic> row, {
  Object? expectedChatId,
}) {
  if (expectedChatId != null &&
      row.containsKey('chat_id') &&
      !sameChatId(row['chat_id'], expectedChatId)) {
    return null;
  }
  if (!isLiveChatMessageRow(row)) {
    debugPrint('parseLiveChatMessage skip deleted id=${row['id']}');
    return null;
  }
  try {
    final message = Message.fromJson(row);
    if (message.id.isEmpty) {
      return message.copyWith(id: chatRowId(row));
    }
    return message;
  } catch (e) {
    debugPrint('parseLiveChatMessage recovered id=${row['id']}: $e');
    return Message(
      id: chatRowId(row),
      senderId: row['sender_id']?.toString() ??
          row['senderId']?.toString() ??
          '',
      text: row['text']?.toString() ?? '',
      timestamp: const TimestampConverter().fromJson(
        (row['timestamp'] is String &&
                (row['timestamp'] as String).isEmpty)
            ? row['created_at']
            : (row['timestamp'] ?? row['created_at']),
      ),
      messageType: MessageType.text,
    );
  }
}
