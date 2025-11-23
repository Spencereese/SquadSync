import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/usecases/initialize_games.dart';

import '../../helpers/mocks.mocks.dart';

void main() {
  late MockGameRepository mockGameRepository;
  late InitializeGames usecase;

  setUp(() {
    mockGameRepository = MockGameRepository();
    usecase = InitializeGames(mockGameRepository);
  });

  tearDown(() {
    reset(mockGameRepository);
  });

  group('InitializeGames', () {
    final mockAvailableGames = [
      {
        'name': 'Call of Duty: Modern Warfare',
        'slug': 'call-of-duty-modern-warfare',
        'igdbId': 12345,
        'maxSpots': 4,
      },
      {
        'name': 'FIFA 23',
        'slug': 'fifa-23',
        'igdbId': 12346,
        'maxSpots': 2,
      },
    ];

    final mockGameLobbies = {
      'call-of-duty-modern-warfare': [
        {
          'squadId': 'squad1',
          'spots': ['user1', null, null, null],
          'timer': null,
        }
      ],
      'fifa-23': [
        {
          'squadId': 'squad2',
          'spots': ['user2', null],
          'timer': null,
        }
      ],
    };

    test('should return initialization data when both repositories succeed',
        () async {
      // Arrange
      when(mockGameRepository.getAvailableGames())
          .thenAnswer((_) async => mockAvailableGames);
      when(mockGameRepository.getGameLobbies())
          .thenAnswer((_) async => mockGameLobbies);

      // Act
      final result = await usecase.call();

      // Assert
      expect(result.availableGames, equals(mockAvailableGames));
      expect(result.gameLobbies, equals(mockGameLobbies));
      verify(mockGameRepository.getAvailableGames()).called(1);
      verify(mockGameRepository.getGameLobbies()).called(1);
      verifyNoMoreInteractions(mockGameRepository);
    });

    test('should handle empty available games', () async {
      // Arrange
      when(mockGameRepository.getAvailableGames()).thenAnswer((_) async => []);
      when(mockGameRepository.getGameLobbies()).thenAnswer((_) async => {});

      // Act
      final result = await usecase.call();

      // Assert
      expect(result.availableGames, isEmpty);
      expect(result.gameLobbies, isEmpty);
    });

    test('should handle empty game lobbies', () async {
      // Arrange
      when(mockGameRepository.getAvailableGames())
          .thenAnswer((_) async => mockAvailableGames);
      when(mockGameRepository.getGameLobbies()).thenAnswer((_) async => {});

      // Act
      final result = await usecase.call();

      // Assert
      expect(result.availableGames, equals(mockAvailableGames));
      expect(result.gameLobbies, isEmpty);
    });

    test('should propagate getAvailableGames exceptions', () async {
      // Arrange
      final exception = Exception('Available games error');
      when(mockGameRepository.getAvailableGames()).thenThrow(exception);

      // Act & Assert
      expect(
        () => usecase.call(),
        throwsA(equals(exception)),
      );
      verify(mockGameRepository.getAvailableGames()).called(1);
      verifyNever(mockGameRepository.getGameLobbies());
    });

    test('should propagate getGameLobbies exceptions', () async {
      // Arrange
      when(mockGameRepository.getAvailableGames())
          .thenAnswer((_) async => mockAvailableGames);
      final exception = Exception('Game lobbies error');
      when(mockGameRepository.getGameLobbies()).thenThrow(exception);

      // Act & Assert
      expect(
        () async => await usecase.call(),
        throwsA(equals(exception)),
      );
    });

    test('should handle network timeout in available games', () async {
      // Arrange
      final timeoutException = Exception('Timeout');
      when(mockGameRepository.getAvailableGames()).thenThrow(timeoutException);

      // Act & Assert
      expect(
        () => usecase.call(),
        throwsA(equals(timeoutException)),
      );
    });

    test('should handle network timeout in game lobbies', () async {
      // Arrange
      when(mockGameRepository.getAvailableGames())
          .thenAnswer((_) async => mockAvailableGames);
      final timeoutException = Exception('Timeout');
      when(mockGameRepository.getGameLobbies()).thenThrow(timeoutException);

      // Act & Assert
      expect(
        () => usecase.call(),
        throwsA(equals(timeoutException)),
      );
    });

    test('should handle Firestore permission errors', () async {
      // Arrange
      final permissionException = Exception('Permission denied');
      when(mockGameRepository.getAvailableGames())
          .thenThrow(permissionException);

      // Act & Assert
      expect(
        () => usecase.call(),
        throwsA(equals(permissionException)),
      );
    });
  });
}
