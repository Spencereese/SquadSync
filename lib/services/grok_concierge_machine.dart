// Grok concierge — three commands only. Pure Dart; no I/O.
//
// Spend is estimated at grok-3 list rates ($3 / $15 per 1M tokens) so a
// missed usage block still cannot run past [kGrokConciergeDailyUsdCap].

enum GrokConciergeCommand {
  whosFreeTonight,
  summarizeLobbyChat,
  draftPeacockInvite,
}

/// Default peacock game when lobby / current game is unset.
const kDefaultPeacockGameFocus = 'Ranked Resurgence';

const kGrokConciergeMaxTokens = 400;
const kGrokConciergeDailyCallCap = 30;
const kGrokConciergeDailyUsdCap = 1.0;

/// Conservative per-call estimate: 1200 in + 400 out at grok-3 list.
const kGrokConciergeEstimatedUsdPerCall = 0.0096;

const kGrokBudgetExceededCopy =
    'Daily Grok budget reached. Try again tomorrow.';

const kGrokConciergeWhosFreeLabel = "Who's free tonight?";
const kGrokConciergeSummarizeLabel = 'Summarize this lobby chat since 8pm';
const kGrokConciergeInviteLabel = 'Draft a peacock invite';

class GrokConciergeMember {
  const GrokConciergeMember({
    required this.uid,
    required this.label,
    this.isOn = false,
    this.isLooking = false,
    this.isInLobby = false,
  });

  final String uid;
  final String label;
  final bool isOn;
  final bool isLooking;
  final bool isInLobby;

  bool get isFreeTonight => isOn || isLooking;
}

class GrokConciergeChatLine {
  const GrokConciergeChatLine({
    required this.sender,
    required this.text,
    required this.timestamp,
  });

  final String sender;
  final String text;
  final DateTime timestamp;
}

class GrokConciergeContext {
  const GrokConciergeContext({
    required this.now,
    this.members = const [],
    this.chatLines = const [],
    this.gameFocus,
    this.squadName,
  });

  final DateTime now;
  final List<GrokConciergeMember> members;
  final List<GrokConciergeChatLine> chatLines;
  final String? gameFocus;
  final String? squadName;
}

class GrokSpendState {
  const GrokSpendState({
    required this.dayUtc,
    this.calls = 0,
    this.estimatedUsd = 0,
  });

  const GrokSpendState.empty()
      : dayUtc = '',
        calls = 0,
        estimatedUsd = 0;

  final String dayUtc;
  final int calls;
  final double estimatedUsd;

  bool get isEmpty => dayUtc.isEmpty && calls == 0 && estimatedUsd == 0;
}

class GrokBudgetDecision {
  const GrokBudgetDecision({
    required this.allowed,
    required this.next,
    this.denyReason,
  });

  final bool allowed;
  final GrokSpendState next;
  final String? denyReason;
}

class GrokConciergePrompt {
  const GrokConciergePrompt({
    required this.command,
    required this.userMessage,
    this.context,
    this.recentMessages = const [],
  });

  final GrokConciergeCommand command;
  final String userMessage;
  final String? context;
  final List<String> recentMessages;
}

String grokConciergeCommandId(GrokConciergeCommand command) {
  switch (command) {
    case GrokConciergeCommand.whosFreeTonight:
      return 'whos_free_tonight';
    case GrokConciergeCommand.summarizeLobbyChat:
      return 'summarize_lobby_chat';
    case GrokConciergeCommand.draftPeacockInvite:
      return 'draft_peacock_invite';
  }
}

String grokConciergeCommandLabel(GrokConciergeCommand command) {
  switch (command) {
    case GrokConciergeCommand.whosFreeTonight:
      return kGrokConciergeWhosFreeLabel;
    case GrokConciergeCommand.summarizeLobbyChat:
      return kGrokConciergeSummarizeLabel;
    case GrokConciergeCommand.draftPeacockInvite:
      return kGrokConciergeInviteLabel;
  }
}

GrokConciergeCommand? grokConciergeCommandFromId(String? id) {
  switch (id) {
    case 'whos_free_tonight':
      return GrokConciergeCommand.whosFreeTonight;
    case 'summarize_lobby_chat':
      return GrokConciergeCommand.summarizeLobbyChat;
    case 'draft_peacock_invite':
      return GrokConciergeCommand.draftPeacockInvite;
    default:
      return null;
  }
}

String grokConciergeUtcDay(DateTime now) =>
    now.toUtc().toIso8601String().substring(0, 10);

/// Tonight's 8pm local. If [now] is before 8pm, that is last night 8pm.
DateTime grokConciergeSince8pm(DateTime now) {
  final local = now.toLocal();
  var start = DateTime(local.year, local.month, local.day, 20);
  if (local.isBefore(start)) {
    start = start.subtract(const Duration(days: 1));
  }
  return start;
}

List<GrokConciergeChatLine> filterChatSince8pm(
  Iterable<GrokConciergeChatLine> lines, {
  required DateTime now,
  int maxLines = 40,
}) {
  final start = grokConciergeSince8pm(now);
  final kept = lines
      .where((line) =>
          !line.timestamp.isBefore(start) && line.text.trim().isNotEmpty)
      .toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  if (kept.length <= maxLines) return kept;
  return kept.sublist(kept.length - maxLines);
}

List<GrokConciergeMember> whoIsFreeTonight(
  Iterable<GrokConciergeMember> members,
) {
  return members.where((m) => m.isFreeTonight).toList(growable: false);
}

String resolveConciergeGameFocus(String? currentGame, String? lobbyGame) {
  final current = currentGame?.trim();
  if (current != null && current.isNotEmpty) return current;
  final lobby = lobbyGame?.trim();
  if (lobby != null && lobby.isNotEmpty) return lobby;
  return kDefaultPeacockGameFocus;
}

