import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';
import 'package:squad_sync/presentation/notifiers/notification_notifier.dart';

void main() {
  test('skips only when the open thread matches the incoming group', () {
    expect(shouldSkipChatBadgeIncrement('g1', 'g1'), isTrue);
    expect(shouldSkipChatBadgeIncrement('g1', 'g2'), isFalse);
  });

  test('messages with no group column still badge while a chat is open', () {
    expect(shouldSkipChatBadgeIncrement('g1', null), isFalse);
  });

  test('no open chat never skips', () {
    expect(shouldSkipChatBadgeIncrement(null, 'g1'), isFalse);
    expect(shouldSkipChatBadgeIncrement(null, null), isFalse);
  });

  test('squad uses selectedLobbyId when widget chatGroupId is null', () {
    expect(
      resolveActiveChatGroupId(
        widgetChatGroupId: null,
        isSquad: true,
        selectedLobbyId: 'lobby-1',
      ),
      'lobby-1',
    );
    expect(
      shouldSkipChatBadgeIncrement('lobby-1', 'lobby-1'),
      isTrue,
    );
  });

  test('widget chatGroupId wins; empty ids never register', () {
    expect(
      resolveActiveChatGroupId(
        widgetChatGroupId: 'group-1',
        isSquad: true,
        selectedLobbyId: 'lobby-1',
      ),
      'group-1',
    );
    expect(
      resolveActiveChatGroupId(
        widgetChatGroupId: '',
        isSquad: true,
        selectedLobbyId: '',
      ),
      isNull,
    );
    expect(
      resolveActiveChatGroupId(
        widgetChatGroupId: null,
        isSquad: true,
        selectedLobbyId: null,
      ),
      isNull,
    );
    expect(
      resolveActiveChatGroupId(
        widgetChatGroupId: null,
        isSquad: false,
        selectedLobbyId: 'lobby-1',
      ),
      isNull,
    );
  });

  test('first non-null thread id starts initializeChat path', () {
    expect(
      shouldStartChatInitialization(
        alreadyInitialized: false,
        nextThreadId: null,
      ),
      isFalse,
    );
    expect(
      shouldStartChatInitialization(
        alreadyInitialized: false,
        nextThreadId: 'lobby-1',
      ),
      isTrue,
    );
    expect(
      shouldStartChatInitialization(
        alreadyInitialized: true,
        nextThreadId: 'lobby-1',
      ),
      isFalse,
    );
  });

  test('lobby switch after first init refreshes initialization service', () {
    expect(
      shouldRefreshChatInitializationOnNewThread(
        alreadyInitialized: true,
        isNewId: true,
      ),
      isTrue,
    );
    expect(
      shouldRefreshChatInitializationOnNewThread(
        alreadyInitialized: false,
        isNewId: true,
      ),
      isFalse,
    );
    expect(
      shouldRefreshChatInitializationOnNewThread(
        alreadyInitialized: true,
        isNewId: false,
      ),
      isFalse,
    );
  });

  test('channel cleanup matches exact thread topics, not substring ids', () {
    expect(
      isChatThreadChannelTopic('realtime:presence:lobby-1', 'lobby-1'),
      isTrue,
    );
    expect(isChatThreadChannelTopic('typing:lobby-1', 'lobby-1'), isTrue);
    expect(isChatThreadChannelTopic('typing_lobby-1', 'lobby-1'), isTrue);
    expect(isChatThreadChannelTopic('messages_lobby-1', 'lobby-1'), isTrue);
    expect(isChatThreadChannelTopic('messages:lobby-1', 'lobby-1'), isTrue);
    expect(isChatThreadChannelTopic('presence:lobby-1', 'other'), isFalse);
    expect(isChatThreadChannelTopic('lobby_momentum', 'lobby-1'), isFalse);
    expect(isChatThreadChannelTopic('chat_badges', 'lobby-1'), isFalse);
    expect(
      isChatThreadChannelTopic('presence:lobby-10', 'lobby-1'),
      isFalse,
    );
    expect(
      isChatThreadChannelTopic('typing_lobby-10', 'lobby-1'),
      isFalse,
    );
    expect(
      isChatThreadChannelTopic('realtime:messages:lobby-10', 'lobby-1'),
      isFalse,
    );
  });

  test('one unreadable topic stays scoped; nuke-all only if every topic failed',
      () {
    expect(
      channelCleanupMode(readableTopicCount: 3, unreadableTopicCount: 1),
      ChannelCleanupMode.scoped,
    );
    expect(
      channelCleanupMode(readableTopicCount: 0, unreadableTopicCount: 4),
      ChannelCleanupMode.nukeAll,
    );
    expect(
      channelCleanupMode(readableTopicCount: 2, unreadableTopicCount: 0),
      ChannelCleanupMode.scoped,
    );
  });

  test('stale init completion is ignored after a lobby switch', () {
    expect(
      shouldCommitInitializationCompletion(
        finishingId: 'lobby-1',
        finishingGeneration: 1,
        currentRegisteredId: 'lobby-2',
        currentGeneration: 2,
      ),
      isFalse,
    );
    expect(
      shouldRunInitializationService(
        requestedId: 'lobby-2',
        requestedGeneration: 2,
        currentRegisteredId: 'lobby-2',
        currentGeneration: 2,
        alreadyCompleted: false,
      ),
      isTrue,
    );
    expect(
      shouldRunInitializationService(
        requestedId: 'lobby-2',
        requestedGeneration: 2,
        currentRegisteredId: 'lobby-2',
        currentGeneration: 2,
        alreadyCompleted: true,
      ),
      isFalse,
    );
    expect(
      shouldCommitInitializationCompletion(
        finishingId: 'lobby-2',
        finishingGeneration: 2,
        currentRegisteredId: 'lobby-2',
        currentGeneration: 2,
      ),
      isTrue,
    );
  });

  test('lobby switch tears down the previous thread channels', () {
    expect(
      shouldCleanupPreviousThreadChannels(
        previousId: 'lobby-1',
        nextId: 'lobby-2',
      ),
      isTrue,
    );
    expect(
      shouldCleanupPreviousThreadChannels(
        previousId: 'lobby-1',
        nextId: 'lobby-1',
      ),
      isFalse,
    );
    expect(
      shouldCleanupPreviousThreadChannels(
        previousId: null,
        nextId: 'lobby-1',
      ),
      isFalse,
    );
  });

  test('initialization service retries only after a null-squad bail', () {
    expect(
      shouldRetryChatInitializationService(
        serviceCompleted: false,
        bail: ChatInitBail.nullSquad,
        squadStateAvailable: true,
        hardFailureRetries: 0,
      ),
      isTrue,
    );
    expect(
      shouldRetryChatInitializationService(
        serviceCompleted: true,
        bail: ChatInitBail.nullSquad,
        squadStateAvailable: true,
        hardFailureRetries: 0,
      ),
      isFalse,
    );
    expect(
      shouldRetryChatInitializationService(
        serviceCompleted: false,
        bail: ChatInitBail.nullSquad,
        squadStateAvailable: false,
        hardFailureRetries: 0,
      ),
      isFalse,
    );
  });

  test('delayed rate-limit re-init is abandoned after a lobby switch', () {
    // Gate only. ChatScreen then calls _scheduleChatStart (notifier +
    // ChatInitializationService), not a raw initializeChat.
    expect(
      shouldContinueDelayedChatReinit(
        isMounted: true,
        scheduledId: 'lobby-1',
        scheduledGeneration: 1,
        currentRegisteredId: 'lobby-2',
        currentGeneration: 2,
      ),
      isFalse,
    );
    expect(
      shouldContinueDelayedChatReinit(
        isMounted: false,
        scheduledId: 'lobby-1',
        scheduledGeneration: 1,
        currentRegisteredId: 'lobby-1',
        currentGeneration: 1,
      ),
      isFalse,
    );
    expect(
      shouldContinueDelayedChatReinit(
        isMounted: true,
        scheduledId: 'lobby-2',
        scheduledGeneration: 2,
        currentRegisteredId: 'lobby-2',
        currentGeneration: 2,
      ),
      isTrue,
    );
  });

  test('delayed rate-limit path stops after one replay', () {
    expect(shouldScheduleRateLimitRetry(0), isTrue);
    expect(shouldScheduleRateLimitRetry(1), isFalse);
    expect(rateLimitRetrySnackMessage(0), kRateLimitRetrySnack);
    expect(rateLimitRetrySnackMessage(1), kRateLimitGiveUpSnack);

    var retries = 0;
    var scheduled = 0;
    final snacks = <String>[];
    void onRateLimit() {
      snacks.add(rateLimitRetrySnackMessage(retries));
      if (shouldScheduleRateLimitRetry(retries)) {
        retries++;
        scheduled++;
      }
    }

    onRateLimit();
    expect(scheduled, 1);
    expect(snacks, [kRateLimitRetrySnack]);
    onRateLimit();
    expect(scheduled, 1);
    expect(snacks, [kRateLimitRetrySnack, kRateLimitGiveUpSnack]);
    onRateLimit();
    expect(scheduled, 1);
  });

  test('init UI writes only apply for the current generation', () {
    expect(
      shouldCommitInitializationCompletion(
        finishingId: 'lobby-1',
        finishingGeneration: 1,
        currentRegisteredId: 'lobby-2',
        currentGeneration: 2,
      ),
      isFalse,
    );
    expect(
      shouldCommitInitializationCompletion(
        finishingId: 'lobby-2',
        finishingGeneration: 2,
        currentRegisteredId: 'lobby-2',
        currentGeneration: 2,
      ),
      isTrue,
    );
  });

  test('hard failure snacks once then allows one bounded retry', () {
    expect(shouldShowInitFailureSnackBar(0), isTrue);
    expect(shouldShowInitFailureSnackBar(1), isFalse);
    expect(
      shouldRetryChatInitializationService(
        serviceCompleted: false,
        bail: ChatInitBail.hardFailure,
        squadStateAvailable: true,
        hardFailureRetries: 0,
      ),
      isTrue,
    );
    expect(
      shouldRetryChatInitializationService(
        serviceCompleted: false,
        bail: ChatInitBail.hardFailure,
        squadStateAvailable: true,
        hardFailureRetries: 1,
      ),
      isFalse,
    );
    expect(
      shouldRetryChatInitializationService(
        serviceCompleted: false,
        bail: ChatInitBail.none,
        squadStateAvailable: true,
        hardFailureRetries: 0,
      ),
      isFalse,
    );
  });

  testWidgets(
      'listenManual registers selectedLobbyId when widget chatGroupId is null',
      (tester) async {
    String? registered;
    String? initialized;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lobbyNotifierProvider.overrideWith(_SeededLobbyNotifier.new),
        ],
        child: MaterialApp(
          home: _SquadActiveThreadHarness(
            onRegister: (id) => registered = id,
            onInitialize: (id) => initialized = id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(registered, 'lobby-squad-1');
    expect(initialized, 'lobby-squad-1');
    expect(shouldSkipChatBadgeIncrement(registered, 'lobby-squad-1'), isTrue);
  });

  testWidgets(
      'lobby switch cleans previous thread, bumps generation, ignores stale complete',
      (tester) async {
    final cleaned = <String>[];
    final started = <({String id, int generation})>[];
    final committed = <({String id, int generation})>[];
    final key = GlobalKey<_LobbySwitchHarnessState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lobbyNotifierProvider.overrideWith(_SwitchableLobbyNotifier.new),
        ],
        child: MaterialApp(
          home: _LobbySwitchHarness(
            key: key,
            onCleanup: cleaned.add,
            onStart: (id, generation) =>
                started.add((id: id, generation: generation)),
            onCommit: (id, generation) =>
                committed.add((id: id, generation: generation)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(started.map((e) => e.id), ['lobby-1']);
    expect(cleaned, isEmpty);

    // In-flight old init is still pending when the lobby switches.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(_LobbySwitchHarness)),
    );
    final notifier = container.read(lobbyNotifierProvider.notifier)
        as _SwitchableLobbyNotifier;
    notifier.setSelectedLobbyId('lobby-2');
    await tester.pumpAndSettle();

    expect(cleaned, ['lobby-1']);
    expect(started.map((e) => e.id), ['lobby-1', 'lobby-2']);
    expect(key.currentState!.generation, 2);
    expect(key.currentState!.registeredId, 'lobby-2');

    expect(
      key.currentState!.tryCommitStaleCompletion('lobby-1', 1),
      isFalse,
    );
    expect(key.currentState!.completed, isFalse);
    expect(
      key.currentState!.tryCommitStaleCompletion('lobby-2', 2),
      isTrue,
    );
    expect(key.currentState!.completed, isTrue);
    expect(committed.map((e) => e.id), ['lobby-2']);
  });

  testWidgets('throw bail snacks once then allows one retry', (tester) async {
    final snacks = <String>[];
    var attempts = 0;
    final key = GlobalKey<_ThrowRetryHarnessState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _ThrowRetryHarness(
            key: key,
            onSnack: snacks.add,
            onAttempt: () {
              attempts++;
              throw StateError('init failed');
            },
          ),
        ),
      ),
    );
    await tester.pump();
    key.currentState!.runInit();
    expect(attempts, 1);
    expect(snacks, ['Could not finish opening chat']);
    expect(key.currentState!.bail, ChatInitBail.hardFailure);
    expect(key.currentState!.hardFailureRetries, 1);
    expect(key.currentState!.retryScheduled, isTrue);

    key.currentState!.runScheduledRetry();
    expect(attempts, 2);
    expect(snacks, ['Could not finish opening chat']);
    expect(key.currentState!.hardFailureRetries, 2);
    expect(key.currentState!.retryScheduled, isFalse);

    key.currentState!.runScheduledRetry();
    expect(attempts, 2);
  });

  // Pattern harness: mirrors ChatScreen._runInitializationService catch +
  // addPostFrameCallback. Does not mount ChatScreen (Provider/Supabase).
  testWidgets(
      'throw bail post-frame retry runs after scheduleFrame and pump',
      (tester) async {
    final snacks = <String>[];
    var attempts = 0;
    final key = GlobalKey<_ThrowRetryPostFrameHarnessState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _ThrowRetryPostFrameHarness(
            key: key,
            onSnack: snacks.add,
            onAttempt: () {
              attempts++;
              throw StateError('init failed');
            },
          ),
        ),
      ),
    );
    await tester.pump();
    key.currentState!.runInit();
    expect(attempts, 1);
    expect(snacks, ['Could not finish opening chat']);
    expect(key.currentState!.bail, ChatInitBail.hardFailure);
    expect(key.currentState!.hardFailureRetries, 1);

    tester.binding.scheduleFrame();
    await tester.pump();
    expect(attempts, 2);
    expect(snacks, ['Could not finish opening chat']);
    expect(key.currentState!.hardFailureRetries, 2);

    tester.binding.scheduleFrame();
    await tester.pump();
    expect(attempts, 2);
  });

  // Pattern harness: ChatScreen rate-limit catch + delay. Does not mount ChatScreen.
  testWidgets('rate-limit delayed replay stops after N failures', (tester) async {
    final snacks = <String>[];
    var scheduledReplays = 0;
    final key = GlobalKey<_RateLimitRetryHarnessState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _RateLimitRetryHarness(
            key: key,
            onSnack: snacks.add,
            onScheduleReplay: () => scheduledReplays++,
          ),
        ),
      ),
    );
    await tester.pump();
    key.currentState!.onRateLimit();
    expect(scheduledReplays, 1);
    expect(snacks, [kRateLimitRetrySnack]);
    key.currentState!.onRateLimit();
    expect(scheduledReplays, 1);
    expect(snacks, [kRateLimitRetrySnack, kRateLimitGiveUpSnack]);
    key.currentState!.onRateLimit();
    expect(scheduledReplays, 1);
  });
}

