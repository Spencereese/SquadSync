import 'package:flutter/foundation.dart';

import '../core/deep_link_routes.dart';
import '../data/services/live_activity_manager.dart';
import 'lobby_ready_lock.dart';

/// Lock Screen / home-widget payload for peacock Ready-Lock.
///
/// Native start/update/end lives on the existing Runner target
/// (`com.squadsync/live_activities`). Lock Screen UI still needs a Widget
/// Extension (separate App ID) — not this target, not a bundle ID change.
/// This file is the Dart payload mock only; it does not register an
/// ActivityConfiguration or a Widget Extension App ID.
enum PeacockLockLiveActivityPhase { ready, locked, ended }

enum PeacockLockLiveActivityOp { none, start, update, end }

/// Glance state for the home-widget / Live Activity payload mock.
/// Native Lock Screen UI still needs a Widget Extension App ID.
enum PeacockLockWidgetView { empty, ready, locked, unlocked, stale }

/// How long an un-refreshed widget payload may sit before it is stale.
/// Dart payload-mock TTL only — not an ActivityKit entitlement.
const kPeacockLockWidgetStaleTimeout = Duration(minutes: 8);

class PeacockLockLiveActivityPayload {
  const PeacockLockLiveActivityPayload({
    required this.lobbyId,
    required this.phase,
    required this.seatedCount,
    required this.readyCount,
    this.gameName,
    this.activityId,
    this.updatedAt,
  });

  /// Empty home-widget / Live Activity payload. No lobby, no peacock.
  static const empty = PeacockLockLiveActivityPayload(
    lobbyId: '',
    phase: PeacockLockLiveActivityPhase.ended,
    seatedCount: 0,
    readyCount: 0,
  );

  final String lobbyId;
  final String? gameName;
  final PeacockLockLiveActivityPhase phase;
  final int seatedCount;
  final int readyCount;
  final String? activityId;
  final DateTime? updatedAt;

  bool get isLocked => phase == PeacockLockLiveActivityPhase.locked;

  DateTime? get staleAt {
    final stamp = updatedAt;
    if (stamp == null) return null;
    return stamp.add(kPeacockLockWidgetStaleTimeout);
  }

  /// Outdated / expired payload. [updatedAt] missing is not stale.
  bool isStaleAt(DateTime now) {
    final expires = staleAt;
    if (expires == null) return false;
    return !now.isBefore(expires);
  }

  String get title {
    switch (phase) {
      case PeacockLockLiveActivityPhase.locked:
        return 'Squad locked';
      case PeacockLockLiveActivityPhase.ready:
        return 'Squad ready';
      case PeacockLockLiveActivityPhase.ended:
        return 'Squad lock ended';
    }
  }

  String get body {
    final game = _nonEmpty(gameName);
    switch (phase) {
      case PeacockLockLiveActivityPhase.locked:
        return game == null
            ? "Everyone's ready — go in the game"
            : "Everyone's ready for $game — go in the game";
      case PeacockLockLiveActivityPhase.ready:
        final counts = '$readyCount of $seatedCount ready';
        return game == null ? counts : '$counts for $game';
      case PeacockLockLiveActivityPhase.ended:
        return game == null ? 'Lobby unlocked' : '$game unlocked';
    }
  }

  /// Tap URL shares [locationForDeepLink] with lobby share / lock notify.
  String get deepLink {
    if (lobbyId.isEmpty) {
      return Uri(scheme: kSimulatorDeepLinkScheme, host: 'lobby').toString();
    }
    if (phase == PeacockLockLiveActivityPhase.locked) {
      return Uri(
        scheme: kSimulatorDeepLinkScheme,
        host: 'notify',
        queryParameters: {
          'type': kLobbyLockedType,
          'lobby_id': lobbyId,
          if (_nonEmpty(gameName) != null) 'game_name': gameName!.trim(),
        },
      ).toString();
    }
    return lobbyShareDeepLink(lobbyId: lobbyId);
  }

  Map<String, dynamic> toChannelArgs() {
    return {
      'lobbyId': lobbyId,
      'gameName': gameName,
      'phase': phase.name,
      'locked': isLocked,
      'seatedCount': seatedCount,
      'readyCount': readyCount,
      'title': title,
      'body': body,
      'deepLink': deepLink,
      if (activityId != null) 'activityId': activityId,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (staleAt != null) 'staleAt': staleAt!.toIso8601String(),
    };
  }

