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
      version: 9, // Increment version for lobbies table
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
            delivered INTEGER,
            read INTEGER,
            reply_to TEXT,
            created_at TEXT,
            chat_group_id TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE groups_cache (
            id TEXT PRIMARY KEY,
            game_name TEXT,
            search_term TEXT,
            data TEXT,
            cached_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE timers (
            key TEXT PRIMARY KEY,
            data TEXT,
            created_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE games_cache (
            id TEXT PRIMARY KEY,
            query TEXT,
            data TEXT,
            cached_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE cache_metadata (
            cache_key TEXT PRIMARY KEY,
            cached_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE voice_rooms_cache (
            room_id TEXT PRIMARY KEY,
            room_name TEXT,
            data TEXT,
            cached_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE lobbies (
            id TEXT PRIMARY KEY,
            name TEXT,
            memberUids TEXT,
            gameName TEXT,
            maxSpots INTEGER,
            createdBy TEXT,
            createdAt TEXT,
            spots TEXT,
            spotTimers TEXT,
            viewers TEXT,
            statuses TEXT,
            isActive INTEGER,
            description TEXT,
            settings TEXT,
            updatedAt TEXT
          )
        ''');
        // Create indexes for better query performance
        await db.execute(
            'CREATE INDEX idx_timestamp_ms ON messages(timestamp_ms DESC)');
        await db.execute(
            'CREATE INDEX idx_chat_group_id ON messages(chat_group_id)');
        await db.execute(
            'CREATE INDEX idx_timestamp_group ON messages(timestamp_ms DESC, chat_group_id)');
        await db.execute(
            'CREATE INDEX idx_groups_cache ON groups_cache(game_name, search_term)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add chat_group_id column to existing databases
          await db
              .execute('ALTER TABLE messages ADD COLUMN chat_group_id TEXT');
        }
        if (oldVersion < 3) {
          // Add indexes for better performance
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_timestamp_ms ON messages(timestamp_ms DESC)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_chat_group_id ON messages(chat_group_id)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_timestamp_group ON messages(timestamp_ms DESC, chat_group_id)');
        }
        if (oldVersion < 4) {
          // Add timers table
          await db.execute('''
            CREATE TABLE timers (
              key TEXT PRIMARY KEY,
              data TEXT,
              created_at TEXT
            )
          ''');
        }
        if (oldVersion < 5) {
          // Add games cache table
          await db.execute('''
            CREATE TABLE games_cache (
              id TEXT PRIMARY KEY,
              query TEXT,
              data TEXT,
              cached_at INTEGER
            )
          ''');
        }
        if (oldVersion < 6) {
          // Add cache metadata table
          await db.execute('''
            CREATE TABLE cache_metadata (
              cache_key TEXT PRIMARY KEY,
              cached_at INTEGER
            )
          ''');
        }
        if (oldVersion < 7) {
          // Add voice rooms cache table
          await db.execute('''
            CREATE TABLE voice_rooms_cache (
              room_id TEXT PRIMARY KEY,
              room_name TEXT,
              data TEXT,
              cached_at TEXT
            )
          ''');
        }
        if (oldVersion < 8) {
          // Update messages table schema to support full Message entity
          await db.execute('ALTER TABLE messages ADD COLUMN sender_id TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN text TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN message_type TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN media_url TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN media_type TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN poll TEXT');
          await db
              .execute('ALTER TABLE messages ADD COLUMN voice_note_url TEXT');
          await db.execute(
              'ALTER TABLE messages ADD COLUMN voice_note_duration INTEGER');
          await db.execute('ALTER TABLE messages ADD COLUMN ai_response TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN metadata TEXT');
          await db.execute(
              'ALTER TABLE messages ADD COLUMN is_edited INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE messages ADD COLUMN edited_at TEXT');
          await db.execute(
              'ALTER TABLE messages ADD COLUMN is_deleted INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE messages ADD COLUMN deleted_at TEXT');
          await db.execute(
              'ALTER TABLE messages ADD COLUMN synced INTEGER DEFAULT 1');
        }
        if (oldVersion < 9) {
          // Add lobbies table
          await db.execute('''
            CREATE TABLE lobbies (
              id TEXT PRIMARY KEY,
              name TEXT,
              memberUids TEXT,
              gameName TEXT,
              maxSpots INTEGER,
              createdBy TEXT,
              createdAt TEXT,
              spots TEXT,
              spotTimers TEXT,
              viewers TEXT,
              statuses TEXT,
              isActive INTEGER,
              description TEXT,
              settings TEXT,
              updatedAt TEXT
            )
          ''');
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
          'delivered': (message['delivered'] ?? false) ? 1 : 0,
          'read': (message['read'] ?? false) ? 1 : 0,
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

      debugPrint(
          'DEBUG SQLite getMessages: chatGroupId=$chatGroupId, whereClause=$whereClause, whereArgs=$whereArgs, offset=$offset, limit=$limit');

      final List<Map<String, dynamic>> maps = await db.query(
        'messages',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'timestamp_ms DESC', // Use indexed column for ordering
        limit: limit,
        offset: offset,
      );

      debugPrint('DEBUG SQLite getMessages: found ${maps.length} messages');

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

  Future<List<Map<String, dynamic>>> getCachedGroups(
      String gameName, String searchTerm) async {
    try {
      final db = await database;
      final results = await db.query(
        'groups_cache',
        where: 'game_name = ? AND search_term = ?',
        whereArgs: [gameName, searchTerm],
        orderBy: 'cached_at DESC',
        limit: 1,
      );
      if (results.isNotEmpty) {
        final data = results.first['data'] as String;
        return List<Map<String, dynamic>>.from(json.decode(data));
      }
      return [];
    } catch (e) {
      debugPrint('Failed to get cached groups: $e');
      return [];
    }
  }

  Future<void> cacheGroups(List<Map<String, dynamic>> groups, String gameName,
      String searchTerm) async {
    try {
      final db = await database;
      final id = '$gameName|$searchTerm';
      final data = json.encode(groups);
      await db.insert(
        'groups_cache',
        {
          'id': id,
          'game_name': gameName,
          'search_term': searchTerm,
          'data': data,
          'cached_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Failed to cache groups: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedGames(String query) async {
    try {
      final db = await database;
      final results = await db.query(
        'games_cache',
        where: 'query = ?',
        whereArgs: [query],
        orderBy: 'cached_at DESC',
        limit: 1,
      );
      if (results.isNotEmpty) {
        final cachedAt = results.first['cached_at'] as int;
        final now = DateTime.now().millisecondsSinceEpoch;
        final fiveMinutes = 5 * 60 * 1000; // 5 minutes in milliseconds
        if (now - cachedAt < fiveMinutes) {
          final data = results.first['data'] as String;
          return List<Map<String, dynamic>>.from(json.decode(data));
        }
      }
      return [];
    } catch (e) {
      debugPrint('Failed to get cached games: $e');
      return [];
    }
  }

  Future<void> cacheGames(
      List<Map<String, dynamic>> games, String query) async {
    try {
      final db = await database;
      final id = 'games_$query';
      final data = json.encode(games);
      await db.insert(
        'games_cache',
        {
          'id': id,
          'query': query,
          'data': data,
          'cached_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Failed to cache games: $e');
    }
  }

  /// Get cache metadata for TTL checking
  Future<Map<String, dynamic>?> getCacheMetadata(String cacheKey) async {
    try {
      final db = await database;
      final results = await db.query(
        'groups_cache',
        where: 'id = ?',
        whereArgs: [cacheKey],
        limit: 1,
      );
      if (results.isNotEmpty) {
        return results.first;
      }
      return null;
    } catch (e) {
      debugPrint('Failed to get cache metadata: $e');
      return null;
    }
  }

  /// Insert cache metadata
  Future<void> insertCacheMetadata(String cacheKey, int timestamp) async {
    try {
      final db = await database;
      await db.insert(
        'cache_metadata',
        {
          'cache_key': cacheKey,
          'cached_at': timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Failed to insert cache metadata: $e');
    }
  }

  /// Clean up expired cache entries
  Future<void> cleanupExpiredCache(Duration ttl) async {
    try {
      final db = await database;
      final cutoffTime = DateTime.now().subtract(ttl).millisecondsSinceEpoch;

      await db.delete(
        'groups_cache',
        where: 'cached_at < ?',
        whereArgs: [cutoffTime],
      );

      await db.delete(
        'games_cache',
        where: 'cached_at < ?',
        whereArgs: [cutoffTime],
      );

      await db.delete(
        'cache_metadata',
        where: 'cached_at < ?',
        whereArgs: [cutoffTime],
      );
    } catch (e) {
      debugPrint('Failed to cleanup expired cache: $e');
    }
  }

  /// Cache voice room data for offline fallback
  Future<void> cacheVoiceRoom(String roomId, Map<String, dynamic> data) async {
    try {
      final db = await database;
      await db.insert(
        'voice_rooms_cache',
        {
          'room_id': roomId,
          'room_name': data['roomName'] ?? 'Voice Room',
          'data': jsonEncode(data),
          'cached_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Failed to cache voice room: $e');
    }
  }

  /// Get cached voice room data
  Future<Map<String, dynamic>?> getCachedVoiceRoom(String roomId) async {
    try {
      final db = await database;
      final result = await db.query(
        'voice_rooms_cache',
        where: 'room_id = ?',
        whereArgs: [roomId],
      );

      if (result.isNotEmpty) {
        final data = jsonDecode(result.first['data'] as String);
        return data;
      }
    } catch (e) {
      debugPrint('Failed to get cached voice room: $e');
    }
    return null;
  }
}
