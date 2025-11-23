import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/usecases/create_poll.dart';

import '../../helpers/manual_mock_chat.dart';

void main() {
  late CreatePoll usecase;
  late ManualMockChatRepository mockRepository;

  setUp(() {
    mockRepository = ManualMockChatRepository();
    usecase = CreatePoll(mockRepository);
  });

  tearDown(() {
    reset(mockRepository);
    mockRepository.shouldThrowException = false;
    mockRepository.exceptionToThrow = null;
  });

  const testChatGroupId = 'group123';
  const testQuestion = 'What is your favorite color?';
  final testOptions = ['Red', 'Blue', 'Green'];

  group('CreatePoll Usecase', () {
    group('Happy Path', () {
      test('should create poll successfully', () async {
        // Act
        final result =
            await usecase(testChatGroupId, testQuestion, testOptions);

        // Assert
        expect(result.question, testQuestion);
        expect(result.options, testOptions);
        expect(result.votes, isEmpty);
        expect(result.createdBy, 'mock_user');
        expect(mockRepository.calledMethods.contains('createPoll'), isTrue);
        expect(mockRepository.methodArgs['createPoll']['chatGroupId'],
            testChatGroupId);
        expect(
            mockRepository.methodArgs['createPoll']['question'], testQuestion);
        expect(mockRepository.methodArgs['createPoll']['options'], testOptions);
      });

      test('should create poll with single option', () async {
        // Arrange
        final singleOption = ['Only Option'];

        // Act
        final result =
            await usecase(testChatGroupId, testQuestion, singleOption);

        // Assert
        expect(result.options, singleOption);
        expect(mockRepository.calledMethods.contains('createPoll'), isTrue);
        expect(
            mockRepository.methodArgs['createPoll']['options'], singleOption);
      });

      test('should create poll with multiple options', () async {
        // Arrange
        final multipleOptions = [
          'Option 1',
          'Option 2',
          'Option 3',
          'Option 4',
          'Option 5'
        ];

        // Act
        final result =
            await usecase(testChatGroupId, testQuestion, multipleOptions);

        // Assert
        expect(result.options, multipleOptions);
        expect(mockRepository.calledMethods.contains('createPoll'), isTrue);
        expect(mockRepository.methodArgs['createPoll']['options'],
            multipleOptions);
      });
    });

    group('Error Path', () {
      test('should throw exception when repository fails', () async {
        // Arrange
        final exception = Exception('Failed to create poll');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase(testChatGroupId, testQuestion, testOptions),
          throwsA(exception),
        );
        expect(mockRepository.calledMethods.contains('createPoll'), isTrue);
      });
    });

    group('Edge Cases', () {
      test('should handle empty question', () async {
        // Act
        final result = await usecase(testChatGroupId, '', testOptions);

        // Assert
        expect(result.question, '');
        expect(mockRepository.calledMethods.contains('createPoll'), isTrue);
        expect(mockRepository.methodArgs['createPoll']['question'], '');
      });

      test('should handle empty options list', () async {
        // Arrange
        final emptyOptions = <String>[];

        // Act
        final result =
            await usecase(testChatGroupId, testQuestion, emptyOptions);

        // Assert
        expect(result.options, emptyOptions);
        expect(mockRepository.calledMethods.contains('createPoll'), isTrue);
        expect(
            mockRepository.methodArgs['createPoll']['options'], emptyOptions);
      });

      test('should handle long question', () async {
        // Arrange
        const longQuestion =
            'This is a very long poll question that exceeds normal limits and should still be handled properly by the system when creating polls for chat groups';

        // Act
        final result =
            await usecase(testChatGroupId, longQuestion, testOptions);

        // Assert
        expect(result.question, longQuestion);
        expect(mockRepository.calledMethods.contains('createPoll'), isTrue);
        expect(
            mockRepository.methodArgs['createPoll']['question'], longQuestion);
      });
    });
  });
}
