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

Map<String, Object> lfgEnqueueParams({
  String? gameName,
}) {
  return lobbyJoinParams(source: 'lfg', gameName: gameName);
}

/// Fire/persist mapper for named core-loop events.
///
/// Success is a named event that reached [FirebaseAnalytics] (or [logHook]).
/// Empty is a blank event name — nothing to fire, not a silent success.
/// Thrown fire/persist is failed. Retry is calling [runAnalyticsFire] again.
enum AnalyticsFireOutcome { success, empty, failed }

const kAnalyticsFireErrorCopy = "Couldn't log analytics event";
const kAnalyticsFireErrorHint = 'Check your connection and try again.';
const kAnalyticsFireEmptyCopy = 'Nothing to log';
const kAnalyticsFireEmptyHint = 'Event name is empty.';
const kAnalyticsFireRetryLabel = 'Retry';

class AnalyticsFireResult {
  const AnalyticsFireResult.success({
    required this.name,
    this.params = const {},
  })  : outcome = AnalyticsFireOutcome.success,
        error = null;

  const AnalyticsFireResult.empty({
    this.name = '',
    this.params = const {},
  })  : outcome = AnalyticsFireOutcome.empty,
        error = null;

  const AnalyticsFireResult.failed(
    this.error, {
    this.name = '',
    this.params = const {},
  }) : outcome = AnalyticsFireOutcome.failed;

  final AnalyticsFireOutcome outcome;
  final String name;
  final Map<String, Object> params;
  final Object? error;

  bool get isSuccess => outcome == AnalyticsFireOutcome.success;
  bool get isEmpty => outcome == AnalyticsFireOutcome.empty;
  bool get isFailed => outcome == AnalyticsFireOutcome.failed;
}

Key analyticsFireFeedbackKey(AnalyticsFireOutcome outcome) {
  switch (outcome) {
    case AnalyticsFireOutcome.success:
      return const Key('analytics-fire-success');
    case AnalyticsFireOutcome.empty:
      return const Key('analytics-fire-empty');
    case AnalyticsFireOutcome.failed:
      return const Key('analytics-fire-error');
  }
}

Key analyticsFireHintKey(AnalyticsFireOutcome outcome) {
  switch (outcome) {
    case AnalyticsFireOutcome.failed:
      return const Key('analytics-fire-error-hint');
    case AnalyticsFireOutcome.empty:
      return const Key('analytics-fire-empty-hint');
    case AnalyticsFireOutcome.success:
      return const Key('analytics-fire-success');
  }
}

Key analyticsFireRetryKey() => const Key('analytics-fire-retry');

Key analyticsFireDetailKey() => const Key('analytics-fire-error-detail');

String analyticsFireMessage(AnalyticsFireResult result) {
  switch (result.outcome) {
    case AnalyticsFireOutcome.success:
      return result.name;
    case AnalyticsFireOutcome.empty:
      return kAnalyticsFireEmptyCopy;
    case AnalyticsFireOutcome.failed:
      return kAnalyticsFireErrorCopy;
  }
}

String? analyticsFireHint(AnalyticsFireResult result) {
  switch (result.outcome) {
    case AnalyticsFireOutcome.failed:
      return kAnalyticsFireErrorHint;
    case AnalyticsFireOutcome.empty:
      return kAnalyticsFireEmptyHint;
    case AnalyticsFireOutcome.success:
      return null;
  }
}

String analyticsFireErrorDetail(Object? error) {
  if (error == null) return '';
  final text = error.toString().trim();
  if (text.isEmpty) return '';
  const prefix = 'Exception: ';
  if (text.startsWith(prefix) && text.length > prefix.length) {
    return text.substring(prefix.length);
  }
  return text;
}

/// Map a fire/persist attempt. Blank name is empty (no write). Thrown
/// [fire] is error. Retry is calling this again with the same [fire].
Future<AnalyticsFireResult> runAnalyticsFire(
  Future<void> Function(String name, Map<String, Object> params) fire, {
  required String name,
  Map<String, Object?>? parameters,
}) async {
  final event = name.trim();
  if (event.isEmpty) {
    return const AnalyticsFireResult.empty();
  }
  final params = sanitizeAnalyticsParams(parameters);
  try {
    await fire(event, params);
    return AnalyticsFireResult.success(name: event, params: params);
  } catch (e) {
    return AnalyticsFireResult.failed(e, name: event, params: params);
  }
}

Future<AnalyticsFireResult> retryAnalyticsFire(
  Future<void> Function(String name, Map<String, Object> params) fire, {
  required String name,
  Map<String, Object?>? parameters,
}) =>
    runAnalyticsFire(fire, name: name, parameters: parameters);

/// Fire-and-forget logger. [logHook] intercepts in unit tests so
/// [FirebaseAnalytics.instance] is never required in the harness.
///
/// Returns [AnalyticsFireResult] so empty/error is inspectable. Thrown
/// Firebase / hook never bubbles into product call sites.
class SquadAnalytics {
  SquadAnalytics._();

  /// Test hook. Production talks to [FirebaseAnalytics.instance].
  @visibleForTesting
  static Future<void> Function(String name, Map<String, Object> params)?
      logHook;

  /// Last fire/persist result. Null before the first [log] in a harness.
  @visibleForTesting
  static AnalyticsFireResult? lastResult;

  @visibleForTesting
  static void resetTestHooks() {
    logHook = null;
    lastResult = null;
  }

  /// Intercepts [log] into a list so unit tests mock Firebase.
  @visibleForTesting
  static List<({String name, Map<String, Object> params})> captureLogs() {
    final logs = <({String name, Map<String, Object> params})>[];
    logHook = (name, params) async {
      logs.add((name: name, params: Map<String, Object>.from(params)));
    };
    return logs;
  }

  static Future<AnalyticsFireResult> log(
    String name, [
    Map<String, Object?>? parameters,
  ]) async {
    final result = await runAnalyticsFire(
      (event, params) async {
        final hook = logHook;
        if (hook != null) {
          await hook(event, params);
          return;
        }
        await FirebaseAnalytics.instance.logEvent(
          name: event,
          parameters: params.isEmpty ? null : params,
        );
      },
      name: name,
      parameters: parameters,
    );
    lastResult = result;
    if (result.isFailed && kDebugMode) {
      debugPrint(
        'SquadAnalytics: ${analyticsFireMessage(result)}'
        '${result.name.isEmpty ? '' : ' (${result.name})'}',
      );
    }
    return result;
  }

  static Future<AnalyticsFireResult> logLobbyJoin({
    String? source,
    String? gameName,
  }) {
    return log(kAnalyticsLobbyJoin, lobbyJoinParams(
      source: source,
      gameName: gameName,
    ));
  }

  /// LFG enqueue (`startLooking`). Reuses [kAnalyticsLobbyJoin] with
  /// `source: lfg` — no new vendor, no PII.
  static Future<AnalyticsFireResult> logLfgEnqueue({
    String? gameName,
  }) {
    return log(kAnalyticsLobbyJoin, lfgEnqueueParams(gameName: gameName));
  }

  static Future<AnalyticsFireResult> logPeacockOffer({
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

  static Future<AnalyticsFireResult> logPeacockLock({
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

  static Future<AnalyticsFireResult> logSessionRate({
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

  static Future<AnalyticsFireResult> logReadyCheck({
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
