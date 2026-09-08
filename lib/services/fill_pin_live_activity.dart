// PIN WAVE P2 — Fill PIN Lock Screen Live Activity.
//
// Friend-visible contract: an active Fill PIN shows Sit / Coming / Can't
// plus Coming hold mm:ss (5:00 → 0). Actions map through reduceComingHold —
// Coming is a 300s hold and never auto-sits. Tap / deep link reuses
// codsquadapp://chat/<id> so locationForDeepLink lands on the thread
// (pin header already binds).
//
// Native start/update/end lives on the existing Runner channel
// (com.squadsync/live_activities). Lock Screen buttons still need a
// Widget Extension + App Intents (separate App ID) — not this target,
// not a bundle ID change. XOR stays planPeacockSelfNotify.
import 'package:flutter/foundation.dart';

import '../chat/fill_pin_thread_header.dart';
import '../core/deep_link_routes.dart';
import '../core/notification_routes.dart';
import '../data/services/live_activity_manager.dart';
import 'coming_hold_machine.dart';
import 'fill_pin_nudge_audience.dart';
import 'pin_expire_machine.dart';

enum FillPinLiveActivityPhase { open, coming, seated, ended }

enum FillPinLiveActivityOp { none, start, update, end }

/// Lock-screen buttons for an active Fill PIN.
enum FillPinLiveActivityAction {
  sit,
  coming,
  cant,
}

const kFillPinLiveActivitySitLabel = 'Sit';
const kFillPinLiveActivityComingLabel = 'Coming';
const kFillPinLiveActivityCantLabel = "Can't";

const kFillPinLiveActivityActions = [
  FillPinLiveActivityAction.sit,
  FillPinLiveActivityAction.coming,
  FillPinLiveActivityAction.cant,
];

const kFillPinLiveActivityActionLabels = [
  kFillPinLiveActivitySitLabel,
  kFillPinLiveActivityComingLabel,
  kFillPinLiveActivityCantLabel,
];

const kFillPinLiveActivityActionIds = ['sit', 'coming', 'cant'];

/// Coming hold label: `5:00` … `0:00`. Never negative.
String formatComingHoldMmSs(Duration remaining) {
  final total = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

FillPinLiveActivityAction? fillPinLiveActivityActionFromId(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'sit':
      return FillPinLiveActivityAction.sit;
    case 'coming':
      return FillPinLiveActivityAction.coming;
    case 'cant':
    case 'can_t':
    case "can't":
    case 'cannot':
      return FillPinLiveActivityAction.cant;
    default:
      return null;
  }
}

String fillPinLiveActivityActionId(FillPinLiveActivityAction action) {
  switch (action) {
    case FillPinLiveActivityAction.sit:
      return 'sit';
    case FillPinLiveActivityAction.coming:
      return 'coming';
    case FillPinLiveActivityAction.cant:
      return 'cant';
  }
}

String fillPinLiveActivityActionLabel(FillPinLiveActivityAction action) {
  switch (action) {
    case FillPinLiveActivityAction.sit:
      return kFillPinLiveActivitySitLabel;
    case FillPinLiveActivityAction.coming:
      return kFillPinLiveActivityComingLabel;
    case FillPinLiveActivityAction.cant:
      return kFillPinLiveActivityCantLabel;
  }
}

/// Tap URL: existing chat route plus pin / lobby query for the header.
/// [locationForDeepLink] still resolves `/chat/<chatGroupId>`.
String fillPinDeepLink({
  required String chatGroupId,
  String? pinId,
  String? lobbyId,
}) {
  final thread = chatGroupId.trim();
  if (thread.isEmpty) {
    return Uri(scheme: kSimulatorDeepLinkScheme, host: 'chat').toString();
  }
  return Uri(
    scheme: kSimulatorDeepLinkScheme,
    host: 'chat',
    pathSegments: [thread],
    queryParameters: {
      if (_nonEmpty(pinId) != null) 'pin_id': pinId!.trim(),
      if (_nonEmpty(lobbyId) != null) 'lobby_id': lobbyId!.trim(),
    },
  ).toString();
}

