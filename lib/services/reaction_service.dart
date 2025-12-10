import 'auth_service_supabase.dart';
import 'supabase_service.dart';
import '../domain/entities/message.dart';

/// Service for managing message reactions
class ReactionService {
  final AuthServiceSupabase _authService = AuthServiceSupabase();

  /// Add a reaction to a message
  Future<void> addReaction({
    required String chatGroupId,
    required String messageId,
    required String emoji,
    required ChatType chatType,
  }) async {
    final user = _authService.currentUser;
    if (user == null) return;

    await SupabaseService.client.from('reactions').upsert({
      'message_id': messageId,
      'user_id': user.id,
      'emoji': emoji,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Remove a reaction from a message
  Future<void> removeReaction({
    required String chatGroupId,
    required String messageId,
    required String emoji,
    required ChatType chatType,
  }) async {
    final user = _authService.currentUser;
    if (user == null) return;

    await SupabaseService.client
        .from('reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', user.id)
        .eq('emoji', emoji);
  }

  /// Get reactions for a message
  Stream<Map<String, List<String>>> getMessageReactions({
    required String chatGroupId,
    required String messageId,
    required ChatType chatType,
  }) {
    final user = _authService.currentUser;
    if (user == null) return Stream.value({});

    return SupabaseService.client
        .from('reactions')
        .stream(primaryKey: ['id'])
        .eq('message_id', messageId)
        .map((data) {
          final reactions = <String, List<String>>{};

          for (final row in data) {
            final emoji = row['emoji'] as String;
            final userId = row['user_id'] as String;

            if (!reactions.containsKey(emoji)) {
              reactions[emoji] = [];
            }
            reactions[emoji]!.add(userId);
          }

          return reactions;
        });
  }

  /// Check if current user has reacted with specific emoji
  Future<bool> hasUserReacted({
    required String chatGroupId,
    required String messageId,
    required String emoji,
    required ChatType chatType,
  }) async {
    final user = _authService.currentUser;
    if (user == null) return false;

    final data = await SupabaseService.client
        .from('reactions')
        .select('id')
        .eq('message_id', messageId)
        .eq('user_id', user.id)
        .eq('emoji', emoji)
        .maybeSingle();

    return data != null;
  }
}
