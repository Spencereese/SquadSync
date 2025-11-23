import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/squad_state.dart';

void main() {
  group('SquadState Entity Tests', () {
    final testSquadState = SquadState(
      isInitialized: true,
      isInitialDataLoaded: true,
      displayName: 'TestUser',
      profileImage: 'https://example.com/avatar.jpg',
      memberProfileImages: {
        'user1': 'https://example.com/user1.jpg',
        'user2': 'https://example.com/user2.jpg',
      },
      gameSquadSpots: {
        'Call of Duty': ['user1', null, 'user2', null],
        'Fortnite': ['user3', 'user4', null, null, null],
      },
      gameSpotTimers: {
        'Call of Duty': [
          {'startTime': DateTime(2023, 12, 25, 10, 5).toIso8601String(), 'duration': 300000},
          null,
          {'startTime': DateTime(2023, 12, 25, 10, 10).toIso8601String(), 'duration': 600000},
          null,
        ],
        'Fortnite': [
          null,
          {'startTime': DateTime(2023, 12, 25, 10, 15).toIso8601String(), 'duration': 300000},
          null,
          null,
          null,
        ],
      },
      gameStatuses: {
        'Call of Duty': {'user1': 'Ready', 'user2': 'Walking'},
        'Fortnite': {'user3': 'Available', 'user4': 'In Lobby'},
      },
      globalStatuses: {
        'user1': 'Online',
        'user2': 'Away',
        'user3': 'Busy',
      },
      squadMemberUids: ['user1', 'user2', 'user3'],
      memberDisplayNames: {
        'user1': 'PlayerOne',
        'user2': 'PlayerTwo',
        'user3': 'PlayerThree',
      },
      userSquadIds: ['squad1', 'squad2'],
      userSquads: {},
      typing: {'squad1': true, 'squad2': false},
      tiltEnabled: true,
      hasNewSquadSpot: false,
      hasUnreadMessages: true,
      gameHistory: [
        {'game': 'Call of Duty', 'timestamp': DateTime(2023, 12, 24, 20, 0).toIso8601String()},
        {'game': 'Fortnite', 'timestamp': DateTime(2023, 12, 23, 18, 30).toIso8601String()},
      ],
      preferredModes: {
        'Call of Duty': 'Ranked',
        'Fortnite': 'Squads',
      },
      userBlocks: {
        'Call of Duty': {'blocked1': true, 'blocked2': false},
      },
      dailyBanVotes: {
        'Call of Duty': {'user1': 2, 'user2': 1},
      },
      bans: {
        'game1': [
          {
            'id': 'ban1',
            'targetUserId': 'user1',
            'reason': 'Spam',
            'bannedBy': 'moderator',
            'timestamp': DateTime(2023, 12, 24, 15, 0).toIso8601String(),
            'duration': 86400000,
          },
        ],
      },
      availableGames: [
        {'name': 'Call of Duty', 'maxSpots': 4},
        {'name': 'Fortnite', 'maxSpots': 5},
      ],
      gameLobbies: {
        'Call of Duty': [
          {'id': 'lobby1', 'host': 'user1', 'players': ['user1', 'user2']},
        ],
      },
      preferredPeacockGames: {'Call of Duty', 'Fortnite'},
      mutedGames: {'Apex Legends'},
      hiddenGames: {'Old Game'},
      peacockTimers: {
        'user1': {'startTime': DateTime(2023, 12, 25, 10, 0).toIso8601String(), 'duration': 1800000},
      },
      peacockQueue: ['user1', 'user2', 'user3'],
      scheduledTimes: [
        {'game': 'Call of Duty', 'time': DateTime(2023, 12, 25, 14, 0).toIso8601String()},
      ],
      hasNewAvailability: true,
      spotTimerStates: {
        'spot1': const Duration(minutes: 5),
        'spot2': const Duration(minutes: 10),
      },
      peacockTimerStates: {
        'user1': const Duration(minutes: 30),
        'user2': const Duration(minutes: 15),
      },
      lastSyncTimestamp: DateTime(2023, 12, 25, 10, 30),
      analyticsMetrics: {
        'totalSquads': 25,
        'activeUsers': 150,
        'gamesPlayed': 89,
      },
    );

    test('should create SquadState with required fields', () {
      expect(testSquadState.isInitialized, true);
      expect(testSquadState.isInitialDataLoaded, true);
      expect(testSquadState.displayName, 'TestUser');
      expect(testSquadState.gameSquadSpots.length, 2);
      expect(testSquadState.globalStatuses.length, 3);
      expect(testSquadState.lastSyncTimestamp, DateTime(2023, 12, 25, 10, 30));
    });

    test('should create initial SquadState', () {
      final initialState = SquadState.initial();

      expect(initialState.isInitialized, false);
      expect(initialState.isInitialDataLoaded, false);
      expect(initialState.displayName, 'Unknown User');
      expect(initialState.gameSquadSpots, {});
      expect(initialState.gameSpotTimers, {});
      expect(initialState.gameStatuses, {});
      expect(initialState.globalStatuses, {});
      expect(initialState.squadMemberUids, []);
      expect(initialState.memberDisplayNames, {});
      expect(initialState.userSquadIds, []);
      expect(initialState.userSquads, {});
      expect(initialState.typing, {});
      expect(initialState.tiltEnabled, false);
      expect(initialState.hasNewSquadSpot, false);
      expect(initialState.hasUnreadMessages, false);
      expect(initialState.gameHistory, []);
      expect(initialState.preferredModes, {});
      expect(initialState.userBlocks, {});
      expect(initialState.dailyBanVotes, {});
      expect(initialState.bans, {});
      expect(initialState.availableGames, []);
      expect(initialState.gameLobbies, {});
      expect(initialState.preferredPeacockGames, isEmpty);
      expect(initialState.mutedGames, isEmpty);
      expect(initialState.hiddenGames, isEmpty);
      expect(initialState.peacockTimers, {});
      expect(initialState.peacockQueue, []);
      expect(initialState.scheduledTimes, []);
      expect(initialState.hasNewAvailability, false);
      expect(initialState.spotTimerStates, {});
      expect(initialState.peacockTimerStates, {});
      expect(initialState.analyticsMetrics, {});
    });

    test('should support equality', () {
      final state1 = testSquadState;
      final state2 = testSquadState.copyWith();
      expect(state1, state2);
    });

    test('should support copyWith', () {
      final updatedState = testSquadState.copyWith(
        displayName: 'UpdatedUser',
        tiltEnabled: false,
        hasNewSquadSpot: true,
        hasUnreadMessages: false,
      );

      expect(updatedState.displayName, 'UpdatedUser');
      expect(updatedState.tiltEnabled, false);
      expect(updatedState.hasNewSquadSpot, true);
      expect(updatedState.hasUnreadMessages, false);

      // Unchanged fields should remain the same
      expect(updatedState.isInitialized, testSquadState.isInitialized);
      expect(updatedState.gameSquadSpots, testSquadState.gameSquadSpots);
    });

    test('should have correct hashCode', () {
      final state1 = testSquadState;
      final state2 = testSquadState.copyWith();
      expect(state1.hashCode, state2.hashCode);
    });

    test('should serialize to JSON', () {
      final json = testSquadState.toJson();

      expect(json['isInitialized'], true);
      expect(json['isInitialDataLoaded'], true);
      expect(json['displayName'], 'TestUser');
      expect(json['gameSquadSpots'], isA<Map<String, dynamic>>());
      expect(json['gameSpotTimers'], isA<Map<String, dynamic>>());
      expect(json['gameStatuses'], isA<Map<String, dynamic>>());
      expect(json['globalStatuses'], isA<Map<String, dynamic>>());
      expect(json['lastSyncTimestamp'], '2023-12-25T10:30:00.000');
      expect(json['analyticsMetrics'], isA<Map<String, dynamic>>());
    });

    test('should deserialize from JSON', () {
      final json = testSquadState.toJson();
      final deserializedState = SquadState.fromJson(json);
      expect(deserializedState, testSquadState);
    });

    test('should handle game-scoped data structures', () {
      // Game squad spots
      expect(testSquadState.gameSquadSpots['Call of Duty'], ['user1', null, 'user2', null]);
      expect(testSquadState.gameSquadSpots['Fortnite'], ['user3', 'user4', null, null, null]);

      // Game spot timers
      expect(testSquadState.gameSpotTimers['Call of Duty']![0], isA<Map<String, dynamic>>());
      expect(testSquadState.gameSpotTimers['Call of Duty']![1], null);

      // Game statuses
      expect(testSquadState.gameStatuses['Call of Duty'], {'user1': 'Ready', 'user2': 'Walking'});
      expect(testSquadState.gameStatuses['Fortnite'], {'user3': 'Available', 'user4': 'In Lobby'});
    });

    test('should handle global vs game-specific statuses', () {
      expect(testSquadState.globalStatuses['user1'], 'Online');
      expect(testSquadState.globalStatuses['user2'], 'Away');

      expect(testSquadState.gameStatuses['Call of Duty']!['user1'], 'Ready');
      expect(testSquadState.gameStatuses['Fortnite']!['user3'], 'Available');
    });

    test('should handle member display name caching', () {
      expect(testSquadState.memberDisplayNames['user1'], 'PlayerOne');
      expect(testSquadState.memberDisplayNames['user2'], 'PlayerTwo');
      expect(testSquadState.memberDisplayNames['user3'], 'PlayerThree');
    });

    test('should handle peacock queue management', () {
      expect(testSquadState.peacockQueue, ['user1', 'user2', 'user3']);
      expect(testSquadState.peacockTimers['user1'], isA<Map<String, dynamic>>());
      expect(testSquadState.peacockTimerStates['user1'], const Duration(minutes: 30));
    });

    test('should handle game preferences and filters', () {
      expect(testSquadState.preferredPeacockGames, {'Call of Duty', 'Fortnite'});
      expect(testSquadState.mutedGames, {'Apex Legends'});
      expect(testSquadState.hiddenGames, {'Old Game'});
      expect(testSquadState.preferredModes['Call of Duty'], 'Ranked');
    });

    test('should handle ban and voting systems', () {
      expect(testSquadState.bans.length, 1);
      expect(testSquadState.bans['game1']!.length, 1);
      expect(testSquadState.bans['game1']!.first['targetUserId'], 'user1');
      expect(testSquadState.bans['game1']!.first['reason'], 'Spam');
      expect(testSquadState.dailyBanVotes['Call of Duty'], {'user1': 2, 'user2': 1});
    });

    test('should handle timer states', () {
      expect(testSquadState.spotTimerStates['spot1'], const Duration(minutes: 5));
      expect(testSquadState.spotTimerStates['spot2'], const Duration(minutes: 10));
      expect(testSquadState.peacockTimerStates['user1'], const Duration(minutes: 30));
    });

    test('should handle analytics metrics', () {
      expect(testSquadState.analyticsMetrics['totalSquads'], 25);
      expect(testSquadState.analyticsMetrics['activeUsers'], 150);
      expect(testSquadState.analyticsMetrics['gamesPlayed'], 89);
    });

    test('should handle empty collections', () {
      final emptyState = SquadState.initial();

      expect(emptyState.gameSquadSpots, {});
      expect(emptyState.peacockQueue, []);
      expect(emptyState.bans, {});
      expect(emptyState.spotTimerStates, {});
    });

    test('should handle dynamic game data updates', () {
      final updatedState = testSquadState.copyWith(
        gameSquadSpots: {
          'Call of Duty': ['user1', 'user2', null, null],
          'Fortnite': ['user3', null, null, null, null],
          'Apex Legends': [null, null, null],
        },
        gameStatuses: {
          'Call of Duty': {'user1': 'In Game', 'user2': 'Ready'},
          'Apex Legends': {'user5': 'Available'},
        },
      );

      expect(updatedState.gameSquadSpots['Call of Duty'], ['user1', 'user2', null, null]);
      expect(updatedState.gameStatuses['Apex Legends'], {'user5': 'Available'});
    });
  });
}