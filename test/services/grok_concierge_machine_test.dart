import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/grok_concierge_machine.dart';

void main() {
  final evening = DateTime(2026, 9, 5, 21, 15);
  final afternoon = DateTime(2026, 9, 5, 15);

  GrokConciergeMember member({
    required String uid,
    String? label,
    bool on = false,
    bool looking = false,
    bool inLobby = false,
  }) {
    return GrokConciergeMember(
      uid: uid,
      label: label ?? uid,
      isOn: on,
      isLooking: looking,
      isInLobby: inLobby,
    );
  }

  GrokConciergeChatLine line({
    required String sender,
    required String text,
    required DateTime at,
  }) {
    return GrokConciergeChatLine(sender: sender, text: text, timestamp: at);
  }

  group('command ids', () {
    test('round-trip the three concierge commands only', () {
      expect(
        grokConciergeCommandId(GrokConciergeCommand.whosFreeTonight),
        'whos_free_tonight',
      );
      expect(
        grokConciergeCommandId(GrokConciergeCommand.summarizeLobbyChat),
        'summarize_lobby_chat',
      );
      expect(
        grokConciergeCommandId(GrokConciergeCommand.draftPeacockInvite),
        'draft_peacock_invite',
      );
      expect(grokConciergeCommandFromId('whos_free_tonight'),
          GrokConciergeCommand.whosFreeTonight);
      expect(grokConciergeCommandFromId('free_chat'), isNull);
      expect(grokConciergeCommandFromId(''), isNull);
    });
  });

  group('who is free tonight', () {
    test('On or Looking counts; In lobby alone does not', () {
      final free = whoIsFreeTonight([
        member(uid: 'a', label: 'Sam', on: true),
        member(uid: 'b', label: 'Kit', looking: true),
        member(uid: 'c', label: 'Alex', inLobby: true),
      ]);
      expect(free.map((m) => m.label), ['Sam', 'Kit']);
    });
  });

  group('since 8pm', () {
    test('before 8pm uses last night 8pm', () {
      expect(
        grokConciergeSince8pm(afternoon),
        DateTime(2026, 9, 4, 20),
      );
    });

    test('after 8pm uses tonight 8pm and drops earlier lines', () {
      expect(grokConciergeSince8pm(evening), DateTime(2026, 9, 5, 20));
      final kept = filterChatSince8pm(
        [
          line(sender: 'Sam', text: 'early', at: DateTime(2026, 9, 5, 19, 59)),
          line(sender: 'Kit', text: 'lock in', at: DateTime(2026, 9, 5, 20, 1)),
          line(sender: 'Sam', text: '  ', at: DateTime(2026, 9, 5, 21)),
        ],
        now: evening,
      );
      expect(kept.map((l) => l.text), ['lock in']);
    });
  });

  group('game focus', () {
    test('defaults to Ranked Resurgence', () {
      expect(resolveConciergeGameFocus(null, null), kDefaultPeacockGameFocus);
      expect(resolveConciergeGameFocus('  ', ''), kDefaultPeacockGameFocus);
      expect(resolveConciergeGameFocus('Warzone', 'Apex'), 'Warzone');
      expect(resolveConciergeGameFocus(null, 'Apex'), 'Apex');
    });
  });

  group('budget', () {
    test('allows first call and records spend', () {
      final first = reduceGrokSpend(
        current: const GrokSpendState.empty(),
        now: DateTime.utc(2026, 9, 5, 18),
      );
      expect(first.allowed, isTrue);
      expect(first.next.calls, 1);
      expect(first.next.dayUtc, '2026-09-05');
      expect(first.next.estimatedUsd, kGrokConciergeEstimatedUsdPerCall);
    });

    test('refuses at call cap', () {
      final denied = reduceGrokSpend(
        current: GrokSpendState(
          dayUtc: '2026-09-05',
          calls: kGrokConciergeDailyCallCap,
          estimatedUsd: 0.1,
        ),
        now: DateTime.utc(2026, 9, 5, 18),
      );
      expect(denied.allowed, isFalse);
      expect(denied.denyReason, 'call_cap');
      expect(denied.next.calls, kGrokConciergeDailyCallCap);
    });

    test('refuses when the next call would cross the USD cap', () {
      final denied = reduceGrokSpend(
        current: GrokSpendState(
          dayUtc: '2026-09-05',
          calls: 1,
          estimatedUsd: kGrokConciergeDailyUsdCap - 0.001,
        ),
        now: DateTime.utc(2026, 9, 5, 18),
      );
      expect(denied.allowed, isFalse);
      expect(denied.denyReason, 'usd_cap');
    });

    test('resets on a new UTC day', () {
      final next = reduceGrokSpend(
        current: GrokSpendState(
          dayUtc: '2026-09-04',
          calls: kGrokConciergeDailyCallCap,
          estimatedUsd: kGrokConciergeDailyUsdCap,
        ),
        now: DateTime.utc(2026, 9, 5, 0, 1),
      );
      expect(next.allowed, isTrue);
      expect(next.next.calls, 1);
      expect(next.next.dayUtc, '2026-09-05');
    });
  });

  group('prompts and fallbacks', () {
    test('who is free prompt includes roster and fallback lists On/Looking', () {
      final ctx = GrokConciergeContext(
        now: evening,
        members: [
          member(uid: 'a', label: 'Sam', on: true),
          member(uid: 'b', label: 'Kit', looking: true),
        ],
      );
      final prompt =
          buildConciergePrompt(GrokConciergeCommand.whosFreeTonight, ctx);
      expect(prompt.userMessage, kGrokConciergeWhosFreeLabel);
      expect(prompt.context, contains('Sam'));
      expect(prompt.context, contains('Kit'));
      expect(
        conciergeFallback(GrokConciergeCommand.whosFreeTonight, ctx),
        contains('On now: Sam'),
      );
    });

    test('summarize prompt uses lines since 8pm', () {
      final ctx = GrokConciergeContext(
        now: evening,
        chatLines: [
          line(sender: 'Sam', text: 'too early', at: DateTime(2026, 9, 5, 10)),
          line(sender: 'Kit', text: 'lets lock', at: DateTime(2026, 9, 5, 20, 5)),
        ],
      );
      final prompt =
          buildConciergePrompt(GrokConciergeCommand.summarizeLobbyChat, ctx);
      expect(prompt.context, contains('lets lock'));
      expect(prompt.context, isNot(contains('too early')));
      expect(
        conciergeFallback(GrokConciergeCommand.summarizeLobbyChat, ctx),
        contains('1 messages since 8pm'),
      );
    });

    test('invite uses current game focus', () {
      final ctx = GrokConciergeContext(
        now: evening,
        gameFocus: 'Warzone',
        squadName: 'Night Owls',
      );
      final prompt =
          buildConciergePrompt(GrokConciergeCommand.draftPeacockInvite, ctx);
      expect(prompt.userMessage, contains('Warzone'));
      expect(prompt.userMessage, contains('Night Owls'));
      expect(
        conciergeFallback(GrokConciergeCommand.draftPeacockInvite, ctx),
        contains('Warzone'),
      );
    });

    test('invite falls back to Ranked Resurgence', () {
      final ctx = GrokConciergeContext(now: evening);
      expect(
        conciergeFallback(GrokConciergeCommand.draftPeacockInvite, ctx),
        contains(kDefaultPeacockGameFocus),
      );
    });
  });
}
