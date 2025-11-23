import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/usecases/send_message.dart';

import '../../helpers/manual_mock_chat.dart';

void main() {
  late SendMessage usecase;
  late ManualMockChatRepository mockRepository;

  setUp(() {
    mockRepository = ManualMockChatRepository();
    usecase = SendMessage(mockRepository);
  });

  tearDown(() {
    reset(mockRepository);
    mockRepository.shouldThrowException = false;
    mockRepository.exceptionToThrow = null;
  });

  const testChatGroupId = 'group123';
  const testText = 'Hello World';
  const testMessageType = MessageType.text;
  const testMediaUrl = 'https://example.com/image.jpg';
  const testMediaType = 'image/jpeg';
  const testReplyTo = 'reply123';
  final testPoll = Poll(
    id: 'poll123',
    question: 'What is your favorite color?',
    options: ['Red', 'Blue', 'Green'],
    votes: {},
    createdAt: DateTime(2023, 12, 25, 10, 30),
    createdBy: 'user123',
  );
  const testVoiceNoteUrl = 'https://example.com/voice.mp3';
  const testVoiceNoteDuration = 30;

  group('SendMessage Usecase', () {
    group('Happy Path', () {
      test('should send text message successfully', () async {
        // Act
        final result =
            await usecase(testChatGroupId, testText, testMessageType);

        // Assert
        expect(mockRepository.calledMethods.contains('sendMessage'), isTrue);
        expect(mockRepository.methodArgs['sendMessage']['chatGroupId'],
            testChatGroupId);
        expect(mockRepository.methodArgs['sendMessage']['text'], testText);
        expect(mockRepository.methodArgs['sendMessage']['messageType'],
            testMessageType);
        expect(result.id, 'mock_msg_id');
        expect(result.senderId, 'mock_sender');
        expect(result.text, testText);
        expect(result.messageType, testMessageType);
      });

      test('should send media message successfully', () async {
        // Act
        final result = await usecase(
            testChatGroupId, testText, MessageType.image,
            mediaUrl: testMediaUrl, mediaType: testMediaType);

        // Assert
        expect(mockRepository.calledMethods.contains('sendMessage'), isTrue);
        expect(mockRepository.methodArgs['sendMessage']['chatGroupId'],
            testChatGroupId);
        expect(mockRepository.methodArgs['sendMessage']['text'], testText);
        expect(mockRepository.methodArgs['sendMessage']['messageType'],
            MessageType.image);
        expect(
            mockRepository.methodArgs['sendMessage']['mediaUrl'], testMediaUrl);
        expect(mockRepository.methodArgs['sendMessage']['mediaType'],
            testMediaType);
        expect(result.mediaUrl, testMediaUrl);
        expect(result.mediaType, testMediaType);
      });

      test('should send reply message successfully', () async {
        // Act
        final result = await usecase(testChatGroupId, testText, testMessageType,
            replyTo: testReplyTo);

        // Assert
        expect(mockRepository.calledMethods.contains('sendMessage'), isTrue);
        expect(mockRepository.methodArgs['sendMessage']['chatGroupId'],
            testChatGroupId);
        expect(mockRepository.methodArgs['sendMessage']['text'], testText);
        expect(mockRepository.methodArgs['sendMessage']['messageType'],
            testMessageType);
        expect(
            mockRepository.methodArgs['sendMessage']['replyTo'], testReplyTo);
        expect(result.replyTo, testReplyTo);
      });

      test('should send poll message successfully', () async {
        // Act
        final result = await usecase(testChatGroupId, '', MessageType.poll,
            poll: testPoll);

        // Assert
        expect(mockRepository.calledMethods.contains('sendMessage'), isTrue);
        expect(mockRepository.methodArgs['sendMessage']['chatGroupId'],
            testChatGroupId);
        expect(mockRepository.methodArgs['sendMessage']['text'], '');
        expect(mockRepository.methodArgs['sendMessage']['messageType'],
            MessageType.poll);
        expect(mockRepository.methodArgs['sendMessage']['poll'], testPoll);
        expect(result.messageType, MessageType.poll);
      });

      test('should send voice note message successfully', () async {
        // Act
        final result = await usecase(testChatGroupId, '', MessageType.voiceNote,
            voiceNoteUrl: testVoiceNoteUrl,
            voiceNoteDuration: testVoiceNoteDuration);

        // Assert
        expect(mockRepository.calledMethods.contains('sendMessage'), isTrue);
        expect(mockRepository.methodArgs['sendMessage']['chatGroupId'],
            testChatGroupId);
        expect(mockRepository.methodArgs['sendMessage']['text'], '');
        expect(mockRepository.methodArgs['sendMessage']['messageType'],
            MessageType.voiceNote);
        expect(mockRepository.methodArgs['sendMessage']['voiceNoteUrl'],
            testVoiceNoteUrl);
        expect(mockRepository.methodArgs['sendMessage']['voiceNoteDuration'],
            testVoiceNoteDuration);
        expect(result.messageType, MessageType.voiceNote);
      });

      test('should send complex message with all parameters', () async {
        // Act
        final result = await usecase(
            testChatGroupId, testText, MessageType.image,
            mediaUrl: testMediaUrl,
            mediaType: testMediaType,
            replyTo: testReplyTo);

        // Assert
        expect(mockRepository.calledMethods.contains('sendMessage'), isTrue);
        expect(mockRepository.methodArgs['sendMessage']['chatGroupId'],
            testChatGroupId);
        expect(mockRepository.methodArgs['sendMessage']['text'], testText);
        expect(mockRepository.methodArgs['sendMessage']['messageType'],
            MessageType.image);
        expect(
            mockRepository.methodArgs['sendMessage']['mediaUrl'], testMediaUrl);
        expect(mockRepository.methodArgs['sendMessage']['mediaType'],
            testMediaType);
        expect(
            mockRepository.methodArgs['sendMessage']['replyTo'], testReplyTo);
        expect(result.mediaUrl, testMediaUrl);
        expect(result.mediaType, testMediaType);
        expect(result.replyTo, testReplyTo);
      });
    });

    group('Error Cases', () {
      test('should throw exception when repository throws', () async {
        // Arrange
        final exception = Exception('Failed to send message');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase(testChatGroupId, testText, testMessageType),
          throwsA(exception),
        );
        expect(mockRepository.calledMethods.contains('sendMessage'), isTrue);
      });

      test('should throw exception for network error', () async {
        // Arrange
        final exception = Exception('Network error');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase(testChatGroupId, testText, testMessageType),
          throwsA(exception),
        );
      });

      test('should throw exception for invalid chat group', () async {
        // Arrange
        final exception = Exception('Invalid chat group');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase('invalid_group', testText, testMessageType),
          throwsA(exception),
        );
      });

      test('should throw exception for empty text', () async {
        // Arrange
        final exception = Exception('Empty text not allowed');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase(testChatGroupId, '', testMessageType),
          throwsA(exception),
        );
      });
    });

    group('Edge Cases', () {
      test('should handle very long text', () async {
        // Arrange
        final longText = 'A' * 10000;

        // Act
        final result =
            await usecase(testChatGroupId, longText, testMessageType);

        // Assert
        expect(mockRepository.calledMethods.contains('sendMessage'), isTrue);
        expect(mockRepository.methodArgs['sendMessage']['text'], longText);
        expect(result.text, longText);
      });

      test('should handle special characters in text', () async {
        // Arrange
        final specialText = 'Hello 🌍 with émojis and spëcial chärs!';

        // Act
        final result =
            await usecase(testChatGroupId, specialText, testMessageType);

        // Assert
        expect(mockRepository.calledMethods.contains('sendMessage'), isTrue);
        expect(mockRepository.methodArgs['sendMessage']['text'], specialText);
        expect(result.text, specialText);
      });

      test('should handle null optional parameters', () async {
        // Act
        await usecase(testChatGroupId, testText, testMessageType);

        // Assert
        expect(mockRepository.calledMethods.contains('sendMessage'), isTrue);
        expect(mockRepository.methodArgs['sendMessage']['mediaUrl'], isNull);
        expect(mockRepository.methodArgs['sendMessage']['mediaType'], isNull);
        expect(mockRepository.methodArgs['sendMessage']['replyTo'], isNull);
        expect(mockRepository.methodArgs['sendMessage']['poll'], isNull);
        expect(
            mockRepository.methodArgs['sendMessage']['voiceNoteUrl'], isNull);
        expect(mockRepository.methodArgs['sendMessage']['voiceNoteDuration'],
            isNull);
      });
    });

    group('SquadSync Specific Features', () {
      test('should handle game-specific chat groups', () async {
        // Arrange
        const gameChatGroupId = 'game_cod_chat';

        // Act
        await usecase(gameChatGroupId, 'Let\'s coordinate!', testMessageType);

        // Assert
        expect(mockRepository.calledMethods.contains('sendMessage'), isTrue);
        expect(mockRepository.methodArgs['sendMessage']['chatGroupId'],
            gameChatGroupId);
        expect(mockRepository.methodArgs['sendMessage']['text'],
            'Let\'s coordinate!');
      });

      test('should handle squad coordination messages', () async {
        // Act
        await usecase(testChatGroupId, 'Squad up at 8 PM!', testMessageType);

        // Assert
        expect(mockRepository.calledMethods.contains('sendMessage'), isTrue);
        expect(mockRepository.methodArgs['sendMessage']['text'],
            'Squad up at 8 PM!');
      });

      test('should handle media sharing for game strategies', () async {
        // Act
        await usecase(
            testChatGroupId, 'Check this strategy:', MessageType.image,
            mediaUrl: 'https://example.com/strategy.jpg',
            mediaType: 'image/jpeg');

        // Assert
        expect(mockRepository.calledMethods.contains('sendMessage'), isTrue);
        expect(mockRepository.methodArgs['sendMessage']['messageType'],
            MessageType.image);
        expect(mockRepository.methodArgs['sendMessage']['mediaUrl'],
            'https://example.com/strategy.jpg');
      });
    });
  });
}
