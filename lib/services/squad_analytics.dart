import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Named Firebase Analytics events for Phase C. Reuses existing
/// [FirebaseAnalytics] wiring. Params never include PII.
const kAnalyticsLobbyJoin = 'lobby_join';
const kAnalyticsPeacockOffer = 'peacock_offer';
const kAnalyticsPeacockLock = 'peacock_lock';
const kAnalyticsSessionRate = 'session_rate';
const kAnalyticsReadyCheck = 'ready_check';

const Set<String> kAnalyticsEventNames = {
  kAnalyticsLobbyJoin,
  kAnalyticsPeacockOffer,
  kAnalyticsPeacockLock,
  kAnalyticsSessionRate,
  kAnalyticsReadyCheck,
};

/// Keys that must never be sent (exact, case-insensitive, `_`/`-` folded).
const Set<String> kAnalyticsPiiKeys = {
  'user_id',
  'userid',
  'uid',
  'user',
  'email',
  'display_name',
  'displayname',
  'name',
  'username',
  'user_name',
  'full_name',
  'phone',
  'phone_number',
  'token',
  'access_token',
  'id_token',
  'refresh_token',
  'password',
  'rater_uid',
  'rater',
  'player_uids',
  'member_uids',
  'from_uid',
  'current_uid',
  'matched_user_id',
  'notification_id',
  'clip_id',
  'video_url',
  'thumb_url',
  'file_name',
  'comment',
  'title',
  'lobby_id',
  'squad_id',
  'match_id',
};

bool isAnalyticsPiiKey(String key) {
  final k = key.trim().toLowerCase().replaceAll('-', '_');
  if (k.isEmpty) return true;
  if (kAnalyticsPiiKeys.contains(k)) return true;
  if (k.contains('password') || k.contains('phone') || k.contains('email')) {
    return true;
  }
  if (k.contains('token')) return true;
  if (k.endsWith('_uid') || k.endsWith('_email')) return true;
  if (k.endsWith('_id') && k != 'experiment_id') return true;
  if (k == 'name') return true;
  if (k.endsWith('_name') && k != 'game_name') return true;
  return false;
}

Object? _analyticsValue(Object? value) {
  if (value == null) return null;
  if (value is bool) return value ? 1 : 0;
  if (value is int || value is double) return value;
  if (value is num) {
    return value == value.roundToDouble() ? value.toInt() : value.toDouble();
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('@')) return null;
    return trimmed.length <= 100 ? trimmed : trimmed.substring(0, 100);
  }
  return null;
}

/// Drop PII keys, empty values, and non-Firebase types. Cap at 25 params.
Map<String, Object> sanitizeAnalyticsParams(Map<String, Object?>? raw) {
  if (raw == null || raw.isEmpty) return const {};
  final out = <String, Object>{};
  for (final entry in raw.entries) {
    if (out.length >= 25) break;
    final name = entry.key.trim();
    if (name.isEmpty || name.length > 40) continue;
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(name)) continue;
    if (isAnalyticsPiiKey(name)) continue;
    final value = _analyticsValue(entry.value);
    if (value == null) continue;
    out[name] = value;
  }
  return out;
}

Map<String, Object> lobbyJoinParams({
  String? source,
  String? gameName,
}) {
  return sanitizeAnalyticsParams({
    'source': source,
    'game_name': gameName,
  });
}

Map<String, Object> peacockOfferParams({
  String? source,
  String? gameName,
  int? seatIndex,
}) {
  return sanitizeAnalyticsParams({
    'source': source,
    'game_name': gameName,
    if (seatIndex != null) 'seat_index': seatIndex,
  });
}

Map<String, Object> peacockLockParams({
  int? seatedCount,
  int? readyCount,
}) {
  return sanitizeAnalyticsParams({
    if (seatedCount != null) 'seated_count': seatedCount,
    if (readyCount != null) 'ready_count': readyCount,
  });
}

Map<String, Object> sessionRateParams({
  int? stars,
  String? result,
  bool skipped = false,
}) {
  return sanitizeAnalyticsParams({
    if (stars != null) 'stars': stars,
    'result': result,
    'skipped': skipped,
  });
}

Map<String, Object> readyCheckParams({
  int? seatedCount,
  int? readyCount,
  String? outcome,
}) {
  return sanitizeAnalyticsParams({
    if (seatedCount != null) 'seated_count': seatedCount,
    if (readyCount != null) 'ready_count': readyCount,
    'outcome': outcome,
  });
}

/// Fire-and-forget logger. [logHook] intercepts in unit tests so
/// [FirebaseAnalytics.instance] is never required in the harness.
class SquadAnalytics {
  SquadAnalytics._();

  /// Test hook. Production talks to [FirebaseAnalytics.instance].
  @visibleForTesting
  static Future<void> Function(String name, Map<String, Object> params)?
      logHook;

  @visibleForTesting
  static void resetTestHooks() {
    logHook = null;
  }

  static Future<void> log(
    String name, [
    Map<String, Object?>? parameters,
  ]) async {
    final event = name.trim();
    if (event.isEmpty) return;
    final params = sanitizeAnalyticsParams(parameters);
    final hook = logHook;
    if (hook != null) {
      await hook(event, params);
      return;
    }
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: event,
        parameters: params.isEmpty ? null : params,
      );
    } catch (_) {
      // Never break product or unit harnesses on analytics.
    }
  }

  static Future<void> logLobbyJoin({
    String? source,
    String? gameName,
  }) {
    return log(kAnalyticsLobbyJoin, lobbyJoinParams(
      source: source,
      gameName: gameName,
    ));
  }

  static Future<void> logPeacockOffer({
    String? source,
    String? gameName,
    int? seatIndex,
  }) {
    return log(
      kAnalyticsPeacockOffer,
      peacockOfferParams(
        source: source,
        gameName: gameName,
        seatIndex: seatIndex,
      ),
    );
  }

  static Future<void> logPeacockLock({
    int? seatedCount,
    int? readyCount,
  }) {
    return log(
      kAnalyticsPeacockLock,
      peacockLockParams(
        seatedCount: seatedCount,
        readyCount: readyCount,
      ),
    );
  }

  static Future<void> logSessionRate({
    int? stars,
    String? result,
    bool skipped = false,
  }) {
    return log(
      kAnalyticsSessionRate,
      sessionRateParams(
        stars: stars,
        result: result,
        skipped: skipped,
      ),
    );
  }

  static Future<void> logReadyCheck({
    int? seatedCount,
    int? readyCount,
    String? outcome,
  }) {
    return log(
      kAnalyticsReadyCheck,
      readyCheckParams(
        seatedCount: seatedCount,
        readyCount: readyCount,
        outcome: outcome,
      ),
    );
  }
}
