import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:squad_sync/data/datasources/squad_remote_datasource.dart';
import 'package:squad_sync/domain/entities/squad.dart';
import '../../helpers/mocks.mocks.dart';

void main() {
  late SquadRemoteDataSourceImpl datasource;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseAuth mockAuth;
  late MockCollectionReference<Map<String, dynamic>> mockSquadsCollection;
  late MockDocumentReference<Map<String, dynamic>> mockSquadDoc;
  late MockDocumentSnapshot<Map<String, dynamic>> mockSquadSnapshot;
  late MockQuery<Map<String, dynamic>> mockQuery;
  late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
  late MockQueryDocumentSnapshot<Map<String, dynamic>> mockQueryDoc;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockSquadsCollection = MockCollectionReference();
    mockSquadDoc = MockDocumentReference();
    mockSquadSnapshot = MockDocumentSnapshot();
    mockQuery = MockQuery();
    mockQuerySnapshot = MockQuerySnapshot();
    mockQueryDoc = MockQueryDocumentSnapshot();

    // Setup Firestore mocks
    when(mockFirestore.collection('squads')).thenReturn(mockSquadsCollection);
    when(mockSquadsCollection.doc(any)).thenReturn(mockSquadDoc);
    when(mockSquadDoc.get()).thenAnswer((_) async => mockSquadSnapshot);

    datasource = SquadRemoteDataSourceImpl(mockFirestore, mockAuth);
  });

  group('SquadRemoteDataSourceImpl', () {
    group('createSquad', () {
      test('should create squad and return it with server-generated ID', () async {
        // Arrange
        final squad = Squad(
          id: 'temp_id',
          name: 'Test Squad',
          memberUids: ['uid1'],
          gameName: 'cod',
          maxSpots: 4,
          createdBy: 'uid1',
          createdAt: DateTime.now(),
          spots: [null, null, null, null],
          spotTimers: [null, null, null, null],
          viewers: [],
          statuses: {},
          isActive: true,
        );

        final serverId = 'server_generated_id';
        when(mockSquadDoc.id).thenReturn(serverId);
        when(mockSquadsCollection.add(any)).thenAnswer((_) async => mockSquadDoc);

        // Act
        final result = await datasource.createSquad(squad);

        // Assert
        expect(result.id, serverId);
        expect(result.name, squad.name);
        expect(result.memberUids, squad.memberUids);
        verify(mockSquadsCollection.add(any)).called(1);
      });

      test('should handle Firestore errors', () async {
        // Arrange
        final squad = Squad(
          id: 'temp_id',
          name: 'Test Squad',
          memberUids: ['uid1'],
          gameName: 'cod',
          maxSpots: 4,
          createdBy: 'uid1',
          createdAt: DateTime.now(),
          spots: [null, null, null, null],
          spotTimers: [null, null, null, null],
          viewers: [],
          statuses: {},
          isActive: true,
        );

        when(mockSquadsCollection.add(any)).thenThrow(FirebaseException(plugin: 'firestore', message: 'Network error'));

        // Act & Assert
        expect(() => datasource.createSquad(squad), throwsA(isA<FirebaseException>()));
      });
    });

    group('getSquad', () {
      test('should return squad when document exists', () async {
        // Arrange
        const squadId = 'squad123';
        final squadData = {
          'id': squadId,
          'name': 'Test Squad',
          'memberUids': ['uid1', 'uid2'],
          'gameName': 'cod',
          'maxSpots': 4,
          'createdBy': 'uid1',
          'createdAt': DateTime.now(),
          'spots': [null, 'uid1', null, null],
          'spotTimers': [null, null, null, null],
          'viewers': [],
          'statuses': {},
          'isActive': true,
        };

        when(mockSquadSnapshot.exists).thenReturn(true);
        when(mockSquadSnapshot.data()).thenReturn(squadData);

        // Act
        final result = await datasource.getSquad(squadId);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, squadId);
        expect(result.name, 'Test Squad');
        verify(mockSquadDoc.get()).called(1);
      });

      test('should return null when document does not exist', () async {
        // Arrange
        when(mockSquadSnapshot.exists).thenReturn(false);

        // Act
        final result = await datasource.getSquad('nonexistent');

        // Assert
        expect(result, isNull);
      });
    });

    group('getUserSquads', () {
      test('should return squads where user is a member', () async {
        // Arrange
        final mockQuery = MockQuery();
        final mockQuerySnapshot = MockQuerySnapshot();
        final mockQueryDoc = MockQueryDocumentSnapshot();

        when(mockSquadsCollection.where('memberUids', arrayContains: 'uid1')).thenReturn(mockQuery);
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([mockQueryDoc]);

        final squadData = {
          'id': 'squad123',
          'name': 'Test Squad',
          'memberUids': ['uid1', 'uid2'],
          'gameName': 'cod',
          'maxSpots': 4,
          'createdBy': 'uid1',
          'createdAt': DateTime.now(),
          'spots': [null, null, null, null],
          'spotTimers': [null, null, null, null],
          'viewers': [],
          'statuses': {},
          'isActive': true,
        };

        when(mockQueryDoc.data()).thenReturn(squadData);

        // Act
        final result = await datasource.getUserSquads('uid1');

        // Assert
        expect(result, hasLength(1));
        expect(result.first.id, 'squad123');
        verify(mockSquadsCollection.where('memberUids', arrayContains: 'uid1')).called(1);
      });
    });

    group('updateSquad', () {
      test('should update squad document', () async {
        // Arrange
        final squad = Squad(
          id: 'squad123',
          name: 'Updated Squad',
          memberUids: ['uid1', 'uid2'],
          gameName: 'cod',
          maxSpots: 4,
          createdBy: 'uid1',
          createdAt: DateTime.now(),
          spots: ['uid1', null, null, null],
          spotTimers: [null, null, null, null],
          viewers: [],
          statuses: {},
          isActive: true,
        );

        when(mockSquadDoc.update(any)).thenAnswer((_) async => {});

        // Act
        await datasource.updateSquad(squad);

        // Assert
        verify(mockSquadDoc.update(any)).called(1);
      });
    });

    group('deleteSquad', () {
      test('should delete squad document', () async {
        // Arrange
        when(mockSquadDoc.delete()).thenAnswer((_) async => {});

        // Act
        await datasource.deleteSquad('squad123');

        // Assert
        verify(mockSquadDoc.delete()).called(1);
      });
    });

    group('joinSquad', () {
      test('should add user to memberUids array', () async {
        // Arrange
        when(mockSquadDoc.update(any)).thenAnswer((_) async => {});

        // Act
        await datasource.joinSquad('squad123', 'uid1');

        // Assert
        verify(mockSquadDoc.update({
          'memberUids': FieldValue.arrayUnion(['uid1'])
        })).called(1);
      });
    });

    group('leaveSquad', () {
      test('should remove user from memberUids array', () async {
        // Arrange
        when(mockSquadDoc.update(any)).thenAnswer((_) async => {});

        // Act
        await datasource.leaveSquad('squad123', 'uid1');

        // Assert
        verify(mockSquadDoc.update({
          'memberUids': FieldValue.arrayRemove(['uid1'])
        })).called(1);
      });
    });

    group('assignSpot', () {
      test('should update spot at specific index', () async {
        // Arrange
        when(mockSquadDoc.update(any)).thenAnswer((_) async => {});

        // Act
        await datasource.assignSpot('squad123', 1, 'uid1');

        // Assert
        verify(mockSquadDoc.update({
          'spots': {1: 'uid1'}
        })).called(1);
      });

      test('should clear spot when userId is null', () async {
        // Arrange
        when(mockSquadDoc.update(any)).thenAnswer((_) async => {});

        // Act
        await datasource.assignSpot('squad123', 1, null);

        // Assert
        verify(mockSquadDoc.update({
          'spots': {1: null}
        })).called(1);
      });
    });

    group('startSpotTimer', () {
      test('should set timer data at specific index', () async {
        // Arrange
        final duration = Duration(minutes: 5);
        final timerData = {
          'userId': 'uid1',
          'startTime': DateTime.now().toIso8601String(),
          'duration': duration.inMilliseconds,
        };

        when(mockSquadDoc.update(any)).thenAnswer((_) async => {});

        // Act
        await datasource.startSpotTimer('squad123', 1, duration);

        // Assert
        verify(mockSquadDoc.update({
          'spotTimers': {1: timerData}
        })).called(1);
      });
    });

    group('cancelSpotTimer', () {
      test('should clear timer at specific index', () async {
        // Arrange
        when(mockSquadDoc.update(any)).thenAnswer((_) async => {});

        // Act
        await datasource.cancelSpotTimer('squad123', 1);

        // Assert
        verify(mockSquadDoc.update({
          'spotTimers': {1: null}
        })).called(1);
      });
    });
  });
}