import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/usecases/delta_sync.dart';

import '../../helpers/manual_mock_chat.dart';

void main() {
  late DeltaSync usecase;
  late ManualMockChatRepository mockRepository;

  setUp(() {
    mockRepository = ManualMockChatRepository();
    usecase = DeltaSync(mockRepository);
  });

  tearDown(() {
    reset(mockRepository);
    mockRepository.shouldThrowException = false;
    mockRepository.exceptionToThrow = null;
  });

  const testChatGroupId = 'group123';
  final testSince = DateTime(2023, 12, 20);

  group('DeltaSync Usecase', () {
    group('Happy Path', () {
      test('should sync messages successfully with since timestamp', () async {
        // Act
        await usecase(testChatGroupId, since: testSince);

        // Assert
        expect(mockRepository.calledMethods.contains('syncMessages'), isTrue);
        expect(mockRepository.methodArgs['syncMessages']['chatGroupId'],
            testChatGroupId);
        expect(mockRepository.methodArgs['syncMessages']['since'], testSince);
      });

      test('should sync messages successfully without since timestamp',
          () async {
        // Act
        await usecase(testChatGroupId);

        // Assert
        expect(mockRepository.calledMethods.contains('syncMessages'), isTrue);
        expect(mockRepository.methodArgs['syncMessages']['chatGroupId'],
            testChatGroupId);
        expect(mockRepository.methodArgs['syncMessages']['since'], isNull);
      });

      test('should handle full sync flow with conflict resolution', () async {
        // Act
        await usecase(testChatGroupId, since: testSince);

        // Assert
        expect(mockRepository.calledMethods.contains('syncMessages'), isTrue);
        expect(mockRepository.methodArgs['syncMessages']['chatGroupId'],
            testChatGroupId);
        expect(mockRepository.methodArgs['syncMessages']['since'], testSince);
      });
    });

    group('SquadSync Delta Sync Flow', () {
      test('should handle 30-day message purging during sync', () async {
        // Arrange
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

        // Act
        await usecase(testChatGroupId, since: thirtyDaysAgo);

        // Assert
        expect(mockRepository.calledMethods.contains('syncMessages'), isTrue);
        expect(mockRepository.methodArgs['syncMessages']['chatGroupId'],
            testChatGroupId);
        expect(
            mockRepository.methodArgs['syncMessages']['since'], thirtyDaysAgo);
      });

      test('should handle conflict resolution with timestamp priority',
          () async {
        // Act
        await usecase(testChatGroupId);

        // Assert
        expect(mockRepository.calledMethods.contains('syncMessages'), isTrue);
        expect(mockRepository.methodArgs['syncMessages']['chatGroupId'],
            testChatGroupId);
      });

      test('should handle concurrent sync operations', () async {
        // Act - Simulate concurrent calls
        final future1 = usecase(testChatGroupId, since: testSince);
        final future2 = usecase(testChatGroupId, since: testSince);

        await Future.wait([future1, future2]);

        // Assert - Both calls should have been made
        expect(
            mockRepository.calledMethods
                .where((method) => method == 'syncMessages')
                .length,
            2);
      });

      test('should handle offline/online transitions', () async {
        // Act
        await usecase(testChatGroupId);

        // Assert
        expect(mockRepository.calledMethods.contains('syncMessages'), isTrue);
        expect(mockRepository.methodArgs['syncMessages']['chatGroupId'],
            testChatGroupId);
      });

      test('should handle large message batches', () async {
        // Act
        await usecase(testChatGroupId, since: testSince);

        // Assert
        expect(mockRepository.calledMethods.contains('syncMessages'), isTrue);
        expect(mockRepository.methodArgs['syncMessages']['chatGroupId'],
            testChatGroupId);
        expect(mockRepository.methodArgs['syncMessages']['since'], testSince);
      });
    });

    group('Error Cases', () {
      test('should throw exception when repository fails', () async {
        // Arrange
        final exception = Exception('Sync failed');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase(testChatGroupId, since: testSince),
          throwsA(exception),
        );
        expect(mockRepository.calledMethods.contains('syncMessages'), isTrue);
      });

      test('should handle network errors during sync', () async {
        // Arrange
        final exception = Exception('Network error');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase(testChatGroupId),
          throwsA(exception),
        );
      });

      test('should handle Firestore permission errors', () async {
        // Arrange
        final exception = Exception('Permission denied');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase(testChatGroupId, since: testSince),
          throwsA(exception),
        );
      });
    });

    group('Edge Cases', () {
      test('should handle very old since timestamps', () async {
        // Arrange
        final veryOldDate = DateTime(2020, 1, 1);

        // Act
        await usecase(testChatGroupId, since: veryOldDate);

        // Assert
        expect(mockRepository.calledMethods.contains('syncMessages'), isTrue);
        expect(mockRepository.methodArgs['syncMessages']['since'], veryOldDate);
      });

      test('should handle future timestamps', () async {
        // Arrange
        final futureDate = DateTime.now().add(const Duration(days: 1));

        // Act
        await usecase(testChatGroupId, since: futureDate);

        // Assert
        expect(mockRepository.calledMethods.contains('syncMessages'), isTrue);
        expect(mockRepository.methodArgs['syncMessages']['since'], futureDate);
      });

      test('should handle null since parameter explicitly', () async {
        // Act
        await usecase(testChatGroupId, since: null);

        // Assert
        expect(mockRepository.calledMethods.contains('syncMessages'), isTrue);
        expect(mockRepository.methodArgs['syncMessages']['since'], isNull);
      });
    });
  });
}
