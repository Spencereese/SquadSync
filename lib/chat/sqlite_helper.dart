import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

class SQLiteHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'squadsync.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            sender_name TEXT,
            timestamp_ms INTEGER,
            content TEXT,
            photos TEXT,
            videos TEXT,
            audio TEXT,
            reactions TEXT,
            is_geoblocked_for_viewer INTEGER,
            is_unsent_image_by_messenger_kid_parent INTEGER,
            delivered INTEGER,
            read INTEGER,
            reply_to TEXT,
            created_at TEXT,
            chat_group_id TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add chat_group_id column to existing databases
          await db
              .execute('ALTER TABLE messages ADD COLUMN chat_group_id TEXT');
        }
      },
    );
  }

  Future<void> insertMessage(Map<String, dynamic> message,
      {String? chatGroupId}) async {
    try {
      final db = await database;
      await db.insert(
        'messages',
        {
          'id': message['id'],
          'sender_name': message['sender_name'] ?? message['sender'],
          'timestamp_ms': message['timestamp_ms'],
          'content': message['content'] ?? message['text'],
          'photos': jsonEncode(message['photos'] ?? []),
          'videos': jsonEncode(message['videos'] ?? []),
          'audio': jsonEncode(message['audio'] ?? []),
          'reactions': jsonEncode(message['reactions'] ?? []),
          'is_geoblocked_for_viewer':
              message['is_geoblocked_for_viewer'] ? 1 : 0,
          'is_unsent_image_by_messenger_kid_parent':
              message['is_unsent_image_by_messenger_kid_parent'] ? 1 : 0,
          'delivered': message['delivered'] ? 1 : 0,
          'read': message['read'] ? 1 : 0,
          'reply_to': message['reply_to'],
          'created_at':
              message['created_at'] ?? DateTime.now().toIso8601String(),
          'chat_group_id': chatGroupId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Failed to insert message to SQLite: $e');
    }
  }

  Future<void> updateMessage(String msgId, Map<String, dynamic> updates) async {
    try {
      final db = await database;
      await db.update(
        'messages',
        {
          'reactions': updates['reactions'] != null
              ? jsonEncode(updates['reactions'])
              : null,
        },
        where: 'id = ?',
        whereArgs: [msgId],
      );
    } catch (e) {
      debugPrint('Failed to update message in SQLite: $e');
    }
  }

  // In sqlite_helper.dart
  Future<void> clearMessages({String? chatGroupId}) async {
    final db = await database;
    if (chatGroupId != null) {
      await db.delete('messages',
          where: 'chat_group_id = ?', whereArgs: [chatGroupId]);
    } else {
      // Clear squad chat messages (where chat_group_id is null)
      await db.delete('messages', where: 'chat_group_id IS NULL');
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(int offset, int limit,
      {String? chatGroupId}) async {
    try {
      final db = await database;
      String? whereClause;
      List<dynamic>? whereArgs;

      if (chatGroupId != null) {
        whereClause = 'chat_group_id = ?';
        whereArgs = [chatGroupId];
      } else {
        // For squad chat, get messages where chat_group_id is null
        whereClause = 'chat_group_id IS NULL';
      }

      final List<Map<String, dynamic>> maps = await db.query(
        'messages',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'timestamp_ms DESC',
        limit: limit,
        offset: offset,
      );
      return maps.map((map) {
        return {
          'id': map['id'],
          'sender_name': map['sender_name'],
          'timestamp_ms': map['timestamp_ms'],
          'content': map['content'],
          'photos': jsonDecode(map['photos'] ?? '[]'),
          'videos': jsonDecode(map['videos'] ?? '[]'),
          'audio': jsonDecode(map['audio'] ?? '[]'),
          'reactions': jsonDecode(map['reactions'] ?? '[]'),
          'is_geoblocked_for_viewer': map['is_geoblocked_for_viewer'] == 1,
          'is_unsent_image_by_messenger_kid_parent':
              map['is_unsent_image_by_messenger_kid_parent'] == 1,
          'delivered': map['delivered'] == 1,
          'read': map['read'] == 1,
          'reply_to': map['reply_to'],
          'created_at': map['created_at'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Failed to fetch messages from SQLite: $e');
      return [];
    }
  }
}