  factory PeacockLockLiveActivityPayload.fromChannelArgs(
    Map<String, dynamic> args,
  ) {
    final phaseName = args['phase'] as String? ?? 'ended';
    final phase = PeacockLockLiveActivityPhase.values.firstWhere(
      (value) => value.name == phaseName,
      orElse: () => PeacockLockLiveActivityPhase.ended,
    );
    return PeacockLockLiveActivityPayload(
      lobbyId: (args['lobbyId'] as String? ?? '').trim(),
      gameName: _nonEmpty(args['gameName'] as String?),
      phase: phase,
      seatedCount: (args['seatedCount'] as num?)?.toInt() ?? 0,
      readyCount: (args['readyCount'] as num?)?.toInt() ?? 0,
      activityId: _nonEmpty(args['activityId'] as String?),
      updatedAt: DateTime.tryParse(args['updatedAt'] as String? ?? ''),
    );
  }

  PeacockLockLiveActivityPayload copyWith({
    String? lobbyId,
    String? gameName,
    PeacockLockLiveActivityPhase? phase,
    int? seatedCount,
    int? readyCount,
    String? activityId,
    DateTime? updatedAt,
    bool clearActivityId = false,
    bool clearUpdatedAt = false,
  }) {
    return PeacockLockLiveActivityPayload(
      lobbyId: lobbyId ?? this.lobbyId,
      gameName: gameName ?? this.gameName,
      phase: phase ?? this.phase,
      seatedCount: seatedCount ?? this.seatedCount,
      readyCount: readyCount ?? this.readyCount,
      activityId: clearActivityId ? null : (activityId ?? this.activityId),
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    );
  }
}

class PeacockLockLiveActivityPlan {
  const PeacockLockLiveActivityPlan({
    required this.op,
    required this.payload,
  });

  final PeacockLockLiveActivityOp op;
  final PeacockLockLiveActivityPayload payload;

  bool get shouldInvoke => op != PeacockLockLiveActivityOp.none;
}

/// Pure start / update / end plan for a peacock-lock Live Activity or
/// home widget. No I/O. Not FCM — XOR stays [planPeacockSelfNotify].
PeacockLockLiveActivityPlan planPeacockLockLiveActivity({
  required LobbyReadyLockSnapshot snapshot,
  required String lobbyId,
  String? gameName,
  String? currentActivityId,
  DateTime? now,
}) {
  final lobby = lobbyId.trim();
  final activityId = _nonEmpty(currentActivityId);
  final seatedCount = snapshot.seatedUids.length;
  final readyCount = snapshot.readyUids.length;
  final show = lobby.isNotEmpty && seatedCount > 0;

  if (!show) {
    final payload = PeacockLockLiveActivityPayload(
      lobbyId: lobby,
      gameName: _nonEmpty(gameName),
      phase: PeacockLockLiveActivityPhase.ended,
      seatedCount: 0,
      readyCount: 0,
      activityId: activityId,
      updatedAt: now,
    );
    if (activityId == null) {
      return PeacockLockLiveActivityPlan(
        op: PeacockLockLiveActivityOp.none,
        payload: payload,
      );
    }
    return PeacockLockLiveActivityPlan(
      op: PeacockLockLiveActivityOp.end,
      payload: payload,
    );
  }

  final phase = snapshot.isLocked
      ? PeacockLockLiveActivityPhase.locked
      : PeacockLockLiveActivityPhase.ready;
  final payload = PeacockLockLiveActivityPayload(
    lobbyId: lobby,
    gameName: _nonEmpty(gameName),
    phase: phase,
    seatedCount: seatedCount,
    readyCount: readyCount,
    activityId: activityId,
    updatedAt: now,
  );
  if (activityId == null) {
    return PeacockLockLiveActivityPlan(
      op: PeacockLockLiveActivityOp.start,
      payload: payload,
    );
  }
  return PeacockLockLiveActivityPlan(
    op: PeacockLockLiveActivityOp.update,
    payload: payload,
  );
}

