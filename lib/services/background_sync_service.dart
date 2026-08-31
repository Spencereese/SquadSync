import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:workmanager/workmanager.dart';
import '../chat/sqlite_helper.dart';
import 'supabase_service.dart';
import '../core/workmanager_skip.dart';

/// Background sync service for offline-first operations
/// Syncs pending messages, uploads, and data changes when online
class BackgroundSyncService {
  static final BackgroundSyncService _instance =
      BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  final Logger _logger = Logger();
  final Connectivity _connectivity = Connectivity();
  SQLiteHelper? _sqliteHelper;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  bool _isSyncing = false;

  static const String syncTaskName = 'com.squadsync.background_sync';
  static const String periodicSyncTask = 'com.squadsync.periodic_sync';

  /// Initialize background sync service
  Future<void> initialize() async {
    try {
      _sqliteHelper = SQLiteHelper();

      // Workmanager is Android/iOS only; sim/desktop often throw here.
      try {
        if (kIsWeb ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux) {
          _logger.i('Workmanager skipped on this platform');
        } else {
          await Workmanager().initialize(
            callbackDispatcher,
            isInDebugMode: kDebugMode,
          );
          try {
            await Workmanager().registerPeriodicTask(
              periodicSyncTask,
              periodicSyncTask,
              frequency: const Duration(minutes: 15),
              constraints: Constraints(
                networkType: NetworkType.connected,
              ),
            );
            _logger.i('Workmanager background tasks registered');
          } catch (e) {
            if (isExpectedWorkmanagerSkip(e)) {
              debugPrint(
                  'Workmanager periodic task skipped (simulator/unsupported)');
            } else {
              _logger.w('Workmanager registerPeriodicTask skipped: $e');
            }
          }
        }
      } catch (e) {
        _logger.w('Workmanager not available on this platform: $e');
      }

      // Listen to connectivity changes
      _connectivitySubscription =
          _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

      // Check initial connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      _isOnline = !connectivityResult.contains(ConnectivityResult.none);

      _logger.i('BackgroundSyncService initialized. Online: $_isOnline');
    } catch (e) {
      _logger.e('Failed to initialize BackgroundSyncService: $e');
      rethrow;
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = !results.contains(ConnectivityResult.none);

    _logger.i('Connectivity changed: $_isOnline');

    // Trigger immediate sync when coming back online
    if (!wasOnline && _isOnline) {
      _logger.i('Device back online - triggering sync');
      triggerImmediateSync();
    }
  }

  /// Check if device is currently online
  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return !results.contains(ConnectivityResult.none);
    } catch (e) {
      _logger.e('Failed to check connectivity: $e');
      return false;
    }
  }

  /// Get current online status (cached)
  bool get isCurrentlyOnline => _isOnline;

  /// Trigger immediate one-time sync
  Future<void> triggerImmediateSync() async {
    if (_isSyncing) {
      _logger.w('Sync already in progress, skipping');
      return;
    }

    try {
      await Workmanager().registerOneOffTask(
        'immediate_sync_${DateTime.now().millisecondsSinceEpoch}',
        syncTaskName,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
    } catch (e) {
      _logger.e('Failed to trigger immediate sync: $e');
    }
  }

  /// Perform sync operation
  Future<void> performSync() async {
    if (_isSyncing) {
      _logger.w('Sync already in progress');
      return;
    }

    if (!await isOnline()) {
      _logger.w('Device offline, skipping sync');
      return;
    }

    _isSyncing = true;
    _logger.i('Starting background sync...');

    try {
      final helper = _sqliteHelper ?? SQLiteHelper();

      // 1. Sync offline queue items
      await _syncOfflineQueue(helper);

      // 2. Sync unsynced clips
      await _syncUnsyncedClips(helper);

      // 3. Sync unsynced messages
      await _syncUnsyncedMessages(helper);

      // 4. Clean up failed items
      await helper.clearFailedOfflineItems(maxRetries: 5);

      // 5. Purge old data
      await helper.purgeOldClips(daysToKeep: 30);
      await helper.cleanupExpiredCache(const Duration(days: 7));

      _logger.i('Background sync completed successfully');
    } catch (e) {
      _logger.e('Background sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync offline queue items
  Future<void> _syncOfflineQueue(SQLiteHelper helper) async {
    try {
      final queueItems = await helper.getOfflineQueue();
      _logger.i('Syncing ${queueItems.length} offline queue items...');

      for (final item in queueItems) {
        try {
          final itemId = item['id'] as String;
          final itemType = item['type'] as String;
          final itemData = jsonDecode(item['data'] as String);
          final retryCount = item['retry_count'] as int;

          // Skip items that have exceeded retry limit
          if (retryCount >= 5) {
            _logger.w('Item $itemId exceeded retry limit, skipping');
            continue;
          }

          // Process based on type
          switch (itemType) {
            case 'message':
              await _syncMessage(itemData);
              break;
            case 'clip_upload':
              await _syncClipUpload(itemData);
              break;
            case 'lobby_update':
              await _syncLobbyUpdate(itemData);
              break;
            case 'media_upload':
              await _syncMediaUpload(itemData);
              break;
            default:
              _logger.w('Unknown queue item type: $itemType');
          }

          // Remove from queue on success
          await helper.dequeueOfflineItem(itemId);
          _logger.d('Successfully synced queue item: $itemId');
        } catch (e) {
          final itemId = item['id'] as String;
          _logger.e('Failed to sync queue item $itemId: $e');
          await helper.updateOfflineItemRetry(itemId, e.toString());
        }
      }
    } catch (e) {
      _logger.e('Failed to sync offline queue: $e');
    }
  }

  /// Sync unsynced clips
  Future<void> _syncUnsyncedClips(SQLiteHelper helper) async {
    try {
      final unsyncedClips = await helper.getUnsyncedClips();
      _logger.i('Syncing ${unsyncedClips.length} unsynced clips...');

      for (final clip in unsyncedClips) {
        try {
          final clipId = clip['id'] as String;

          // Update clip in Supabase
          await SupabaseService.client.from('clips').update({
            'views': clip['views'],
            'hype_reactions': jsonDecode(clip['hype_reactions'] as String),
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', clipId);

          // Mark as synced
          await helper.markClipSynced(clipId);
          _logger.d('Synced clip: $clipId');
        } catch (e) {
          _logger.e('Failed to sync clip ${clip['id']}: $e');
        }
      }
    } catch (e) {
      _logger.e('Failed to sync unsynced clips: $e');
    }
  }

  /// Sync unsynced messages
  Future<void> _syncUnsyncedMessages(SQLiteHelper helper) async {
    try {
      final db = await helper.database;
      final unsyncedMessages = await db.query(
        'messages',
        where: 'synced = ?',
        whereArgs: [0],
        orderBy: 'timestamp_ms ASC',
      );

      _logger.i('Syncing ${unsyncedMessages.length} unsynced messages...');

      for (final message in unsyncedMessages) {
        try {
          final messageId = message['id'] as String;
          final chatId = message['chat_group_id'] as String? ??
              message['chat_id'] as String?;

          // Send message to Supabase chat_messages table
          await SupabaseService.client.from('chat_messages').insert({
            'id': messageId,
            'chat_id': chatId,
            'sender_id': message['sender_id'],
            'text': message['text'],
            'timestamp': DateTime.fromMillisecondsSinceEpoch(
                    message['timestamp_ms'] as int)
                .toIso8601String(),
            'message_type': message['message_type'],
            'media_url': message['media_url'],
            'media_type': message['media_type'],
          });

          // Mark as synced
          await db.update(
            'messages',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [messageId],
          );

          _logger.d('Synced message: $messageId');
        } catch (e) {
          _logger.e('Failed to sync message ${message['id']}: $e');
        }
      }
    } catch (e) {
      _logger.e('Failed to sync unsynced messages: $e');
    }
  }

  /// Sync individual message
  Future<void> _syncMessage(Map<String, dynamic> data) async {
    // Ensure data uses correct column names for chat_messages table
    final messageData = {
      ...data,
      'chat_id': data['chat_id'] ?? data['chat_group_id'],
    };
    messageData.remove('chat_group_id'); // Remove legacy column name
    await SupabaseService.client.from('chat_messages').insert(messageData);
  }

  /// Sync clip upload
  Future<void> _syncClipUpload(Map<String, dynamic> data) async {
    await SupabaseService.client.from('clips').insert(data);
  }

  /// Sync lobby update
  Future<void> _syncLobbyUpdate(Map<String, dynamic> data) async {
    final lobbyId = data['id'] as String;
    await SupabaseService.client.from('lobbies').update(data).eq('id', lobbyId);
  }

  /// Sync media upload
  Future<void> _syncMediaUpload(Map<String, dynamic> data) async {
    // Implement media upload sync logic
    _logger.w('Media upload sync not yet implemented');
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    try {
      await Workmanager().cancelAll();
    } catch (e) {
      _logger.w('Workmanager cancelAll skipped: $e');
    }
  }
}

/// Workmanager callback dispatcher (must be top-level function)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final syncService = BackgroundSyncService();
      await syncService.performSync();
      return Future.value(true);
    } catch (e) {
      debugPrint('Background sync task failed: $e');
      return Future.value(false);
    }
  });
}
