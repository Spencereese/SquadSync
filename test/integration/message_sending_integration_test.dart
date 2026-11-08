import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/core/chat_history.dart';
import 'package:squad_sync/core/chat_send.dart';
import 'package:squad_sync/core/injection.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';
import 'package:squad_sync/presentation/notifiers/message_notifier.dart';
import 'package:squad_sync/services/message_service.dart';

class _Repo extends Mock implements ChatRepository {
  List<Message> older = const [];

  @override
  Future<List<Message>> loadMessages(
    String chatGroupId, {
    int limit = 50,
    DateTime? before,
    String? beforeId,
  }) async {
    return older;
  }
}

class _Send extends Mock implements MessageService {
  int calls = 0;
  String? lastClientId;

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
    calls++;
    lastClientId = clientMessageId;
    if (calls == 1) return MessageSendResult.failure('offline');
    return MessageSendResult.success(clientMessageId ?? '');
  }
}

void main() {
  test('an offline queue result is not confirmation', () {
    final offline = MessageSendResult.offline('client-1');
    expect(
      isServerConfirmed(
        success: offline.success,
        isOffline: offline.isOffline,
        messageId: offline.messageId,
        clientId: 'client-1',
      ),
      isFalse,
    );
  });

  test('opening a long thread is the newest page', () {
    final all = List.generate(
      120,
      (i) => Message(
        id: 'm$i',
        senderId: 'u',
        text: 't',
        timestamp: DateTime.utc(2026, 1, 1, 0, i),
        messageType: MessageType.text,
      ),
    );
    final page = newestHistoryPage(all, limit: 50);
    expect(page.first.id, 'm70');
    expect(page.last.id, 'm119');
  });

  testWidgets('retry uses the same client id the failed send already has',
      (tester) async {
    final send = _Send();
    final repo = _Repo();
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
    final notifier = ref.read(messageNotifierProvider.notifier);

    await notifier.sendMessage(
      ref,
      'group-1',
      'ping',
      MessageType.text,
      ChatType.dm,
    );
    final failed =
        ref.read(messageNotifierProvider).value!.messages['group-1']!.single;
    expect(outboundDeliveryOf(failed), OutboundDelivery.failed);

    await notifier.retryFailedMessage(
      ref,
      'group-1',
      failed.id,
      ChatType.dm,
    );
    final sent =
        ref.read(messageNotifierProvider).value!.messages['group-1']!.single;
    expect(sent.id, failed.id);
    expect(send.lastClientId, failed.id);
    expect(send.calls, 2);
    expect(outboundDeliveryOf(sent), OutboundDelivery.sent);
  });
}
