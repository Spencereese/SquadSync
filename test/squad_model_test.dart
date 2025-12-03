import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cod_squad_app/models/squad.dart';

void main() {
  group('Squad Model Tests', () {
    test('Squad can be created with all required fields', () {
      final squad = Squad(
        id: 'test-id',
        name: 'Test Squad',
        primaryGameName: 'Call of Duty',
        primaryGameId: 'cod-123',
        maxSpots: 4,
        creatorUid: 'user123',
        createdAt: Timestamp.now(),
        isPublic: true,
        memberUids: ['user123'],
        lastActivity: Timestamp.now(),
        spotClaims: {'1': null, '2': null, '3': null, '4': null},
        peacockTimers: {},
        userStatuses: {},
        tags: ['fps', 'competitive'],
        lookingForMore: true,
        description: 'Looking for skilled players',
      );

      expect(squad.id, 'test-id');
      expect(squad.name, 'Test Squad');
      expect(squad.primaryGameName, 'Call of Duty');
      expect(squad.tags, ['fps', 'competitive']);
      expect(squad.lookingForMore, true);
      expect(squad.description, 'Looking for skilled players');
    });

    test('Squad.toJson and fromJson work correctly', () {
      final originalSquad = Squad(
        id: 'test-id',
        name: 'Test Squad',
        primaryGameName: 'Warzone',
        maxSpots: 3,
        creatorUid: 'creator123',
        createdAt: Timestamp.now(),
        isPublic: false,
        memberUids: ['creator123', 'user456'],
        lastActivity: Timestamp.now(),
        spotClaims: {'1': 'creator123', '2': 'user456', '3': null},
        peacockTimers: {},
        userStatuses: {},
        tags: ['battle-royale'],
        lookingForMore: true,
        description: 'Warzone squad',
      );

      final json = originalSquad.toJson();
      final reconstructedSquad = Squad.fromJson(json);

      expect(reconstructedSquad.name, originalSquad.name);
      expect(reconstructedSquad.primaryGameName, originalSquad.primaryGameName);
      expect(reconstructedSquad.tags, originalSquad.tags);
      expect(reconstructedSquad.lookingForMore, originalSquad.lookingForMore);
      expect(reconstructedSquad.description, originalSquad.description);
      expect(reconstructedSquad.spotClaims, originalSquad.spotClaims);
    });

    test('Squad with nullable fields works correctly', () {
      final squad = Squad(
        id: 'test-id',
        name: 'Minimal Squad',
        creatorUid: 'user123',
        createdAt: Timestamp.now(),
        isPublic: false,
        memberUids: ['user123'],
        lastActivity: Timestamp.now(),
        spotClaims: {},
        peacockTimers: {},
        userStatuses: {},
        tags: [],
        lookingForMore: false,
        description: '',
        primaryGameName: null,
        primaryGameId: null,
        maxSpots: null,
        inviteCode: null,
        bumpTimestamp: null,
      );

      expect(squad.primaryGameName, null);
      expect(squad.primaryGameId, null);
      expect(squad.bumpTimestamp, null);
    });
  });
}
