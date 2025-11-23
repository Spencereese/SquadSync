import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/app_user.dart';

void main() {
  group('AppUser Entity Tests', () {
    const testUid = 'test-uid-123';
    const testDisplayName = 'Test User';
    const testProfileImage = 'https://example.com/image.jpg';

    final testAppUser = AppUser(
      uid: testUid,
      displayName: testDisplayName,
      profileImage: testProfileImage,
      preferredModes: {'game1': 'ranked'},
      userBlocks: {'game1': {'user1': true}},
      pinnedGames: [{'id': 'game1', 'name': 'Game One'}],
      mutedGames: {'game2'},
      hasRatedGame: {'game1': true},
      dailyRatings: {'game1': {'rating': 5}},
      allTimeRatings: {'game1': {'rating': 4}},
      currentStreaks: {'game1': 3},
      complaints: {'game1': {'user1': 2}},
      bans: {'game1': [{'reason': 'spam'}]},
      dailyBanVotes: {'game1': {'user1': true}},
      blockedUsers: ['user2'],
    );

    test('should create AppUser with required fields', () {
      expect(testAppUser.uid, testUid);
      expect(testAppUser.displayName, testDisplayName);
      expect(testAppUser.profileImage, testProfileImage);
    });

    test('should create empty AppUser', () {
      final emptyUser = AppUser.empty();
      expect(emptyUser.uid, '');
      expect(emptyUser.displayName, null);
      expect(emptyUser.pinnedGames, []);
      expect(emptyUser.blockedUsers, []);
    });

    test('should support equality', () {
      final user1 = testAppUser;
      final user2 = testAppUser.copyWith();
      expect(user1, user2);
    });

    test('should support copyWith', () {
      final updatedUser = testAppUser.copyWith(displayName: 'Updated Name');
      expect(updatedUser.displayName, 'Updated Name');
      expect(updatedUser.uid, testUid); // unchanged
    });

    test('should have correct hashCode', () {
      final user1 = testAppUser;
      final user2 = testAppUser.copyWith();
      expect(user1.hashCode, user2.hashCode);
    });

    test('should serialize to JSON', () {
      final json = testAppUser.toJson();
      expect(json['uid'], testUid);
      expect(json['displayName'], testDisplayName);
      expect(json['profileImage'], testProfileImage);
      expect(json['pinnedGames'], isA<List>());
      expect(json['blockedUsers'], isA<List>());
    });

    test('should deserialize from JSON', () {
      final json = testAppUser.toJson();
      final deserializedUser = AppUser.fromJson(json);
      expect(deserializedUser, testAppUser);
    });

    test('should handle complex nested structures', () {
      expect(testAppUser.preferredModes['game1'], 'ranked');
      expect(testAppUser.userBlocks['game1']!['user1'], true);
      expect(testAppUser.pinnedGames.first['id'], 'game1');
      expect(testAppUser.mutedGames.contains('game2'), true);
      expect(testAppUser.hasRatedGame['game1'], true);
      expect(testAppUser.dailyRatings['game1']!['rating'], 5);
      expect(testAppUser.allTimeRatings['game1']!['rating'], 4);
      expect(testAppUser.currentStreaks['game1'], 3);
      expect(testAppUser.complaints['game1']!['user1'], 2);
      expect(testAppUser.bans['game1']!.first['reason'], 'spam');
      expect(testAppUser.dailyBanVotes['game1']!['user1'], true);
      expect(testAppUser.blockedUsers.contains('user2'), true);
    });

    test('should handle null values correctly', () {
      final userWithNulls = AppUser.empty().copyWith(
        displayName: null,
        profileImage: null,
      );
      expect(userWithNulls.displayName, null);
      expect(userWithNulls.profileImage, null);
    });
  });
}