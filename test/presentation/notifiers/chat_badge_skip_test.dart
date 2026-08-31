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

  test('channel cleanup matches chat topics for the thread id', () {
    expect(
      isChatThreadChannelTopic('realtime:presence:lobby-1', 'lobby-1'),
      isTrue,
    );
    expect(isChatThreadChannelTopic('typing:lobby-1', 'lobby-1'), isTrue);
    expect(isChatThreadChannelTopic('messages_lobby-1', 'lobby-1'), isTrue);
    expect(isChatThreadChannelTopic('presence:lobby-1', 'other'), isFalse);
    expect(isChatThreadChannelTopic('lobby_momentum', 'lobby-1'), isFalse);
    expect(isChatThreadChannelTopic('chat_badges', 'lobby-1'), isFalse);
  });

  test('initialization service retries only after a null-squad bail', () {
    expect(
      shouldRetryChatInitializationService(
        serviceCompleted: false,
        bailedOnNullSquad: true,
        squadStateAvailable: true,
      ),
      isTrue,
    );
    expect(
      shouldRetryChatInitializationService(
        serviceCompleted: true,
        bailedOnNullSquad: true,
        squadStateAvailable: true,
      ),
      isFalse,
    );
    expect(
      shouldRetryChatInitializationService(
        serviceCompleted: false,
        bailedOnNullSquad: true,
        squadStateAvailable: false,
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