/// Glance state for the home-widget payload mock. Pure. No native I/O.
///
/// Lock Screen UI still needs a Widget Extension App ID — this maps the
/// existing start/update/end payload onto empty / locked / unlocked / stale.
PeacockLockWidgetView resolvePeacockLockWidgetView({
  required PeacockLockLiveActivityPayload payload,
  PeacockLockLiveActivityOp op = PeacockLockLiveActivityOp.none,
  PeacockLockLiveActivityPhase? previousPhase,
  DateTime? now,
}) {
  if (now != null && payload.isStaleAt(now)) {
    return PeacockLockWidgetView.stale;
  }
  if (payload.phase == PeacockLockLiveActivityPhase.locked) {
    return PeacockLockWidgetView.locked;
  }
  if (payload.phase == PeacockLockLiveActivityPhase.ready) {
    if (previousPhase == PeacockLockLiveActivityPhase.locked) {
      return PeacockLockWidgetView.unlocked;
    }
    return PeacockLockWidgetView.ready;
  }
  if (op == PeacockLockLiveActivityOp.end) {
    return PeacockLockWidgetView.unlocked;
  }
  return PeacockLockWidgetView.empty;
}

/// Outdated / expired stored payload → mark stale and clear when live.
/// Fresh Ready-Lock snapshots still go through [planPeacockLockLiveActivity].
PeacockLockLiveActivityPlan planStalePeacockLockWidget({
  required PeacockLockLiveActivityPayload lastPayload,
  required DateTime now,
}) {
  if (!lastPayload.isStaleAt(now)) {
    return PeacockLockLiveActivityPlan(
      op: PeacockLockLiveActivityOp.none,
      payload: lastPayload,
    );
  }
  final activityId = _nonEmpty(lastPayload.activityId);
  final payload = PeacockLockLiveActivityPayload(
    lobbyId: lastPayload.lobbyId,
    gameName: lastPayload.gameName,
    phase: PeacockLockLiveActivityPhase.ended,
    seatedCount: 0,
    readyCount: 0,
    activityId: activityId,
    updatedAt: now,
  );
  if (activityId == null) {
    return PeacockLockLiveActivityPlan(
      op: PeacockLockLiveActivityOp.none,
      payload: payload,
    );
  }
  return PeacockLockLiveActivityPlan(
    op: PeacockLockLiveActivityOp.end,
    payload: payload,
  );
}

/// Live path: [LobbyNotifier.applySeatedReady] / [LobbyNotifier.lockSpot].
/// Local Live Activity / widget only — never FCM-to-self.
class PeacockLockLiveActivity {
  PeacockLockLiveActivity._();

  static String? _activityId;

  /// Test hook. Production talks to [LiveActivityManager] on iOS.
  @visibleForTesting
  static Future<String?> Function(PeacockLockLiveActivityPlan plan)? invokeHook;

  @visibleForTesting
  static String? get debugActivityId => _activityId;

  @visibleForTesting
  static void resetTestHooks() {
    invokeHook = null;
    _activityId = null;
  }

  static Future<void> syncFromReadyLock({
    required LobbyReadyLockSnapshot snapshot,
    required String lobbyId,
    String? gameName,
    DateTime? now,
  }) async {
    final plan = planPeacockLockLiveActivity(
      snapshot: snapshot,
      lobbyId: lobbyId,
      gameName: gameName,
      currentActivityId: _activityId,
      now: now,
    );
    await _applyPlan(plan);
  }

  /// Clear an outdated / expired widget payload. Payload-mock only.
  static Future<void> syncStaleWidget({
    required PeacockLockLiveActivityPayload lastPayload,
    DateTime? now,
  }) async {
    final plan = planStalePeacockLockWidget(
      lastPayload: lastPayload,
      now: now ?? DateTime.now(),
    );
    await _applyPlan(plan);
  }

  static Future<void> _applyPlan(PeacockLockLiveActivityPlan plan) async {
    if (!plan.shouldInvoke) return;

    final hook = invokeHook;
    if (hook != null) {
      final id = await hook(plan);
      _activityId =
          plan.op == PeacockLockLiveActivityOp.end ? null : _nonEmpty(id);
      return;
    }

    await _invokeNative(plan);
  }

  static Future<void> _invokeNative(PeacockLockLiveActivityPlan plan) async {
    final manager = LiveActivityManager();
    switch (plan.op) {
      case PeacockLockLiveActivityOp.start:
        _activityId = _nonEmpty(
          await manager.startPeacockLockActivity(plan.payload.toChannelArgs()),
        );
        return;
      case PeacockLockLiveActivityOp.update:
        final id = plan.payload.activityId;
        if (id == null) return;
        await manager.updatePeacockLockActivity(
          activityId: id,
          args: plan.payload.toChannelArgs(),
        );
        return;
      case PeacockLockLiveActivityOp.end:
        final id = plan.payload.activityId;
        if (id != null) await manager.endActivity(id);
        _activityId = null;
        return;
      case PeacockLockLiveActivityOp.none:
        return;
    }
  }
}

String? _nonEmpty(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}
