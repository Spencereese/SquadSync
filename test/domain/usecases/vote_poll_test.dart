import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/usecases/vote_poll.dart';

import '../../helpers/manual_mock_chat.dart';

void main() {
  late VotePoll usecase;
  late ManualMockChatRepository mockRepository;

  setUp(() {
    mockRepository = ManualMockChatRepository();
    usecase = VotePoll(mockRepository);
  });

  tearDown(() {
    reset(mockRepository);
    mockRepository.shouldThrowException = false;
    mockRepository.exceptionToThrow = null;
  });

  const testChatGroupId = 'group123';
  const testPollId = 'poll123';
  const testOption = 'Red';
  const testVoterId = 'user123';

  group('VotePoll Usecase', () {
    group('Happy Path', () {
      test('should vote on poll successfully', () async {
        // Act
        await usecase(testChatGroupId, testPollId, testOption, testVoterId);

        // Assert
        expect(mockRepository.calledMethods.contains('votePoll'), isTrue);
        expect(mockRepository.methodArgs['votePoll']['chatGroupId'],
            testChatGroupId);
        expect(mockRepository.methodArgs['votePoll']['pollId'], testPollId);
        expect(mockRepository.methodArgs['votePoll']['option'], testOption);
        expect(mockRepository.methodArgs['votePoll']['voterId'], testVoterId);
      });

      test('should allow changing vote', () async {
        // Act - Vote first time
        await usecase(testChatGroupId, testPollId, 'Red', testVoterId);
        // Vote again with different option
        await usecase(testChatGroupId, testPollId, 'Blue', testVoterId);

        // Assert
        expect(
            mockRepository.calledMethods
                .where((method) => method == 'votePoll')
                .length,
            2);
      });
    });

    group('Error Path', () {
      test('should throw exception when repository fails', () async {
        // Arrange
        final exception = Exception('Failed to vote on poll');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase(testChatGroupId, testPollId, testOption, testVoterId),
          throwsA(exception),
        );
        expect(mockRepository.calledMethods.contains('votePoll'), isTrue);
      });

      test('should throw exception for closed poll', () async {
        // Arrange
        final exception = Exception('Poll is closed');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () =>
              usecase(testChatGroupId, 'closed_poll', testOption, testVoterId),
          throwsA(exception),
        );
        expect(mockRepository.calledMethods.contains('votePoll'), isTrue);
        expect(mockRepository.methodArgs['votePoll']['pollId'], 'closed_poll');
      });
    });

    group('Edge Cases', () {
      test('should handle empty option', () async {
        // Act
        await usecase(testChatGroupId, testPollId, '', testVoterId);

        // Assert
        expect(mockRepository.calledMethods.contains('votePoll'), isTrue);
        expect(mockRepository.methodArgs['votePoll']['option'], '');
      });

      test('should handle voting on own poll', () async {
        // Act
        await usecase(testChatGroupId, 'own_poll', testOption, 'creator_id');

        // Assert
        expect(mockRepository.calledMethods.contains('votePoll'), isTrue);
        expect(mockRepository.methodArgs['votePoll']['voterId'], 'creator_id');
      });

      test('should handle concurrent votes', () async {
        // Act - Simulate concurrent voting
        await Future.wait([
          usecase(testChatGroupId, testPollId, 'Red', 'user1'),
          usecase(testChatGroupId, testPollId, 'Blue', 'user2'),
          usecase(testChatGroupId, testPollId, 'Green', 'user3'),
        ]);

        // Assert
        expect(
            mockRepository.calledMethods
                .where((method) => method == 'votePoll')
                .length,
            3);
      });
    });
  });
}
