import 'package:flutter/foundation.dart';

import '../core/deep_link_routes.dart';
import '../data/services/live_activity_manager.dart';
import 'lobby_ready_lock.dart';

/// Lock Screen / home-widget payload for peacock Ready-Lock.
///
/// Native start/update/end lives on the existing Runner target
/// (`com.squadsync/live_activities`). Lock Screen UI still needs a Widget
/// Extension (separate App ID) — not this target, not a bundle ID change.
enum PeacockLockLiveActivityPhase { ready, locked, ended }

enum PeacockLockLiveActivityOp { none, start, update, end }

class PeacockLockLiveActivityPayload {
  const PeacockLockLiveActivityPayload({
    required this.lobbyId,
    required this.phase,
    required this.seatedCount,
    required this.readyCount,
    this.gameName,
    this.activityId,
  });

  final String lobbyId;
  final String? gameName;
  final PeacockLockLiveActivityPhase phase;
  final int seatedCount;
  final int readyCount;
  final String? activityId;

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
      'seatedCount': seatedCount,
      'readyCount': readyCount,
      'title': title,
      'body': body,
      'deepLink': deepLink,
      if (activityId != null) 'activityId': activityId,
    };
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
  }) async {
    final plan = planPeacockLockLiveActivity(
      snapshot: snapshot,
      lobbyId: lobbyId,
      gameName: gameName,
      currentActivityId: _activityId,
    );
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
