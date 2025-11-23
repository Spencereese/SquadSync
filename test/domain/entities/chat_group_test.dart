import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/chat_group.dart';

void main() {
  group('ChatGroup Entity', () {
    const testId = 'group123';
    const testName = 'Squad Chat';
    const testMemberUids = ['user123', 'user456', 'user789'];
    const testIsPublic = true;
    const testMemberCount = 3;
    const testCreatedBy = 'user123';
    final testCreatedAt = DateTime(2023, 12, 25, 10, 30);
    const testDescription = 'Main squad communication';
    const testAvatarUrl = 'https://example.com/avatar.jpg';
    const testMetadata = {'theme': 'dark', 'notifications': true};
    const testAdmins = ['user123', 'user456'];
    const testModerators = ['user456'];
    const testIsActive = true;
    final testLastActivity = DateTime(2023, 12, 26, 15, 45);
    const testSettings = {'allowInvites': true, 'maxMembers': 50};

    final testChatGroup = ChatGroup(
      id: testId,
      name: testName,
      memberUids: testMemberUids,
      isPublic: testIsPublic,
      memberCount: testMemberCount,
      createdBy: testCreatedBy,
      createdAt: testCreatedAt,
      description: testDescription,
      avatarUrl: testAvatarUrl,
      metadata: testMetadata,
      admins: testAdmins,
      moderators: testModerators,
      isActive: testIsActive,
      lastActivity: testLastActivity,
      settings: testSettings,
    );

    group('Constructor', () {
      test('should create ChatGroup with all required fields', () {
        expect(testChatGroup.id, testId);
        expect(testChatGroup.name, testName);
        expect(testChatGroup.memberUids, testMemberUids);
        expect(testChatGroup.isPublic, testIsPublic);
        expect(testChatGroup.memberCount, testMemberCount);
        expect(testChatGroup.createdBy, testCreatedBy);
        expect(testChatGroup.createdAt, testCreatedAt);
      });

      test('should create ChatGroup with optional fields', () {
        expect(testChatGroup.description, testDescription);
        expect(testChatGroup.avatarUrl, testAvatarUrl);
        expect(testChatGroup.metadata, testMetadata);
        expect(testChatGroup.admins, testAdmins);
        expect(testChatGroup.moderators, testModerators);
        expect(testChatGroup.isActive, testIsActive);
        expect(testChatGroup.lastActivity, testLastActivity);
        expect(testChatGroup.settings, testSettings);
      });
    });

    group('Factory create', () {
      test('should create ChatGroup with create factory', () {
        final createdGroup = ChatGroup.create(
          name: testName,
          createdBy: testCreatedBy,
          isPublic: testIsPublic,
          description: testDescription,
          metadata: testMetadata,
        );

        expect(createdGroup.name, testName);
        expect(createdGroup.createdBy, testCreatedBy);
        expect(createdGroup.isPublic, testIsPublic);
        expect(createdGroup.description, testDescription);
        expect(createdGroup.metadata, testMetadata);
        expect(createdGroup.memberUids, [testCreatedBy]);
        expect(createdGroup.memberCount, 1);
        expect(createdGroup.admins, [testCreatedBy]);
        expect(createdGroup.moderators, []);
        expect(createdGroup.isActive, true);
        expect(createdGroup.id, isNotEmpty);
        expect(createdGroup.createdAt, isNotNull);
        expect(createdGroup.lastActivity, isNotNull);
        expect(createdGroup.settings, {});
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final json = testChatGroup.toJson();

        expect(json['id'], testId);
        expect(json['name'], testName);
        expect(json['memberUids'], testMemberUids);
        expect(json['isPublic'], testIsPublic);
        expect(json['memberCount'], testMemberCount);
        expect(json['createdBy'], testCreatedBy);
        expect(json['createdAt'], testCreatedAt.toIso8601String());
        expect(json['description'], testDescription);
        expect(json['avatarUrl'], testAvatarUrl);
        expect(json['metadata'], testMetadata);
        expect(json['admins'], testAdmins);
        expect(json['moderators'], testModerators);
        expect(json['isActive'], testIsActive);
        expect(json['lastActivity'], testLastActivity.toIso8601String());
        expect(json['settings'], testSettings);
      });

      test('should deserialize from JSON correctly', () {
        final json = testChatGroup.toJson();
        final deserializedGroup = ChatGroup.fromJson(json);

        expect(deserializedGroup, equals(testChatGroup));
      });

      test('should handle null optional fields in JSON', () {
        final minimalGroup = ChatGroup(
          id: testId,
          name: testName,
          memberUids: testMemberUids,
          isPublic: testIsPublic,
          memberCount: testMemberCount,
          createdBy: testCreatedBy,
          createdAt: testCreatedAt,
        );

        final json = minimalGroup.toJson();
        final deserialized = ChatGroup.fromJson(json);

        expect(deserialized.id, testId);
        expect(deserialized.name, testName);
        expect(deserialized.description, isNull);
        expect(deserialized.avatarUrl, isNull);
        expect(deserialized.metadata, isNull);
        expect(deserialized.admins, isNull);
        expect(deserialized.moderators, isNull);
        expect(deserialized.isActive, isNull);
        expect(deserialized.lastActivity, isNull);
        expect(deserialized.settings, isNull);
      });
    });

    group('Equality and Hash', () {
      test('should be equal when all fields are the same', () {
        final anotherGroup = ChatGroup(
          id: testId,
          name: testName,
          memberUids: testMemberUids,
          isPublic: testIsPublic,
          memberCount: testMemberCount,
          createdBy: testCreatedBy,
          createdAt: testCreatedAt,
          description: testDescription,
          avatarUrl: testAvatarUrl,
          metadata: testMetadata,
          admins: testAdmins,
          moderators: testModerators,
          isActive: testIsActive,
          lastActivity: testLastActivity,
          settings: testSettings,
        );

        expect(testChatGroup, equals(anotherGroup));
        expect(testChatGroup.hashCode, equals(anotherGroup.hashCode));
      });

      test('should not be equal when id differs', () {
        final differentGroup = testChatGroup.copyWith(id: 'different');

        expect(testChatGroup, isNot(equals(differentGroup)));
      });

      test('should not be equal when name differs', () {
        final differentGroup = testChatGroup.copyWith(name: 'Different Name');

        expect(testChatGroup, isNot(equals(differentGroup)));
      });
    });

    group('CopyWith', () {
      test('should create copy with modified name', () {
        final copiedGroup = testChatGroup.copyWith(name: 'New Name');

        expect(copiedGroup.name, 'New Name');
        expect(copiedGroup.id, testId); // unchanged
        expect(copiedGroup.createdBy, testCreatedBy); // unchanged
      });

      test('should create copy with modified memberUids', () {
        final newMemberUids = ['user123', 'user456', 'user789', 'user101'];
        final copiedGroup = testChatGroup.copyWith(memberUids: newMemberUids);

        expect(copiedGroup.memberUids, newMemberUids);
        expect(copiedGroup.name, testName); // unchanged
      });

      test('should create copy with null values', () {
        final copiedGroup = testChatGroup.copyWith(
          description: null,
          metadata: null,
          avatarUrl: null,
        );

        expect(copiedGroup.description, isNull);
        expect(copiedGroup.metadata, isNull);
        expect(copiedGroup.avatarUrl, isNull);
        expect(copiedGroup.name, testName); // unchanged
      });
    });

    group('Computed Properties', () {
      test('should return correct member count', () {
        expect(testChatGroup.memberCount, testMemberCount);
      });

      test('should check if user is admin', () {
        expect(testChatGroup.admins?.contains(testCreatedBy), true);
        expect(testChatGroup.admins?.contains('user999'), false);
      });

      test('should check if user is member', () {
        expect(testChatGroup.memberUids.contains(testCreatedBy), true);
        expect(testChatGroup.memberUids.contains('user999'), false);
      });

      test('should check if user is moderator', () {
        expect(testChatGroup.moderators?.contains('user456'), true);
        expect(testChatGroup.moderators?.contains('user999'), false);
      });

      test('should check if group is active', () {
        expect(testChatGroup.isActive, testIsActive);
      });
    });

    group('Edge Cases', () {
      test('should handle empty description', () {
        final group = testChatGroup.copyWith(description: '');

        expect(group.description, '');
      });

      test('should handle empty metadata', () {
        final group = testChatGroup.copyWith(metadata: {});

        expect(group.metadata, isEmpty);
      });

      test('should handle empty admins list', () {
        final group = testChatGroup.copyWith(admins: []);

        expect(group.admins, isEmpty);
      });

      test('should handle empty moderators list', () {
        final group = testChatGroup.copyWith(moderators: []);

        expect(group.moderators, isEmpty);
      });

      test('should handle null optional fields', () {
        final minimalGroup = ChatGroup(
          id: testId,
          name: testName,
          memberUids: [testCreatedBy],
          isPublic: testIsPublic,
          memberCount: 1,
          createdBy: testCreatedBy,
          createdAt: testCreatedAt,
        );

        expect(minimalGroup.description, isNull);
        expect(minimalGroup.avatarUrl, isNull);
        expect(minimalGroup.metadata, isNull);
        expect(minimalGroup.admins, isNull);
        expect(minimalGroup.moderators, isNull);
        expect(minimalGroup.isActive, isNull);
        expect(minimalGroup.lastActivity, isNull);
        expect(minimalGroup.settings, isNull);
      });
    });
  });
}
