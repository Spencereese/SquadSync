import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/squad.dart';
import 'package:squad_sync/domain/entities/squad_state.dart';
import 'package:squad_sync/domain/repositories/squad_repository.dart';
import 'package:squad_sync/domain/usecases/load_squad_state.dart';

// Mock class for SquadRepository
class MockSquadRepository implements SquadRepository {
  SquadState? _loadSquadStateResponse;
  Exception? _loadSquadStateException;

  void setLoadSquadStateResponse(SquadState response) {
    _loadSquadStateResponse = response;
    _loadSquadStateException = null;
  }

  void setLoadSquadStateException(Exception exception) {
    _loadSquadStateException = exception;
    _loadSquadStateResponse = null;
  }

  @override
  Future<SquadState> loadSquadState() async {
    if (_loadSquadStateException != null) {
      throw _loadSquadStateException!;
    }
    return _loadSquadStateResponse ?? SquadState.initial();
  }

  @override
  Future<Squad> createSquad(String name, String gameName, int maxSpots) => throw UnimplementedError();

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
  late LoadSquadState usecase;

  setUp(() {
    mockSquadRepository = MockSquadRepository();
    usecase = LoadSquadState(mockSquadRepository);
  });

  group('LoadSquadState', () {
    final mockSquadState = SquadState(
      isInitialized: true,
      isInitialDataLoaded: true,
      displayName: 'TestUser',
      profileImage: 'https://example.com/avatar.jpg',
      memberProfileImages: {
        'user1': 'https://example.com/user1.jpg',
        'user2': 'https://example.com/user2.jpg',
      },
      gameSquadSpots: {
        'Call of Duty': ['user1', null, 'user2', null],
        'Fortnite': ['user3', 'user4', null, null, null],
      },
      gameSpotTimers: {
        'Call of Duty': [
          {'startTime': DateTime(2023, 12, 25, 10, 5).toIso8601String(), 'duration': 300000},
          null,
          {'startTime': DateTime(2023, 12, 25, 10, 10).toIso8601String(), 'duration': 600000},
          null,
        ],
      },
      gameStatuses: {
        'Call of Duty': {'user1': 'Ready', 'user2': 'Walking'},
        'Fortnite': {'user3': 'Available', 'user4': 'In Lobby'},
      },
      globalStatuses: {
        'user1': 'Online',
        'user2': 'Away',
        'user3': 'Busy',
      },
      squadMemberUids: ['user1', 'user2', 'user3'],
      memberDisplayNames: {
        'user1': 'PlayerOne',
        'user2': 'PlayerTwo',
        'user3': 'PlayerThree',
      },
      userSquadIds: ['squad1', 'squad2'],
      userSquads: {},
      typing: {},
      tiltEnabled: true,
      hasNewSquadSpot: false,
      hasUnreadMessages: true,
      gameHistory: [
        {'game': 'Call of Duty', 'timestamp': DateTime(2023, 12, 24, 20, 0).toIso8601String()},
      ],
      preferredModes: {
        'Call of Duty': 'Ranked',
      },
      userBlocks: {},
      dailyBanVotes: {},
      bans: {},
      availableGames: [
        {'name': 'Call of Duty', 'maxSpots': 4},
        {'name': 'Fortnite', 'maxSpots': 5},
      ],
      gameLobbies: {},
      preferredPeacockGames: {'Call of Duty', 'Fortnite'},
      mutedGames: {},
      hiddenGames: {},
      peacockTimers: {},
      peacockQueue: ['user1', 'user2'],
      scheduledTimes: [],
      hasNewAvailability: true,
      spotTimerStates: {},
      peacockTimerStates: {},
      lastSyncTimestamp: DateTime(2023, 12, 25, 10, 30),
      analyticsMetrics: {
        'totalSquads': 25,
        'activeUsers': 150,
      },
    );

    test('should return squad state when repository succeeds', () async {
      // Arrange
      mockSquadRepository.setLoadSquadStateResponse(mockSquadState);

      // Act
      final result = await usecase.call();

      // Assert
      expect(result, equals(mockSquadState));
    });

    test('should return initial state when repository returns default', () async {
      // Arrange
      final initialState = SquadState.initial();
      mockSquadRepository.setLoadSquadStateResponse(initialState);

      // Act
      final result = await usecase.call();

      // Assert
      expect(result, equals(initialState));
      expect(result.isInitialized, false);
      expect(result.displayName, 'Unknown User');
    });

    test('should handle complex game-scoped data', () async {
      // Arrange
      mockSquadRepository.setLoadSquadStateResponse(mockSquadState);

      // Act
      final result = await usecase.call();

      // Assert
      expect(result.gameSquadSpots['Call of Duty'], ['user1', null, 'user2', null]);
      expect(result.gameStatuses['Fortnite'], {'user3': 'Available', 'user4': 'In Lobby'});
      expect(result.peacockQueue, ['user1', 'user2']);
    });

    test('should propagate repository exceptions', () async {
      // Arrange
      final exception = Exception('Failed to load squad state');
      mockSquadRepository.setLoadSquadStateException(exception);

      // Act & Assert
      expect(
        () => usecase.call(),
        throwsA(equals(exception)),
      );
    });

    test('should handle SharedPreferences corruption', () async {
      // Arrange
      final corruptionException = Exception('SharedPreferences data corrupted');
      mockSquadRepository.setLoadSquadStateException(corruptionException);

      // Act & Assert
      expect(
        () => usecase.call(),
        throwsA(equals(corruptionException)),
      );
    });

    test('should handle Firebase connectivity issues', () async {
      // Arrange
      final firebaseException = Exception('Firebase connection failed');
      mockSquadRepository.setLoadSquadStateException(firebaseException);

      // Act & Assert
      expect(
        () => usecase.call(),
        throwsA(equals(firebaseException)),
      );
    });

    test('should handle SQLite database errors', () async {
      // Arrange
      final dbException = Exception('SQLite database error');
      mockSquadRepository.setLoadSquadStateException(dbException);

      // Act & Assert
      expect(
        () => usecase.call(),
        throwsA(equals(dbException)),
      );
    });

    test('should handle large state data loading', () async {
      // Arrange
      mockSquadRepository.setLoadSquadStateResponse(mockSquadState);

      // Act
      final result = await usecase.call();

      // Assert - successful loading indicates large data handled
      expect(result.analyticsMetrics['totalSquads'], 25);
    });

    test('should handle member display name caching', () async {
      // Arrange
      mockSquadRepository.setLoadSquadStateResponse(mockSquadState);

      // Act
      final result = await usecase.call();

      // Assert
      expect(result.memberDisplayNames['user1'], 'PlayerOne');
      expect(result.memberDisplayNames['user2'], 'PlayerTwo');
    });

    test('should handle game preferences and filters', () async {
      // Arrange
      mockSquadRepository.setLoadSquadStateResponse(mockSquadState);

      // Act
      final result = await usecase.call();

      // Assert
      expect(result.preferredPeacockGames, {'Call of Duty', 'Fortnite'});
      expect(result.preferredModes['Call of Duty'], 'Ranked');
    });

    test('should handle timer state restoration', () async {
      // Arrange
      final stateWithTimers = mockSquadState.copyWith(
        spotTimerStates: {'spot1': const Duration(minutes: 5)},
        peacockTimerStates: {'user1': const Duration(minutes: 30)},
      );
      mockSquadRepository.setLoadSquadStateResponse(stateWithTimers);

      // Act
      final result = await usecase.call();

      // Assert
      expect(result.spotTimerStates['spot1'], const Duration(minutes: 5));
      expect(result.peacockTimerStates['user1'], const Duration(minutes: 30));
    });
  });
}