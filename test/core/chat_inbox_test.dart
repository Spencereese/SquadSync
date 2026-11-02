import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/chat_inbox.dart';
import 'package:squad_sync/core/notification_routes.dart';

void main() {
  test('a saved message notifies the other members and opens that chat', () {
    final notice = noticeForSavedMessage(
      memberUids: const ['me', 'friend', 'friend', ''],
      senderId: 'me',
      chatId: 'group-1',
      text: 'hello',
    );

    expect(notice, isNotNull);
    expect(notice!.recipients, ['friend']);
    expect(notice.body, 'hello');
    expect(NotificationRoutes.locationFor(notice.payload), '/chat/group-1');
  });

  test('muted recipients stay quiet and the sender is not notified', () {
    final notice = noticeForSavedMessage(
      memberUids: const ['me', 'quiet', 'loud'],
      senderId: 'me',
      chatId: 'group-1',
      text: 'hello',
      mutedRecipientIds: const {'quiet'},
    );

    expect(notice!.recipients, ['loud']);
  });

  test('a fully muted group produces no notice', () {
    expect(
      noticeForSavedMessage(
        memberUids: const ['me', 'quiet'],
        senderId: 'me',
        chatId: 'group-1',
        text: 'hello',
        mutedRecipientIds: const {'quiet'},
      ),
      isNull,
    );
  });

  test('user_groups notifications_enabled false is a mute', () {
    final muted = mutedRecipientsFromUserRows(
      chatId: 'group-1',
      rows: [
        {
          'uid': 'quiet',
          'user_groups': [
            {'id': 'group-1', 'notifications_enabled': false},
          ],
        },
        {
          'uid': 'loud',
          'user_groups': [
            {'id': 'group-1', 'notifications_enabled': true},
          ],
        },
        {
          'uid': 'squad',
          'squad_chat_muted': true,
          'squad_chat_id': 'group-1',
        },
      ],
    );
    expect(muted, {'quiet', 'squad'});
  });

  test('opening a group clears only that group', () {
    final counts = addUnread({'other': 4}, 'group-1', 2);
    expect(counts, {'other': 4, 'group-1': 2});
    expect(clearUnread(counts, 'group-1'), {'other': 4, 'group-1': 0});
    expect(clearUnread(counts, 'missing'), counts);
  });

  test('incoming messages from other people count only while the thread is closed',
      () {
    expect(
      incomingFromOthers(
        newSenderIds: const ['friend', 'me', 'friend'],
        currentUserId: 'me',
        threadIsOpen: false,
      ),
      2,
    );
    expect(
      incomingFromOthers(
        newSenderIds: const ['friend'],
        currentUserId: 'me',
        threadIsOpen: true,
      ),
      0,
    );
  });
}
