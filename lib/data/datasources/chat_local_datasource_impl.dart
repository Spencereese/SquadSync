import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:squad_sync/chat/sqlite_helper.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/entities/chat_group.dart';
import 'package:squad_sync/data/datasources/chat_local_datasource.dart';

class ChatLocalDataSourceImpl implements ChatLocalDataSource {
  final SQLiteHelper _sqliteHelper;

  ChatLocalDataSourceImpl(this._sqliteHelper);

  @override
  Future<void> cacheMessages(String chatGroupId, List<Message> messages) async {
    final db = await _sqliteHelper.database;
    final batch = db.batch();

    for (final message in messages) {
      batch.insert(
        'messages',
        {
          'id': message.id,
          'chat_group_id': chatGroupId,
          'sender_id': message.senderId,
          'sender_name': message.senderId, // Use senderId as fallback
          'text': message.text,
          'timestamp_ms': message.timestamp.millisecondsSinceEpoch,
          'content': message.text, // Duplicate for compatibility
          'message_type': message.messageType.toString(),
          'media_url': message.mediaUrl,
          'media_type': message.mediaType,
          'reactions': message.reactions != null
              ? jsonEncode(Map<String, dynamic>.from(message.reactions!))
              : null,
          'reply_to': message.replyTo,
          'poll':
              message.poll != null ? jsonEncode(message.poll!.toJson()) : null,
          'voice_note_url': message.voiceNoteUrl,
          'voice_note_duration': message.voiceNoteDuration,
          'ai_response': message.aiResponse,
          'metadata': message.metadata,
          'is_edited': (message.isEdited ?? false) ? 1 : 0,
          'edited_at': message.editedAt?.toIso8601String(),
          'is_deleted': (message.isDeleted ?? false) ? 1 : 0,
          'deleted_at': message.deletedAt?.toIso8601String(),
          'synced': 1,
          'delivered': 1, // Assume delivered for cached messages
          'read': 0, // Will be updated separately
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
  }

  @override
  Future<List<Message>> getCachedMessages(String chatGroupId,
      {int limit = 50, DateTime? before}) async {
    final db = await _sqliteHelper.database;
    final whereClause = before != null
        ? 'chat_group_id = ? AND timestamp_ms < ?'
        : 'chat_group_id = ?';
    final whereArgs = before != null
        ? [chatGroupId, before.millisecondsSinceEpoch]
        : [chatGroupId];

    final maps = await db.query(
      'messages',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp_ms DESC',
      limit: limit,
    );

    return maps
        .where((map) => map['sender_id'] != null && map['text'] != null)
        .map((map) => Message.fromJson({
              'id': map['id'],
              'senderId': map['sender_id'],
              'text': map['text'],
              'timestamp': map['timestamp_ms'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      map['timestamp_ms'] as int)
                  : map['timestamp'] is DateTime
                      ? map['timestamp'] as DateTime
                      : DateTime.parse(
                          map['timestamp'] as String), // Fallback for old data
              'messageType': MessageType.values.firstWhere(
                (e) => e.toString() == map['message_type'],
                orElse: () => MessageType.text,
              ),
              'mediaUrl': map['media_url'],
              'mediaType': map['media_type'],
              'reactions': map['reactions'] != null
                  ? jsonDecode(map['reactions'] as String)
                      as Map<String, dynamic>
                  : null,
              'replyTo': map['reply_to'],
              'poll': map['poll'] != null
                  ? jsonDecode(map['poll'] as String) as Map<String, dynamic>
                  : null,
              'voiceNoteUrl': map['voice_note_url'],
              'voiceNoteDuration': map['voice_note_duration'],
              'aiResponse': map['ai_response'],
              'metadata': map['metadata'] != null
                  ? jsonDecode(map['metadata'] as String)
                      as Map<String, dynamic>
                  : null,
              'isEdited': map['is_edited'] == 1,
              'editedAt': map['edited_at'] != null
                  ? DateTime.parse(map['edited_at'] as String)
                  : null,
              'isDeleted': map['is_deleted'] == 1,
              'deletedAt': map['deleted_at'] != null
                  ? DateTime.parse(map['deleted_at'] as String)
                  : null,
            }))
        .toList();
  }

  @override
  Future<void> updateMessage(
      String chatGroupId, String messageId, Message message) async {
    await cacheMessages(chatGroupId, [message]);
  }

  @override
  Future<void> deleteMessage(String chatGroupId, String messageId) async {
    final db = await _sqliteHelper.database;
    await db.update(
      'messages',
      {'is_deleted': 1, 'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND chat_group_id = ?',
      whereArgs: [messageId, chatGroupId],
    );
  }

  @override
  Future<void> cacheChatGroups(List<ChatGroup> groups) async {
    final db = await _sqliteHelper.database;
    final batch = db.batch();

    for (final group in groups) {
      batch.insert(
        'chat_groups',
        {
          'id': group.id,
          'name': group.name,
          'member_uids': group.memberUids.join(','),
          'is_public': group.isPublic ? 1 : 0,
          'member_count': group.memberCount,
          'created_by': group.createdBy,
          'created_at': group.createdAt.toIso8601String(),
          'description': group.description,
          'avatar_url': group.avatarUrl,
          'metadata': group.metadata,
          'admins': group.admins?.join(','),
          'moderators': group.moderators?.join(','),
          'is_active': group.isActive ?? true ? 1 : 0,
          'last_activity': group.lastActivity?.toIso8601String(),
          'settings': group.settings,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
  }

  @override
  Future<List<ChatGroup>> getCachedChatGroups() async {
    final db = await _sqliteHelper.database;
    final maps = await db.query('chat_groups');

    return maps
        .map((map) => ChatGroup(
              id: map['id'] as String,
              name: map['name'] as String,
              memberUids: (map['member_uids'] as String).split(','),
              isPublic: map['is_public'] == 1,
              memberCount: map['member_count'] as int,
              createdBy: map['created_by'] as String,
              createdAt: DateTime.parse(map['created_at'] as String),
              description: map['description'] as String?,
              avatarUrl: map['avatar_url'] as String?,
              metadata: map['metadata'] as Map<String, dynamic>?,
              admins: map['admins'] != null
                  ? (map['admins'] as String).split(',')
                  : null,
              moderators: map['moderators'] != null
                  ? (map['moderators'] as String).split(',')
                  : null,
              isActive: map['is_active'] == 1,
              lastActivity: map['last_activity'] != null
                  ? DateTime.parse(map['last_activity'] as String)
                  : null,
              settings: map['settings'] as Map<String, dynamic>?,
            ))
        .toList();
  }

  @override
  Future<void> updateChatGroup(ChatGroup group) async {
    await cacheChatGroups([group]);
  }

  @override
  Future<void> markMessagesAsSynced(
      String chatGroupId, List<String> messageIds) async {
    final db = await _sqliteHelper.database;
    await db.update(
      'messages',
      {'synced': 1},
      where:
          'chat_group_id = ? AND id IN (${List.filled(messageIds.length, '?').join(',')})',
      whereArgs: [chatGroupId, ...messageIds],
    );
  }

  @override
  Future<List<Message>> getUnsyncedMessages(String chatGroupId) async {
    final db = await _sqliteHelper.database;
    final maps = await db.query(
      'messages',
      where: 'chat_group_id = ? AND synced = 0',
      whereArgs: [chatGroupId],
    );

    return maps
        .map((map) => Message.fromJson({
              'id': map['id'],
              'senderId': map['sender_id'],
              'text': map['text'],
              'timestamp': map['timestamp_ms'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      map['timestamp_ms'] as int)
                  : DateTime.parse(
                      map['timestamp'] as String), // Fallback for old data
              'messageType': MessageType.values.firstWhere(
                (e) => e.toString() == map['message_type'],
                orElse: () => MessageType.text,
              ),
              'mediaUrl': map['media_url'],
              'mediaType': map['media_type'],
              'reactions': map['reactions'] != null
                  ? jsonDecode(map['reactions'] as String)
                      as Map<String, dynamic>
                  : null,
              'replyTo': map['reply_to'],
              'poll': map['poll'] != null
                  ? jsonDecode(map['poll'] as String) as Map<String, dynamic>
                  : null,
              'voiceNoteUrl': map['voice_note_url'],
              'voiceNoteDuration': map['voice_note_duration'],
              'aiResponse': map['ai_response'],
              'metadata': map['metadata'] != null
                  ? jsonDecode(map['metadata'] as String)
                      as Map<String, dynamic>
                  : null,
              'isEdited': map['is_edited'] == 1,
              'editedAt': map['edited_at'] != null
                  ? DateTime.parse(map['edited_at'] as String)
                  : null,
              'isDeleted': map['is_deleted'] == 1,
              'deletedAt': map['deleted_at'] != null
                  ? DateTime.parse(map['deleted_at'] as String)
                  : null,
            }))
        .toList();
  }

  @override
  Future<void> updateLastSyncTimestamp(
      String chatGroupId, DateTime timestamp) async {
    final db = await _sqliteHelper.database;
    await db.insert(
      'sync_timestamps',
      {
        'chat_group_id': chatGroupId,
        'last_sync': timestamp.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<DateTime?> getLastSyncTimestamp(String chatGroupId) async {
    final db = await _sqliteHelper.database;
    final maps = await db.query(
      'sync_timestamps',
      where: 'chat_group_id = ?',
      whereArgs: [chatGroupId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return DateTime.parse(maps.first['last_sync'] as String);
    }
    return null;
  }

  @override
  Future<void> cacheReactions(
      String chatGroupId, String messageId, Map<String, int> reactions) async {
    final db = await _sqliteHelper.database;
    await db.insert(
      'message_reactions',
      {
        'chat_group_id': chatGroupId,
        'message_id': messageId,
        'reactions': reactions,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Map<String, int>?> getCachedReactions(
      String chatGroupId, String messageId) async {
    final db = await _sqliteHelper.database;
    final maps = await db.query(
      'message_reactions',
      where: 'chat_group_id = ? AND message_id = ?',
      whereArgs: [chatGroupId, messageId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Map<String, int>.from(maps.first['reactions'] as Map);
    }
    return null;
  }

  @override
  Future<void> cachePoll(String chatGroupId, Poll poll) async {
    final db = await _sqliteHelper.database;
    await db.insert(
      'polls',
      {
        'id': poll.id,
        'chat_group_id': chatGroupId,
        'question': poll.question,
        'options': poll.options,
        'votes': poll.votes,
        'created_at': poll.createdAt.toIso8601String(),
        'created_by': poll.createdBy,
        'is_closed': poll.isClosed ?? false ? 1 : 0,
        'closed_at': poll.closedAt?.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Map<String, Poll>> getCachedPolls(String chatGroupId) async {
    final db = await _sqliteHelper.database;
    final maps = await db.query(
      'polls',
      where: 'chat_group_id = ?',
      whereArgs: [chatGroupId],
    );

    final polls = <String, Poll>{};
    for (final map in maps) {
      final poll = Poll(
        id: map['id'] as String,
        question: map['question'] as String,
        options: List<String>.from(map['options'] as List),
        votes: Map<String, List<String>>.from(map['votes'] as Map),
        createdAt: DateTime.parse(map['created_at'] as String),
        createdBy: map['created_by'] as String,
        isClosed: map['is_closed'] == 1,
        closedAt: map['closed_at'] != null
            ? DateTime.parse(map['closed_at'] as String)
            : null,
      );
      polls[poll.id] = poll;
    }
    return polls;
  }

  @override
  Future<void> updateTypingIndicator(
      String chatGroupId, String userId, bool isTyping) async {
    final db = await _sqliteHelper.database;
    if (isTyping) {
      await db.insert(
        'typing_indicators',
        {
          'chat_group_id': chatGroupId,
          'user_id': userId,
          'timestamp': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db.delete(
        'typing_indicators',
        where: 'chat_group_id = ? AND user_id = ?',
        whereArgs: [chatGroupId, userId],
      );
    }
  }

  @override
  Future<Map<String, Set<String>>> getTypingIndicators(
      String chatGroupId) async {
    final db = await _sqliteHelper.database;
    final maps = await db.query(
      'typing_indicators',
      where: 'chat_group_id = ?',
      whereArgs: [chatGroupId],
    );

    final indicators = <String, Set<String>>{};
    for (final map in maps) {
      final groupId = map['chat_group_id'] as String;
      final userId = map['user_id'] as String;
      indicators.putIfAbsent(groupId, () => {}).add(userId);
    }
    return indicators;
  }

  @override
  Future<void> markAsRead(String chatGroupId, DateTime timestamp) async {
    final db = await _sqliteHelper.database;
    await db.insert(
      'read_timestamps',
      {
        'chat_group_id': chatGroupId,
        'user_id': 'current_user_id', // This should come from auth
        'timestamp': timestamp.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<DateTime?> getLastReadTimestamp(String chatGroupId) async {
    final db = await _sqliteHelper.database;
    final maps = await db.query(
      'read_timestamps',
      where: 'chat_group_id = ? AND user_id = ?',
      whereArgs: [chatGroupId, 'current_user_id'],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return DateTime.parse(maps.first['timestamp'] as String);
    }
    return null;
  }

  @override
  Future<void> cacheMediaHistory(List<Map<String, dynamic>> mediaItems) async {
    final db = await _sqliteHelper.database;
    final batch = db.batch();

    for (final item in mediaItems) {
      batch.insert(
        'media_history',
        {
          'id': item['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'chat_group_id': item['chatGroupId'],
          'url': item['url'],
          'type': item['type'],
          'uploaded_by': item['uploadedBy'],
          'uploaded_at': item['uploadedAt'] ?? DateTime.now().toIso8601String(),
          'file_name': item['fileName'],
          'file_size': item['fileSize'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
  }

  @override
  Future<List<Map<String, dynamic>>> getCachedMediaHistory(
      String chatGroupId) async {
    final db = await _sqliteHelper.database;
    final maps = await db.query(
      'media_history',
      where: 'chat_group_id = ?',
      whereArgs: [chatGroupId],
      orderBy: 'uploaded_at DESC',
    );

    return maps
        .map((map) => {
              'id': map['id'],
              'chatGroupId': map['chat_group_id'],
              'url': map['url'],
              'type': map['type'],
              'uploadedBy': map['uploaded_by'],
              'uploadedAt': map['uploaded_at'],
              'fileName': map['file_name'],
              'fileSize': map['file_size'],
            })
        .toList();
  }

  @override
  Future<void> purgeOldMessages(
      {Duration maxAge = const Duration(days: 30)}) async {
    final db = await _sqliteHelper.database;
    final cutoffDate = DateTime.now().subtract(maxAge).toIso8601String();
    await db.delete(
      'messages',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate],
    );
  }

  @override
  Future<void> purgeOldMedia(
      {Duration maxAge = const Duration(days: 30)}) async {
    final db = await _sqliteHelper.database;
    final cutoffDate = DateTime.now().subtract(maxAge).toIso8601String();
    await db.delete(
      'media_history',
      where: 'uploaded_at < ?',
      whereArgs: [cutoffDate],
    );
  }

  @override
  Future<void> cacheAnalytics(
      String chatGroupId, Map<String, dynamic> analytics) async {
    final db = await _sqliteHelper.database;
    await db.insert(
      'chat_analytics',
      {
        'chat_group_id': chatGroupId,
        'analytics': analytics,
        'timestamp': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Map<String, dynamic>?> getCachedAnalytics(String chatGroupId) async {
    final db = await _sqliteHelper.database;
    final maps = await db.query(
      'chat_analytics',
      where: 'chat_group_id = ?',
      whereArgs: [chatGroupId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return maps.first['analytics'] as Map<String, dynamic>;
    }
    return null;
  }
}
