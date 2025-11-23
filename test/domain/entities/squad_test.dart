import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/squad.dart';

void main() {
  group('Squad Entity Tests', () {
    final testSquad = Squad(
      id: 'squad123',
      name: 'Alpha Squad',
      memberUids: ['user1', 'user2', 'user3'],
      gameName: 'Call of Duty',
      maxSpots: 4,
      createdBy: 'user1',
      createdAt: DateTime(2023, 12, 25, 10, 0),
      spots: ['user1', null, 'user2', null],
      spotTimers: [
        {'startTime': DateTime(2023, 12, 25, 10, 5).toIso8601String(), 'duration': 300000},
        null,
        {'startTime': DateTime(2023, 12, 25, 10, 10).toIso8601String(), 'duration': 600000},
        null,
      ],
      viewers: ['viewer1', 'viewer2'],
      statuses: {'user1': 'Ready', 'user2': 'Walking', 'user3': 'Available'},
      isActive: true,
      description: 'Competitive squad for ranked matches',
      settings: {'autoKick': true, 'allowViewers': true},
    );

    test('should create Squad with required fields', () {
      expect(testSquad.id, 'squad123');
      expect(testSquad.name, 'Alpha Squad');
      expect(testSquad.memberUids, ['user1', 'user2', 'user3']);
      expect(testSquad.gameName, 'Call of Duty');
      expect(testSquad.maxSpots, 4);
      expect(testSquad.createdBy, 'user1');
      expect(testSquad.createdAt, DateTime(2023, 12, 25, 10, 0));
      expect(testSquad.spots, ['user1', null, 'user2', null]);
      expect(testSquad.spotTimers.length, 4);
      expect(testSquad.viewers, ['viewer1', 'viewer2']);
      expect(testSquad.statuses, {'user1': 'Ready', 'user2': 'Walking', 'user3': 'Available'});
      expect(testSquad.isActive, true);
      expect(testSquad.description, 'Competitive squad for ranked matches');
      expect(testSquad.settings, {'autoKick': true, 'allowViewers': true});
    });

    test('should create Squad using factory constructor', () {
      final createdSquad = Squad.create(
        name: 'Beta Squad',
        gameName: 'Fortnite',
        maxSpots: 3,
        createdBy: 'creator1',
      );

      expect(createdSquad.name, 'Beta Squad');
      expect(createdSquad.gameName, 'Fortnite');
      expect(createdSquad.maxSpots, 3);
      expect(createdSquad.createdBy, 'creator1');
      expect(createdSquad.memberUids, ['creator1']);
      expect(createdSquad.spots.length, 3);
      expect(createdSquad.spotTimers.length, 3);
      expect(createdSquad.viewers, []);
      expect(createdSquad.statuses, {});
      expect(createdSquad.isActive, true);
      expect(createdSquad.id, isNotEmpty);
      expect(createdSquad.createdAt, isA<DateTime>());
    });

    test('should support equality', () {
      final squad1 = testSquad;
      final squad2 = testSquad.copyWith();
      expect(squad1, squad2);
    });

    test('should support copyWith', () {
      final updatedSquad = testSquad.copyWith(
        name: 'Updated Squad',
        maxSpots: 6,
        isActive: false,
        description: 'Updated description',
      );

      expect(updatedSquad.name, 'Updated Squad');
      expect(updatedSquad.maxSpots, 6);
      expect(updatedSquad.isActive, false);
      expect(updatedSquad.description, 'Updated description');

      // Unchanged fields should remain the same
      expect(updatedSquad.id, testSquad.id);
      expect(updatedSquad.gameName, testSquad.gameName);
      expect(updatedSquad.createdBy, testSquad.createdBy);
    });

    test('should have correct hashCode', () {
      final squad1 = testSquad;
      final squad2 = testSquad.copyWith();
      expect(squad1.hashCode, squad2.hashCode);
    });

    test('should serialize to JSON', () {
      final json = testSquad.toJson();

      expect(json['id'], 'squad123');
      expect(json['name'], 'Alpha Squad');
      expect(json['memberUids'], ['user1', 'user2', 'user3']);
      expect(json['gameName'], 'Call of Duty');
      expect(json['maxSpots'], 4);
      expect(json['createdBy'], 'user1');
      expect(json['createdAt'], '2023-12-25T10:00:00.000');
      expect(json['spots'], ['user1', null, 'user2', null]);
      expect(json['spotTimers'], isA<List>());
      expect(json['viewers'], ['viewer1', 'viewer2']);
      expect(json['statuses'], {'user1': 'Ready', 'user2': 'Walking', 'user3': 'Available'});
      expect(json['isActive'], true);
      expect(json['description'], 'Competitive squad for ranked matches');
      expect(json['settings'], {'autoKick': true, 'allowViewers': true});
    });

    test('should deserialize from JSON', () {
      final json = testSquad.toJson();
      final deserializedSquad = Squad.fromJson(json);
      expect(deserializedSquad, testSquad);
    });

    test('should handle complex nested structures', () {
      // Spot timers
      expect(testSquad.spotTimers[0], isA<Map<String, dynamic>>());
      expect(testSquad.spotTimers[0]!['startTime'], DateTime(2023, 12, 25, 10, 5).toIso8601String());
      expect(testSquad.spotTimers[0]!['duration'], 300000);
      expect(testSquad.spotTimers[1], null);

      // Statuses
      expect(testSquad.statuses['user1'], 'Ready');
      expect(testSquad.statuses['user2'], 'Walking');
      expect(testSquad.statuses['user3'], 'Available');

      // Settings
      expect(testSquad.settings!['autoKick'], true);
      expect(testSquad.settings!['allowViewers'], true);
    });

    test('should handle empty collections', () {
      final emptySquad = Squad(
        id: 'empty123',
        name: 'Empty Squad',
        memberUids: [],
        gameName: 'Test Game',
        maxSpots: 2,
        createdBy: 'creator',
        createdAt: DateTime.now(),
        spots: [null, null],
        spotTimers: [null, null],
        viewers: [],
        statuses: {},
        isActive: true,
      );

      expect(emptySquad.memberUids, []);
      expect(emptySquad.viewers, []);
      expect(emptySquad.statuses, {});
      expect(emptySquad.spots, [null, null]);
      expect(emptySquad.spotTimers, [null, null]);
    });

    test('should handle null optional fields', () {
      final minimalSquad = Squad(
        id: 'minimal123',
        name: 'Minimal Squad',
        memberUids: ['user1'],
        gameName: 'Test Game',
        maxSpots: 1,
        createdBy: 'user1',
        createdAt: DateTime.now(),
        spots: [null],
        spotTimers: [null],
        viewers: [],
        statuses: {},
        isActive: true,
        description: null,
        settings: null,
      );

      expect(minimalSquad.description, null);
      expect(minimalSquad.settings, null);
    });

    test('should handle dynamic spot assignments', () {
      final dynamicSquad = testSquad.copyWith(
        spots: ['user1', 'user2', null, 'user3'],
        spotTimers: [
          {'startTime': DateTime.now().toIso8601String(), 'duration': 300000},
          {'startTime': DateTime.now().toIso8601String(), 'duration': 300000},
          null,
          {'startTime': DateTime.now().toIso8601String(), 'duration': 300000},
        ],
      );

      expect(dynamicSquad.spots[0], 'user1');
      expect(dynamicSquad.spots[1], 'user2');
      expect(dynamicSquad.spots[2], null);
      expect(dynamicSquad.spots[3], 'user3');

      expect(dynamicSquad.spotTimers[0], isNotNull);
      expect(dynamicSquad.spotTimers[1], isNotNull);
      expect(dynamicSquad.spotTimers[2], null);
      expect(dynamicSquad.spotTimers[3], isNotNull);
    });

    test('should handle viewer management', () {
      final viewerSquad = testSquad.copyWith(
        viewers: ['viewer1', 'viewer2', 'viewer3', 'viewer4'],
      );

      expect(viewerSquad.viewers.length, 4);
      expect(viewerSquad.viewers.contains('viewer1'), true);
      expect(viewerSquad.viewers.contains('viewer4'), true);
    });

    test('should handle status updates', () {
      final statusUpdatedSquad = testSquad.copyWith(
        statuses: {
          'user1': 'Ready',
          'user2': 'In Game',
          'user3': 'Away',
          'user4': 'Available',
        },
      );

      expect(statusUpdatedSquad.statuses['user1'], 'Ready');
      expect(statusUpdatedSquad.statuses['user2'], 'In Game');
      expect(statusUpdatedSquad.statuses['user3'], 'Away');
      expect(statusUpdatedSquad.statuses['user4'], 'Available');
    });
  });
}