/// Open the thread + pin through the existing chat deep-link table.
void openFillPinLiveActivity({
  required String chatGroupId,
  String? pinId,
  String? lobbyId,
  void Function(String location)? go,
}) {
  final location = locationForDeepLink(
    fillPinDeepLink(
      chatGroupId: chatGroupId,
      pinId: pinId,
      lobbyId: lobbyId,
    ),
  );
  if (location == null) return;
  (go ?? NotificationRoutes.go)?.call(location);
}

class FillPinLiveActivityPayload {
  const FillPinLiveActivityPayload({
    required this.chatGroupId,
    required this.phase,
    required this.seated,
    required this.maxSpots,
    this.pinId,
    this.lobbyId,
    this.gameName,
    this.holdRemaining = Duration.zero,
    this.activityId,
    this.updatedAt,
  });

  static const empty = FillPinLiveActivityPayload(
    chatGroupId: '',
    phase: FillPinLiveActivityPhase.ended,
    seated: 0,
    maxSpots: 0,
  );

  final String chatGroupId;
  final String? pinId;
  final String? lobbyId;
  final String? gameName;
  final FillPinLiveActivityPhase phase;
  final int seated;
  final int maxSpots;
  final Duration holdRemaining;
  final String? activityId;
  final DateTime? updatedAt;

  bool get isLive => phase != FillPinLiveActivityPhase.ended;

  bool get isComing => phase == FillPinLiveActivityPhase.coming;

  String get seatLabel => '$seated/$maxSpots';

  /// Lock-screen buttons. Empty once the pin / activity has ended.
  List<FillPinLiveActivityAction> get actions =>
      isLive ? kFillPinLiveActivityActions : const [];

  List<String> get actionLabels =>
      actions.map(fillPinLiveActivityActionLabel).toList(growable: false);

  List<String> get actionIds =>
      actions.map(fillPinLiveActivityActionId).toList(growable: false);

  /// Coming hold `mm:ss`. Empty unless the seat is on the 300s hold.
  String get holdLabel => isComing ? formatComingHoldMmSs(holdRemaining) : '';

  String get title {
    final game = _nonEmpty(gameName) ?? 'Fill PIN';
    if (phase == FillPinLiveActivityPhase.ended) return '$game ended';
    return '$game $seatLabel';
  }

  String get body {
    switch (phase) {
      case FillPinLiveActivityPhase.coming:
        return 'Coming $holdLabel';
      case FillPinLiveActivityPhase.seated:
        return "I'm in";
      case FillPinLiveActivityPhase.open:
        return 'Sit · Coming · Can\'t';
      case FillPinLiveActivityPhase.ended:
        return 'Pin ended';
    }
  }

  String get deepLink => fillPinDeepLink(
        chatGroupId: chatGroupId,
        pinId: pinId,
        lobbyId: lobbyId,
      );