/// Same listenManual + resolve path ChatScreen._syncActiveChatThread uses.
class _SquadActiveThreadHarness extends ConsumerStatefulWidget {
  const _SquadActiveThreadHarness({
    required this.onRegister,
    this.onInitialize,
  });

  final void Function(String id) onRegister;
  final void Function(String id)? onInitialize;

  @override
  ConsumerState<_SquadActiveThreadHarness> createState() =>
      _SquadActiveThreadHarnessState();
}

class _SquadActiveThreadHarnessState
    extends ConsumerState<_SquadActiveThreadHarness> {
  String? _registered;
  var _hasInitializedChat = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      lobbyNotifierProvider.select((value) => value.valueOrNull),
      (previous, next) {
        final id = resolveActiveChatGroupId(
          widgetChatGroupId: null,
          isSquad: true,
          selectedLobbyId: next?.selectedLobbyId,
        );
        if (id == null || id == _registered) return;
        final already = _hasInitializedChat;
        _registered = id;
        widget.onRegister(id);
        if (shouldStartChatInitialization(
          alreadyInitialized: already,
          nextThreadId: id,
        )) {
          _hasInitializedChat = true;
          widget.onInitialize?.call(id);
        }
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _SeededLobbyNotifier extends LobbyNotifier {
  @override
  Future<LobbyState> build() async {
    return LobbyState.initial().copyWith(selectedLobbyId: 'lobby-squad-1');
  }
}

class _SwitchableLobbyNotifier extends LobbyNotifier {
  @override
  Future<LobbyState> build() async {
    return LobbyState.initial().copyWith(selectedLobbyId: 'lobby-1');
  }

  @override
  void setSelectedLobbyId(String? lobbyId) {
    final current = state.valueOrNull ?? LobbyState.initial();
    state = AsyncData(current.copyWith(selectedLobbyId: lobbyId));
  }
}

/// Mirrors ChatScreen._syncActiveChatThread generation + cleanup on switch.
class _LobbySwitchHarness extends ConsumerStatefulWidget {
  const _LobbySwitchHarness({
    super.key,
    required this.onCleanup,
    required this.onStart,
    required this.onCommit,
  });

  final void Function(String previousId) onCleanup;
  final void Function(String id, int generation) onStart;
  final void Function(String id, int generation) onCommit;

  @override
  ConsumerState<_LobbySwitchHarness> createState() => _LobbySwitchHarnessState();
}

class _LobbySwitchHarnessState extends ConsumerState<_LobbySwitchHarness> {
  String? _registered;
  var _hasInitializedChat = false;
  var _completed = false;
  var _generation = 0;

  String? get registeredId => _registered;
  int get generation => _generation;
  bool get completed => _completed;

  bool tryCommitStaleCompletion(String finishingId, int finishingGeneration) {
    if (!shouldCommitInitializationCompletion(
      finishingId: finishingId,
      finishingGeneration: finishingGeneration,
      currentRegisteredId: _registered,
      currentGeneration: _generation,
    )) {
      return false;
    }
    _completed = true;
    widget.onCommit(finishingId, finishingGeneration);
    return true;
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      lobbyNotifierProvider.select((value) => value.valueOrNull),
      (previous, next) {
        final id = resolveActiveChatGroupId(
          widgetChatGroupId: null,
          isSquad: true,
          selectedLobbyId: next?.selectedLobbyId,
        );
        final isNewId = id != null && id != _registered;
        if (!isNewId) return;
        final previousId = _registered;
        if (shouldCleanupPreviousThreadChannels(
          previousId: previousId,
          nextId: id,
        )) {
          widget.onCleanup(previousId!);
        }
        final already = _hasInitializedChat;
        _registered = id;
        _generation++;
        _completed = false;
        if (shouldStartChatInitialization(
          alreadyInitialized: already,
          nextThreadId: id,
        )) {
          _hasInitializedChat = true;
          widget.onStart(id, _generation);
        } else if (shouldRefreshChatInitializationOnNewThread(
          alreadyInitialized: already,
          isNewId: true,
        )) {
          widget.onStart(id, _generation);
        }
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Mirrors ChatScreen._runInitializationService catch: snack once, one retry.
class _ThrowRetryHarness extends StatefulWidget {
  const _ThrowRetryHarness({
    super.key,
    required this.onSnack,
    required this.onAttempt,
  });

  final void Function(String message) onSnack;
  final void Function() onAttempt;

  @override
  State<_ThrowRetryHarness> createState() => _ThrowRetryHarnessState();
}

class _ThrowRetryHarnessState extends State<_ThrowRetryHarness> {
  var _completed = false;
  var _bail = ChatInitBail.none;
  var _retries = 0;
  var _generation = 1;
  var _retryScheduled = false;
  final _id = 'lobby-1';

  ChatInitBail get bail => _bail;
  int get hardFailureRetries => _retries;
  bool get retryScheduled => _retryScheduled;

  void runScheduledRetry() {
    if (!_retryScheduled) return;
    _retryScheduled = false;
    runInit();
  }

  void runInit() {
    if (!shouldRunInitializationService(
      requestedId: _id,
      requestedGeneration: _generation,
      currentRegisteredId: _id,
      currentGeneration: _generation,
      alreadyCompleted: _completed,
    )) {
      return;
    }
    try {
      widget.onAttempt();
      _completed = true;
      _bail = ChatInitBail.none;
    } catch (_) {
      if (!shouldCommitInitializationCompletion(
        finishingId: _id,
        finishingGeneration: _generation,
        currentRegisteredId: _id,
        currentGeneration: _generation,
      )) {
        return;
      }
      _bail = ChatInitBail.hardFailure;
      if (shouldShowInitFailureSnackBar(_retries)) {
        widget.onSnack('Could not finish opening chat');
      }
      final shouldRetry = shouldRetryChatInitializationService(
        serviceCompleted: false,
        bail: ChatInitBail.hardFailure,
        squadStateAvailable: true,
        hardFailureRetries: _retries,
      );
      _retries++;
      _retryScheduled = shouldRetry;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Pattern harness for ChatScreen._runInitializationService catch:
/// one snack, then addPostFrameCallback for a single retry.
/// Does not mount ChatScreen.
class _ThrowRetryPostFrameHarness extends StatefulWidget {
  const _ThrowRetryPostFrameHarness({
    super.key,
    required this.onSnack,
    required this.onAttempt,
  });

  final void Function(String message) onSnack;
  final void Function() onAttempt;

  @override
  State<_ThrowRetryPostFrameHarness> createState() =>
      _ThrowRetryPostFrameHarnessState();
}

class _ThrowRetryPostFrameHarnessState
    extends State<_ThrowRetryPostFrameHarness> {
  var _completed = false;
  var _bail = ChatInitBail.none;
  var _retries = 0;
  var _generation = 1;
  final _id = 'lobby-1';

  ChatInitBail get bail => _bail;
  int get hardFailureRetries => _retries;

  void runInit() {
    if (!shouldRunInitializationService(
      requestedId: _id,
      requestedGeneration: _generation,
      currentRegisteredId: _id,
      currentGeneration: _generation,
      alreadyCompleted: _completed,
    )) {
      return;
    }
    try {
      widget.onAttempt();
      _completed = true;
      _bail = ChatInitBail.none;
    } catch (_) {
      if (!shouldCommitInitializationCompletion(
        finishingId: _id,
        finishingGeneration: _generation,
        currentRegisteredId: _id,
        currentGeneration: _generation,
      )) {
        return;
      }
      _bail = ChatInitBail.hardFailure;
      if (shouldShowInitFailureSnackBar(_retries)) {
        widget.onSnack('Could not finish opening chat');
      }
      final shouldRetry = shouldRetryChatInitializationService(
        serviceCompleted: false,
        bail: ChatInitBail.hardFailure,
        squadStateAvailable: true,
        hardFailureRetries: _retries,
      );
      _retries++;
      if (shouldRetry) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          runInit();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Pattern harness for ChatScreen ChannelRateLimitReached: one delayed
/// _scheduleChatStart, then give up. Does not mount ChatScreen.
class _RateLimitRetryHarness extends StatefulWidget {
  const _RateLimitRetryHarness({
    super.key,
    required this.onSnack,
    required this.onScheduleReplay,
  });

  final void Function(String message) onSnack;
  final void Function() onScheduleReplay;

  @override
  State<_RateLimitRetryHarness> createState() => _RateLimitRetryHarnessState();
}

class _RateLimitRetryHarnessState extends State<_RateLimitRetryHarness> {
  var _retries = 0;

  void onRateLimit() {
    widget.onSnack(rateLimitRetrySnackMessage(_retries));
    if (shouldScheduleRateLimitRetry(_retries)) {
      _retries++;
      widget.onScheduleReplay();
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
