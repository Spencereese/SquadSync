import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;
import 'package:squad_sync/core/sqlite_cells.dart';

class SQLiteHelper {
  static Database? _database;
  static Future<Database>? _opening;
  static const String _encryptionKeyName = 'sqlite_encryption_key';
  static const _secureStorage = FlutterSecureStorage();

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_opening != null) return _opening!;
    _opening = _initDatabase();
    try {
      _database = await _opening!;
      return _database!;
    } finally {
      _opening = null;
    }
  }

  /// Get or generate encryption key for SQLite database
  Future<String> _getEncryptionKey() async {
    try {
      String? key = await _secureStorage.read(key: _encryptionKeyName);

      if (key == null) {
        key = generateSecureKey();
        await _secureStorage.write(key: _encryptionKeyName, value: key);
        debugPrint('🔐 Generated new SQLite encryption key');
      }

      return key;
    } catch (e) {
      debugPrint('⚠️  Failed to get encryption key: $e');
      // Deterministic OS/locale fallback removed. Friends/release never use it.
      if (kDebugMode) {
        debugPrint(
          'SECURITY: sqlite key storage failed; minting ephemeral CSPRNG key. '
          'NOT a deterministic OS/locale fallback. Debug only — release rethrows.',
        );
        return generateSecureKey();
      }
      rethrow;
    }
  }

  /// 256-bit hex key from CSPRNG. Not derived from clock, OS, or locale.
  @visibleForTesting
  static String generateSecureKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Old deterministic OS/locale fallback path is gone.
  @visibleForTesting
  static bool get usesDeterministicFallback => false;

  /// Full v16 schema. Used by first open and cipher-recovery recreate.
  static Future<void> createFullSchema(Database db) async {
    await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            sender_id TEXT,
            sender_name TEXT,
            timestamp_ms INTEGER,
            content TEXT,
            text TEXT,
            reactions TEXT,
            delivered INTEGER,
            read INTEGER,
            reply_to TEXT,
            created_at TEXT,
            chat_group_id TEXT,
            message_type TEXT,
            media_url TEXT,
            media_type TEXT,
            poll TEXT,
            voice_note_url TEXT,
            voice_note_duration INTEGER,
            ai_response TEXT,
            metadata TEXT,
            is_edited INTEGER DEFAULT 0,
            edited_at TEXT,
            is_deleted INTEGER DEFAULT 0,
            deleted_at TEXT,
            synced INTEGER DEFAULT 1
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
    await db.execute('''
          CREATE TABLE chat_groups (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            member_uids TEXT,
            is_public INTEGER DEFAULT 0,
            member_count INTEGER DEFAULT 0,
            created_by TEXT,
            created_at TEXT NOT NULL,
            description TEXT,
            avatar_url TEXT,
            metadata TEXT,
            admins TEXT,
            moderators TEXT,
            is_active INTEGER DEFAULT 1,
            last_activity TEXT,
            settings TEXT
          )
        ''');
    await db.execute('''
          CREATE TABLE polls (
            id TEXT PRIMARY KEY,
            question TEXT NOT NULL,
            options TEXT NOT NULL,
            votes TEXT NOT NULL,
            created_by TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            expires_at INTEGER,
            chat_group_id TEXT,
            is_active INTEGER DEFAULT 1
          )
        ''');
    await db.execute(
        'CREATE INDEX idx_timestamp_ms ON messages(timestamp_ms DESC)');
    await db.execute(
        'CREATE INDEX idx_chat_group_id ON messages(chat_group_id)');
    await db.execute(
        'CREATE INDEX idx_timestamp_group ON messages(timestamp_ms DESC, chat_group_id)');
    await db.execute(
        'CREATE INDEX idx_groups_cache ON groups_cache(game_name, search_term)');
    await db.execute(
        'CREATE INDEX idx_polls_chat_group ON polls(chat_group_id)');
    await db.execute('''
          CREATE TABLE offline_queue (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            data TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            retry_count INTEGER DEFAULT 0,
            last_retry_at INTEGER,
            error TEXT
          )
        ''');
    await db.execute('''
          CREATE TABLE clips (
            id TEXT PRIMARY KEY,
            squad_id TEXT,
            sender_id TEXT,
            sender_name TEXT,
            video_url TEXT NOT NULL,
            thumbnail_url TEXT,
            duration_sec INTEGER,
            width INTEGER,
            height INTEGER,
            views INTEGER DEFAULT 0,
            hype_reactions TEXT,
            created_at INTEGER NOT NULL,
            synced INTEGER DEFAULT 1,
            updated_at INTEGER
          )
        ''');
    await db.execute(
        'CREATE INDEX idx_offline_queue_type ON offline_queue(type)');
    await db.execute(
        'CREATE INDEX idx_offline_queue_created ON offline_queue(created_at)');
    await db.execute('CREATE INDEX idx_clips_squad ON clips(squad_id)');
    await db.execute(
        'CREATE INDEX idx_clips_created ON clips(created_at DESC)');
    await db.execute('CREATE INDEX idx_clips_synced ON clips(synced)');
  }

  Future<Database> _initDatabase() async {
    try {
      // Get database path with proper error handling
      final databasesPath = await getDatabasesPath();
      debugPrint('📂 Database path: $databasesPath');

      // Ensure directory exists
      final directory = Directory(databasesPath);
      if (!await directory.exists()) {
        debugPrint('📁 Creating database directory...');
        await directory.create(recursive: true);
      }

      final path = join(databasesPath, 'lobbiesync.db');
      debugPrint('💾 Opening database at: $path');

      // Get encryption key
      final encryptionKey = await _getEncryptionKey();

      // Use sqlcipher for encrypted database
      return await sqlcipher.openDatabase(
        path,
        version: 16, // Clear cache again due to metadata corruption
        password: encryptionKey,
        onCreate: (db, version) async {
          await createFullSchema(db);
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
            await db
                .execute('ALTER TABLE messages ADD COLUMN message_type TEXT');
            await db.execute('ALTER TABLE messages ADD COLUMN media_url TEXT');
            await db.execute('ALTER TABLE messages ADD COLUMN media_type TEXT');
            await db.execute('ALTER TABLE messages ADD COLUMN poll TEXT');
            await db
                .execute('ALTER TABLE messages ADD COLUMN voice_note_url TEXT');
            await db.execute(
                'ALTER TABLE messages ADD COLUMN voice_note_duration INTEGER');
            await db
                .execute('ALTER TABLE messages ADD COLUMN ai_response TEXT');
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
          if (oldVersion < 10) {
            // Add offline queue table for pending messages/uploads
            await db.execute('''
            CREATE TABLE offline_queue (
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL,
              data TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              retry_count INTEGER DEFAULT 0,
              last_retry_at INTEGER,
              error TEXT
            )
          ''');

            // Add clips cache table
            await db.execute('''
            CREATE TABLE clips (
              id TEXT PRIMARY KEY,
              squad_id TEXT,
              sender_id TEXT,
              sender_name TEXT,
              video_url TEXT NOT NULL,
              thumbnail_url TEXT,
              duration_sec INTEGER,
              width INTEGER,
              height INTEGER,
              views INTEGER DEFAULT 0,
              hype_reactions TEXT,
              created_at INTEGER NOT NULL,
              synced INTEGER DEFAULT 1,
              updated_at INTEGER
            )
          ''');

            // Add chat_groups table for offline caching
            await db.execute('''
            CREATE TABLE IF NOT EXISTS chat_groups (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              member_uids TEXT,
              is_public INTEGER DEFAULT 0,
              member_count INTEGER DEFAULT 0,
              created_by TEXT,
              created_at TEXT NOT NULL,
              description TEXT,
              avatar_url TEXT,
              metadata TEXT,
              admins TEXT,
              moderators TEXT,
              is_active INTEGER DEFAULT 1,
              last_activity TEXT,
              settings TEXT
            )
          ''');

            // Create indexes for offline queue
            await db.execute(
                'CREATE INDEX idx_offline_queue_type ON offline_queue(type)');
            await db.execute(
                'CREATE INDEX idx_offline_queue_created ON offline_queue(created_at)');

            // Create indexes for clips
            await db.execute('CREATE INDEX idx_clips_squad ON clips(squad_id)');
            await db.execute(
                'CREATE INDEX idx_clips_created ON clips(created_at DESC)');
            await db.execute('CREATE INDEX idx_clips_synced ON clips(synced)');

            // Create indexes for chat_groups
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_chat_groups_public ON chat_groups(is_public)');
          }
          if (oldVersion < 11) {
            // Recreate chat_groups table with correct schema
            await db.execute('DROP TABLE IF EXISTS chat_groups');
            await db.execute('''
            CREATE TABLE chat_groups (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              member_uids TEXT,
              is_public INTEGER DEFAULT 0,
              member_count INTEGER DEFAULT 0,
              created_by TEXT,
              created_at TEXT NOT NULL,
              description TEXT,
              avatar_url TEXT,
              metadata TEXT,
              admins TEXT,
              moderators TEXT,
              is_active INTEGER DEFAULT 1,
              last_activity TEXT,
              settings TEXT
            )
          ''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_chat_groups_public ON chat_groups(is_public)');
          }
          if (oldVersion < 12) {
            // Add missing columns to messages table for existing databases
            // These were in onCreate but missing from older migrations
            try {
              await db
                  .execute('ALTER TABLE messages ADD COLUMN sender_id TEXT');
            } catch (e) {
              // Column may already exist
            }
            try {
              await db.execute('ALTER TABLE messages ADD COLUMN text TEXT');
            } catch (e) {
              // Column may already exist
            }
            try {
              await db
                  .execute('ALTER TABLE messages ADD COLUMN message_type TEXT');
            } catch (e) {
              // Column may already exist
            }
            try {
              await db
                  .execute('ALTER TABLE messages ADD COLUMN media_url TEXT');
            } catch (e) {
              // Column may already exist
            }
            try {
              await db
                  .execute('ALTER TABLE messages ADD COLUMN media_type TEXT');
            } catch (e) {
              // Column may already exist
            }
            try {
              await db.execute('ALTER TABLE messages ADD COLUMN poll TEXT');
            } catch (e) {
              // Column may already exist
            }
            try {
              await db.execute(
                  'ALTER TABLE messages ADD COLUMN voice_note_url TEXT');
            } catch (e) {
              // Column may already exist
            }
            try {
              await db.execute(
                  'ALTER TABLE messages ADD COLUMN voice_note_duration INTEGER');
            } catch (e) {
              // Column may already exist
            }
            try {
              await db
                  .execute('ALTER TABLE messages ADD COLUMN ai_response TEXT');
            } catch (e) {
              // Column may already exist
            }
            try {
              await db.execute('ALTER TABLE messages ADD COLUMN metadata TEXT');
            } catch (e) {
              // Column may already exist
            }
            try {
              await db.execute(
                  'ALTER TABLE messages ADD COLUMN is_edited INTEGER DEFAULT 0');
            } catch (e) {
              // Column may already exist
            }
            try {
              await db
                  .execute('ALTER TABLE messages ADD COLUMN edited_at TEXT');
            } catch (e) {
              // Column may already exist
            }
            try {
              await db.execute(
                  'ALTER TABLE messages ADD COLUMN is_deleted INTEGER DEFAULT 0');
            } catch (e) {
              // Column may already exist
            }
            try {
              await db
                  .execute('ALTER TABLE messages ADD COLUMN deleted_at TEXT');
            } catch (e) {
              // Column may already exist
            }
            try {
              await db.execute(
                  'ALTER TABLE messages ADD COLUMN synced INTEGER DEFAULT 1');
            } catch (e) {
              // Column may already exist
            }
          }
          if (oldVersion < 13) {
            // Add polls table for existing databases
            await db.execute('''
            CREATE TABLE IF NOT EXISTS polls (
              id TEXT PRIMARY KEY,
              question TEXT NOT NULL,
              options TEXT NOT NULL,
              votes TEXT NOT NULL,
              created_by TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              expires_at INTEGER,
              chat_group_id TEXT,
              is_active INTEGER DEFAULT 1
            )
          ''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_polls_chat_group ON polls(chat_group_id)');
          }
          if (oldVersion < 14) {
            // Clear old messages with incompatible schema (photos/videos/audio TEXT columns)
            // These were from Firebase migration and are no longer compatible
            debugPrint(
                '🔄 SQLite v14: Clearing old cached messages with incompatible schema');
            await db.execute('DELETE FROM messages');

            // Remove obsolete columns if they exist
            // SQLite doesn't support DROP COLUMN, so we need to recreate the table
            try {
              // Check if old columns exist by trying to select from them
              await db.rawQuery(
                  'SELECT photos, videos, audio FROM messages LIMIT 1');

              // If we got here, old columns exist - recreate table
              debugPrint(
                  '🔄 SQLite v14: Recreating messages table without obsolete columns');

              // Create new table with correct schema
              await db.execute('''
              CREATE TABLE messages_new (
                id TEXT PRIMARY KEY,
                sender_id TEXT,
                sender_name TEXT,
                timestamp_ms INTEGER,
                content TEXT,
                text TEXT,
                reactions TEXT,
                delivered INTEGER,
                read INTEGER,
                reply_to TEXT,
                created_at TEXT,
                chat_group_id TEXT,
                message_type TEXT,
                media_url TEXT,
                media_type TEXT,
                poll TEXT,
                voice_note_url TEXT,
                voice_note_duration INTEGER,
                ai_response TEXT,
                metadata TEXT,
                is_edited INTEGER DEFAULT 0,
                edited_at TEXT,
                is_deleted INTEGER DEFAULT 0,
                deleted_at TEXT,
                synced INTEGER DEFAULT 1
              )
            ''');

              // Copy data from old table (excluding photos/videos/audio columns)
              await db.execute('''
              INSERT INTO messages_new 
                (id, sender_id, sender_name, timestamp_ms, content, text, reactions, 
                 delivered, read, reply_to, created_at, chat_group_id, message_type, 
                 media_url, media_type, poll, voice_note_url, voice_note_duration, 
                 ai_response, metadata, is_edited, edited_at, is_deleted, deleted_at, synced)
              SELECT 
                id, sender_id, sender_name, timestamp_ms, content, text, reactions, 
                delivered, read, reply_to, created_at, chat_group_id, message_type, 
                media_url, media_type, poll, voice_note_url, voice_note_duration, 
                ai_response, metadata, is_edited, edited_at, is_deleted, deleted_at, synced
              FROM messages
            ''');

              // Drop old table and rename new one
              await db.execute('DROP TABLE messages');
              await db.execute('ALTER TABLE messages_new RENAME TO messages');

              // Recreate indexes
              await db.execute(
                  'CREATE INDEX IF NOT EXISTS idx_timestamp_ms ON messages(timestamp_ms DESC)');
              await db.execute(
                  'CREATE INDEX IF NOT EXISTS idx_chat_group_id ON messages(chat_group_id)');
              await db.execute(
                  'CREATE INDEX IF NOT EXISTS idx_timestamp_group ON messages(timestamp_ms DESC, chat_group_id)');

              debugPrint(
                  '✅ SQLite v14: Messages table recreated without obsolete columns');
            } catch (e) {
              // Old columns don't exist, table is already in new format
              debugPrint('✅ SQLite v14: Messages table already in correct format');
            }
          }
          if (oldVersion < 15) {
            // Force clear ALL messages to remove any remaining incompatible data
            debugPrint(
                '🔄 SQLite v15: Force clearing all cached messages to ensure clean slate');
            await db.execute('DELETE FROM messages');
            debugPrint(
                '✅ SQLite v15: All old messages cleared, fresh cache will be built from Supabase');
          }
          if (oldVersion < 16) {
            // Clear cache again due to persistent metadata corruption
            debugPrint(
                '🔄 SQLite v16: Clearing cache to remove metadata corruption');
            await db.execute('DELETE FROM messages');
            debugPrint('✅ SQLite v16: Cache cleared');
          }
        },
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize database: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!isSqliteCipherOpenFailure(e)) {
        rethrow;
      }

      // Key-mismatch / exclusive lock: delete and recreate once.
      try {
        try {
          await _database?.close();
        } catch (_) {}
        _database = null;
        final databasesPath = await getDatabasesPath();
        final path = join(databasesPath, 'lobbiesync.db');
        try {
          await sqlcipher.deleteDatabase(path);
        } catch (_) {}
        final file = File(path);
        if (await file.exists()) {
          debugPrint('🗑️  Deleting corrupted database...');
          await file.delete();
        }
        debugPrint('♻️  Recreating database after cipher open_failed...');
        final encryptionKey = await _getEncryptionKey();
        return await sqlcipher.openDatabase(
          path,
          version: 16,
          password: encryptionKey,
          onCreate: (db, version) async {
            await createFullSchema(db);
          },
        );
      } catch (retryError) {
        debugPrint('❌ Retry failed: $retryError');
      }

      rethrow;
    }
  }

  Future<void> insertMessage(Map<String, dynamic> message,
      {String? chatGroupId}) async {
    try {
      final db = await database;
      // New schema format (no photos/videos/audio columns)
      await db.insert(
        'messages',
        {
          'id': message['id'],
          'sender_id': message['sender_id'],
          'sender_name': message['sender_name'],
          'timestamp_ms': message['timestamp_ms'],
          'content': message['content'],
          'text': message['text'],
          'message_type': message['message_type'],
          'media_url': message['media_url'],
          'media_type': message['media_type'],
          'reactions': message['reactions'] is String
              ? message['reactions']
              : jsonEncode(message['reactions'] ?? {}),
          'delivered': message['delivered'] ?? 1,
          'read': message['read'] ?? 0,
          'reply_to': message['reply_to'],
          'created_at':
              message['created_at'] ?? DateTime.now().toIso8601String(),
          'chat_group_id': chatGroupId ?? message['chat_group_id'],
          'poll': message['poll'] is String
              ? message['poll']
              : (message['poll'] != null ? jsonEncode(message['poll']) : null),
          'voice_note_url': message['voice_note_url'],
          'voice_note_duration': message['voice_note_duration'],
          'ai_response': message['ai_response'],
          'metadata': message['metadata'] is String
              ? message['metadata']
              : (message['metadata'] != null
                  ? jsonEncode(message['metadata'])
                  : null),
          'is_edited': message['is_edited'] ?? 0,
          'edited_at': message['edited_at'],
          'is_deleted': message['is_deleted'] ?? 0,
          'deleted_at': message['deleted_at'],
          'synced': message['synced'] ?? 1,
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

      // Return messages in new schema format (no photos/videos/audio)
      return maps.map((map) {
        return {
          'id': map['id'],
          'sender_id': map['sender_id'],
          'sender_name': map['sender_name'],
          'timestamp_ms': map['timestamp_ms'],
          'content': map['content'],
          'text': map['text'],
          'message_type': map['message_type'],
          'media_url': map['media_url'],
          'media_type': map['media_type'],
          'reactions': map['reactions'],
          'delivered': map['delivered'],
          'read': map['read'],
          'reply_to': map['reply_to'],
          'created_at': map['created_at'],
          'chat_group_id': map['chat_group_id'],
          'poll': map['poll'],
          'voice_note_url': map['voice_note_url'],
          'voice_note_duration': map['voice_note_duration'],
          'ai_response': map['ai_response'],
          'metadata': map['metadata'],
          'is_edited': map['is_edited'],
          'edited_at': map['edited_at'],
          'is_deleted': map['is_deleted'],
          'deleted_at': map['deleted_at'],
          'synced': map['synced'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Failed to fetch messages from SQLite: $e');
      // If we hit an error (likely old schema data), clear messages and return empty
      if (e.toString().contains('no such column')) {
        debugPrint('🔄 Detected old schema, clearing messages table');
        try {
          final db = await database;
          await db.execute('DELETE FROM messages');
        } catch (clearError) {
          debugPrint('Failed to clear old messages: $clearError');
        }
      }
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

  // ============================================================
  // OFFLINE QUEUE METHODS
  // ============================================================

  /// Add item to offline queue
  Future<void> enqueueOfflineItem({
    required String id,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    try {
      final db = await database;
      await db.insert(
        'offline_queue',
        {
          'id': id,
          'type': type,
          'data': jsonEncode(data),
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'retry_count': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('Enqueued offline item: $id (type: $type)');
    } catch (e) {
      debugPrint('Failed to enqueue offline item: $e');
    }
  }

  /// Get all pending offline queue items
  Future<List<Map<String, dynamic>>> getOfflineQueue() async {
    try {
      final db = await database;
      final results = await db.query(
        'offline_queue',
        orderBy: 'created_at ASC',
      );
      return results;
    } catch (e) {
      debugPrint('Failed to get offline queue: $e');
      return [];
    }
  }

  /// Get offline queue items by type
  Future<List<Map<String, dynamic>>> getOfflineQueueByType(String type) async {
    try {
      final db = await database;
      final results = await db.query(
        'offline_queue',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'created_at ASC',
      );
      return results;
    } catch (e) {
      debugPrint('Failed to get offline queue by type: $e');
      return [];
    }
  }

  /// Update retry count for offline queue item
  Future<void> updateOfflineItemRetry(String id, String? error) async {
    try {
      final db = await database;
      await db.rawUpdate('''
        UPDATE offline_queue 
        SET retry_count = retry_count + 1,
            last_retry_at = ?,
            error = ?
        WHERE id = ?
      ''', [DateTime.now().millisecondsSinceEpoch, error, id]);
    } catch (e) {
      debugPrint('Failed to update offline item retry: $e');
    }
  }

  /// Remove item from offline queue
  Future<void> dequeueOfflineItem(String id) async {
    try {
      final db = await database;
      await db.delete(
        'offline_queue',
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('Dequeued offline item: $id');
    } catch (e) {
      debugPrint('Failed to dequeue offline item: $e');
    }
  }

  /// Clear failed items after max retries
  Future<void> clearFailedOfflineItems({int maxRetries = 5}) async {
    try {
      final db = await database;
      await db.delete(
        'offline_queue',
        where: 'retry_count >= ?',
        whereArgs: [maxRetries],
      );
    } catch (e) {
      debugPrint('Failed to clear failed offline items: $e');
    }
  }

  // ============================================================
  // CLIPS CACHE METHODS
  // ============================================================

  /// Cache a clip
  Future<void> cacheClip(Map<String, dynamic> clipData) async {
    try {
      final db = await database;
      await db.insert(
        'clips',
        {
          'id': clipData['id'],
          'squad_id': clipData['squad_id'],
          'sender_id': clipData['sender_id'],
          'sender_name': clipData['sender_name'],
          'video_url': clipData['video_url'],
          'thumbnail_url': clipData['thumbnail_url'],
          'duration_sec': clipData['duration_sec'],
          'width': clipData['width'],
          'height': clipData['height'],
          'views': clipData['views'] ?? 0,
          'hype_reactions': clipData['hype_reactions'] != null
              ? jsonEncode(clipData['hype_reactions'])
              : '[]',
          'created_at':
              clipData['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
          'synced': 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Failed to cache clip: $e');
    }
  }

  /// Get cached clips for a squad
  Future<List<Map<String, dynamic>>> getCachedClips(String squadId,
      {int limit = 20, int offset = 0}) async {
    try {
      final db = await database;
      final results = await db.query(
        'clips',
        where: 'squad_id = ?',
        whereArgs: [squadId],
        orderBy: 'created_at DESC',
        limit: limit,
        offset: offset,
      );

      return results.map((row) {
        return {
          'id': row['id'],
          'squad_id': row['squad_id'],
          'sender_id': row['sender_id'],
          'sender_name': row['sender_name'],
          'video_url': row['video_url'],
          'thumbnail_url': row['thumbnail_url'],
          'duration_sec': row['duration_sec'],
          'width': row['width'],
          'height': row['height'],
          'views': row['views'],
          'hype_reactions': jsonDecode(row['hype_reactions'] as String),
          'created_at': row['created_at'],
          'synced': row['synced'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Failed to get cached clips: $e');
      return [];
    }
  }

  /// Update clip views locally
  Future<void> updateClipViews(String clipId, int views) async {
    try {
      final db = await database;
      await db.update(
        'clips',
        {
          'views': views,
          'synced': 0, // Mark as needing sync
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [clipId],
      );
    } catch (e) {
      debugPrint('Failed to update clip views: $e');
    }
  }

  /// Update clip hype reactions locally
  Future<void> updateClipHypeReactions(
      String clipId, List<String> reactions) async {
    try {
      final db = await database;
      await db.update(
        'clips',
        {
          'hype_reactions': jsonEncode(reactions),
          'synced': 0, // Mark as needing sync
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [clipId],
      );
    } catch (e) {
      debugPrint('Failed to update clip hype reactions: $e');
    }
  }

  /// Get unsynced clips
  Future<List<Map<String, dynamic>>> getUnsyncedClips() async {
    try {
      final db = await database;
      final results = await db.query(
        'clips',
        where: 'synced = ?',
        whereArgs: [0],
        orderBy: 'updated_at ASC',
      );
      return results;
    } catch (e) {
      debugPrint('Failed to get unsynced clips: $e');
      return [];
    }
  }

  /// Mark clip as synced
  Future<void> markClipSynced(String clipId) async {
    try {
      final db = await database;
      await db.update(
        'clips',
        {
          'synced': 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [clipId],
      );
    } catch (e) {
      debugPrint('Failed to mark clip synced: $e');
    }
  }

  /// Delete old clips cache
  Future<void> purgeOldClips({int daysToKeep = 30}) async {
    try {
      final db = await database;
      final cutoffTime = DateTime.now()
          .subtract(Duration(days: daysToKeep))
          .millisecondsSinceEpoch;
      await db.delete(
        'clips',
        where: 'created_at < ?',
        whereArgs: [cutoffTime],
      );
    } catch (e) {
      debugPrint('Failed to purge old clips: $e');
    }
  }
}
