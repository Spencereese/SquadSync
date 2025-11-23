import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:squad_sync/data/repositories/squad_repository_impl.dart';
import 'package:squad_sync/domain/entities/squad.dart';
import 'package:squad_sync/core/error/failures.dart';
import '../../helpers/mocks.mocks.dart';

void main() {
  late SquadRepositoryImpl repository;
  late MockSquadLocalDataSource mockLocalDataSource;
  late MockSquadRemoteDataSource mockRemoteDataSource;

  setUp(() {
    mockLocalDataSource = MockSquadLocalDataSource();
    mockRemoteDataSource = MockSquadRemoteDataSource();
    repository = SquadRepositoryImpl(
      localDataSource: mockLocalDataSource,
      remoteDataSource: mockRemoteDataSource,
    );
  });

  group('SquadRepositoryImpl', () {
    final testSquad = Squad(
      id: 'squad123',
      name: 'Test Squad',
      memberUids: ['uid1', 'uid2'],
      gameName: 'cod',
      maxSpots: 4,
      createdBy: 'uid1',
      createdAt: DateTime.now(),
      spots: [null, 'uid1', null, null],
      spotTimers: [null, null, null, null],
      viewers: [],
      statuses: {},
      isActive: true,
    );

    group('createSquad', () {
      test('should create squad remotely and cache locally', () async {
        // Arrange
        final createdSquad = testSquad.copyWith(id: 'remote_id');
        when(mockRemoteDataSource.createSquad(testSquad)).thenAnswer((_) async => createdSquad);
        when(mockLocalDataSource.saveSquad(createdSquad)).thenAnswer((_) async => {});

        // Act
        final result = await repository.createSquad(testSquad);

        // Assert
        expect(result, Right(createdSquad));
        verify(mockRemoteDataSource.createSquad(testSquad)).called(1);
        verify(mockLocalDataSource.saveSquad(createdSquad)).called(1);
      });

      test('should return failure when remote creation fails', () async {
        // Arrange
        when(mockRemoteDataSource.createSquad(testSquad)).thenThrow(Exception('Network error'));

        // Act
        final result = await repository.createSquad(testSquad);

        // Assert
        expect(result, isA<Left<Failure, Squad>>());
        verifyNever(mockLocalDataSource.saveSquad(any));
      });
    });

    group('getSquad', () {
      test('should return cached squad when available', () async {
        // Arrange
        when(mockLocalDataSource.getSquad('squad123')).thenAnswer((_) async => testSquad);

        // Act
        final result = await repository.getSquad('squad123');

        // Assert
        expect(result, Right(testSquad));
        verify(mockLocalDataSource.getSquad('squad123')).called(1);
        verifyNever(mockRemoteDataSource.getSquad(any));
      });

      test('should fetch from remote when not cached and cache result', () async {
        // Arrange
        when(mockLocalDataSource.getSquad('squad123')).thenAnswer((_) async => null);
        when(mockRemoteDataSource.getSquad('squad123')).thenAnswer((_) async => testSquad);
        when(mockLocalDataSource.saveSquad(testSquad)).thenAnswer((_) async => {});

        // Act
        final result = await repository.getSquad('squad123');

        // Assert
        expect(result, Right(testSquad));
        verify(mockLocalDataSource.getSquad('squad123')).called(1);
        verify(mockRemoteDataSource.getSquad('squad123')).called(1);
        verify(mockLocalDataSource.saveSquad(testSquad)).called(1);
      });

      test('should return failure when both local and remote fail', () async {
        // Arrange
        when(mockLocalDataSource.getSquad('squad123')).thenAnswer((_) async => null);
        when(mockRemoteDataSource.getSquad('squad123')).thenThrow(Exception('Network error'));

        // Act
        final result = await repository.getSquad('squad123');

        // Assert
        expect(result, isA<Left<Failure, Squad>>());
      });
    });

    group('getUserSquads', () {
      test('should return cached user squads when available', () async {
        // Arrange
        final squads = [testSquad];
        when(mockLocalDataSource.getUserSquads('uid1')).thenAnswer((_) async => squads);

        // Act
        final result = await repository.getUserSquads('uid1');

        // Assert
        expect(result, Right(squads));
        verify(mockLocalDataSource.getUserSquads('uid1')).called(1);
        verifyNever(mockRemoteDataSource.getUserSquads(any));
      });

      test('should fetch from remote when not cached and cache results', () async {
        // Arrange
        final squads = [testSquad];
        when(mockLocalDataSource.getUserSquads('uid1')).thenAnswer((_) async => []);
        when(mockRemoteDataSource.getUserSquads('uid1')).thenAnswer((_) async => squads);
        when(mockLocalDataSource.saveSquad(testSquad)).thenAnswer((_) async => {});

        // Act
        final result = await repository.getUserSquads('uid1');

        // Assert
        expect(result, Right(squads));
        verify(mockLocalDataSource.getUserSquads('uid1')).called(1);
        verify(mockRemoteDataSource.getUserSquads('uid1')).called(1);
        verify(mockLocalDataSource.saveSquad(testSquad)).called(1);
      });
    });

    group('updateSquad', () {
      test('should update remotely and cache locally', () async {
        // Arrange
        when(mockRemoteDataSource.updateSquad(testSquad)).thenAnswer((_) async => {});
        when(mockLocalDataSource.saveSquad(testSquad)).thenAnswer((_) async => {});

        // Act
        final result = await repository.updateSquad(testSquad);

        // Assert
        expect(result, const Right(unit));
        verify(mockRemoteDataSource.updateSquad(testSquad)).called(1);
        verify(mockLocalDataSource.saveSquad(testSquad)).called(1);
      });

      test('should return failure when remote update fails', () async {
        // Arrange
        when(mockRemoteDataSource.updateSquad(testSquad)).thenThrow(Exception('Network error'));

        // Act
        final result = await repository.updateSquad(testSquad);

        // Assert
        expect(result, isA<Left<Failure, Unit>>());
        verifyNever(mockLocalDataSource.saveSquad(any));
      });
    });

    group('deleteSquad', () {
      test('should delete from both local and remote', () async {
        // Arrange
        when(mockRemoteDataSource.deleteSquad('squad123')).thenAnswer((_) async => {});
        when(mockLocalDataSource.deleteSquad('squad123')).thenAnswer((_) async => {});

        // Act
        final result = await repository.deleteSquad('squad123');

        // Assert
        expect(result, const Right(unit));
        verify(mockRemoteDataSource.deleteSquad('squad123')).called(1);
        verify(mockLocalDataSource.deleteSquad('squad123')).called(1);
      });
    });

    group('joinSquad', () {
      test('should join remotely and update local cache', () async {
        // Arrange
        when(mockRemoteDataSource.joinSquad('squad123', 'uid1')).thenAnswer((_) async => {});
        when(mockRemoteDataSource.getSquad('squad123')).thenAnswer((_) async => testSquad);
        when(mockLocalDataSource.saveSquad(testSquad)).thenAnswer((_) async => {});

        // Act
        final result = await repository.joinSquad('squad123', 'uid1');

        // Assert
        expect(result, const Right(unit));
        verify(mockRemoteDataSource.joinSquad('squad123', 'uid1')).called(1);
        verify(mockRemoteDataSource.getSquad('squad123')).called(1);
        verify(mockLocalDataSource.saveSquad(testSquad)).called(1);
      });
    });

    group('leaveSquad', () {
      test('should leave remotely and update local cache', () async {
        // Arrange
        when(mockRemoteDataSource.leaveSquad('squad123', 'uid1')).thenAnswer((_) async => {});
        when(mockRemoteDataSource.getSquad('squad123')).thenAnswer((_) async => testSquad);
        when(mockLocalDataSource.saveSquad(testSquad)).thenAnswer((_) async => {});

        // Act
        final result = await repository.leaveSquad('squad123', 'uid1');

        // Assert
        expect(result, const Right(unit));
        verify(mockRemoteDataSource.leaveSquad('squad123', 'uid1')).called(1);
        verify(mockRemoteDataSource.getSquad('squad123')).called(1);
        verify(mockLocalDataSource.saveSquad(testSquad)).called(1);
      });
    });

    group('assignSpot', () {
      test('should assign spot remotely and update local cache', () async {
        // Arrange
        when(mockRemoteDataSource.assignSpot('squad123', 1, 'uid1')).thenAnswer((_) async => {});
        when(mockRemoteDataSource.getSquad('squad123')).thenAnswer((_) async => testSquad);
        when(mockLocalDataSource.saveSquad(testSquad)).thenAnswer((_) async => {});

        // Act
        final result = await repository.assignSpot('squad123', 1, 'uid1');

        // Assert
        expect(result, const Right(unit));
        verify(mockRemoteDataSource.assignSpot('squad123', 1, 'uid1')).called(1);
        verify(mockRemoteDataSource.getSquad('squad123')).called(1);
        verify(mockLocalDataSource.saveSquad(testSquad)).called(1);
      });
    });

    group('startSpotTimer', () {
      test('should start timer remotely and update local cache', () async {
        // Arrange
        final duration = Duration(minutes: 5);
        when(mockRemoteDataSource.startSpotTimer('squad123', 1, duration)).thenAnswer((_) async => {});
        when(mockRemoteDataSource.getSquad('squad123')).thenAnswer((_) async => testSquad);
        when(mockLocalDataSource.saveSquad(testSquad)).thenAnswer((_) async => {});

        // Act
        final result = await repository.startSpotTimer('squad123', 1, duration);

        // Assert
        expect(result, const Right(unit));
        verify(mockRemoteDataSource.startSpotTimer('squad123', 1, duration)).called(1);
        verify(mockRemoteDataSource.getSquad('squad123')).called(1);
        verify(mockLocalDataSource.saveSquad(testSquad)).called(1);
      });
    });

    group('cancelSpotTimer', () {
      test('should cancel timer remotely and update local cache', () async {
        // Arrange
        when(mockRemoteDataSource.cancelSpotTimer('squad123', 1)).thenAnswer((_) async => {});
        when(mockRemoteDataSource.getSquad('squad123')).thenAnswer((_) async => testSquad);
        when(mockLocalDataSource.saveSquad(testSquad)).thenAnswer((_) async => {});

        // Act
        final result = await repository.cancelSpotTimer('squad123', 1);

        // Assert
        expect(result, const Right(unit));
        verify(mockRemoteDataSource.cancelSpotTimer('squad123', 1)).called(1);
        verify(mockRemoteDataSource.getSquad('squad123')).called(1);
        verify(mockLocalDataSource.saveSquad(testSquad)).called(1);
      });
    });

    group('purgeOldData', () {
      test('should purge old data from local storage', () async {
        // Arrange
        when(mockLocalDataSource.purgeOldData()).thenAnswer((_) async => {});

        // Act
        final result = await repository.purgeOldData();

        // Assert
        expect(result, const Right(unit));
        verify(mockLocalDataSource.purgeOldData()).called(1);
      });
    });
  });
}