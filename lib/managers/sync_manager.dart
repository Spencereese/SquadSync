import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../chat/sqlite_helper.dart';

/// Represents a sync conflict between local and remote messages
class SyncConflict {
  final Map<String, dynamic> localMessage;
  final Map<String, dynamic> remoteMessage;
  final ConflictResolution resolution;

  SyncConflict({
    required this.localMessage,
    required this.remoteMessage,
    this.resolution = ConflictResolution.unresolved,
  });
}

/// Conflict resolution strategies
enum ConflictResolution {
  unresolved,
  useLocal,
  useRemote,
  merge,
}

/// Sync operation result
class SyncResult {
  final bool success;
  final int messagesSynced;
  final List<SyncConflict> conflicts;
  final String? error;

  SyncResult({
    required this.success,
    this.messagesSynced = 0,
    this.conflicts = const [],
    this.error,
  });
}

/// SyncManager handles hybrid Firestore/SQLite synchronization
/// with delta queries, conflict detection/resolution, and data purging
class SyncManager {
  final SQLiteHelper _sqliteHelper;
  SharedPreferences? _prefs;

  static const String _lastSyncKey = 'lastSyncTimestamp';
  static const Duration _purgeThreshold = Duration(days: 30);

  SyncManager({
    required SQLiteHelper sqliteHelper,
  }) : _sqliteHelper = sqliteHelper;

  Future<SharedPreferences> get _prefsFuture async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Performs delta synchronization for a specific chat group
  /// Only syncs messages newer than lastSyncTimestamp from SharedPreferences
  Future<SyncResult> deltaSync(String chatGroupId) async {
    final prefs = await _prefsFuture;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return SyncResult(
          success: false,
          error: 'User not authenticated',
        );
      }

      // Get last sync timestamp
      final lastSyncTimestamp = prefs.getInt(_lastSyncKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Query remote messages since last sync
      final remoteMessages = await _fetchRemoteMessagesSince(
        chatGroupId,
        lastSyncTimestamp,
      );

      // Get local pending messages (not yet synced)
      final localPendingMessages = await _getLocalPendingMessages(chatGroupId);

      // Detect conflicts
      final conflicts =
          await _detectConflicts(localPendingMessages, remoteMessages);

      // Resolve conflicts automatically where possible
      final resolvedConflicts = _resolveConflicts(conflicts);

      // Apply resolved changes
      await _applyResolvedChanges(resolvedConflicts, chatGroupId);

      // Upload remaining local messages in batches
      final uploadedCount = await _batchUploadPendingMessages(
        localPendingMessages.where((msg) =>
            !resolvedConflicts.any((c) => c.localMessage['id'] == msg['id'])),
        chatGroupId,
      );

      // Update last sync timestamp
      await prefs.setInt(_lastSyncKey, now);

      // Purge old local data
      await _purgeOldData();

      return SyncResult(
        success: true,
        messagesSynced: remoteMessages.length + uploadedCount,
        conflicts: resolvedConflicts
            .where((c) => c.resolution == ConflictResolution.unresolved)
            .toList(),
      );
    } catch (e) {
      return SyncResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Fetches remote messages since the given timestamp
  Future<List<Map<String, dynamic>>> _fetchRemoteMessagesSince(
    String chatGroupId,
    int sinceTimestamp,
  ) async {
    final user = FirebaseAuth.instance.currentUser!;
    final collectionPath =
        'users/${user.uid}/chat_groups/$chatGroupId/messages';

    final query = FirebaseFirestore.instance
        .collection(collectionPath)
        .where('timestamp_ms', isGreaterThan: sinceTimestamp)
        .orderBy('timestamp_ms', descending: false)
        .limit(1000); // Reasonable batch size

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => doc.data()..['id'] = doc.id).toList();
  }

