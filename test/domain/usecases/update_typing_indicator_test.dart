import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/usecases/update_typing_indicator.dart';

import '../../helpers/manual_mock_chat.dart';

void main() {
  late UpdateTypingIndicator usecase;
  late ManualMockChatRepository mockRepository;

  setUp(() {
    mockRepository = ManualMockChatRepository();
    usecase = UpdateTypingIndicator(mockRepository);
  });

  tearDown(() {
    reset(mockRepository);
    mockRepository.shouldThrowException = false;
    mockRepository.exceptionToThrow = null;
  });

  const testChatGroupId = 'group123';

  group('UpdateTypingIndicator Usecase', () {
    group('Happy Path', () {
      test('should update typing indicator to true successfully', () async {
        // Act
        await usecase(testChatGroupId, true);

        // Assert
        expect(mockRepository.calledMethods.contains('updateTypingIndicator'),
            isTrue);
        expect(
            mockRepository.methodArgs['updateTypingIndicator']['chatGroupId'],
            testChatGroupId);
        expect(mockRepository.methodArgs['updateTypingIndicator']['isTyping'],
            isTrue);
      });

      test('should update typing indicator to false successfully', () async {
        // Act
        await usecase(testChatGroupId, false);

        // Assert
        expect(mockRepository.calledMethods.contains('updateTypingIndicator'),
            isTrue);
        expect(
            mockRepository.methodArgs['updateTypingIndicator']['chatGroupId'],
            testChatGroupId);
        expect(mockRepository.methodArgs['updateTypingIndicator']['isTyping'],
            isFalse);
      });
    });

    group('Error Path', () {
      test('should throw exception when repository fails', () async {
        // Arrange
        final exception = Exception('Failed to update typing indicator');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase(testChatGroupId, true),
          throwsA(exception),
        );
        expect(mockRepository.calledMethods.contains('updateTypingIndicator'),
            isTrue);
      });
    });

    group('Edge Cases', () {
      test('should handle rapid typing indicator changes', () async {
        // Act - Simulate rapid changes
        await usecase(testChatGroupId, true);
        await usecase(testChatGroupId, false);
        await usecase(testChatGroupId, true);

        // Assert
        expect(
            mockRepository.calledMethods
                .where((method) => method == 'updateTypingIndicator')
                .length,
            3);
      });

      test('should handle typing in non-existent group', () async {
        // Act
        await usecase('nonexistent_group', true);

        // Assert
        expect(mockRepository.calledMethods.contains('updateTypingIndicator'),
            isTrue);
        expect(
            mockRepository.methodArgs['updateTypingIndicator']['chatGroupId'],
            'nonexistent_group');
      });
    });
  });
}
