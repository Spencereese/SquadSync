import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/usecases/load_media_history.dart';

import '../../helpers/manual_mock_chat.dart';

void main() {
  late LoadMediaHistory usecase;
  late ManualMockChatRepository mockRepository;

  setUp(() {
    mockRepository = ManualMockChatRepository();
    usecase = LoadMediaHistory(mockRepository);
  });

  tearDown(() {
    reset(mockRepository);
    mockRepository.shouldThrowException = false;
    mockRepository.exceptionToThrow = null;
  });

  const testChatGroupId = 'group123';

  group('LoadMediaHistory Usecase', () {
    group('Happy Path', () {
      test('should load media history successfully', () async {
        // Act
        final result = await usecase(testChatGroupId);

        // Assert
        expect(result, isA<List<Map<String, dynamic>>>());
        expect(
            mockRepository.calledMethods.contains('getMediaHistory'), isTrue);
        expect(mockRepository.methodArgs['getMediaHistory']['chatGroupId'],
            testChatGroupId);
      });
    });

    group('Error Path', () {
      test('should throw exception when repository fails', () async {
        // Arrange
        final exception = Exception('Failed to load media history');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase(testChatGroupId),
          throwsA(exception),
        );
        expect(
            mockRepository.calledMethods.contains('getMediaHistory'), isTrue);
      });
    });

    group('Edge Cases', () {
      test('should handle empty chat group id', () async {
        // Act
        final result = await usecase('');

        // Assert
        expect(result, isA<List<Map<String, dynamic>>>());
        expect(
            mockRepository.calledMethods.contains('getMediaHistory'), isTrue);
        expect(mockRepository.methodArgs['getMediaHistory']['chatGroupId'], '');
      });

      test('should handle group with no media history', () async {
        // Act
        final result = await usecase('empty_group');

        // Assert
        expect(result, isA<List<Map<String, dynamic>>>());
        expect(
            mockRepository.calledMethods.contains('getMediaHistory'), isTrue);
        expect(mockRepository.methodArgs['getMediaHistory']['chatGroupId'],
            'empty_group');
      });
    });
  });
}
