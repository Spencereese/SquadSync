import 'dart:async';
import 'dart:io';

import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/core/sq8_database.dart';
import 'package:squadsync/features/chat/data/chat_repository.dart';
import 'package:squadsync/features/chat/domain/chat_message.dart';
import 'package:squadsync/features/chat/domain/message_history.dart';
import 'package:squadsync/features/chat/domain/messenger.dart';
import 'package:squadsync/features/chat/domain/send_machine.dart';
import 'package:squadsync/features/chat/domain/typing.dart';
import 'package:squadsync/features/chat/domain/unread.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._db, [this._client]);

  final Sq8Database _db;
  final SupabaseClient? _client;
  var _messengerOff = false;
  final Map<String, RealtimeChannel> _typingChannels = {};
  final Map<String, StreamController<Set<String>>> _typingRooms = {};
  final Map<String, TypingRoster> _typingRosters = {};

  @override
  Future<HistoryPage> newest(String chatId, {int limit = openPageSize}) async {
    final rows = await _db.newestMessages(chatId, limit: limit + 1);
    return _page(rows, limit, await _quoteBodies(rows));
  }

  @override
  Future<HistoryPage> before(
    String chatId, {
    required ChatMessage cursor,
    int limit = olderPageSize,
  }) async {
    final rows = await _db.olderMessages(
      chatId,
      before: cursor.sentAt,
      beforeId: cursor.id,
      limit: limit + 1,
    );
    return _page(rows, limit, await _quoteBodies(rows));
  }

  @override
  Future<SendOutcome> send(ChatMessage message) async {
    try {
      await _insert(message, withReply: message.replyToId != null);
    } on Sq8DuplicateRow {
      return SendConflict(message.id);
    } on RepositoryFailure catch (error) {
      if (message.replyToId != null &&
          messengerTableMissing(error.code, error.message)) {
        _messengerOff = true;
        await _insert(message, withReply: false);
        return SendConfirmed(message.id);
      }
      rethrow;
    }
    return SendConfirmed(message.id);
  }

  Future<void> _insert(ChatMessage message, {required bool withReply}) {
    return _db.insertMessage(
      Sq8Message(
        id: message.id,
        squadId: message.chatId,
        senderId: message.senderId,
        body: message.text,
        sentAt: message.sentAt,
        replyToId: withReply ? message.replyToId : null,
      ),
    );
  }

  @override
  Stream<List<ChatMessage>> watch(String chatId) {
    return _db.watchInserts(chatId).asyncMap((row) async {
      final quotes = await _quoteBodies([row]);
      return [_toMessage(row, quotes)];
    });
  }

  @override
  Future<UnreadBook> unread() async {
    final squadId = await _db.mySquadId();
    if (squadId == null) return const UnreadBook();
    final cursor = await _db.readCursor(squadId);
    final count = await _db.unreadCount(squadId, cursor);
    return UnreadBook({squadId: count});
  }

  @override
  Future<void> saveUnread(UnreadBook book) async {
    final squadId = await _db.mySquadId();
    if (squadId == null || !book.counts.containsKey(squadId)) return;
    if (book.of(squadId) != 0) return;
    final latest = await _db.newestMessages(squadId, limit: 1);
    final message = latest.isEmpty ? null : latest.first;
    await _db.upsertCursor(
      squadId: squadId,
      lastReadAt: message?.sentAt ?? DateTime.now().toUtc(),
      lastReadId: message?.id,
    );
  }

  @override
  Future<String?> readThrough(String chatId) async {
    final cursor = await _db.readCursor(chatId);
    return cursor?.lastReadId;
  }

  @override
  Future<MessengerBoard> messenger(String chatId) async {
    final client = _client;
    if (client == null || _messengerOff) return MessengerBoard.disabled;
    try {
      final reactionRows = await client
          .from('sq8_message_reactions')
          .select('message_id, user_id, emoji')
          .eq('squad_id', chatId);
      final readRows = await client
          .from('sq8_message_reads')
          .select('user_id, last_read_at, last_read_id')
          .eq('squad_id', chatId);
      return MessengerBoard(
        enabled: true,
        reactions: [
          for (final row in reactionRows)
            MessageReaction(
              messageId: row['message_id'] as String,
              userId: row['user_id'] as String,
              emoji: row['emoji'] as String,
            ),
        ],
        reads: [
          for (final row in readRows)
            MemberRead(
              userId: row['user_id'] as String,
              readAt: DateTime.parse(row['last_read_at'] as String),
              messageId: row['last_read_id'] as String?,
            ),
        ],
      );
    } on PostgrestException catch (error) {
      if (messengerTableMissing(error.code, error.message)) {
        _messengerOff = true;
        return MessengerBoard.disabled;
      }
      throw RepositoryFailure(error.message, code: error.code);
    }
  }

  @override
  Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
  }) async {
    final client = _client;
    final me = _db.userId;
    if (client == null || me == null || _messengerOff) return;
    if (!isQuickReaction(emoji)) return;
    try {
      final existing = await client
          .from('sq8_message_reactions')
          .select('emoji')
          .eq('message_id', messageId)
          .eq('user_id', me)
          .eq('emoji', emoji)
          .maybeSingle();
      if (existing == null) {
        await client.from('sq8_message_reactions').insert({
          'message_id': messageId,
          'squad_id': chatId,
          'user_id': me,
          'emoji': emoji,
        });
      } else {
        await client
            .from('sq8_message_reactions')
            .delete()
            .eq('message_id', messageId)
            .eq('user_id', me)
            .eq('emoji', emoji);
      }
    } on PostgrestException catch (error) {
      if (messengerTableMissing(error.code, error.message)) {
        _messengerOff = true;
        return;
      }
      throw RepositoryFailure(error.message, code: error.code);
    }
  }

  @override
  Future<void> saveReadReceipt({
    required String chatId,
    required String messageId,
    required DateTime readAt,
  }) async {
    final client = _client;
    final me = _db.userId;
    if (client == null || me == null || _messengerOff) return;
    try {
      await client.from('sq8_message_reads').upsert({
        'user_id': me,
        'squad_id': chatId,
        'last_read_at': readAt.toUtc().toIso8601String(),
        'last_read_id': messageId,
      }, onConflict: 'user_id,squad_id');
    } on PostgrestException catch (error) {
      if (messengerTableMissing(error.code, error.message)) {
        _messengerOff = true;
        return;
      }
      throw RepositoryFailure(error.message, code: error.code);
    }
  }

  @override
  Stream<MessengerEvent> watchMessenger(String chatId) {
    final client = _client;
    if (client == null || _messengerOff) return const Stream.empty();
    final controller = StreamController<MessengerEvent>.broadcast();
    final channel = client.channel('sq8-messenger-$chatId');
    void emit(MessengerEvent event) {
      if (!controller.isClosed) controller.add(event);
    }

    for (final event in [
      PostgresChangeEvent.insert,
      PostgresChangeEvent.update,
    ]) {
      channel.onPostgresChanges(
        event: event,
        schema: 'public',
        table: 'sq8_message_reactions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'squad_id',
          value: chatId,
        ),
        callback: (payload) {
          emit(
            MessengerEvent(
              table: 'sq8_message_reactions',
              deleted: false,
              squadId: payload.newRecord['squad_id']?.toString(),
              messageId: payload.newRecord['message_id']?.toString(),
              userId: payload.newRecord['user_id']?.toString(),
            ),
          );
        },
      );
      channel.onPostgresChanges(
        event: event,
        schema: 'public',
        table: 'sq8_message_reads',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'squad_id',
          value: chatId,
        ),
        callback: (payload) {
          emit(
            MessengerEvent(
              table: 'sq8_message_reads',
              deleted: false,
              squadId: payload.newRecord['squad_id']?.toString(),
              messageId: payload.newRecord['last_read_id']?.toString(),
              userId: payload.newRecord['user_id']?.toString(),
            ),
          );
        },
      );
    }
    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'sq8_message_reactions',
      callback: (payload) {
        emit(
          MessengerEvent(
            table: 'sq8_message_reactions',
            deleted: true,
            messageId: payload.oldRecord['message_id']?.toString(),
            userId: payload.oldRecord['user_id']?.toString(),
          ),
        );
      },
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'sq8_message_reads',
      callback: (payload) {
        emit(
          MessengerEvent(
            table: 'sq8_message_reads',
            deleted: true,
            squadId: payload.oldRecord['squad_id']?.toString(),
            userId: payload.oldRecord['user_id']?.toString(),
          ),
        );
      },
    );
    channel.subscribe();
    controller.onCancel = () {
      unawaited(client.removeChannel(channel));
    };
    return controller.stream;
  }

  @override
  Stream<Set<String>> watchTyping(String chatId) {
    final client = _client;
    final me = _db.userId;
    if (client == null) return const Stream.empty();
    final open = _typingRooms[chatId];
    if (open != null && !open.isClosed) return open.stream;

    final controller = StreamController<Set<String>>.broadcast();
    final roster = TypingRoster();
    _typingRooms[chatId] = controller;
    _typingRosters[chatId] = roster;
    final channel = _typingChannel(chatId);
    channel.onBroadcast(
      event: 'typing',
      callback: (payload) {
        final id = payload['user_id']?.toString() ?? '';
        if (id.isEmpty || id == me) return;
        final names = roster.apply(
          userId: id,
          typing: payload['typing'] == true,
          emit: (left) {
            if (!controller.isClosed) controller.add(left);
          },
        );
        if (!controller.isClosed) controller.add(names);
      },
    );
    controller.onCancel = () async {
      final meId = _db.userId;
      if (meId != null) {
        try {
          await channel.sendBroadcastMessage(
            event: 'typing',
            payload: {'user_id': meId, 'typing': false},
          );
        } on Object {
          // The other phone drops a typer after a few seconds.
        }
      }
      roster.dispose();
      _typingRooms.remove(chatId);
      _typingRosters.remove(chatId);
      final live = _typingChannels.remove(chatId);
      if (live != null) await client.removeChannel(live);
    };
    return controller.stream;
  }

  @override
  Future<void> setTyping(String chatId, {required bool typing}) async {
    final me = _db.userId;
    final channel = _typingChannels[chatId];
    if (me == null || channel == null) return;
    await channel.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': me, 'typing': typing},
    );
  }

  RealtimeChannel _typingChannel(String chatId) {
    final client = _client!;
    final existing = _typingChannels[chatId];
    if (existing != null) return existing;
    final channel = client.channel('sq8-typing-$chatId');
    channel.subscribe();
    _typingChannels[chatId] = channel;
    return channel;
  }

  Future<Map<String, String>> _quoteBodies(List<Sq8Message> rows) async {
    final ids = [
      for (final row in rows)
        if (row.replyToId != null) row.replyToId!,
    ];
    if (ids.isEmpty) return const {};
    try {
      return await _db.messageBodies(ids);
    } on RepositoryFailure {
      // A PostgREST refusal must not drop the thread. Each reply falls back.
      return const {};
    } catch (error) {
      // SocketException, package:http ClientException, and TimeoutException
      // are the network failures. PostgREST already arrived as
      // RepositoryFailure above. http stays transitive, so ClientException
      // is matched by type name.
      if (error is SocketException ||
          error is TimeoutException ||
          error.runtimeType.toString() == 'ClientException') {
        return const {};
      }
      rethrow;
    }
  }

  HistoryPage _page(
    List<Sq8Message> newestFirst,
    int limit,
    Map<String, String> quotes,
  ) {
    final hasOlder = newestFirst.length > limit;
    final window = newestFirst.take(limit).toList().reversed;
    return HistoryPage(
      messages: [for (final row in window) _toMessage(row, quotes)],
      hasOlder: hasOlder,
    );
  }

  ChatMessage _toMessage(Sq8Message row, Map<String, String> quotes) {
    final mine = row.senderId == _db.userId;
    final replyId = row.replyToId;
    return ChatMessage(
      id: row.id,
      chatId: row.squadId,
      senderId: row.senderId,
      text: row.body,
      sentAt: row.sentAt,
      delivery: mine ? Delivery.sent : null,
      replyToId: replyId,
      replyText: replyId == null
          ? null
          : (quotes[replyId] ?? originalMessageUnavailable),
    );
  }
}
