import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/usecases/create_group.dart';

import '../../helpers/manual_mock_chat.dart';

void main() {
  late CreateGroup usecase;
  late ManualMockChatRepository mockRepository;

  setUp(() {
    mockRepository = ManualMockChatRepository();
    usecase = CreateGroup(mockRepository);
  });

  tearDown(() {
    reset(mockRepository);
    mockRepository.shouldThrowException = false;
    mockRepository.exceptionToThrow = null;
  });

  const testName = 'Test Group';
  const testIsPublic = true;
  const testDescription = 'A test chat group';

  group('CreateGroup Usecase', () {
    group('Happy Path', () {
      test('should create public group successfully', () async {
        // Act
        final result =
            await usecase(testName, testIsPublic, description: testDescription);

        // Assert
        expect(result.name, testName);
        expect(result.isPublic, testIsPublic);
        expect(result.memberUids, ['mock_user']);
        expect(result.createdBy, 'mock_user');
        expect(mockRepository.calledMethods.contains('createGroup'), isTrue);
        expect(mockRepository.methodArgs['createGroup']['name'], testName);
        expect(
            mockRepository.methodArgs['createGroup']['isPublic'], testIsPublic);
        expect(mockRepository.methodArgs['createGroup']['description'],
            testDescription);
      });

      test('should create private group successfully', () async {
        // Act
        final result = await usecase('Private Group', false);

        // Assert
        expect(result.name, 'Private Group');
        expect(result.isPublic, isFalse);
        expect(mockRepository.calledMethods.contains('createGroup'), isTrue);
        expect(mockRepository.methodArgs['createGroup']['isPublic'], isFalse);
      });

      test('should create group without description', () async {
        // Act
        final result = await usecase(testName, testIsPublic);

        // Assert
        expect(result.name, testName);
        expect(result.isPublic, testIsPublic);
        expect(mockRepository.calledMethods.contains('createGroup'), isTrue);
        expect(mockRepository.methodArgs['createGroup']['description'], isNull);
      });
    });

    group('Error Path', () {
      test('should throw exception when repository fails', () async {
        // Arrange
        final exception = Exception('Failed to create group');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase(testName, testIsPublic),
          throwsA(exception),
        );
        expect(mockRepository.calledMethods.contains('createGroup'), isTrue);
      });
    });

    group('Edge Cases', () {
      test('should handle empty group name', () async {
        // Act
        final result = await usecase('', testIsPublic);

        // Assert
        expect(result.name, '');
        expect(mockRepository.calledMethods.contains('createGroup'), isTrue);
        expect(mockRepository.methodArgs['createGroup']['name'], '');
      });

      test('should handle long group name', () async {
        // Arrange
        const longName =
            'This is a very long group name that exceeds normal limits and should still be handled properly by the system';

        // Act
        final result = await usecase(longName, testIsPublic);

        // Assert
        expect(result.name, longName);
        expect(mockRepository.calledMethods.contains('createGroup'), isTrue);
        expect(mockRepository.methodArgs['createGroup']['name'], longName);
      });
    });
  });
}
