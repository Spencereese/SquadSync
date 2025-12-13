import 'package:flutter/foundation.dart';
import 'package:squad_sync/services/background_sync_service.dart';
import 'package:squad_sync/chat/sqlite_helper.dart';

/// Mixin for adding offline-first capabilities to notifiers
/// Use this to add connectivity checks and local caching to your notifiers
mixin OfflineFirstMixin {
  BackgroundSyncService? _syncService;
  SQLiteHelper? _sqliteHelper;

  /// Initialize offline-first services
  @protected
  Future<void> initializeOfflineFirst() async {
    _syncService ??= BackgroundSyncService();
    _sqliteHelper ??= SQLiteHelper();
    await _syncService!.initialize();
  }

  /// Check if device is currently online
  @protected
  Future<bool> isOnline() async {
    _syncService ??= BackgroundSyncService();
    return await _syncService!.isOnline();
  }

  /// Get cached online status (no async check)
  @protected
  bool get isCurrentlyOnline {
    return _syncService?.isCurrentlyOnline ?? true;
  }

  /// Queue an item for syncing when back online
  @protected
  Future<void> queueForSync({
    required String id,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    _sqliteHelper ??= SQLiteHelper();
    await _sqliteHelper!.enqueueOfflineItem(
      id: id,
      type: type,
      data: data,
    );
  }

  /// Trigger immediate sync if online
  @protected
  Future<void> triggerSync() async {
    _syncService ??= BackgroundSyncService();
    if (await isOnline()) {
      await _syncService!.triggerImmediateSync();
    }
  }

  /// Execute an operation with offline fallback
  /// If online, executes [onlineOperation], otherwise executes [offlineOperation]
  @protected
  Future<T> executeWithOfflineFallback<T>({
    required Future<T> Function() onlineOperation,
    required Future<T> Function() offlineOperation,
    bool forceOffline = false,
  }) async {
    if (forceOffline || !await isOnline()) {
      debugPrint('Device offline - using local data');
      return await offlineOperation();
    }

    try {
      return await onlineOperation();
    } catch (e) {
      debugPrint('Online operation failed: $e - falling back to offline');
      return await offlineOperation();
    }
  }

  /// Execute an operation and queue for sync if offline
  @protected
  Future<void> executeAndQueueIfOffline({
    required String id,
    required String type,
    required Map<String, dynamic> data,
    required Future<void> Function() onlineOperation,
    required Future<void> Function() offlineOperation,
  }) async {
    if (!await isOnline()) {
      debugPrint('Device offline - queuing operation: $type');
      await offlineOperation();
      await queueForSync(id: id, type: type, data: data);
      return;
    }

    try {
      await onlineOperation();
    } catch (e) {
      debugPrint('Online operation failed: $e - queuing for later');
      await offlineOperation();
      await queueForSync(id: id, type: type, data: data);
    }
  }

  /// Get SQLite helper instance
  @protected
  SQLiteHelper get sqliteHelper {
    _sqliteHelper ??= SQLiteHelper();
    return _sqliteHelper!;
  }

  /// Dispose offline-first resources
  @protected
  Future<void> disposeOfflineFirst() async {
    await _syncService?.dispose();
  }
}