  /// Gets local messages that haven't been synced yet
  Future<List<Map<String, dynamic>>> _getLocalPendingMessages(
      String chatGroupId) async {
    // Get messages from SQLite that are not marked as delivered
    final allMessages =
        await _sqliteHelper.getMessages(0, 1000, chatGroupId: chatGroupId);
    return allMessages.where((msg) {
      // Consider messages pending if delivered is false or null
      return (msg['delivered'] == false ||
          msg['delivered'] == null ||
          msg['delivered'] == 0);
    }).toList();
  }

  /// Detects conflicts between local and remote messages
  List<SyncConflict> _detectConflicts(
    List<Map<String, dynamic>> localMessages,
    List<Map<String, dynamic>> remoteMessages,
  ) {
    final conflicts = <SyncConflict>[];

    // Create maps for efficient lookup
    final localMap = {for (var msg in localMessages) msg['id']: msg};
    final remoteMap = {for (var msg in remoteMessages) msg['id']: msg};

    // Find messages that exist in both with different content
    for (final localId in localMap.keys) {
      if (remoteMap.containsKey(localId)) {
        final local = localMap[localId]!;
        final remote = remoteMap[localId]!;

        if (_messagesDiffer(local, remote)) {
          conflicts.add(SyncConflict(
            localMessage: local,
            remoteMessage: remote,
          ));
        }
      }
    }

    return conflicts;
  }

  /// Checks if two messages have conflicting content
  bool _messagesDiffer(
      Map<String, dynamic> local, Map<String, dynamic> remote) {
    // Compare content, reactions, etc.
    final localContent = local['content'] ?? local['text'] ?? '';
    final remoteContent = remote['content'] ?? remote['text'] ?? '';
    if (localContent != remoteContent) return true;

    final localReactions = jsonEncode(local['reactions'] ?? []);
    final remoteReactions = jsonEncode(remote['reactions'] ?? []);
    if (localReactions != remoteReactions) return true;

    return false;
  }

  /// Automatically resolves conflicts using timestamp + UID strategy
  List<SyncConflict> _resolveConflicts(List<SyncConflict> conflicts) {
    final resolved = <SyncConflict>[];

    for (final conflict in conflicts) {
      final local = conflict.localMessage;
      final remote = conflict.remoteMessage;

      final localTimestamp = local['timestamp_ms'] ?? 0;
      final remoteTimestamp = remote['timestamp_ms'] ?? 0;
      final localUid = local['sender_uid'] ?? local['sender'];
      final remoteUid = remote['sender_uid'] ?? remote['sender'];

      ConflictResolution resolution;

      if (localTimestamp > remoteTimestamp) {
        resolution = ConflictResolution.useLocal;
      } else if (remoteTimestamp > localTimestamp) {
        resolution = ConflictResolution.useRemote;
      } else {
        // Same timestamp, use UID comparison
        if ((localUid ?? '').compareTo(remoteUid ?? '') > 0) {
          resolution = ConflictResolution.useLocal;
        } else {
          resolution = ConflictResolution.useRemote;
        }
      }

      resolved.add(conflict.copyWith(resolution: resolution));
    }

    return resolved;
  }

  /// Applies resolved conflict changes
  Future<void> _applyResolvedChanges(
      List<SyncConflict> conflicts, String chatGroupId) async {
    for (final conflict in conflicts) {
      final messageToUse = conflict.resolution == ConflictResolution.useLocal
          ? conflict.localMessage
          : conflict.remoteMessage;

      // Update local SQLite with resolved message
      await _sqliteHelper.insertMessage(messageToUse, chatGroupId: chatGroupId);

      // If using local version, update remote
      if (conflict.resolution == ConflictResolution.useLocal) {
        await _updateRemoteMessage(chatGroupId, messageToUse);
      }
    }
  }

  /// Updates a message in Firestore
  Future<void> _updateRemoteMessage(
      String chatGroupId, Map<String, dynamic> message) async {
    final user = FirebaseAuth.instance.currentUser!;
    final collectionPath =
        'users/${user.uid}/chat_groups/$chatGroupId/messages';
    final docId = message['id'];

    await FirebaseFirestore.instance
        .collection(collectionPath)
        .doc(docId)
        .set(message, SetOptions(merge: true));
  }