GrokBudgetDecision reduceGrokSpend({
  required GrokSpendState current,
  required DateTime now,
  double estimatedUsd = kGrokConciergeEstimatedUsdPerCall,
  int callCap = kGrokConciergeDailyCallCap,
  double usdCap = kGrokConciergeDailyUsdCap,
}) {
  final day = grokConciergeUtcDay(now);
  final rolled = current.dayUtc == day
      ? current
      : GrokSpendState(dayUtc: day);
  if (rolled.calls >= callCap) {
    return GrokBudgetDecision(
      allowed: false,
      next: rolled,
      denyReason: 'call_cap',
    );
  }
  if (rolled.estimatedUsd >= usdCap ||
      rolled.estimatedUsd + estimatedUsd > usdCap) {
    return GrokBudgetDecision(
      allowed: false,
      next: rolled,
      denyReason: 'usd_cap',
    );
  }
  return GrokBudgetDecision(
    allowed: true,
    next: GrokSpendState(
      dayUtc: day,
      calls: rolled.calls + 1,
      estimatedUsd: rolled.estimatedUsd + estimatedUsd,
    ),
  );
}

GrokConciergePrompt buildConciergePrompt(
  GrokConciergeCommand command,
  GrokConciergeContext ctx,
) {
  switch (command) {
    case GrokConciergeCommand.whosFreeTonight:
      return _whosFreePrompt(ctx);
    case GrokConciergeCommand.summarizeLobbyChat:
      return _summarizePrompt(ctx);
    case GrokConciergeCommand.draftPeacockInvite:
      return _invitePrompt(ctx);
  }
}

String conciergeFallback(
  GrokConciergeCommand command,
  GrokConciergeContext ctx,
) {
  switch (command) {
    case GrokConciergeCommand.whosFreeTonight:
      return _whosFreeFallback(ctx);
    case GrokConciergeCommand.summarizeLobbyChat:
      return _summarizeFallback(ctx);
    case GrokConciergeCommand.draftPeacockInvite:
      return _inviteFallback(ctx);
  }
}

bool looksLikeGrokTransportFailure(String text) {
  final lower = text.toLowerCase();
  return lower.contains('trouble connecting') ||
      lower.contains('temporarily disrupted') ||
      lower.contains("api's down") ||
      lower.contains('is the server running');
}

GrokConciergePrompt _whosFreePrompt(GrokConciergeContext ctx) {
  final free = whoIsFreeTonight(ctx.members);
  final roster = free.isEmpty
      ? 'Nobody is marked On or Looking.'
      : free
          .map((m) =>
              '${m.label}: ${[
                if (m.isOn) 'On',
                if (m.isLooking) 'Looking',
                if (m.isInLobby) 'In lobby',
              ].join(', ')}')
          .join('\n');
  return GrokConciergePrompt(
    command: GrokConciergeCommand.whosFreeTonight,
    userMessage: kGrokConciergeWhosFreeLabel,
    context:
        'Squad roster with On / Looking / In lobby. Do not invent people.\n$roster',
  );
}

GrokConciergePrompt _summarizePrompt(GrokConciergeContext ctx) {
  final lines = filterChatSince8pm(ctx.chatLines, now: ctx.now);
  final start = grokConciergeSince8pm(ctx.now);
  final body = lines.isEmpty
      ? 'No lobby messages since 8pm.'
      : lines
          .map((l) => '${l.sender}: ${l.text}')
          .join('\n');
  return GrokConciergePrompt(
    command: GrokConciergeCommand.summarizeLobbyChat,
    userMessage:
        'Summarize this lobby chat since 8pm (${start.toIso8601String()}). '
        '3-5 bullets: plans, decisions, open questions. Do not invent messages.',
    context: body,
    recentMessages: lines.map((l) => '${l.sender}: ${l.text}').toList(),
  );
}

GrokConciergePrompt _invitePrompt(GrokConciergeContext ctx) {
  final game = resolveConciergeGameFocus(ctx.gameFocus, null);
  final squad = ctx.squadName?.trim();
  final who = squad == null || squad.isEmpty ? 'the squad' : squad;
  return GrokConciergePrompt(
    command: GrokConciergeCommand.draftPeacockInvite,
    userMessage:
        'Draft a peacock invite for $game. 2-4 short sentences, casual lock-in, '
        'no hashtag dump. Address $who.',
    context: 'Game focus: $game',
  );
}

String _whosFreeFallback(GrokConciergeContext ctx) {
  final free = whoIsFreeTonight(ctx.members);
  if (free.isEmpty) {
    return 'Nobody is marked On or Looking right now.';
  }
  final on = free.where((m) => m.isOn).map((m) => m.label).toList();
  final looking =
      free.where((m) => m.isLooking).map((m) => m.label).toList();
  final parts = <String>[];
  if (on.isNotEmpty) parts.add('On now: ${on.join(', ')}');
  if (looking.isNotEmpty) parts.add('Looking: ${looking.join(', ')}');
  return parts.join('\n');
}

String _summarizeFallback(GrokConciergeContext ctx) {
  final lines = filterChatSince8pm(ctx.chatLines, now: ctx.now);
  if (lines.isEmpty) {
    return 'No lobby chat since 8pm.';
  }
  final speakers = <String>{};
  for (final line in lines) {
    speakers.add(line.sender);
  }
  return '${lines.length} messages since 8pm (${speakers.join(', ')}). '
      'Open chat for the full thread.';
}

String _inviteFallback(GrokConciergeContext ctx) {
  final game = resolveConciergeGameFocus(ctx.gameFocus, null);
  return 'Peacock up for $game. Lock in if you are on — need a full squad.';
}
