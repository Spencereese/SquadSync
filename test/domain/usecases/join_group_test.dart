import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/usecases/join_group.dart';

import '../../helpers/manual_mock_chat.dart';

void main() {
  late JoinGroup usecase;
  late ManualMockChatRepository mockRepository;

  setUp(() {
    mockRepository = ManualMockChatRepository();
    usecase = JoinGroup(mockRepository);
  });

  tearDown(() {
    reset(mockRepository);
    mockRepository.shouldThrowException = false;
    mockRepository.exceptionToThrow = null;
  });

  const testGroupId = 'group123';

  group('JoinGroup Usecase', () {
    group('Happy Path', () {
      test('should join group successfully', () async {
        // Act
        await usecase(testGroupId);

        // Assert
        expect(mockRepository.calledMethods.contains('joinGroup'), isTrue);
        expect(mockRepository.methodArgs['joinGroup']['groupId'], testGroupId);
      });
    });

    group('Error Path', () {
      test('should throw exception when repository fails', () async {
        // Arrange
        final exception = Exception('Failed to join group');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase(testGroupId),
          throwsA(exception),
        );
        expect(mockRepository.calledMethods.contains('joinGroup'), isTrue);
      });

      test('should throw exception for invalid group id', () async {
        // Arrange
        final exception = Exception('Group not found');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase('invalid_group'),
          throwsA(exception),
        );
        expect(mockRepository.calledMethods.contains('joinGroup'), isTrue);
        expect(
            mockRepository.methodArgs['joinGroup']['groupId'], 'invalid_group');
      });
    });

    group('Edge Cases', () {
      test('should handle empty group id', () async {
        // Act
        await usecase('');

        // Assert
        expect(mockRepository.calledMethods.contains('joinGroup'), isTrue);
        expect(mockRepository.methodArgs['joinGroup']['groupId'], '');
      });

      test('should handle long group id', () async {
        // Arrange
        const longGroupId =
            'very_long_group_id_that_exceeds_normal_limits_and_should_still_be_handled';

        // Act
        await usecase(longGroupId);

        // Assert
        expect(mockRepository.calledMethods.contains('joinGroup'), isTrue);
        expect(mockRepository.methodArgs['joinGroup']['groupId'], longGroupId);
      });
    });
  });
}
