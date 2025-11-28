import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/message.dart';

void main() {
  group('Message Entity', () {
    const testId = 'msg123';
    const testSenderId = 'user123';
    const testText = 'Hello World';
    final testTimestamp = DateTime.utc(2023, 12, 25, 10, 30);
    const testMessageType = MessageType.text;
    const testMediaUrl = 'https://example.com/image.jpg';
    const testMediaType = 'image/jpeg';
    const testReactions = {'👍': 2, '❤️': 1};
    const testReplyTo = 'reply123';
    const testVoiceNoteUrl = 'https://example.com/voice.mp3';
    const testVoiceNoteDuration = 30;
    const testAiResponse = 'AI response text';
    const testMetadata = {'key': 'value'};
    const testIsEdited = true;
    final testEditedAt = DateTime.utc(2023, 12, 25, 10, 35);
    const testIsDeleted = false;
    final testDeletedAt = DateTime.utc(2023, 12, 25, 11, 00);

    final testMessage = Message(
      id: testId,
      senderId: testSenderId,
      text: testText,
      timestamp: testTimestamp,
      messageType: testMessageType,
      mediaUrl: testMediaUrl,
      mediaType: testMediaType,
      reactions: testReactions,
      replyTo: testReplyTo,
      voiceNoteUrl: testVoiceNoteUrl,
      voiceNoteDuration: testVoiceNoteDuration,
      aiResponse: testAiResponse,
      metadata: testMetadata,
      isEdited: testIsEdited,
      editedAt: testEditedAt,
      isDeleted: testIsDeleted,
      deletedAt: testDeletedAt,
    );

    group('Constructor', () {
      test('should create Message with all required fields', () {
        expect(testMessage.id, testId);
        expect(testMessage.senderId, testSenderId);
        expect(testMessage.text, testText);
        expect(testMessage.timestamp, testTimestamp);
        expect(testMessage.messageType, testMessageType);
      });

      test('should create Message with optional fields', () {
        expect(testMessage.mediaUrl, testMediaUrl);
        expect(testMessage.mediaType, testMediaType);
        expect(testMessage.reactions, testReactions);
        expect(testMessage.replyTo, testReplyTo);
        expect(testMessage.voiceNoteUrl, testVoiceNoteUrl);
        expect(testMessage.voiceNoteDuration, testVoiceNoteDuration);
        expect(testMessage.aiResponse, testAiResponse);
        expect(testMessage.metadata, testMetadata);
        expect(testMessage.isEdited, testIsEdited);
        expect(testMessage.editedAt, testEditedAt);
        expect(testMessage.isDeleted, testIsDeleted);
        expect(testMessage.deletedAt, testDeletedAt);
      });
    });

    group('Factory create', () {
      test('should create Message with create factory', () {
        final createdMessage = Message.create(
          senderId: testSenderId,
          text: testText,
          messageType: testMessageType,
          mediaUrl: testMediaUrl,
          mediaType: testMediaType,
          replyTo: testReplyTo,
        );

        expect(createdMessage.senderId, testSenderId);
        expect(createdMessage.text, testText);
        expect(createdMessage.messageType, testMessageType);
        expect(createdMessage.mediaUrl, testMediaUrl);
        expect(createdMessage.mediaType, testMediaType);
        expect(createdMessage.replyTo, testReplyTo);
        expect(createdMessage.reactions, {});
        expect(createdMessage.isEdited, false);
        expect(createdMessage.isDeleted, false);
        expect(createdMessage.id, isNotEmpty);
        expect(createdMessage.timestamp, isNotNull);
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final json = testMessage.toJson();

        expect(json['id'], testId);
        expect(json['senderId'], testSenderId);
        expect(json['text'], testText);
        expect(json['timestamp'], testTimestamp.toIso8601String());
        expect(json['messageType'], testMessageType.name);
        expect(json['mediaUrl'], testMediaUrl);
        expect(json['mediaType'], testMediaType);
        expect(json['reactions'], testReactions);
        expect(json['replyTo'], testReplyTo);
        expect(json['voiceNoteUrl'], testVoiceNoteUrl);
        expect(json['voiceNoteDuration'], testVoiceNoteDuration);
        expect(json['aiResponse'], testAiResponse);
        expect(json['metadata'], testMetadata);
        expect(json['isEdited'], testIsEdited);
        expect(json['editedAt'], testEditedAt.toIso8601String());
        expect(json['isDeleted'], testIsDeleted);
        expect(json['deletedAt'], testDeletedAt.toIso8601String());
      });

      test('should deserialize from JSON correctly', () {
        final json = testMessage.toJson();
        final deserializedMessage = Message.fromJson(json);

        expect(deserializedMessage, equals(testMessage));
      });

      test('should handle null optional fields in JSON', () {
        final minimalMessage = Message(
          id: testId,
          senderId: testSenderId,
          text: testText,
          timestamp: testTimestamp,
          messageType: testMessageType,
        );

        final json = minimalMessage.toJson();
        final deserialized = Message.fromJson(json);

        expect(deserialized.id, testId);
        expect(deserialized.senderId, testSenderId);
        expect(deserialized.text, testText);
        expect(deserialized.timestamp, testTimestamp);
        expect(deserialized.messageType, testMessageType);
        expect(deserialized.mediaUrl, isNull);
        expect(deserialized.reactions, isNull);
        expect(deserialized.isEdited, isNull);
        expect(deserialized.isDeleted, isNull);
      });

      test('should handle null timestamp in JSON', () {
        final jsonWithNullTimestamp = {
          'id': testId,
          'senderId': testSenderId,
          'text': testText,
          'timestamp': null,
          'messageType': testMessageType.name,
        };

        final deserialized = Message.fromJson(jsonWithNullTimestamp);

        expect(deserialized.id, testId);
        expect(deserialized.senderId, testSenderId);
        expect(deserialized.text, testText);
        expect(deserialized.timestamp,
            isNotNull); // Should default to current time
        expect(deserialized.messageType, testMessageType);
      });

      test('should handle missing timestamp field in JSON', () {
        final jsonWithoutTimestamp = {
          'id': testId,
          'senderId': testSenderId,
          'text': testText,
          'messageType': testMessageType.name,
        };

        final deserialized = Message.fromJson(jsonWithoutTimestamp);

        expect(deserialized.id, testId);
        expect(deserialized.senderId, testSenderId);
        expect(deserialized.text, testText);
        expect(deserialized.timestamp,
            isNotNull); // Should default to current time
        expect(deserialized.messageType, testMessageType);
      });
    });

    group('Equality and Hash', () {
      test('should be equal when all fields are the same', () {
        final anotherMessage = Message(
          id: testId,
          senderId: testSenderId,
          text: testText,
          timestamp: testTimestamp,
          messageType: testMessageType,
          mediaUrl: testMediaUrl,
          mediaType: testMediaType,
          reactions: testReactions,
          replyTo: testReplyTo,
          voiceNoteUrl: testVoiceNoteUrl,
          voiceNoteDuration: testVoiceNoteDuration,
          aiResponse: testAiResponse,
          metadata: testMetadata,
          isEdited: testIsEdited,
          editedAt: testEditedAt,
          isDeleted: testIsDeleted,
          deletedAt: testDeletedAt,
        );

        expect(testMessage, equals(anotherMessage));
        expect(testMessage.hashCode, equals(anotherMessage.hashCode));
      });

      test('should not be equal when id differs', () {
        final differentMessage = testMessage.copyWith(id: 'different');

        expect(testMessage, isNot(equals(differentMessage)));
      });

      test('should not be equal when timestamp differs', () {
        final differentMessage =
            testMessage.copyWith(timestamp: DateTime(2023, 12, 26));

        expect(testMessage, isNot(equals(differentMessage)));
      });
    });

    group('CopyWith', () {
      test('should create copy with modified text', () {
        final copiedMessage = testMessage.copyWith(text: 'New text');

        expect(copiedMessage.text, 'New text');
        expect(copiedMessage.id, testId); // unchanged
        expect(copiedMessage.senderId, testSenderId); // unchanged
      });

      test('should create copy with modified reactions', () {
        final newReactions = {'😂': 3};
        final copiedMessage = testMessage.copyWith(reactions: newReactions);

        expect(copiedMessage.reactions, newReactions);
        expect(copiedMessage.text, testText); // unchanged
      });

      test('should create copy with null values', () {
        final copiedMessage = testMessage.copyWith(
          mediaUrl: null,
          reactions: null,
          isEdited: null,
        );

        expect(copiedMessage.mediaUrl, isNull);
        expect(copiedMessage.reactions, isNull);
        expect(copiedMessage.isEdited, isNull);
        expect(copiedMessage.text, testText); // unchanged
      });
    });

    group('MessageType Enum', () {
      test('should have all expected message types', () {
        expect(MessageType.text, equals(MessageType.text));
        expect(MessageType.image, equals(MessageType.image));
        expect(MessageType.video, equals(MessageType.video));
        expect(MessageType.audio, equals(MessageType.audio));
        expect(MessageType.voiceNote, equals(MessageType.voiceNote));
        expect(MessageType.file, equals(MessageType.file));
        expect(MessageType.poll, equals(MessageType.poll));
        expect(MessageType.aiResponse, equals(MessageType.aiResponse));
        expect(MessageType.system, equals(MessageType.system));
      });
    });

    group('Poll Entity', () {
      const testPollId = 'poll123';
      const testQuestion = 'What is your favorite color?';
      const testOptions = ['Red', 'Blue', 'Green'];
      final testVotes = {
        'Red': ['user1', 'user2'],
        'Blue': ['user3']
      };
      final testCreatedAt = DateTime.utc(2023, 12, 25, 10, 30);
      const testCreatedBy = 'user123';
      const testIsClosed = false;
      final testClosedAt = DateTime.utc(2023, 12, 25, 11, 00);

      final testPoll = Poll(
        id: testPollId,
        question: testQuestion,
        options: testOptions,
        votes: testVotes,
        createdAt: testCreatedAt,
        createdBy: testCreatedBy,
        isClosed: testIsClosed,
        closedAt: testClosedAt,
      );

      test('should create Poll with all fields', () {
        expect(testPoll.id, testPollId);
        expect(testPoll.question, testQuestion);
        expect(testPoll.options, testOptions);
        expect(testPoll.votes, testVotes);
        expect(testPoll.createdAt, testCreatedAt);
        expect(testPoll.createdBy, testCreatedBy);
        expect(testPoll.isClosed, testIsClosed);
        expect(testPoll.closedAt, testClosedAt);
      });

      test('should serialize Poll to JSON', () {
        final json = testPoll.toJson();

        expect(json['id'], testPollId);
        expect(json['question'], testQuestion);
        expect(json['options'], testOptions);
        expect(json['votes'], testVotes);
        expect(json['createdAt'], testCreatedAt.toIso8601String());
        expect(json['createdBy'], testCreatedBy);
        expect(json['isClosed'], testIsClosed);
        expect(json['closedAt'], testClosedAt.toIso8601String());
      });

      test('should deserialize Poll from JSON', () {
        final json = testPoll.toJson();
        final deserializedPoll = Poll.fromJson(json);

        expect(deserializedPoll, equals(testPoll));
      });

      test('should handle null optional fields in Poll JSON', () {
        final minimalPoll = Poll(
          id: testPollId,
          question: testQuestion,
          options: testOptions,
          votes: {},
          createdAt: testCreatedAt,
          createdBy: testCreatedBy,
        );

        final json = minimalPoll.toJson();
        final deserialized = Poll.fromJson(json);

        expect(deserialized.isClosed, isNull);
        expect(deserialized.closedAt, isNull);
      });
    });

    group('Edge Cases', () {
      test('should handle empty text', () {
        final message = Message(
          id: testId,
          senderId: testSenderId,
          text: '',
          timestamp: testTimestamp,
          messageType: MessageType.text,
        );

        expect(message.text, '');
      });

      test('should handle empty reactions map', () {
        final message = testMessage.copyWith(reactions: {});

        expect(message.reactions, isEmpty);
      });

      test('should handle null metadata', () {
        final message = testMessage.copyWith(metadata: null);

        expect(message.metadata, isNull);
      });

      test('should handle voice note without duration', () {
        final message = Message(
          id: testId,
          senderId: testSenderId,
          text: '',
          timestamp: testTimestamp,
          messageType: MessageType.voiceNote,
          voiceNoteUrl: testVoiceNoteUrl,
          voiceNoteDuration: null,
        );

        expect(message.voiceNoteUrl, testVoiceNoteUrl);
        expect(message.voiceNoteDuration, isNull);
      });
    });
  });
}