  /// Uploads pending local messages in batches
  Future<int> _batchUploadPendingMessages(
    Iterable<Map<String, dynamic>> messages,
    String chatGroupId,
  ) async {
    const batchSize = 10;
    int uploadedCount = 0;

    final batches = <List<Map<String, dynamic>>>[];
    final messageList = messages.toList();

    for (int i = 0; i < messageList.length; i += batchSize) {
      batches.add(messageList.sublist(
        i,
        i + batchSize > messageList.length ? messageList.length : i + batchSize,
      ));
    }

    for (final batch in batches) {
      final batchOps = <Future>[];

      for (final message in batch) {
        batchOps.add(_uploadSingleMessage(chatGroupId, message));
      }

      await Future.wait(batchOps);
      uploadedCount += batch.length;
    }

    return uploadedCount;
  }

  /// Uploads a single message to Firestore
  Future<void> _uploadSingleMessage(
      String chatGroupId, Map<String, dynamic> message) async {
    final user = FirebaseAuth.instance.currentUser!;
    final collectionPath =
        'users/${user.uid}/chat_groups/$chatGroupId/messages';
    final docId = message['id'];

    await FirebaseFirestore.instance
        .collection(collectionPath)
        .doc(docId)
        .set(message, SetOptions(merge: true));

    // Mark as delivered in local SQLite
    await _sqliteHelper.updateMessage(docId, {'delivered': true});
  }

  /// Merges two messages when conflict resolution requires it
  Map<String, dynamic> mergeMessages(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    // Take the newer timestamp
    final localTimestamp = local['timestamp_ms'] ?? 0;
    final remoteTimestamp = remote['timestamp_ms'] ?? 0;

    final merged = Map<String, dynamic>.from(
        localTimestamp > remoteTimestamp ? local : remote);

    // Merge reactions (combine unique ones)
    final localReactions = (local['reactions'] as List?) ?? [];
    final remoteReactions = (remote['reactions'] as List?) ?? [];
    final allReactions = [...localReactions, ...remoteReactions];
    final uniqueReactions = <Map<String, dynamic>>[];

    for (final reaction in allReactions) {
      if (!uniqueReactions.any((r) =>
          r['emoji'] == reaction['emoji'] && r['user'] == reaction['user'])) {
        uniqueReactions.add(reaction);
      }
    }

    merged['reactions'] = uniqueReactions;

    return merged;
  }

  /// Purges SQLite data older than 30 days
  Future<void> _purgeOldData() async {
    final cutoffTimestamp =
        DateTime.now().subtract(_purgeThreshold).millisecondsSinceEpoch;

    // Delete old messages from SQLite
    final db = await _sqliteHelper.database;
    await db.delete(
      'messages',
      where: 'timestamp_ms < ?',
      whereArgs: [cutoffTimestamp],
    );
  }

  /// Gets the last sync timestamp
  Future<int> getLastSyncTimestamp() async {
    final prefs = await _prefsFuture;
    return prefs.getInt(_lastSyncKey) ?? 0;
  }

  /// Manually sets the last sync timestamp
  Future<void> setLastSyncTimestamp(int timestamp) async {
    final prefs = await _prefsFuture;
    await prefs.setInt(_lastSyncKey, timestamp);
  }
}

// Extension for SyncConflict
extension SyncConflictExtension on SyncConflict {
  SyncConflict copyWith({
    Map<String, dynamic>? localMessage,
    Map<String, dynamic>? remoteMessage,
    ConflictResolution? resolution,
  }) {
    return SyncConflict(
      localMessage: localMessage ?? this.localMessage,
      remoteMessage: remoteMessage ?? this.remoteMessage,
      resolution: resolution ?? this.resolution,
    );
  }
}

// Riverpod provider for SyncManager - moved to providers.dart to avoid circular imports
// final syncManagerProvider = Provider<SyncManager>((ref) {
//   final sqliteHelper = ref.watch(sqliteHelperProvider);
//   return SyncManager(sqliteHelper: sqliteHelper);
// });
