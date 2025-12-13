import 'package:flutter/material.dart';
import '../../services/auth_service_supabase.dart';
import '../../services/supabase_service.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/message.dart';

class ReactionService {
  static Future<void> addReaction(
    BuildContext context,
    String emoji,
    String messageId,
    String? chatGroupId,
    ChatType chatType,
    String? squadId,
  ) async {
    try {
      final userId = AuthServiceSupabase().currentUser?.id;
      if (userId == null || messageId.isEmpty || emoji.isEmpty) {
        debugPrint(
            'Invalid reaction data: userId=$userId, messageId=$messageId, emoji="$emoji"');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to add reaction: Invalid data')),
          );
        }
        return;
      }

      debugPrint(
          'Adding reaction: emoji=$emoji, messageId=$messageId, userId=$userId');

      // Check if user already reacted with this emoji
      final existingReaction = await SupabaseService.client
          .from('reactions')
          .select()
          .eq('message_id', messageId)
          .eq('user_id', userId)
          .eq('emoji', emoji)
          .maybeSingle();

      if (existingReaction != null) {
        // User already reacted with this emoji, remove it
        await SupabaseService.client
            .from('reactions')
            .delete()
            .eq('id', existingReaction['id']);
        debugPrint(
            '✅ Removed existing reaction: $emoji from message $messageId');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Removed $emoji reaction'),
                duration: const Duration(seconds: 1)),
          );
        }
      } else {
        // User hasn't reacted with this emoji, add it
        await SupabaseService.client.from('reactions').insert({
          'message_id': messageId,
          'user_id': userId,
          'emoji': emoji.trim(),
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ Added new reaction: $emoji to message $messageId');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Added $emoji reaction'),
                duration: const Duration(seconds: 1)),
          );
        }
      }

      // Also update the message's reactions JSONB column for real-time UI updates
      await _updateMessageReactionsColumn(
          messageId, emoji, userId, existingReaction != null);

      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Error updating reaction: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update reaction: ${e.toString()}')),
        );
      }
    }
  }

  /// Update the message's reactions JSONB column
  static Future<void> _updateMessageReactionsColumn(
    String messageId,
    String emoji,
    String userId,
    bool isRemoving,
  ) async {
    try {
      // Fetch current message reactions
      final response = await SupabaseService.client
          .from('chat_messages')
          .select('reactions')
          .eq('id', messageId)
          .single();

      final Map<String, dynamic> reactions =
          Map<String, dynamic>.from(response['reactions'] ?? {});

      // Toggle reaction in JSONB
      if (isRemoving) {
        final List<dynamic> users = List<dynamic>.from(reactions[emoji] ?? []);
        users.remove(userId);
        if (users.isEmpty) {
          reactions.remove(emoji);
        } else {
          reactions[emoji] = users;
        }
      } else {
        final List<dynamic> users = List<dynamic>.from(reactions[emoji] ?? []);
        if (!users.contains(userId)) {
          users.add(userId);
          reactions[emoji] = users;
        }
      }

      // Update message with new reactions
      await SupabaseService.client
          .from('chat_messages')
          .update({'reactions': reactions}).eq('id', messageId);

      debugPrint('✅ Updated message reactions JSONB column');
    } catch (e) {
      debugPrint('⚠️ Failed to update message reactions column: $e');
    }
  }
}
