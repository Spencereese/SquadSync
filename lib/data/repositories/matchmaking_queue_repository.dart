import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/realtime_subscribe.dart';
import '../../services/matchmaking_queue_machine.dart';
import '../../services/supabase_service.dart';

const kMatchmakingQueueTable = 'matchmaking_queue';

/// Incremental Realtime change for [matchmaking_queue].
class MatchmakingQueueChange {
  const MatchmakingQueueChange({
    required this.userId,
    this.entry,
  });

  final String userId;

  /// Null means the row was deleted (idle).
  final MatchmakingQueueEntry? entry;
}

/// Persist / hydrate / Realtime for LFG looking state.
///
/// Null-client implementations no-op so unit harnesses never touch
/// [Supabase.instance].
abstract class MatchmakingQueueRepository {
  Future<void> upsert(String userId, MatchmakingQueueEntry entry);
  Future<void> remove(String userId);
  Future<Map<String, MatchmakingQueueEntry>> fetchActive();
  Stream<MatchmakingQueueChange> watch();
  Future<void> dispose();
}

MatchmakingQueuePhase? matchmakingPhaseFromRow(Object? raw) {
  final name = raw?.toString();
  if (name == null || name.isEmpty) return null;
  for (final phase in MatchmakingQueuePhase.values) {
    if (phase.name == name) return phase;
  }
  return null;
}

DateTime? matchmakingQueuedAtFromRow(Object? raw) {
  if (raw is DateTime) return raw.toUtc();
  if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw)?.toUtc();
  return null;
}

/// Snake_case row for upsert. Omits [created_at] so FIFO is preserved.
Map<String, dynamic> matchmakingQueueRow(
  String userId,
  MatchmakingQueueEntry entry,
) {
  return <String, dynamic>{
    'user_uid': userId,
    'phase': entry.phase.name,
    'squad_id': entry.squadId,
    'lobby_id': entry.lobbyId,
    'game_name': entry.gameName,
    'matched_user_id': entry.matchedUserId,
    'notification_id': entry.notificationId,
  };
}

MatchmakingQueueEntry? matchmakingQueueEntryFromRow(
  Map<String, dynamic>? row,
) {
  if (row == null || row.isEmpty) return null;
  final phase = matchmakingPhaseFromRow(row['phase']);
  if (phase == null || phase == MatchmakingQueuePhase.idle) {
    return null;
  }
  return MatchmakingQueueEntry(
    phase: phase,
    squadId: _nonEmpty(row['squad_id']),
    lobbyId: _nonEmpty(row['lobby_id']),
    gameName: _nonEmpty(row['game_name']),
    matchedUserId: _nonEmpty(row['matched_user_id']),
    notificationId: _nonEmpty(row['notification_id']),
    queuedAt: matchmakingQueuedAtFromRow(row['created_at']),
  );
}

String? _nonEmpty(Object? raw) {
  final value = raw?.toString();
  if (value == null || value.isEmpty) return null;
  return value;
}

String? matchmakingUserIdFromRow(Map<String, dynamic>? row) {
  return _nonEmpty(row?['user_uid']);
}

/// Live Supabase store. No-ops when [client] is null (unit / parked env).
class MatchmakingQueueRepositoryImpl implements MatchmakingQueueRepository {
  MatchmakingQueueRepositoryImpl({SupabaseClient? client})
      : _client = client ?? SupabaseService.maybeClient;

  final SupabaseClient? _client;
  RealtimeChannel? _channel;
  StreamController<MatchmakingQueueChange>? _watchController;
  int _watchRetries = 0;

  @override
  Future<void> upsert(String userId, MatchmakingQueueEntry entry) async {
    final client = _client;
    if (client == null || userId.isEmpty) return;
    if (entry.phase == MatchmakingQueuePhase.idle) {
      await remove(userId);
      return;
    }
    await client.from(kMatchmakingQueueTable).upsert(
          matchmakingQueueRow(userId, entry),
          onConflict: 'user_uid',
        );
  }

  @override
  Future<void> remove(String userId) async {
    final client = _client;
    if (client == null || userId.isEmpty) return;
    await client.from(kMatchmakingQueueTable).delete().eq('user_uid', userId);
  }

  @override
  Future<Map<String, MatchmakingQueueEntry>> fetchActive() async {
    final client = _client;
    if (client == null) return const <String, MatchmakingQueueEntry>{};
    final rows = await client
        .from(kMatchmakingQueueTable)
        .select()
        .order('created_at', ascending: true);
    final list = rows as List<dynamic>;
    final out = <String, MatchmakingQueueEntry>{};
    for (final raw in list) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final uid = matchmakingUserIdFromRow(row);
      final entry = matchmakingQueueEntryFromRow(row);
      if (uid == null || entry == null) continue;
      out[uid] = entry;
    }
    return out;
  }

  @override
  Stream<MatchmakingQueueChange> watch() {
    final existing = _watchController;
    if (existing != null) return existing.stream;
    final controller = StreamController<MatchmakingQueueChange>.broadcast(
      onListen: _subscribeWatch,
      onCancel: () {
        if (!(_watchController?.hasListener ?? true)) {
          unawaited(dispose());
        }
      },
    );
    _watchController = controller;
    return controller.stream;
  }

  void _subscribeWatch() {
    final client = _client;
    final controller = _watchController;
    if (client == null || controller == null || controller.isClosed) return;
    _channel?.unsubscribe();
    _channel = client
        .channel('matchmaking_queue_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: kMatchmakingQueueTable,
          callback: (payload) {
            final change = matchmakingQueueChangeFromPayload(
              eventType: payload.eventType.name,
              newRecord: payload.newRecord,
              oldRecord: payload.oldRecord,
            );
            if (change != null && !controller.isClosed) {
              controller.add(change);
            }
          },
        )
        .subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _watchRetries = 0;
        return;
      }
      if (!isDeadRealtimeStatus(status)) return;
      if (!shouldResubscribeAfterChannelError(_watchRetries)) {
        debugPrint('Matchmaking queue channel dead after resubscribe');
        return;
      }
      _watchRetries++;
      _subscribeWatch();
    });
  }

  @override
  Future<void> dispose() async {
    await _channel?.unsubscribe();
    _channel = null;
    final controller = _watchController;
    _watchController = null;
    await controller?.close();
  }
}

/// Pure mapping used by Realtime callbacks and unit tests.
MatchmakingQueueChange? matchmakingQueueChangeFromPayload({
  required String eventType,
  Map<String, dynamic>? newRecord,
  Map<String, dynamic>? oldRecord,
}) {
  final deleted = eventType.toLowerCase() == 'delete';
  if (deleted) {
    final uid = matchmakingUserIdFromRow(oldRecord) ??
        matchmakingUserIdFromRow(newRecord);
    if (uid == null) return null;
    return MatchmakingQueueChange(userId: uid);
  }
  final uid = matchmakingUserIdFromRow(newRecord) ??
      matchmakingUserIdFromRow(oldRecord);
  if (uid == null) return null;
  return MatchmakingQueueChange(
    userId: uid,
    entry: matchmakingQueueEntryFromRow(newRecord),
  );
}
