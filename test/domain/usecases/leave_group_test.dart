import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/usecases/leave_group.dart';

import '../../helpers/manual_mock_chat.dart';

void main() {
  late LeaveGroup usecase;
  late ManualMockChatRepository mockRepository;

  setUp(() {
    mockRepository = ManualMockChatRepository();
    usecase = LeaveGroup(mockRepository);
  });

  tearDown(() {
    reset(mockRepository);
    mockRepository.shouldThrowException = false;
    mockRepository.exceptionToThrow = null;
  });

  const testGroupId = 'group123';

  group('LeaveGroup Usecase', () {
    group('Happy Path', () {
      test('should leave group successfully', () async {
        // Act
        await usecase(testGroupId);

        // Assert
        expect(mockRepository.calledMethods.contains('leaveGroup'), isTrue);
        expect(mockRepository.methodArgs['leaveGroup']['groupId'], testGroupId);
      });
    });

    group('Error Path', () {
      test('should throw exception when repository fails', () async {
        // Arrange
        final exception = Exception('Failed to leave group');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase(testGroupId),
          throwsA(exception),
        );
        expect(mockRepository.calledMethods.contains('leaveGroup'), isTrue);
      });

      test('should throw exception when not a member', () async {
        // Arrange
        final exception = Exception('Not a member of this group');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase('not_member_group'),
          throwsA(exception),
        );
        expect(mockRepository.calledMethods.contains('leaveGroup'), isTrue);
        expect(mockRepository.methodArgs['leaveGroup']['groupId'],
            'not_member_group');
      });
    });

    group('Edge Cases', () {
      test('should handle empty group id', () async {
        // Act
        await usecase('');

        // Assert
        expect(mockRepository.calledMethods.contains('leaveGroup'), isTrue);
        expect(mockRepository.methodArgs['leaveGroup']['groupId'], '');
      });

      test('should handle leaving own group as admin', () async {
        // Arrange
        const adminGroupId = 'admin_created_group';

        // Act
        await usecase(adminGroupId);

        // Assert
        expect(mockRepository.calledMethods.contains('leaveGroup'), isTrue);
        expect(
            mockRepository.methodArgs['leaveGroup']['groupId'], adminGroupId);
      });
    });
  });
}
