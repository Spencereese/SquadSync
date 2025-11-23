import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';
import 'package:squad_sync/data/datasources/squad_local_datasource.dart';
import 'package:squad_sync/domain/entities/squad_state.dart';
import '../../helpers/mocks.mocks.dart';

void main() {
  late SquadLocalDataSourceImpl datasource;
  late MockSharedPreferences mockPrefs;
  late MockSQLiteHelper mockSQLiteHelper;

  setUp(() {
    mockPrefs = MockSharedPreferences();
    mockSQLiteHelper = MockSQLiteHelper();
    datasource = SquadLocalDataSourceImpl(mockPrefs, mockSQLiteHelper);
  });

  group('SquadLocalDataSourceImpl', () {
    group('loadSquadState', () {
      test('should load complete squad state from SharedPreferences', () async {
        // Arrange
        final expectedState = SquadState(
          isInitialized: true,
          isInitialDataLoaded: true,
          displayName: 'Test User',
          profileImage: null,
          memberProfileImages: {},
          gameSquadSpots: {'cod': ['uid1', null, 'uid2']},
          gameSpotTimers: {'cod': [null, {'userId': 'uid2', 'startTime': DateTime.now().toIso8601String(), 'duration': 300000}, null]},
          gameStatuses: {'cod': {'uid1': 'Ready', 'uid2': 'Walking'}},
          globalStatuses: {},
          squadMemberUids: ['uid1', 'uid2'],
          memberDisplayNames: {'uid1': 'Player1', 'uid2': 'Player2'},
          userSquadIds: ['squad123'],
          selectedSquadId: 'squad123',
          userSquads: {},
          currentSquadData: null,
          typing: {},
          tiltEnabled: false,
          hasNewSquadSpot: false,
          hasUnreadMessages: false,
          gameHistory: [],
          preferredModes: {},
          userBlocks: {},
          dailyBanVotes: {},
          bans: {},
          availableGames: [],
          gameLobbies: {},
          preferredPeacockGames: {},
          mutedGames: {},
          hiddenGames: {},
          peacockTimers: {},
          peacockQueue: ['uid3', 'uid4'],
          scheduledTimes: [],
          hasNewAvailability: false,
          spotTimerStates: {},
          peacockTimerStates: {},
          lastSyncTimestamp: DateTime.now(),
          analyticsMetrics: {},
        );
        when(mockPrefs.getString('squad_state')).thenReturn(jsonEncode(expectedState.toJson()));

        // Act
        final result = await datasource.loadSquadState();

        // Assert
        expect(result, isNotNull);
        expect(result!.selectedSquadId, expectedState.selectedSquadId);
        expect(result.gameSquadSpots, expectedState.gameSquadSpots);
        expect(result.gameSpotTimers, expectedState.gameSpotTimers);
        expect(result.gameStatuses, expectedState.gameStatuses);
        expect(result.peacockQueue, expectedState.peacockQueue);
        expect(result.peacockTimers, expectedState.peacockTimers);
        expect(result.memberDisplayNames, expectedState.memberDisplayNames);
      });

      test('should return null when SharedPreferences is empty', () async {
        // Arrange
        when(mockPrefs.getString('squad_state')).thenReturn(null);

        // Act
        final result = await datasource.loadSquadState();

        // Assert
        expect(result, isNull);
      });

      test('should return null when stored JSON is corrupted', () async {
        // Arrange
        when(mockPrefs.getString('squad_state')).thenReturn('invalid json');

        // Act
        final result = await datasource.loadSquadState();

        // Assert
        expect(result, isNull);
      });
    });

    group('saveSquadState', () {
      test('should serialize and store squad state as JSON', () async {
        // Arrange
        final state = SquadState(
          isInitialized: true,
          isInitialDataLoaded: true,
          displayName: 'Test User',
          profileImage: null,
          memberProfileImages: {},
          gameSquadSpots: {'cod': ['uid1', null, 'uid2']},
          gameSpotTimers: {'cod': [null, null, null]},
          gameStatuses: {'cod': {'uid1': 'Ready'}},
          globalStatuses: {},
          squadMemberUids: ['uid1', 'uid2'],
          memberDisplayNames: {'uid1': 'Player1'},
          userSquadIds: ['squad123'],
          selectedSquadId: 'squad123',
          userSquads: {},
          currentSquadData: null,
          typing: {},
          tiltEnabled: false,
          hasNewSquadSpot: false,
          hasUnreadMessages: false,
          gameHistory: [],
          preferredModes: {},
          userBlocks: {},
          dailyBanVotes: {},
          bans: {},
          availableGames: [],
          gameLobbies: {},
          preferredPeacockGames: {},
          mutedGames: {},
          hiddenGames: {},
          peacockTimers: {},
          peacockQueue: [],
          scheduledTimes: [],
          hasNewAvailability: false,
          spotTimerStates: {},
          peacockTimerStates: {},
          lastSyncTimestamp: DateTime.now(),
          analyticsMetrics: {},
        );

        // Act
        await datasource.saveSquadState(state);

        // Assert
        verify(mockPrefs.setString('squad_state', jsonEncode(state.toJson()))).called(1);
      });
    });

    /*
    group('saveSquad', () {
      test('should insert squad into SQLite database', () async {
        // Arrange
        final squad = Squad(
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

        // Act
        await datasource.saveSquad(squad);

        // Assert
        verify(mockSQLiteHelper.insertSquad(squad.toJson())).called(1);
      });
    });
    */

    /*
    group('getSquad', () {
      test('should return squad from SQLite database', () async {
        // Arrange
        final squad = Squad(
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
        when(mockSQLiteHelper.getSquad('squad123')).thenAnswer((_) async => squad.toJson());

        // Act
        final result = await datasource.getSquad('squad123');

        // Assert
        expect(result, squad);
        verify(mockSQLiteHelper.getSquad('squad123')).called(1);
      });

      test('should return null when squad not found', () async {
        // Arrange
        when(mockSQLiteHelper.getSquad('nonexistent')).thenAnswer((_) async => null);

        // Act
        final result = await datasource.getSquad('nonexistent');

        // Assert
        expect(result, isNull);
      });
    });
    */

    /*
    group('getUserSquads', () {
      test('should return user squads from SQLite database', () async {
        // Arrange
        final squads = [
          Squad(
            id: 'squad123',
            name: 'Test Squad 1',
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
          ),
          Squad(
            id: 'squad456',
            name: 'Test Squad 2',
            memberUids: ['uid1', 'uid3'],
            gameName: 'valorant',
            maxSpots: 5,
            createdBy: 'uid1',
            createdAt: DateTime.now(),
            spots: [null, null, null, null, null],
            spotTimers: [null, null, null, null, null],
            viewers: [],
            statuses: {},
            isActive: true,
          ),
        ];
        when(mockSQLiteHelper.getUserSquads('uid1')).thenAnswer((_) async => squads.map((s) => s.toJson()).toList());

        // Act
        final result = await datasource.getUserSquads('uid1');

        // Assert
        expect(result, squads);
        verify(mockSQLiteHelper.getUserSquads('uid1')).called(1);
      });

      test('should return empty list when no squads found', () async {
        // Arrange
        when(mockSQLiteHelper.getUserSquads('uid1')).thenAnswer((_) async => []);

        // Act
        final result = await datasource.getUserSquads('uid1');

        // Assert
        expect(result, isEmpty);
      });
    });
    */

    /*
    group('deleteSquad', () {
      test('should delete squad from SQLite database', () async {
        // Arrange
        when(mockSQLiteHelper.deleteSquad('squad123')).thenAnswer((_) async => 1);

        // Act
        await datasource.deleteSquad('squad123');

        // Assert
        verify(mockSQLiteHelper.deleteSquad('squad123')).called(1);
      });
    });

    group('purgeOldData', () {
      test('should purge old squads from SQLite database', () async {
        // Arrange
        final cutoffDate = DateTime.now().subtract(Duration(days: 30));
        when(mockSQLiteHelper.purgeOldSquads(cutoffDate)).thenAnswer((_) async => 5);

        // Act
        await datasource.purgeOldData();

        // Assert
        verify(mockSQLiteHelper.purgeOldSquads(argThat(isA<DateTime>()))).called(1);
      });
    });
    */
  });
}

// Mock class for Database
class MockDatabase extends Mock implements Database {}