import '../domain/entities/lobby_state.dart';
import '../domain/entities/message.dart';
import 'availability_on.dart';
import 'grok_concierge_machine.dart';
import 'grok_service.dart';
import 'matchmaking_queue_machine.dart';
import 'presence_badges.dart';

/// In-memory UTC-day spend tracker. Mirrors the backend cap so the client
/// cannot fire unbounded Grok calls if Cloud Run has not picked up the guard.
class GrokSpendTracker {
  GrokSpendTracker({
    int callCap = kGrokConciergeDailyCallCap,
    double usdCap = kGrokConciergeDailyUsdCap,
  })  : _callCap = callCap,
        _usdCap = usdCap;

  static GrokSpendTracker instance = GrokSpendTracker();

  final int _callCap;
  final double _usdCap;
  GrokSpendState _state = const GrokSpendState.empty();

  GrokSpendState get state => _state;

  static void resetInstance() {
    instance = GrokSpendTracker();
  }

  GrokBudgetDecision peek(DateTime now) => reduceGrokSpend(
        current: _state,
        now: now,
        callCap: _callCap,
        usdCap: _usdCap,
      );

  GrokBudgetDecision consume(DateTime now) {
    final decision = peek(now);
    if (decision.allowed) {
      _state = decision.next;
    }
    return decision;
  }
}

class GrokConciergeResult {
  const GrokConciergeResult({
    required this.command,
    required this.text,
    this.usedFallback = false,
    this.budgetExceeded = false,
  });

  final GrokConciergeCommand command;
  final String text;
  final bool usedFallback;
  final bool budgetExceeded;
}

typedef GrokConciergeCaller = Future<String> Function(
  String userMessage, {
  String? context,
  List<String>? recentMessages,
  String? command,
});

/// Runs one of the three concierge commands through existing [GrokService].
class GrokConciergeRunner {
  GrokConciergeRunner({
    GrokService? grok,
    GrokSpendTracker? spend,
    GrokConciergeCaller? caller,
  })  : _grok = grok,
        _spend = spend ?? GrokSpendTracker.instance,
        _caller = caller;

  final GrokService? _grok;
  final GrokSpendTracker _spend;
  final GrokConciergeCaller? _caller;

  Future<GrokConciergeResult> run({
    required GrokConciergeCommand command,
    required GrokConciergeContext context,
  }) async {
    final now = context.now;
    final decision = _spend.peek(now);
    if (!decision.allowed) {
      return GrokConciergeResult(
        command: command,
        text: kGrokBudgetExceededCopy,
        usedFallback: true,
        budgetExceeded: true,
      );
    }

    final prompt = buildConciergePrompt(command, context);
    final fallback = conciergeFallback(command, context);
    try {
      final raw = await _call(prompt);
      final trimmed = raw.trim();
      if (trimmed == kGrokBudgetExceededCopy) {
        return GrokConciergeResult(
          command: command,
          text: kGrokBudgetExceededCopy,
          usedFallback: true,
          budgetExceeded: true,
        );
      }
      if (trimmed.isEmpty || looksLikeGrokTransportFailure(trimmed)) {
        return GrokConciergeResult(
          command: command,
          text: fallback,
          usedFallback: true,
        );
      }
      _spend.consume(now);
      return GrokConciergeResult(command: command, text: trimmed);
    } catch (_) {
      return GrokConciergeResult(
        command: command,
        text: fallback,
        usedFallback: true,
      );
    }
  }

  Future<String> _call(GrokConciergePrompt prompt) {
    final commandId = grokConciergeCommandId(prompt.command);
    if (_caller != null) {
      return _caller(
        prompt.userMessage,
        context: prompt.context,
        recentMessages: prompt.recentMessages,
        command: commandId,
      );
    }
    return (_grok ?? GrokService()).getGrokResponse(
      prompt.userMessage,
      context: prompt.context,
      recentMessages: prompt.recentMessages,
      command: commandId,
    );
  }
}

GrokConciergeContext buildConciergeContext({
  required DateTime now,
  LobbyState? lobbyState,
  List<GrokConciergeChatLine> chatLines = const [],
  MatchmakingQueueTracker? lfg,
  AvailabilityOnStore? onStore,
}) {
  final names = lobbyState?.memberDisplayNames ?? const <String, String>{};
  final uids = <String>{
    ...?lobbyState?.lobbyMemberUids,
    ...names.keys,
    ...?lobbyState?.currentLobby?.memberUids,
  };
  final members = <GrokConciergeMember>[];
  for (final raw in uids) {
    final uid = raw.trim();
    if (uid.isEmpty) continue;
    final badges = resolvePresenceBadgesFromTrackers(
      userId: uid,
      lobbyState: lobbyState,
      lfg: lfg,
      onStore: onStore,
    );
    members.add(GrokConciergeMember(
      uid: uid,
      label: (names[uid] ?? uid).trim().isEmpty ? uid : (names[uid] ?? uid),
      isOn: badges.isOn,
      isLooking: badges.isLooking,
      isInLobby: badges.isInLobby,
    ));
  }
  return GrokConciergeContext(
    now: now,
    members: members,
    chatLines: chatLines,
    gameFocus: resolveConciergeGameFocus(
      lobbyState?.currentGame?['name']?.toString(),
      lobbyState?.currentLobby?.gameName,
    ),
    squadName: lobbyState?.currentLobby?.name,
  );
}

List<GrokConciergeChatLine> chatLinesFromMessages(
  Iterable<Message> messages, {
  Map<String, String> displayNames = const {},
}) {
  final lines = <GrokConciergeChatLine>[];
  for (final message in messages) {
    final text = message.text.trim();
    if (text.isEmpty) continue;
    final ai = message.aiResponse?.trim();
    if (ai != null && ai.isNotEmpty) continue;
    final sender = displayNames[message.senderId]?.trim();
    lines.add(GrokConciergeChatLine(
      sender: (sender != null && sender.isNotEmpty)
          ? sender
          : message.senderId,
      text: text,
      timestamp: message.timestamp,
    ));
  }
  return lines;
}
