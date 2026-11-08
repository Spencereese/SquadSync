import 'package:flutter/foundation.dart';

import '../services/supabase_service.dart';
import 'chat_inbox.dart';

/// Optional `chat_read_states` rows. Missing table or column is a no-op
/// and the in-memory count on ChatState stays the badge.
class ChatReadStateStore {
  static Future<void> write({
    required String userId,
    required String chatId,
    required int unreadCount,
  }) async {
    if (userId.isEmpty || chatId.isEmpty) return;
    try {
      final client = SupabaseService.maybeClient;
      if (client == null) return;
      await client.from('chat_read_states').upsert(
        {
          'user_id': userId,
          'chat_id': chatId,
          'unread_count': unreadCount,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,chat_id',
      );
    } catch (e) {
      debugPrint('chat_read_states write skipped: $e');
    }
  }

  static Future<Map<String, int>?> load(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final client = SupabaseService.maybeClient;
      if (client == null) return null;
      final rows = await client
          .from('chat_read_states')
          .select('chat_id, unread_count')
          .eq('user_id', userId);
      final counts = <String, int>{};
      for (final row in rows) {
        final id = row['chat_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final count = row['unread_count'];
        counts[id] = count is int ? count : int.tryParse('$count') ?? 0;
      }
      return counts;
    } catch (e) {
      debugPrint('chat_read_states read skipped: $e');
      return null;
    }
  }
}

/// Best-effort member list and mute flags. Any missing table or column
/// returns what it could, or null when the group itself cannot be read.
Future<ChatMessageNotice?> noticeForSavedChat({
  required String chatId,
  required String senderId,
  required String text,
}) async {
  try {
    final client = SupabaseService.maybeClient;
    if (client == null) return null;
    final row = await client
        .from('chat_groups')
        .select('member_uids')
        .eq('id', chatId)
        .maybeSingle();
    final members = <String>[];
    final raw = row?['member_uids'];
    if (raw is List) {
      for (final id in raw) {
        final textId = id?.toString() ?? '';
        if (textId.isNotEmpty) members.add(textId);
      }
    }
    var muted = <String>{};
    if (members.isNotEmpty) {
      try {
        final rows = await client
            .from('users')
            .select('uid, user_groups, squad_chat_muted, squad_chat_id')
            .inFilter('uid', members);
        muted = mutedRecipientsFromUserRows(
          chatId: chatId,
          rows: [
            for (final row in rows) Map<String, dynamic>.from(row as Map),
          ],
        );
      } catch (e) {
        debugPrint('chat mute lookup skipped: $e');
      }
    }
    return noticeForSavedMessage(
      memberUids: members,
      senderId: senderId,
      chatId: chatId,
      text: text,
      mutedRecipientIds: muted,
    );
  } catch (e) {
    debugPrint('chat notify members skipped: $e');
    return null;
  }
}
