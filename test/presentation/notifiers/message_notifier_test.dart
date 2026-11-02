import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/core/chat_send.dart';
import 'package:squad_sync/core/injection.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';
import 'package:squad_sync/presentation/notifiers/message_notifier.dart';
import 'package:squad_sync/services/message_service.dart';

class _Repo extends Mock implements ChatRepository {
  _Repo(this.pages);

  final List<List<Message>> pages;
  int calls = 0;
  DateTime? lastBefore;
  String? lastBeforeId;

  @override
  Future<List<Message>> loadMessages(
    String chatGroupId, {
    int limit = 50,
    DateTime? before,
    String? beforeId,
  }) async {
    lastBefore = before;
    lastBeforeId = beforeId;
    final page = calls < pages.length ? pages[calls] : const <Message>[];
    calls++;
    return page;
  }
}

class _Send extends Mock implements MessageService {
  bool succeed = true;
  final List<String?> clientIds = [];
  final List<String?> texts = [];

  @override
  Future<MessageSendResult> sendMessage(
    WidgetRef ref, {
    required String senderUid,
    String? text,
    String? imageUrl,
    String? videoUrl,
    String? audioUrl,
    List<Map<String, dynamic>> photos = const [],
    List<Map<String, dynamic>> videos = const [],
    List<Map<String, dynamic>> audio = const [],
    List<Map<String, dynamic>> reactions = const [],
    String? pollId,
    String? replyTo,
    String? chatGroupId,
    required ChatType chatType,
    String? mediaFilePath,
    String? mediaType,
    String? clientMessageId,
  }) async {
    clientIds.add(clientMessageId);
    texts.add(text);
    if (!succeed) return MessageSendResult.failure('insert failed');
    return MessageSendResult.success(clientMessageId ?? '');
  }
}

Future<WidgetRef> _pump({
  required WidgetTester tester,
  required _Repo repo,
  required _Send send,
}) async {
  late WidgetRef ref;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        messageNotifierProvider.overrideWith(
          () => MessageNotifier.testing(
            messageService: send,
            currentUserId: 'me',
          ),
        ),
      ],
      child: Consumer(
        builder: (context, r, _) {
          ref = r;
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pump();
  await ref.read(messageNotifierProvider.future);
  return ref;
}

void main() {
  testWidgets('a failed send stays, with one id, until retry confirms it',
      (tester) async {
    final send = _Send()..succeed = false;
    final ref = await _pump(
      tester: tester,
      repo: _Repo(const []),
      send: send,
    );
    final notifier = ref.read(messageNotifierProvider.notifier);

    await notifier.sendMessage(
      ref,
      'group-1',
      'hello',
      MessageType.text,
      ChatType.userGroup,
    );

    var thread =
        ref.read(messageNotifierProvider).value!.messages['group-1']!;
    expect(thread, hasLength(1));
    expect(thread.single.id, send.clientIds.single);
    expect(outboundDeliveryOf(thread.single), OutboundDelivery.failed);

    send.succeed = true;
    await notifier.retryFailedMessage(
      ref,
      'group-1',
      thread.single.id,
      ChatType.userGroup,
    );

    thread = ref.read(messageNotifierProvider).value!.messages['group-1']!;
    expect(thread, hasLength(1));
    expect(thread.single.id, send.clientIds.first);
    expect(send.clientIds, [thread.single.id, thread.single.id]);
    expect(outboundDeliveryOf(thread.single), OutboundDelivery.sent);
  });

  testWidgets('server confirm is the only path to sent', (tester) async {
    final send = _Send();
    final ref = await _pump(
      tester: tester,
      repo: _Repo(const []),
      send: send,
    );

    await ref.read(messageNotifierProvider.notifier).sendMessage(
          ref,
          'group-1',
          'hi',
          MessageType.text,
          ChatType.userGroup,
        );

    final thread =
        ref.read(messageNotifierProvider).value!.messages['group-1']!;
    expect(outboundDeliveryOf(thread.single), OutboundDelivery.sent);
    expect(
      isServerConfirmed(
        success: true,
        isOffline: false,
        messageId: thread.single.id,
        clientId: thread.single.id,
      ),
      isTrue,
    );
  });

  testWidgets('older history joins the open thread without a duplicate',
      (tester) async {
    final older = Message(
      id: 'old-1',
      senderId: 'them',
      text: 'earlier',
      timestamp: DateTime.utc(2026, 1, 1),
      messageType: MessageType.text,
    );
    final repo = _Repo([
      [older],
    ]);
    final ref = await _pump(tester: tester, repo: repo, send: _Send());
    final notifier = ref.read(messageNotifierProvider.notifier);

    await notifier.sendMessage(
      ref,
      'group-1',
      'now',
      MessageType.text,
      ChatType.userGroup,
    );
    final beforeLoad =
        ref.read(messageNotifierProvider).value!.messages['group-1']!;
    final sentId = beforeLoad.single.id;

    final hasMore = await notifier.loadOlderMessages('group-1');

    final thread =
        ref.read(messageNotifierProvider).value!.messages['group-1']!;
    expect(hasMore, isFalse);
    expect(thread.map((m) => m.id), ['old-1', sentId]);
    expect(repo.lastBeforeId, sentId);
    expect(repo.calls, 1);
  });
}
