import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/models/message_data.dart' show MessageData, MessageStatus;
import 'package:squad_sync/core/chat_send.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/services/message_service.dart';

Message _msg(
  String id, {
  String text = 'hi',
  DateTime? timestamp,
  OutboundDelivery? delivery,
  String senderId = 'me',
}) {
  final message = Message(
    id: id,
    senderId: senderId,
    text: text,
    timestamp: timestamp ?? DateTime.utc(2026, 1, 1, 0, 0, int.parse(id.replaceAll(RegExp(r'\D'), '').isEmpty ? '0' : '1')),
    messageType: MessageType.text,
  );
  if (delivery == null) return message;
  return withDelivery(message, delivery);
}

Message _at(String id, int second, {OutboundDelivery? delivery}) {
  return _msg(
    id,
    timestamp: DateTime.utc(2026, 1, 1, 0, 0, second),
    delivery: delivery,
  );
}

void main() {
  test('sending then server confirm keeps one id and only then shows sent', () {
    final sending = _at('client-1', 10, delivery: OutboundDelivery.sending);
    final thread = appendSending(const [], sending);

    expect(thread, hasLength(1));
    expect(thread.single.id, 'client-1');
    expect(outboundDeliveryOf(thread.single), OutboundDelivery.sending);

    final stillSending = applySendResult(
      messages: thread,
      clientId: 'client-1',
      confirmed: false,
    );
    expect(stillSending.single.id, 'client-1');
    expect(outboundDeliveryOf(stillSending.single), OutboundDelivery.failed);
    expect(stillSending, hasLength(1));

    final sent = applySendResult(
      messages: thread,
      clientId: 'client-1',
      confirmed: true,
    );
    expect(sent.single.id, 'client-1');
    expect(outboundDeliveryOf(sent.single), OutboundDelivery.sent);
  });

  test('offline queue success is not a server confirm', () {
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
    expect(
      isServerConfirmed(
        success: true,
        isOffline: false,
        messageId: 'client-1',
        clientId: 'client-1',
      ),
      isTrue,
    );
    expect(
      isServerConfirmed(
        success: true,
        isOffline: false,
        messageId: 'other-id',
        clientId: 'client-1',
      ),
      isFalse,
    );
  });

  test('realtime echo of the client id does not duplicate the bubble', () {
    final local = [
      _at('older', 1),
      _at('client-1', 5, delivery: OutboundDelivery.sending),
    ];
    final remote = [
      _at('older', 1),
      _at('client-1', 5),
    ];

    final merged = mergeRemoteEcho(local: local, remote: remote);

    expect(merged.map((m) => m.id), ['older', 'client-1']);
    expect(outboundDeliveryOf(merged.last), OutboundDelivery.sent);
    expect(
      merged.where((m) => m.id == 'client-1'),
      hasLength(1),
    );
  });

  test('failed send stays when the server page does not include it', () {
    final local = [
      _at('kept', 1),
      _at('client-1', 9, delivery: OutboundDelivery.failed),
    ];
    final remote = [_at('kept', 1), _at('other', 4)];

    final merged = mergeRemoteEcho(local: local, remote: remote);

    final failed = merged.singleWhere((m) => m.id == 'client-1');
    expect(outboundDeliveryOf(failed), OutboundDelivery.failed);
    expect(merged.map((m) => m.id), ['kept', 'other', 'client-1']);
  });

  test('retry uses the same id and a later confirm shows sent', () {
    final failed = applySendResult(
      messages: appendSending(
        const [],
        _at('client-1', 3, delivery: OutboundDelivery.sending),
      ),
      clientId: 'client-1',
      confirmed: false,
    );
    final retrying = markRetrying(messages: failed, clientId: 'client-1');
    expect(retrying.single.id, 'client-1');
    expect(outboundDeliveryOf(retrying.single), OutboundDelivery.sending);

    final sent = applySendResult(
      messages: retrying,
      clientId: 'client-1',
      confirmed: true,
    );
    expect(sent.single.id, 'client-1');
    expect(outboundDeliveryOf(sent.single), OutboundDelivery.sent);
    expect(sent, hasLength(1));
  });

  test('retry ignores a row that is not failed', () {
    final sent = [
      _at('client-1', 3, delivery: OutboundDelivery.sent),
    ];
    final again = markRetrying(messages: sent, clientId: 'client-1');
    expect(outboundDeliveryOf(again.single), OutboundDelivery.sent);
  });

  test('a failure after the echo already confirmed does not demote to failed', () {
    final sending = appendSending(
      const [],
      _at('client-1', 3, delivery: OutboundDelivery.sending),
    );
    final echoed = mergeRemoteEcho(
      local: sending,
      remote: [_at('client-1', 3)],
    );
    expect(outboundDeliveryOf(echoed.single), OutboundDelivery.sent);

    final afterTimeout = applySendResult(
      messages: echoed,
      clientId: 'client-1',
      confirmed: false,
    );
    expect(outboundDeliveryOf(afterTimeout.single), OutboundDelivery.sent);
    expect(afterTimeout, hasLength(1));
  });

  test('bubble status reads sending and failed from metadata', () {
    final sending = MessageData.fromMap({
      'id': 'client-1',
      'sender_id': 'me',
      'text': 'hello',
      'timestamp': '2026-01-01T00:00:10.000Z',
      'message_type': 'text',
      'metadata': {'delivery_status': 'sending'},
    });
    final failed = MessageData.fromMap({
      'id': 'client-1',
      'sender_id': 'me',
      'text': 'hello',
      'timestamp': '2026-01-01T00:00:10.000Z',
      'message_type': 'text',
      'metadata': {'delivery_status': 'failed', 'photos': []},
    });
    final history = MessageData.fromMap({
      'id': 'server-1',
      'sender_id': 'me',
      'text': 'old',
      'timestamp': '2026-01-01T00:00:01.000Z',
      'message_type': 'text',
    });

    expect(sending.status, MessageStatus.sending);
    expect(failed.status, MessageStatus.failed);
    expect(history.status, MessageStatus.sent);
  });
}
