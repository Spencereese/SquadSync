import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/squad.dart';
import 'package:squad_sync/domain/entities/squad_state.dart';
import 'package:squad_sync/domain/repositories/squad_repository.dart';
import 'package:squad_sync/domain/usecases/create_squad.dart';

// Mock class for SquadRepository
class MockSquadRepository implements SquadRepository {
  Squad? _createSquadResponse;
  Exception? _createSquadException;

  void setCreateSquadResponse(Squad response) {
    _createSquadResponse = response;
    _createSquadException = null;
  }

  void setCreateSquadException(Exception exception) {
    _createSquadException = exception;
    _createSquadResponse = null;
  }

  @override
  Future<Squad> createSquad(String name, String gameName, int maxSpots) async {
    if (_createSquadException != null) {
      throw _createSquadException!;
    }
    return _createSquadResponse ?? Squad.create(
      name: name,
      gameName: gameName,
      maxSpots: maxSpots,
      createdBy: 'testUser',
    );
  }

  @override
  Future<Squad?> getSquad(String squadId) => throw UnimplementedError();

  @override
  Future<List<Squad>> getUserSquads(String userId) => throw UnimplementedError();

  @override
  Future<void> deleteSquad(String squadId) => throw UnimplementedError();

  @override
  Future<void> joinSquad(String squadId, String userId) => throw UnimplementedError();

  @override
  Future<void> leaveSquad(String squadId, String userId) => throw UnimplementedError();

  @override
  Future<void> kickMember(String squadId, String memberId, String kickedBy) => throw UnimplementedError();

  @override
  Future<void> assignSpot(String squadId, int spotIndex, String? userId) => throw UnimplementedError();

  @override
  Future<void> startSpotTimer(String squadId, int spotIndex, Duration duration) => throw UnimplementedError();

  @override
  Future<void> cancelSpotTimer(String squadId, int spotIndex) => throw UnimplementedError();

  @override
  Future<void> processExpiredTimers() => throw UnimplementedError();

  @override
  Stream<Map<String, Duration>> getSpotTimerStates(String squadId) => throw UnimplementedError();

  @override
  Stream<Map<String, Duration>> getPeacockTimerStates() => throw UnimplementedError();

  @override
  Future<void> addToPeacockQueue(String userId, String gameName) => throw UnimplementedError();

  @override
  Future<void> removeFromPeacockQueue(String userId) => throw UnimplementedError();

  @override
  Future<void> processPeacockQueue() => throw UnimplementedError();

  @override
  Future<void> updateMemberStatus(String squadId, String userId, String status) => throw UnimplementedError();

  @override
  Future<void> updateGlobalStatus(String userId, String status) => throw UnimplementedError();

  @override
  Future<SquadState> loadSquadState() => throw UnimplementedError();

  @override
  Future<void> saveSquadState(SquadState state) => throw UnimplementedError();

  @override
  Future<void> syncSquadData() => throw UnimplementedError();

  @override
  Future<void> purgeOldData() => throw UnimplementedError();

  @override
  Future<void> trackSquadEvent(String event, Map<String, dynamic> data) => throw UnimplementedError();
}

void main() {
  late MockSquadRepository mockSquadRepository;
  late CreateSquad usecase;

  setUp(() {
    mockSquadRepository = MockSquadRepository();
    usecase = CreateSquad(mockSquadRepository);
  });

  group('CreateSquad', () {
    final mockSquad = Squad(
      id: 'squad123',
      name: 'Test Squad',
      memberUids: ['creator1'],
      gameName: 'Call of Duty',
      maxSpots: 4,
      createdBy: 'creator1',
      createdAt: DateTime(2023, 12, 25, 10, 0),
      spots: [null, null, null, null],
      spotTimers: [null, null, null, null],
      viewers: [],
      statuses: {},
      isActive: true,
    );

    test('should return squad when repository succeeds', () async {
      // Arrange
      mockSquadRepository.setCreateSquadResponse(mockSquad);

      // Act
      final result = await usecase.call('Test Squad', 'Call of Duty', 4);

      // Assert
      expect(result, equals(mockSquad));
      expect(result.name, 'Test Squad');
      expect(result.gameName, 'Call of Duty');
      expect(result.maxSpots, 4);
    });

    test('should create squad with correct parameters', () async {
      // Arrange
      final expectedSquad = Squad.create(
        name: 'Alpha Squad',
        gameName: 'Fortnite',
        maxSpots: 5,
        createdBy: 'testUser',
      );
      mockSquadRepository.setCreateSquadResponse(expectedSquad);

      // Act
      final result = await usecase.call('Alpha Squad', 'Fortnite', 5);

      // Assert
      expect(result.name, 'Alpha Squad');
      expect(result.gameName, 'Fortnite');
      expect(result.maxSpots, 5);
      expect(result.memberUids, ['testUser']);
      expect(result.createdBy, 'testUser');
      expect(result.spots.length, 5);
      expect(result.spotTimers.length, 5);
      expect(result.isActive, true);
    });

    test('should handle different game types', () async {
      // Arrange
      final games = ['Call of Duty', 'Fortnite', 'Apex Legends', 'Valorant'];
      final maxSpotsList = [4, 5, 3, 5];

      for (int i = 0; i < games.length; i++) {
        final expectedSquad = Squad.create(
          name: '${games[i]} Squad',
          gameName: games[i],
          maxSpots: maxSpotsList[i],
          createdBy: 'testUser',
        );
        mockSquadRepository.setCreateSquadResponse(expectedSquad);

        // Act
        final result = await usecase.call('${games[i]} Squad', games[i], maxSpotsList[i]);

        // Assert
        expect(result.gameName, games[i]);
        expect(result.maxSpots, maxSpotsList[i]);
        expect(result.spots.length, maxSpotsList[i]);
      }
    });

    test('should propagate repository exceptions', () async {
      // Arrange
      final exception = Exception('Failed to create squad');
      mockSquadRepository.setCreateSquadException(exception);

      // Act & Assert
      expect(
        () => usecase.call('Test Squad', 'Call of Duty', 4),
        throwsA(equals(exception)),
      );
    });

    test('should handle network errors', () async {
      // Arrange
      final networkException = Exception('Network connection failed');
      mockSquadRepository.setCreateSquadException(networkException);

      // Act & Assert
      expect(
        () => usecase.call('Test Squad', 'Call of Duty', 4),
        throwsA(equals(networkException)),
      );
    });

    test('should handle validation errors', () async {
      // Arrange
      final validationException = Exception('Invalid squad parameters');
      mockSquadRepository.setCreateSquadException(validationException);

      // Act & Assert
      expect(
        () => usecase.call('', 'Call of Duty', 4),
        throwsA(equals(validationException)),
      );
    });

    test('should handle duplicate squad name errors', () async {
      // Arrange
      final duplicateException = Exception('Squad name already exists');
      mockSquadRepository.setCreateSquadException(duplicateException);

      // Act & Assert
      expect(
        () => usecase.call('Existing Squad', 'Call of Duty', 4),
        throwsA(equals(duplicateException)),
      );
    });

    test('should handle invalid max spots', () async {
      // Arrange
      final invalidSpotsException = Exception('Max spots must be between 2 and 10');
      mockSquadRepository.setCreateSquadException(invalidSpotsException);

      // Act & Assert
      expect(
        () => usecase.call('Test Squad', 'Call of Duty', 15),
        throwsA(equals(invalidSpotsException)),
      );
    });
  });
}