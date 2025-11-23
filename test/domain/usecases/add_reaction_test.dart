import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/usecases/add_reaction.dart';

import '../../helpers/manual_mock_chat.dart';

void main() {
  late AddReaction usecase;
  late ManualMockChatRepository mockRepository;

  setUp(() {
    mockRepository = ManualMockChatRepository();
    usecase = AddReaction(mockRepository);
  });

  tearDown(() {
    reset(mockRepository);
    mockRepository.shouldThrowException = false;
    mockRepository.exceptionToThrow = null;
  });

  const testChatGroupId = 'group123';
  const testMessageId = 'msg123';
  const testReaction = '👍';

  group('AddReaction Usecase', () {
    group('Happy Path', () {
      test('should add reaction successfully', () async {
        // Act
        await usecase(testChatGroupId, testMessageId, testReaction);

        // Assert
        expect(mockRepository.calledMethods.contains('addReaction'), isTrue);
        expect(mockRepository.methodArgs['addReaction']['chatGroupId'],
            testChatGroupId);
        expect(mockRepository.methodArgs['addReaction']['messageId'],
            testMessageId);
        expect(
            mockRepository.methodArgs['addReaction']['reaction'], testReaction);
      });
    });

    group('Error Path', () {
      test('should throw exception when repository fails', () async {
        // Arrange
        final exception = Exception('Failed to add reaction');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase(testChatGroupId, testMessageId, testReaction),
          throwsA(exception),
        );
        expect(mockRepository.calledMethods.contains('addReaction'), isTrue);
      });
    });

    group('Edge Cases', () {
      test('should handle empty reaction', () async {
        // Act
        await usecase(testChatGroupId, testMessageId, '');

        // Assert
        expect(mockRepository.calledMethods.contains('addReaction'), isTrue);
        expect(mockRepository.methodArgs['addReaction']['reaction'], '');
      });

      test('should handle special characters in reaction', () async {
        // Act
        await usecase(testChatGroupId, testMessageId, '🚀');

        // Assert
        expect(mockRepository.calledMethods.contains('addReaction'), isTrue);
        expect(mockRepository.methodArgs['addReaction']['reaction'], '🚀');
      });
    });
  });
}
