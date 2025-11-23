import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/usecases/pin_message.dart';

import '../../helpers/manual_mock_chat.dart';

void main() {
  late PinMessage usecase;
  late ManualMockChatRepository mockRepository;

  setUp(() {
    mockRepository = ManualMockChatRepository();
    usecase = PinMessage(mockRepository);
  });

  tearDown(() {
    reset(mockRepository);
    mockRepository.shouldThrowException = false;
    mockRepository.exceptionToThrow = null;
  });

  const testChatGroupId = 'group123';
  const testMessageId = 'msg123';

  group('PinMessage Usecase', () {
    group('Happy Path', () {
      test('should pin message successfully', () async {
        // Act
        await usecase(testChatGroupId, testMessageId);

        // Assert
        expect(mockRepository.calledMethods.contains('pinMessage'), isTrue);
        expect(mockRepository.methodArgs['pinMessage']['chatGroupId'],
            testChatGroupId);
        expect(mockRepository.methodArgs['pinMessage']['messageId'],
            testMessageId);
      });
    });

    group('Error Path', () {
      test('should throw exception when repository fails', () async {
        // Arrange
        final exception = Exception('Failed to pin message');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase(testChatGroupId, testMessageId),
          throwsA(exception),
        );
        expect(mockRepository.calledMethods.contains('pinMessage'), isTrue);
      });

      test('should throw exception when message not found', () async {
        // Arrange
        final exception = Exception('Message not found');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase(testChatGroupId, 'nonexistent_msg'),
          throwsA(exception),
        );
        expect(mockRepository.calledMethods.contains('pinMessage'), isTrue);
        expect(mockRepository.methodArgs['pinMessage']['messageId'],
            'nonexistent_msg');
      });
    });

    group('Edge Cases', () {
      test('should handle pinning already pinned message', () async {
        // Act
        await usecase(testChatGroupId, 'already_pinned');

        // Assert
        expect(mockRepository.calledMethods.contains('pinMessage'), isTrue);
        expect(mockRepository.methodArgs['pinMessage']['messageId'],
            'already_pinned');
      });

      test('should handle pinning own message', () async {
        // Act
        await usecase(testChatGroupId, 'own_message');

        // Assert
        expect(mockRepository.calledMethods.contains('pinMessage'), isTrue);
        expect(mockRepository.methodArgs['pinMessage']['messageId'],
            'own_message');
      });
    });
  });
}
