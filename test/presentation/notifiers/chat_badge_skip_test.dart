import 'package:flutter_test/flutter_test.dart';
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
}
