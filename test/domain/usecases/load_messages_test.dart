import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/usecases/load_messages.dart';

import '../../helpers/manual_mock_chat.dart';

void main() {
  late LoadMessages usecase;
  late ManualMockChatRepository mockRepository;

  setUp(() {
    mockRepository = ManualMockChatRepository();
    usecase = LoadMessages(mockRepository);
  });

  tearDown(() {
    reset(mockRepository);
    mockRepository.shouldThrowException = false;
    mockRepository.exceptionToThrow = null;
  });

  const testChatGroupId = 'group123';
  const testLimit = 20;
  final testBefore = DateTime(2023, 12, 25, 10, 30);

  group('LoadMessages Usecase', () {
    group('Happy Path', () {
      test('should load messages successfully with default parameters',
          () async {
        // Act
        final result = await usecase(testChatGroupId);

        // Assert
        expect(result, isA<List<Message>>());
        expect(mockRepository.calledMethods.contains('loadMessages'), isTrue);
        expect(mockRepository.methodArgs['loadMessages']['chatGroupId'],
            testChatGroupId);
        expect(
            mockRepository.methodArgs['loadMessages']['limit'], 50); // default
        expect(mockRepository.methodArgs['loadMessages']['before'], isNull);
      });

      test('should load messages successfully with custom limit', () async {
        // Act
        final result = await usecase(testChatGroupId, limit: testLimit);

        // Assert
        expect(result, isA<List<Message>>());
        expect(mockRepository.calledMethods.contains('loadMessages'), isTrue);
        expect(mockRepository.methodArgs['loadMessages']['limit'], testLimit);
      });

      test('should load messages successfully with before timestamp', () async {
        // Act
        final result = await usecase(testChatGroupId, before: testBefore);

        // Assert
        expect(result, isA<List<Message>>());
        expect(mockRepository.calledMethods.contains('loadMessages'), isTrue);
        expect(mockRepository.methodArgs['loadMessages']['before'], testBefore);
      });

      test('should load messages successfully with all parameters', () async {
        // Act
        final result = await usecase(testChatGroupId,
            limit: testLimit, before: testBefore);

        // Assert
        expect(result, isA<List<Message>>());
        expect(mockRepository.calledMethods.contains('loadMessages'), isTrue);
        expect(mockRepository.methodArgs['loadMessages']['chatGroupId'],
            testChatGroupId);
        expect(mockRepository.methodArgs['loadMessages']['limit'], testLimit);
        expect(mockRepository.methodArgs['loadMessages']['before'], testBefore);
      });
    });

    group('Error Path', () {
      test('should throw exception when repository fails', () async {
        // Arrange
        final exception = Exception('Failed to load messages');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase(testChatGroupId),
          throwsA(exception),
        );
        expect(mockRepository.calledMethods.contains('loadMessages'), isTrue);
      });
    });

    group('Edge Cases', () {
      test('should handle zero limit', () async {
        // Act
        final result = await usecase(testChatGroupId, limit: 0);

        // Assert
        expect(result, isA<List<Message>>());
        expect(mockRepository.calledMethods.contains('loadMessages'), isTrue);
        expect(mockRepository.methodArgs['loadMessages']['limit'], 0);
      });

      test('should handle very high limit', () async {
        // Act
        final result = await usecase(testChatGroupId, limit: 1000);

        // Assert
        expect(result, isA<List<Message>>());
        expect(mockRepository.calledMethods.contains('loadMessages'), isTrue);
        expect(mockRepository.methodArgs['loadMessages']['limit'], 1000);
      });

      test('should handle past before timestamp', () async {
        // Arrange
        final pastDate = DateTime(2020, 1, 1);

        // Act
        final result = await usecase(testChatGroupId, before: pastDate);

        // Assert
        expect(result, isA<List<Message>>());
        expect(mockRepository.calledMethods.contains('loadMessages'), isTrue);
        expect(mockRepository.methodArgs['loadMessages']['before'], pastDate);
      });

      test('should handle future before timestamp', () async {
        // Arrange
        final futureDate = DateTime(2030, 1, 1);

        // Act
        final result = await usecase(testChatGroupId, before: futureDate);

        // Assert
        expect(result, isA<List<Message>>());
        expect(mockRepository.calledMethods.contains('loadMessages'), isTrue);
        expect(mockRepository.methodArgs['loadMessages']['before'], futureDate);
      });
    });
  });
}
