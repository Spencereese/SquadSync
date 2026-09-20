import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/services/availability_on.dart';
import 'package:squad_sync/services/grok_concierge.dart';
import 'package:squad_sync/services/grok_concierge_machine.dart';
import 'package:squad_sync/services/matchmaking_queue_machine.dart';

void main() {
  late GrokSpendTracker spend;

  setUp(() {
    spend = GrokSpendTracker();
    GrokSpendTracker.resetInstance();
    MatchmakingQueueTracker.resetInstance();
    resetAvailabilityOnStore();
  });

  tearDown(() {
    GrokSpendTracker.resetInstance();
    MatchmakingQueueTracker.resetInstance();
    resetAvailabilityOnStore();
  });

  test('runner calls existing grok path with concierge command id', () async {
    String? seenCommand;
    String? seenMessage;
    final runner = GrokConciergeRunner(
      spend: spend,
      caller: (message, {context, recentMessages, command}) async {
        seenCommand = command;
        seenMessage = message;
        return 'Sam is on.';
      },
    );
    final result = await runner.run(
      command: GrokConciergeCommand.whosFreeTonight,
      context: GrokConciergeContext(
        now: DateTime.utc(2026, 9, 5, 21),
        members: const [
          GrokConciergeMember(uid: 'a', label: 'Sam', isOn: true),
        ],
      ),
    );
    expect(seenCommand, 'whos_free_tonight');
    expect(seenMessage, kGrokConciergeWhosFreeLabel);
    expect(result.text, 'Sam is on.');
    expect(result.usedFallback, isFalse);
    expect(spend.state.calls, 1);
  });

  test('hard budget blocks a second call at cap without calling grok', () async {
    var calls = 0;
    final tight = GrokSpendTracker(callCap: 1, usdCap: 1);
    final runner = GrokConciergeRunner(
      spend: tight,
      caller: (message, {context, recentMessages, command}) async {
        calls += 1;
        return 'ok';
      },
    );
    final ctx = GrokConciergeContext(now: DateTime.utc(2026, 9, 5, 21));
    final first = await runner.run(
      command: GrokConciergeCommand.draftPeacockInvite,
      context: ctx,
    );
    final second = await runner.run(
      command: GrokConciergeCommand.whosFreeTonight,
      context: ctx,
    );
    expect(first.budgetExceeded, isFalse);
    expect(calls, 1);
    expect(second.budgetExceeded, isTrue);
    expect(second.text, kGrokBudgetExceededCopy);
    expect(calls, 1);
  });

  test('transport failure uses local fallback and does not spend', () async {
    final runner = GrokConciergeRunner(
      spend: spend,
      caller: (message, {context, recentMessages, command}) async {
        return "I'm having trouble connecting to my backend. Is the server running on port 8080?";
      },
    );
    final result = await runner.run(
      command: GrokConciergeCommand.whosFreeTonight,
      context: GrokConciergeContext(
        now: DateTime.utc(2026, 9, 5, 21),
        members: const [
          GrokConciergeMember(uid: 'a', label: 'Sam', isOn: true),
        ],
      ),
    );
    expect(result.usedFallback, isTrue);
    expect(result.text, contains('On now: Sam'));
    expect(spend.state.calls, 0);
  });

  test('buildConciergeContext marks On / Looking from existing trackers', () {
    final onStore = AvailabilityOnStore(
      clock: () => DateTime.utc(2026, 9, 5, 21),
    );
    onStore.markOn('sam');
    final lfg = MatchmakingQueueTracker();
    lfg.applyRemote(
      'kit',
      const MatchmakingQueueEntry(
        phase: MatchmakingQueuePhase.looking,
        squadId: 'squad-1',
      ),
    );
    final lobby = Lobby.create(
      name: 'Night Owls',
      gameName: 'Warzone',
      maxSpots: 4,
      createdBy: 'sam',
    ).copyWith(
      id: 'lobby-1',
      memberUids: const ['sam', 'kit', 'alex'],
      chatGroupId: 'squad-1',
    );
    final ctx = buildConciergeContext(
      now: DateTime.utc(2026, 9, 5, 21),
      lobbyState: LobbyState.initial().copyWith(
        currentLobby: lobby,
        lobbyMemberUids: const ['sam', 'kit', 'alex'],
        memberDisplayNames: const {
          'sam': 'Sam',
          'kit': 'Kit',
          'alex': 'Alex',
        },
        currentGame: const {'name': 'Warzone'},
      ),
      lfg: lfg,
      onStore: onStore,
    );
    expect(ctx.gameFocus, 'Warzone');
    expect(whoIsFreeTonight(ctx.members).map((m) => m.label), ['Sam', 'Kit']);
    onStore.clear();
  });

  test('chatLinesFromMessages skips empty and AI rows', () {
    final lines = chatLinesFromMessages(
      [
        Message(
          id: '1',
          senderId: 'sam',
          text: 'lock in',
          timestamp: DateTime(2026, 9, 5, 20, 5),
          messageType: MessageType.text,
        ),
        Message(
          id: '2',
          senderId: 'bot',
          text: 'ignored',
          timestamp: DateTime(2026, 9, 5, 20, 6),
          messageType: MessageType.aiResponse,
          aiResponse: 'ignored',
        ),
        Message(
          id: '3',
          senderId: 'kit',
          text: '   ',
          timestamp: DateTime(2026, 9, 5, 20, 7),
          messageType: MessageType.text,
        ),
      ],
      displayNames: const {'sam': 'Sam'},
    );
    expect(lines, hasLength(1));
    expect(lines.single.sender, 'Sam');
    expect(lines.single.text, 'lock in');
  });
}
