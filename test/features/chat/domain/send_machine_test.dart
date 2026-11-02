import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/features/chat/domain/chat_message.dart';
import 'package:squadsync/features/chat/domain/send_machine.dart';

ChatMessage _at(
  String id,
  int second, {
  String text = 'hi',
  String senderId = 'spencer',
  Delivery? delivery,
}) {
  return ChatMessage(
    id: id,
    chatId: 'squad',
    senderId: senderId,
    text: text,
    sentAt: DateTime.utc(2026, 1, 1, 0, 0, second),
    delivery: delivery,
  );
}

void main() {
  test('a send stays sending until the repository confirms that same id', () {
    final thread = ChatThread(const [])
        .start(_at('client-1', 10, delivery: Delivery.sending));

    expect(thread.messages, hasLength(1));
    expect(thread.messages.single.id, 'client-1');
    expect(thread.messages.single.delivery, Delivery.sending);

    final failed = thread.apply('client-1', const SendFailed());
    expect(failed.messages, hasLength(1));
    expect(failed.messages.single.id, 'client-1');
    expect(failed.messages.single.delivery, Delivery.failed);

    final sent = thread.apply('client-1', const SendConfirmed('client-1'));
    expect(sent.messages.single.id, 'client-1');
    expect(sent.messages.single.delivery, Delivery.sent);
  });

  test('a confirm that names a different id is not sent', () {
    final thread = ChatThread(const [])
        .start(_at('client-1', 10, delivery: Delivery.sending));
    final missed = thread.apply('client-1', const SendConfirmed('other-id'));

    expect(
      outcomeConfirms(const SendConfirmed('other-id'), 'client-1'),
      isFalse,
    );
    expect(missed.messages.single.delivery, Delivery.failed);
  });

  test('a duplicate-insert conflict on the same id counts as sent', () {
    final thread = ChatThread(const [])
        .start(_at('client-1', 4, delivery: Delivery.sending));
    final conflict = const SendConflict('client-1');

    expect(outcomeConfirms(conflict, 'client-1'), isTrue);
    expect(outcomeConfirms(const SendConflict('other'), 'client-1'), isFalse);

    final sent = thread.apply('client-1', conflict);
    expect(sent.messages, hasLength(1));
    expect(sent.messages.single.delivery, Delivery.sent);
  });

  test('retry uses the same id and a later confirm shows sent', () {
    final failed = ChatThread(const [])
        .start(_at('client-1', 3, delivery: Delivery.sending))
        .apply('client-1', const SendFailed());
    final retrying = failed.retry('client-1');

    expect(retrying.messages, hasLength(1));
    expect(retrying.messages.single.id, 'client-1');
    expect(retrying.messages.single.delivery, Delivery.sending);

    final sent = retrying.apply('client-1', const SendConfirmed('client-1'));
    expect(sent.messages, hasLength(1));
    expect(sent.messages.single.delivery, Delivery.sent);
  });

  test('retry ignores a row that is not failed', () {
    final sent = ChatThread([_at('client-1', 3, delivery: Delivery.sent)]);
    final sending = ChatThread([
      _at('client-1', 3, delivery: Delivery.sending),
    ]);

    expect(sent.retry('client-1').messages.single.delivery, Delivery.sent);
    expect(
      sending.retry('client-1').messages.single.delivery,
      Delivery.sending,
    );
  });

  test('a realtime echo of the client id does not duplicate the bubble', () {
    final local = ChatThread([
      _at('older', 1, senderId: 'friend'),
      _at('client-1', 5, delivery: Delivery.sending),
    ]);
    final merged = local.mergeEcho([
      _at('older', 1, senderId: 'friend'),
      _at('client-1', 5, senderId: 'spencer'),
    ], meId: 'spencer');

    expect(merged.messages.map((message) => message.id), ['older', 'client-1']);
    expect(
      merged.messages.where((message) => message.id == 'client-1'),
      hasLength(1),
    );
    expect(merged.messages.last.delivery, Delivery.sent);
  });

  test('a failed send stays when the echo does not include it', () {
    final local = ChatThread([
      _at('kept', 1, senderId: 'friend'),
      _at('client-1', 9, delivery: Delivery.failed),
    ]);
    final merged = local.mergeEcho([
      _at('kept', 1, senderId: 'friend'),
      _at('other', 4, senderId: 'friend'),
    ], meId: 'spencer');

    final failed = merged.messages.singleWhere(
      (message) => message.id == 'client-1',
    );
    expect(failed.delivery, Delivery.failed);
    expect(merged.messages.map((message) => message.id), [
      'kept',
      'other',
      'client-1',
    ]);
  });

  test(
    'a failure after the echo already confirmed does not demote to failed',
    () {
      final sending = ChatThread(const [])
          .start(_at('client-1', 3, delivery: Delivery.sending));
      final echoed = sending.mergeEcho([
        _at('client-1', 3, senderId: 'spencer'),
      ], meId: 'spencer');
      expect(echoed.messages.single.delivery, Delivery.sent);

      final afterTimeout = echoed.apply('client-1', const SendFailed());
      expect(afterTimeout.messages, hasLength(1));
      expect(afterTimeout.messages.single.delivery, Delivery.sent);
    },
  );

  test('two echoes of the same id stay one row', () {
    final thread = ChatThread(const [])
        .start(_at('client-1', 2, text: 'hi', delivery: Delivery.sending));
    final merged = thread.mergeEcho([
      _at('client-1', 2, text: 'hi', senderId: 'spencer'),
      _at('client-1', 2, text: 'hi', senderId: 'spencer'),
    ], meId: 'spencer');

    expect(merged.messages, hasLength(1));
    expect(merged.messages.single.delivery, Delivery.sent);
  });

  test('someone else echoing in is inserted once and has no send mark', () {
    final merged = ChatThread([_at('older', 1, senderId: 'friend')]).mergeEcho([
      _at('from-friend', 6, senderId: 'friend', text: 'on'),
    ], meId: 'spencer');

    expect(merged.messages.map((message) => message.id), [
      'older',
      'from-friend',
    ]);
    expect(merged.messages.last.delivery, isNull);
  });

  test('starting a send with an id already on screen is refused', () {
    final thread = ChatThread(const [])
        .start(_at('client-1', 1, delivery: Delivery.sending));

    expect(
      () => thread.start(_at('client-1', 2, delivery: Delivery.sending)),
      throwsStateError,
    );
  });
}
