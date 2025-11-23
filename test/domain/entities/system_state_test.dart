import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/system_state.dart';

void main() {
  group('SystemState Entity Tests', () {
    final testSystemState = SystemState(
      themeMode: ThemeMode.dark,
      notificationsEnabled: true,
      soundEnabled: false,
      vibrationEnabled: true,
      lastSyncTimestamp: DateTime(2023, 12, 25, 10, 30),
      analyticsMetrics: {
        'totalUsers': 150,
        'activeSquads': 25,
        'messagesSent': 1200,
        'gamesPlayed': 89,
      },
      notifications: [
        {
          'id': 'notif1',
          'title': 'New Squad Invite',
          'body': 'You have been invited to join Squad Alpha',
          'timestamp': DateTime(2023, 12, 25, 9, 0).toIso8601String(),
          'read': false,
        },
        {
          'id': 'notif2',
          'title': 'Game Starting',
          'body': 'Call of Duty match begins in 5 minutes',
          'timestamp': DateTime(2023, 12, 25, 10, 0).toIso8601String(),
          'read': true,
        },
      ],
      availabilitySlots: [
        {
          'id': 'slot1',
          'game': 'Call of Duty',
          'startTime': DateTime(2023, 12, 25, 14, 0).toIso8601String(),
          'endTime': DateTime(2023, 12, 25, 16, 0).toIso8601String(),
          'isAvailable': true,
        },
      ],
      dailyBanVotes: {
        'game1': {'user1': true, 'user2': false},
        'game2': {'user3': true},
      },
      bans: [
        {
          'id': 'ban1',
          'targetUserId': 'user1',
          'reason': 'Spam messaging',
          'bannedBy': 'moderator1',
          'timestamp': DateTime(2023, 12, 24, 15, 30).toIso8601String(),
          'duration': const Duration(days: 7).inMilliseconds,
        },
      ],
      hasNewNotifications: true,
      hasNewAvailability: false,
      isInitialized: true,
      errorMessage: null,
    );

    test('should create SystemState with required fields', () {
      expect(testSystemState.themeMode, ThemeMode.dark);
      expect(testSystemState.notificationsEnabled, true);
      expect(testSystemState.soundEnabled, false);
      expect(testSystemState.vibrationEnabled, true);
      expect(testSystemState.lastSyncTimestamp, DateTime(2023, 12, 25, 10, 30));
      expect(testSystemState.isInitialized, true);
    });

    test('should create initial SystemState', () {
      final initialState = SystemState.initial();
      expect(initialState.themeMode, ThemeMode.system);
      expect(initialState.notificationsEnabled, true);
      expect(initialState.soundEnabled, true);
      expect(initialState.vibrationEnabled, true);
      expect(initialState.lastSyncTimestamp, null);
      expect(initialState.analyticsMetrics, {});
      expect(initialState.notifications, []);
      expect(initialState.availabilitySlots, []);
      expect(initialState.dailyBanVotes, {});
      expect(initialState.bans, []);
      expect(initialState.hasNewNotifications, false);
      expect(initialState.hasNewAvailability, false);
      expect(initialState.isInitialized, false);
      expect(initialState.errorMessage, null);
    });

    test('should support equality', () {
      final state1 = testSystemState;
      final state2 = testSystemState.copyWith();
      expect(state1, state2);
    });

    test('should support copyWith', () {
      final updatedState = testSystemState.copyWith(
        themeMode: ThemeMode.light,
        notificationsEnabled: false,
        hasNewNotifications: false,
      );
      expect(updatedState.themeMode, ThemeMode.light);
      expect(updatedState.notificationsEnabled, false);
      expect(updatedState.hasNewNotifications, false);
      // Unchanged fields should remain the same
      expect(updatedState.soundEnabled, testSystemState.soundEnabled);
      expect(updatedState.lastSyncTimestamp, testSystemState.lastSyncTimestamp);
    });

    test('should have correct hashCode', () {
      final state1 = testSystemState;
      final state2 = testSystemState.copyWith();
      expect(state1.hashCode, state2.hashCode);
    });

    test('should serialize to JSON', () {
      final json = testSystemState.toJson();
      expect(json['themeMode'], 'dark');
      expect(json['notificationsEnabled'], true);
      expect(json['soundEnabled'], false);
      expect(json['vibrationEnabled'], true);
      expect(json['lastSyncTimestamp'], '2023-12-25T10:30:00.000');
      expect(json['analyticsMetrics'], isA<Map<String, dynamic>>());
      expect(json['notifications'], isA<List>());
      expect(json['availabilitySlots'], isA<List>());
      expect(json['dailyBanVotes'], isA<Map<String, Map<String, bool>>>());
      expect(json['bans'], isA<List>());
      expect(json['hasNewNotifications'], true);
      expect(json['hasNewAvailability'], false);
      expect(json['isInitialized'], true);
      expect(json['errorMessage'], null);
    });

    test('should deserialize from JSON', () {
      final json = testSystemState.toJson();
      final deserializedState = SystemState.fromJson(json);
      expect(deserializedState, testSystemState);
    });

    test('should handle complex nested structures', () {
      // Analytics metrics
      expect(testSystemState.analyticsMetrics['totalUsers'], 150);
      expect(testSystemState.analyticsMetrics['activeSquads'], 25);

      // Notifications
      expect(testSystemState.notifications.length, 2);
      expect(testSystemState.notifications.first['id'], 'notif1');
      expect(testSystemState.notifications.first['title'], 'New Squad Invite');
      expect(testSystemState.notifications.first['read'], false);

      // Availability slots
      expect(testSystemState.availabilitySlots.length, 1);
      expect(testSystemState.availabilitySlots.first['game'], 'Call of Duty');
      expect(testSystemState.availabilitySlots.first['isAvailable'], true);

      // Daily ban votes
      expect(testSystemState.dailyBanVotes['game1']!['user1'], true);
      expect(testSystemState.dailyBanVotes['game1']!['user2'], false);
      expect(testSystemState.dailyBanVotes['game2']!['user3'], true);

      // Bans
      expect(testSystemState.bans.length, 1);
      expect(testSystemState.bans.first['targetUserId'], 'user1');
      expect(testSystemState.bans.first['reason'], 'Spam messaging');
    });

    test('should handle null values correctly', () {
      final stateWithNulls = SystemState.initial().copyWith(
        lastSyncTimestamp: null,
        errorMessage: null,
      );
      expect(stateWithNulls.lastSyncTimestamp, null);
      expect(stateWithNulls.errorMessage, null);
    });

    test('should handle empty collections', () {
      final emptyState = SystemState.initial();
      expect(emptyState.analyticsMetrics, {});
      expect(emptyState.notifications, []);
      expect(emptyState.availabilitySlots, []);
      expect(emptyState.dailyBanVotes, {});
      expect(emptyState.bans, []);
    });

    test('should handle ThemeMode enum values', () {
      final systemMode = testSystemState.copyWith(themeMode: ThemeMode.system);
      final lightMode = testSystemState.copyWith(themeMode: ThemeMode.light);
      final darkMode = testSystemState.copyWith(themeMode: ThemeMode.dark);

      expect(systemMode.themeMode, ThemeMode.system);
      expect(lightMode.themeMode, ThemeMode.light);
      expect(darkMode.themeMode, ThemeMode.dark);
    });

    test('should handle boolean flags correctly', () {
      final flagsState = testSystemState.copyWith(
        notificationsEnabled: false,
        soundEnabled: false,
        vibrationEnabled: false,
        hasNewNotifications: false,
        hasNewAvailability: true,
        isInitialized: false,
      );

      expect(flagsState.notificationsEnabled, false);
      expect(flagsState.soundEnabled, false);
      expect(flagsState.vibrationEnabled, false);
      expect(flagsState.hasNewNotifications, false);
      expect(flagsState.hasNewAvailability, true);
      expect(flagsState.isInitialized, false);
    });
  });
}