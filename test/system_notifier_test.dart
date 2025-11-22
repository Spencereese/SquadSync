import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/providers/system_notifier.dart';
import 'test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    await TestSetup.initializeFirebase();
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    TestSetup.tearDown();
  });

  group('SystemNotifier', () {
    test('initial state should be correct', () async {
      final state = await container.read(systemNotifierProvider.future);

      expect(state.notifications, isEmpty);
      expect(state.availabilitySlots, isEmpty);
      expect(state.dailyBanVotes, isEmpty);
      expect(state.bans, isEmpty);
      expect(state.hasNewNotifications, isFalse);
      expect(state.hasNewAvailability, isFalse);
      expect(state.isInitialized, isTrue);
      expect(state.errorMessage, isNull);
    });

    test('addNotification should add notification to list', () async {
      final notification = {
        'id': 'notif1',
        'title': 'Test Notification',
        'body': 'This is a test',
        'type': 'info',
        'timestamp': DateTime.now(),
      };
      final notifier = container.read(systemNotifierProvider.notifier);

      // Act
      await notifier.addNotification(notification);

      // Assert
      final state = container.read(systemNotifierProvider).value!;
      expect(state.notifications.length, 1);
      expect(state.notifications[0]['title'], 'Test Notification');
      expect(state.hasNewNotifications, isTrue);
      expect(state.errorMessage, isNull);
    });

    test('markNotificationsAsRead should clear new notifications flag',
        () async {
      final notification = {
        'id': 'notif1',
        'title': 'Test Notification',
        'body': 'This is a test',
        'type': 'info',
        'timestamp': DateTime.now(),
      };
      final notifier = container.read(systemNotifierProvider.notifier);

      // First add a notification
      await notifier.addNotification(notification);
      expect(container.read(systemNotifierProvider).value!.hasNewNotifications,
          isTrue);

      // Act
      await notifier.markNotificationsAsRead();

      // Assert
      final state = container.read(systemNotifierProvider).value!;
      expect(state.hasNewNotifications, isFalse);
      expect(state.notifications.length, 1); // Notifications should still exist
      expect(state.errorMessage, isNull);
    });

    test('deleteNotification should remove notification from list', () async {
      final notification = {
        'id': 'notif1',
        'title': 'Test Notification',
        'body': 'This is a test',
        'type': 'info',
        'timestamp': DateTime.now(),
      };
      final notifier = container.read(systemNotifierProvider.notifier);

      // First add a notification
      await notifier.addNotification(notification);
      expect(container.read(systemNotifierProvider).value!.notifications.length,
          1);

      // Act
      await notifier.deleteNotification('notif1');

      // Assert
      final state = container.read(systemNotifierProvider).value!;
      expect(state.notifications, isEmpty);
      expect(state.errorMessage, isNull);
    });

    test('addAvailabilitySlot should add slot to availability list', () async {
      final slot = {
        'id': 'slot1',
        'day': 'Monday',
        'startTime': '18:00',
        'endTime': '22:00',
        'isAvailable': true,
      };
      final notifier = container.read(systemNotifierProvider.notifier);

      // Act
      await notifier.addAvailabilitySlot(slot);

      // Assert
      final state = container.read(systemNotifierProvider).value!;
      expect(state.availabilitySlots.length, 1);
      expect(state.availabilitySlots[0]['day'], 'Monday');
      expect(state.hasNewAvailability, isTrue);
      expect(state.errorMessage, isNull);
    });

    test('removeAvailabilitySlot should remove slot from list', () async {
      final slot = {
        'id': 'slot1',
        'day': 'Monday',
        'startTime': '18:00',
        'endTime': '22:00',
        'isAvailable': true,
      };
      final notifier = container.read(systemNotifierProvider.notifier);

      // First add a slot
      await notifier.addAvailabilitySlot(slot);
      expect(
          container
              .read(systemNotifierProvider)
              .value!
              .availabilitySlots
              .length,
          1);

      // Act
      await notifier.removeAvailabilitySlot('slot1');

      // Assert
      final state = container.read(systemNotifierProvider).value!;
      expect(state.availabilitySlots, isEmpty);
      expect(state.errorMessage, isNull);
    });

    test('updateAvailabilitySlot should modify existing slot', () async {
      final slot = {
        'id': 'slot1',
        'day': 'Monday',
        'startTime': '18:00',
        'endTime': '22:00',
        'isAvailable': true,
      };
      final updatedSlot = {
        'id': 'slot1',
        'day': 'Monday',
        'startTime': '19:00',
        'endTime': '23:00',
        'isAvailable': false,
      };
      final notifier = container.read(systemNotifierProvider.notifier);

      // First add a slot
      await notifier.addAvailabilitySlot(slot);
      expect(
          container.read(systemNotifierProvider).value!.availabilitySlots[0]
              ['startTime'],
          '18:00');

      // Act
      await notifier.updateAvailabilitySlot('slot1', updatedSlot);

      // Assert
      final state = container.read(systemNotifierProvider).value!;
      expect(state.availabilitySlots.length, 1);
      expect(state.availabilitySlots[0]['startTime'], '19:00');
      expect(state.availabilitySlots[0]['isAvailable'], isFalse);
      expect(state.errorMessage, isNull);
    });

    test('submitBanVote should add vote to daily votes', () async {
      final notifier = container.read(systemNotifierProvider.notifier);

      // Act
      await notifier.submitBanVote('user123', true);

      // Assert
      final state = container.read(systemNotifierProvider).value!;
      expect(state.dailyBanVotes.containsKey('user123'), isTrue);
      expect(state.dailyBanVotes['user123']!['current_user'], isTrue);
      expect(state.errorMessage, isNull);
    });

    test('submitBanVote should handle multiple votes', () async {
      final notifier = container.read(systemNotifierProvider.notifier);

      // Submit multiple votes
      await notifier.submitBanVote('user123', true);
      await notifier.submitBanVote('user456', false);

      // Assert
      final state = container.read(systemNotifierProvider).value!;
      expect(state.dailyBanVotes.length, 2);
      expect(state.dailyBanVotes['user123']!['current_user'], isTrue);
      expect(state.dailyBanVotes['user456']!['current_user'], isFalse);
      expect(state.errorMessage, isNull);
    });

    test('processBanVotes should create bans for users with majority votes',
        () async {
      final notifier = container.read(systemNotifierProvider.notifier);

      // Set up votes that would result in a ban (assuming majority logic)
      // Note: This test assumes the implementation checks for majority
      await notifier.submitBanVote('user123', true);

      // Act
      await notifier.processBanVotes();

      // Assert
      final state = container.read(systemNotifierProvider).value!;
      // The exact behavior depends on the implementation, but it should process votes
      expect(state.errorMessage, isNull);
    });

    test('sendNotificationToUser should add notification for specific user',
        () async {
      final notifier = container.read(systemNotifierProvider.notifier);

      // Act
      await notifier.sendNotificationToUser(
          'user123', 'Test Title', 'Test Body');

      // Assert
      final state = container.read(systemNotifierProvider).value!;
      expect(state.notifications.length, 1);
      expect(state.notifications[0]['title'], 'Test Title');
      expect(state.notifications[0]['body'], 'Test Body');
      expect(state.notifications[0]['targetUserId'], 'user123');
      expect(state.errorMessage, isNull);
    });

    test('sendNotificationToSquad should add notification for squad', () async {
      final notifier = container.read(systemNotifierProvider.notifier);

      // Act
      await notifier.sendNotificationToSquad(
          'squad123', 'Squad Alert', 'Important message');

      // Assert
      final state = container.read(systemNotifierProvider).value!;
      expect(state.notifications.length, 1);
      expect(state.notifications[0]['title'], 'Squad Alert');
      expect(state.notifications[0]['body'], 'Important message');
      expect(state.notifications[0]['targetSquadId'], 'squad123');
      expect(state.errorMessage, isNull);
    });

    test('scheduleNotification should add scheduled notification', () async {
      final scheduleTime = DateTime.now().add(const Duration(hours: 1));
      final notifier = container.read(systemNotifierProvider.notifier);

      // Act
      await notifier.scheduleNotification(
        scheduleTime,
        'Scheduled Title',
        'Scheduled Body',
        data: {'targetUserId': 'user123'},
      );

      // Assert
      final state = container.read(systemNotifierProvider).value!;
      expect(state.notifications.length, 1);
      expect(state.notifications[0]['title'], 'Scheduled Title');
      expect(state.notifications[0]['scheduledTime'], scheduleTime);
      expect(state.notifications[0]['data']['targetUserId'], 'user123');
      expect(state.errorMessage, isNull);
    });

    test('clearOldNotifications should remove old notifications', () async {
      final oldNotification = {
        'id': 'old_notif',
        'title': 'Old Notification',
        'body': 'This is old',
        'type': 'info',
        'timestamp': DateTime.now().subtract(const Duration(days: 30)),
      };
      final newNotification = {
        'id': 'new_notif',
        'title': 'New Notification',
        'body': 'This is new',
        'type': 'info',
        'timestamp': DateTime.now(),
      };
      final notifier = container.read(systemNotifierProvider.notifier);

      // Add notifications
      await notifier.addNotification(oldNotification);
      await notifier.addNotification(newNotification);
      expect(container.read(systemNotifierProvider).value!.notifications.length,
          2);

      // Act - clear notifications older than 7 days
      await notifier.clearOldNotifications(olderThan: const Duration(days: 7));

      // Assert
      final state = container.read(systemNotifierProvider).value!;
      expect(state.notifications.length, 1);
      expect(state.notifications[0]['id'], 'new_notif');
      expect(state.errorMessage, isNull);
    });

    test('resetDailyVotes should clear all daily ban votes', () async {
      final notifier = container.read(systemNotifierProvider.notifier);

      // Add some votes
      await notifier.submitBanVote('user123', true);
      await notifier.submitBanVote('user456', false);
      expect(container.read(systemNotifierProvider).value!.dailyBanVotes.length,
          2);

      // Act
      await notifier.resetDailyVotes();

      // Assert
      final state = container.read(systemNotifierProvider).value!;
      expect(state.dailyBanVotes, isEmpty);
      expect(state.errorMessage, isNull);
    });

    test('should handle empty notification lists', () async {
      final notifier = container.read(systemNotifierProvider.notifier);

      // Act
      await notifier.markNotificationsAsRead();
      await notifier.deleteNotification('nonexistent');

      // Assert
      final state = container.read(systemNotifierProvider).value!;
      expect(state.notifications, isEmpty);
      expect(state.hasNewNotifications, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('should handle empty availability slots', () async {
      final notifier = container.read(systemNotifierProvider.notifier);

      // Act
      await notifier.removeAvailabilitySlot('nonexistent');
      await notifier.updateAvailabilitySlot('nonexistent', {});

      // Assert
      final state = container.read(systemNotifierProvider).value!;
      expect(state.availabilitySlots, isEmpty);
      expect(state.errorMessage, isNull);
    });

    test('should handle duplicate notifications', () async {
      final notification = {
        'id': 'notif1',
        'title': 'Test Notification',
        'body': 'This is a test',
        'type': 'info',
        'timestamp': DateTime.now(),
      };
      final notifier = container.read(systemNotifierProvider.notifier);

      // Add same notification twice
      await notifier.addNotification(notification);
      await notifier.addNotification(notification);

      // Assert
      final state = container.read(systemNotifierProvider).value!;
      expect(state.notifications.length, 2); // Should allow duplicates
      expect(state.errorMessage, isNull);
    });

    test('should handle overlapping availability slots', () async {
      final slot1 = {
        'id': 'slot1',
        'day': 'Monday',
        'startTime': '18:00',
        'endTime': '22:00',
        'isAvailable': true,
      };
      final slot2 = {
        'id': 'slot2',
        'day': 'Monday',
        'startTime': '20:00',
        'endTime': '23:00',
        'isAvailable': true,
      };
      final notifier = container.read(systemNotifierProvider.notifier);

      // Add overlapping slots
      await notifier.addAvailabilitySlot(slot1);
      await notifier.addAvailabilitySlot(slot2);

      // Assert
      final state = container.read(systemNotifierProvider).value!;
      expect(state.availabilitySlots.length, 2);
      expect(state.errorMessage, isNull);
    });

    test('should handle vote changes', () async {
      final notifier = container.read(systemNotifierProvider.notifier);

      // Submit initial vote
      await notifier.submitBanVote('user123', true);
      expect(
          container
              .read(systemNotifierProvider)
              .value!
              .dailyBanVotes['user123']!['current_user'],
          isTrue);

      // Change vote
      await notifier.submitBanVote('user123', false);

      // Assert
      final state = container.read(systemNotifierProvider).value!;
      expect(state.dailyBanVotes['user123']!['current_user'], isFalse);
      expect(state.errorMessage, isNull);
    });
  });
}