  Map<String, dynamic> toChannelArgs() {
    return {
      'chatGroupId': chatGroupId,
      'pinId': pinId,
      'lobbyId': lobbyId,
      'gameName': gameName,
      'phase': phase.name,
      'seated': seated,
      'maxSpots': maxSpots,
      'seatLabel': seatLabel,
      'holdRemainingSeconds': holdRemaining.inSeconds < 0
          ? 0
          : holdRemaining.inSeconds,
      'holdLabel': holdLabel,
      'actions': actionLabels,
      'actionIds': actionIds,
      'title': title,
      'body': body,
      'deepLink': deepLink,
      if (activityId != null) 'activityId': activityId,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  factory FillPinLiveActivityPayload.fromChannelArgs(
    Map<String, dynamic> args,
  ) {
    final phaseName = args['phase'] as String? ?? 'ended';
    final phase = FillPinLiveActivityPhase.values.firstWhere(
      (value) => value.name == phaseName,
      orElse: () => FillPinLiveActivityPhase.ended,
    );
    final holdSeconds = (args['holdRemainingSeconds'] as num?)?.toInt() ?? 0;
    return FillPinLiveActivityPayload(
      chatGroupId: (args['chatGroupId'] as String? ?? '').trim(),
      pinId: _nonEmpty(args['pinId'] as String?),
      lobbyId: _nonEmpty(args['lobbyId'] as String?),
      gameName: _nonEmpty(args['gameName'] as String?),
      phase: phase,
      seated: (args['seated'] as num?)?.toInt() ?? 0,
      maxSpots: (args['maxSpots'] as num?)?.toInt() ?? 0,
      holdRemaining: Duration(seconds: holdSeconds < 0 ? 0 : holdSeconds),
      activityId: _nonEmpty(args['activityId'] as String?),
      updatedAt: DateTime.tryParse(args['updatedAt'] as String? ?? ''),
    );
  }

  FillPinLiveActivityPayload copyWith({
    String? chatGroupId,
    String? pinId,
    String? lobbyId,
    String? gameName,
    FillPinLiveActivityPhase? phase,
    int? seated,
    int? maxSpots,
    Duration? holdRemaining,
    String? activityId,
    DateTime? updatedAt,
    bool clearActivityId = false,
  }) {
    return FillPinLiveActivityPayload(
      chatGroupId: chatGroupId ?? this.chatGroupId,
      pinId: pinId ?? this.pinId,
      lobbyId: lobbyId ?? this.lobbyId,
      gameName: gameName ?? this.gameName,
      phase: phase ?? this.phase,
      seated: seated ?? this.seated,
      maxSpots: maxSpots ?? this.maxSpots,
      holdRemaining: holdRemaining ?? this.holdRemaining,
      activityId: clearActivityId ? null : (activityId ?? this.activityId),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class FillPinLiveActivityPlan {
  const FillPinLiveActivityPlan({
    required this.op,
    required this.payload,
  });

  final FillPinLiveActivityOp op;
  final FillPinLiveActivityPayload payload;

  bool get shouldInvoke => op != FillPinLiveActivityOp.none;
}

bool fillPinLiveActivityShouldShow({
  required bool hasSnapshot,
  PinExpireState expire = PinExpireState.idle,
}) {
  if (!hasSnapshot) return false;
  if (expire.phase == PinExpirePhase.expired ||
      expire.phase == PinExpirePhase.endedEarly) {
    return false;
  }
  return true;
}

FillPinLiveActivityPhase fillPinLiveActivityPhaseFor({
  required bool showing,
  ComingHoldState hold = ComingHoldState.idle,
}) {
  if (!showing) return FillPinLiveActivityPhase.ended;
  switch (hold.phase) {
    case ComingHoldPhase.coming:
      return FillPinLiveActivityPhase.coming;
    case ComingHoldPhase.seated:
      return FillPinLiveActivityPhase.seated;
    case ComingHoldPhase.idle:
    case ComingHoldPhase.released:
    case ComingHoldPhase.expired:
      return FillPinLiveActivityPhase.open;
  }
}

/// Pure start / update / end plan. No I/O. Not FCM — XOR stays
/// [planPeacockSelfNotify].
FillPinLiveActivityPlan planFillPinLiveActivity({
  required String chatGroupId,
  FillPinSnapshot? snapshot,
  ComingHoldState hold = ComingHoldState.idle,
  PinExpireState expire = PinExpireState.idle,
  String? currentActivityId,
  DateTime? now,
}) {
  final thread = chatGroupId.trim();
  final activityId = _nonEmpty(currentActivityId);
  final showing = fillPinLiveActivityShouldShow(
    hasSnapshot: snapshot != null && thread.isNotEmpty,
    expire: expire,
  );
  final phase = fillPinLiveActivityPhaseFor(showing: showing, hold: hold);
  final payload = FillPinLiveActivityPayload(
    chatGroupId: thread,
    pinId: _nonEmpty(hold.pinId) ??
        _nonEmpty(expire.pinId) ??
        _nonEmpty(snapshot?.lobbyId),
    lobbyId: _nonEmpty(snapshot?.lobbyId),
    gameName: _nonEmpty(snapshot?.gameName),
    phase: phase,
    seated: snapshot?.seated ?? 0,
    maxSpots: snapshot?.maxSpots ?? 0,
    holdRemaining: phase == FillPinLiveActivityPhase.coming
        ? hold.remaining
        : Duration.zero,
    activityId: activityId,
    updatedAt: now,
  );

  if (!showing) {
    if (activityId == null) {
      return FillPinLiveActivityPlan(
        op: FillPinLiveActivityOp.none,
        payload: payload,
      );
    }
    return FillPinLiveActivityPlan(
      op: FillPinLiveActivityOp.end,
      payload: payload,
    );
  }

  if (activityId == null) {
    return FillPinLiveActivityPlan(
      op: FillPinLiveActivityOp.start,
      payload: payload,
    );
  }
  return FillPinLiveActivityPlan(
    op: FillPinLiveActivityOp.update,
    payload: payload,
  );
}

/// Sit / Coming / Can't → [reduceComingHold]. Coming never auto-sits.
///
/// Sit from idle takes the seat (**I'm in**) by startComing + sit so
/// the existing machine owns the seated phase. Coming starts the 300s
/// hold only. Can't releases a Coming hold; seated Can't frees the seat
/// and fires the optional spot-open nudge stub.
void Function()? _needOneSpotOpenNudge({
  void Function()? onSpotOpenNudge,
  Iterable<String> memberUids = const [],
  Iterable<String> sitUids = const [],
  Iterable<String> comingUids = const [],
  Iterable<String> cantUids = const [],
}) {
  return () {
    fillPinNudgeAudience(
      memberUids: memberUids,
      sitUids: sitUids,
      comingUids: comingUids,
      cantUids: cantUids,
    );
    onSpotOpenNudge?.call();
  };
}

ComingHoldState applyFillPinLiveActivityAction({
  required FillPinLiveActivityAction action,
  required ComingHoldState current,
  int? seatIndex,
  String? pinId,
  String? userId,
  void Function()? onSpotOpenNudge,
  Iterable<String> memberUids = const [],
  Iterable<String> sitUids = const [],
  Iterable<String> comingUids = const [],
  Iterable<String> cantUids = const [],
}) {
  switch (action) {
    case FillPinLiveActivityAction.sit:
      if (current.phase == ComingHoldPhase.coming) {
        return reduceComingHold(
          current: current,
          event: ComingHoldEvent.sit,
        );
      }
      final started = reduceComingHold(
        current: current,
        event: ComingHoldEvent.startComing,
        seatIndex: seatIndex,
        pinId: pinId,
        userId: userId,
      );
      return reduceComingHold(
        current: started,
        event: ComingHoldEvent.sit,
      );

    case FillPinLiveActivityAction.coming:
      if (current.phase == ComingHoldPhase.coming ||
          current.phase == ComingHoldPhase.seated) {
        return current;
      }
      return reduceComingHold(
        current: current,
        event: ComingHoldEvent.startComing,
        seatIndex: seatIndex,
        pinId: pinId,
        userId: userId,
      );

    case FillPinLiveActivityAction.cant:
      final nudge = _needOneSpotOpenNudge(
        onSpotOpenNudge: onSpotOpenNudge,
        memberUids: memberUids,
        sitUids: sitUids,
        comingUids: comingUids,
        cantUids: cantUids,
      );
      if (current.phase == ComingHoldPhase.coming) {
        return reduceComingHold(
          current: current,
          event: ComingHoldEvent.release,
          onSpotOpenNudge: nudge,
        );
      }
      if (current.phase == ComingHoldPhase.seated) {
        nudge();
        return current.copyWith(
          phase: ComingHoldPhase.released,
          remaining: Duration.zero,
          shouldNudgeSpotOpen: true,
        );
      }
      return current;
  }
}

/// Clock tick on an active Coming hold. Never auto-sits; t=0 frees the
/// seat and may fire [onSpotOpenNudge].
ComingHoldState tickFillPinComingHold({
  required ComingHoldState current,
  Duration? elapsed,
  void Function()? onSpotOpenNudge,
  Iterable<String> memberUids = const [],
  Iterable<String> sitUids = const [],
  Iterable<String> comingUids = const [],
  Iterable<String> cantUids = const [],
}) {
  return reduceComingHold(
    current: current,
    event: ComingHoldEvent.tick,
    elapsed: elapsed,
    onSpotOpenNudge: _needOneSpotOpenNudge(
      onSpotOpenNudge: onSpotOpenNudge,
      memberUids: memberUids,
      sitUids: sitUids,
      comingUids: comingUids,
      cantUids: cantUids,
    ),
  );
}

/// Live path: Fill PIN snapshot + Coming hold. Local Live Activity
/// only — never FCM-to-self ([planPeacockSelfNotify] stays XOR).
class FillPinLiveActivity {
  FillPinLiveActivity._();

  static String? _activityId;
  static ComingHoldState _hold = ComingHoldState.idle;

  /// Test hook. Production talks to [LiveActivityManager] on iOS.
  @visibleForTesting
  static Future<String?> Function(FillPinLiveActivityPlan plan)? invokeHook;

  @visibleForTesting
  static String? get debugActivityId => _activityId;

  @visibleForTesting
  static ComingHoldState get debugHold => _hold;

  @visibleForTesting
  static void resetTestHooks() {
    invokeHook = null;
    _activityId = null;
    _hold = ComingHoldState.idle;
  }

  static Future<void> syncFromThread({
    required String chatGroupId,
    FillPinSnapshot? snapshot,
    ComingHoldState? hold,
    PinExpireState expire = PinExpireState.idle,
    DateTime? now,
  }) async {
    if (hold != null) _hold = hold;
    final plan = planFillPinLiveActivity(
      chatGroupId: chatGroupId,
      snapshot: snapshot,
      hold: _hold,
      expire: expire,
      currentActivityId: _activityId,
      now: now,
    );
    await _applyPlan(plan);
  }

  /// Lock-screen / App Intent action id (`sit` / `coming` / `cant`).
  static Future<ComingHoldState> applyChannelAction({
    required String actionId,
    required String chatGroupId,
    FillPinSnapshot? snapshot,
    PinExpireState expire = PinExpireState.idle,
    int? seatIndex,
    String? pinId,
    String? userId,
    DateTime? now,
    void Function()? onSpotOpenNudge,
  }) async {
    final action = fillPinLiveActivityActionFromId(actionId);
    if (action == null) return _hold;
    _hold = applyFillPinLiveActivityAction(
      action: action,
      current: _hold,
      seatIndex: seatIndex,
      pinId: pinId ?? snapshot?.lobbyId ?? _hold.pinId,
      userId: userId,
      onSpotOpenNudge: onSpotOpenNudge,
    );
    await syncFromThread(
      chatGroupId: chatGroupId,
      snapshot: snapshot,
      hold: _hold,
      expire: expire,
      now: now,
    );
    return _hold;
  }

  static Future<ComingHoldState> tick({
    required String chatGroupId,
    FillPinSnapshot? snapshot,
    PinExpireState expire = PinExpireState.idle,
    Duration? elapsed,
    DateTime? now,
    void Function()? onSpotOpenNudge,
  }) async {
    _hold = tickFillPinComingHold(
      current: _hold,
      elapsed: elapsed,
      onSpotOpenNudge: onSpotOpenNudge,
    );
    await syncFromThread(
      chatGroupId: chatGroupId,
      snapshot: snapshot,
      hold: _hold,
      expire: expire,
      now: now,
    );
    return _hold;
  }

  static Future<void> _applyPlan(FillPinLiveActivityPlan plan) async {
    if (!plan.shouldInvoke) return;

    final hook = invokeHook;
    if (hook != null) {
      final id = await hook(plan);
      _activityId =
          plan.op == FillPinLiveActivityOp.end ? null : _nonEmpty(id);
      return;
    }

    await _invokeNative(plan);
  }

  static Future<void> _invokeNative(FillPinLiveActivityPlan plan) async {
    final manager = LiveActivityManager();
    switch (plan.op) {
      case FillPinLiveActivityOp.start:
        _activityId = _nonEmpty(
          await manager.startFillPinActivity(plan.payload.toChannelArgs()),
        );
        return;
      case FillPinLiveActivityOp.update:
        final id = plan.payload.activityId;
        if (id == null) return;
        await manager.updateFillPinActivity(
          activityId: id,
          args: plan.payload.toChannelArgs(),
        );
        return;
      case FillPinLiveActivityOp.end:
        final id = plan.payload.activityId;
        if (id != null) await manager.endActivity(id);
        _activityId = null;
        return;
      case FillPinLiveActivityOp.none:
        return;
    }
  }
}

String? _nonEmpty(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}
