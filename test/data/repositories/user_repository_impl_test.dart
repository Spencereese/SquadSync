import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:squad_sync/data/repositories/user_repository_impl.dart';
import 'package:squad_sync/domain/entities/app_user.dart';
import '../../helpers/mocks.mocks.dart';

void main() {
  late UserRepositoryImpl repository;
  late MockUserLocalDataSourceImpl mockLocalDatasource;
  late MockUserRemoteDataSourceImpl mockRemoteDatasource;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockUser mockUser;
  late MockDocumentReference<Map<String, dynamic>> mockDocRef;

  setUp(() {
    mockLocalDatasource = MockUserLocalDataSourceImpl();
    mockRemoteDatasource = MockUserRemoteDataSourceImpl();
    mockFirebaseAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockDocRef = MockDocumentReference();

    // Setup Firebase Auth mock
    when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test-uid');

    repository = UserRepositoryImpl(mockLocalDatasource, mockRemoteDatasource);
  });

  group('UserRepositoryImpl', () {
    const testUid = 'test-uid';
    const testName = 'Test User';
    const testImageUrl = 'https://example.com/image.jpg';

    final testUser = AppUser(
      uid: testUid,
      displayName: testName,
      profileImageUrl: testImageUrl,
      pinnedGames: [],
      blockedUsers: [],
      achievements: {},
    );

    group('getCurrentUser', () {
      test('should return AppUser when Firebase user exists and profile loaded', () async {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.uid).thenReturn(testUid);
        when(mockRemoteDatasource.getUserProfile(testUid)).thenAnswer((_) async => testUser);

        // Act
        final result = await repository.getCurrentUser();

        // Assert
        expect(result, testUser);
        verify(mockFirebaseAuth.currentUser).called(1);
        verify(mockRemoteDatasource.getUserProfile(testUid)).called(1);
      });

      test('should return null when Firebase user is null', () async {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(null);

        // Act
        final result = await repository.getCurrentUser();

        // Assert
        expect(result, isNull);
        verify(mockFirebaseAuth.currentUser).called(1);
        verifyNever(mockRemoteDatasource.getUserProfile(any));
      });

      test('should return null when profile is null', () async {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.uid).thenReturn(testUid);
        when(mockRemoteDatasource.getUserProfile(testUid)).thenAnswer((_) async => null);

        // Act
        final result = await repository.getCurrentUser();

        // Assert
        expect(result, isNull);
        verify(mockFirebaseAuth.currentUser).called(1);
        verify(mockRemoteDatasource.getUserProfile(testUid)).called(1);
      });

      test('should propagate exceptions from remote datasource', () async {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.uid).thenReturn(testUid);
        when(mockRemoteDatasource.getUserProfile(testUid))
            .thenThrow(FirebaseException(plugin: 'firestore', message: 'Network error'));

        // Act & Assert
        expect(
          () => repository.getCurrentUser(),
          throwsA(isA<FirebaseException>()),
        );
      });
    });

    group('updateDisplayName', () {
      test('should call remote datasource updateUserProfile with display name', () async {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.uid).thenReturn(testUid);
        when(mockRemoteDatasource.updateUserProfile(testUid, displayName: testName))
            .thenAnswer((_) async => Future.value());

        // Act
        await repository.updateDisplayName(testName);

        // Assert
        verify(mockFirebaseAuth.currentUser).called(1);
        verify(mockRemoteDatasource.updateUserProfile(testUid, displayName: testName)).called(1);
      });

      test('should handle special characters in display name', () async {
        // Arrange
        const specialName = 'Test User 🚀🎮';
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.uid).thenReturn(testUid);
        when(mockRemoteDatasource.updateUserProfile(testUid, displayName: specialName))
            .thenAnswer((_) async => Future.value());

        // Act
        await repository.updateDisplayName(specialName);

        // Assert
        verify(mockRemoteDatasource.updateUserProfile(testUid, displayName: specialName)).called(1);
      });

      test('should propagate exceptions from remote datasource', () async {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.uid).thenReturn(testUid);
        when(mockRemoteDatasource.updateUserProfile(testUid, displayName: testName))
            .thenThrow(FirebaseException(plugin: 'firestore', message: 'Permission denied'));

        // Act & Assert
        expect(
          () => repository.updateDisplayName(testName),
          throwsA(isA<FirebaseException>()),
        );
      });

      test('should throw exception when user is not authenticated', () async {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(null);

        // Act & Assert
        expect(
          () => repository.updateDisplayName(testName),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('updateProfileImage', () {
      test('should update both remote and local datasources', () async {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.uid).thenReturn(testUid);
        when(mockRemoteDatasource.updateUserProfile(testUid, profileImageUrl: testImageUrl))
            .thenAnswer((_) async => Future.value());
        when(mockLocalDatasource.setProfileImage(testImageUrl))
            .thenAnswer((_) async => Future.value());

        // Act
        await repository.updateProfileImage(testImageUrl);

        // Assert
        verify(mockFirebaseAuth.currentUser).called(1);
        verify(mockRemoteDatasource.updateUserProfile(testUid, profileImageUrl: testImageUrl)).called(1);
        verify(mockLocalDatasource.setProfileImage(testImageUrl)).called(1);
      });

      test('should propagate exceptions from remote datasource', () async {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.uid).thenReturn(testUid);
        when(mockRemoteDatasource.updateUserProfile(testUid, profileImageUrl: testImageUrl))
            .thenThrow(FirebaseException(plugin: 'firestore', message: 'Storage error'));
        when(mockLocalDatasource.setProfileImage(testImageUrl))
            .thenAnswer((_) async => Future.value());

        // Act & Assert
        expect(
          () => repository.updateProfileImage(testImageUrl),
          throwsA(isA<FirebaseException>()),
        );
      });
    });

    group('blockUser', () {
      test('should call remote datasource to block user', () async {
        // Arrange
        const blockedUserName = 'blocked-user';
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.uid).thenReturn(testUid);
        when(mockRemoteDatasource.blockUser(testUid, blockedUserName))
            .thenAnswer((_) async => Future.value());

        // Act
        await repository.blockUser(blockedUserName);

        // Assert
        verify(mockFirebaseAuth.currentUser).called(1);
        verify(mockRemoteDatasource.blockUser(testUid, blockedUserName)).called(1);
      });

      test('should propagate exceptions from remote datasource', () async {
        // Arrange
        const blockedUserName = 'blocked-user';
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.uid).thenReturn(testUid);
        when(mockRemoteDatasource.blockUser(testUid, blockedUserName))
            .thenThrow(FirebaseException(plugin: 'firestore', message: 'Block failed'));

        // Act & Assert
        expect(
          () => repository.blockUser(blockedUserName),
          throwsA(isA<FirebaseException>()),
        );
      });
    });

    group('unblockUser', () {
      test('should call remote datasource to unblock user', () async {
        // Arrange
        const unblockedUserName = 'unblocked-user';
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.uid).thenReturn(testUid);
        when(mockRemoteDatasource.unblockUser(testUid, unblockedUserName))
            .thenAnswer((_) async => Future.value());

        // Act
        await repository.unblockUser(unblockedUserName);

        // Assert
        verify(mockFirebaseAuth.currentUser).called(1);
        verify(mockRemoteDatasource.unblockUser(testUid, unblockedUserName)).called(1);
      });
    });

    group('addPinnedGame', () {
      test('should add game to pinned games list', () async {
        // Arrange
        final game = {'id': 'game1', 'name': 'Game One'};
        final existingGames = [{'id': 'game2', 'name': 'Game Two'}];

        when(mockLocalDatasource.getPinnedGames())
            .thenAnswer((_) async => existingGames);
        when(mockLocalDatasource.setPinnedGames(any))
            .thenAnswer((_) async => Future.value());

        // Act
        await repository.addPinnedGame(game);

        // Assert
        verify(mockLocalDatasource.getPinnedGames()).called(1);
        verify(mockLocalDatasource.setPinnedGames([
          {'id': 'game2', 'name': 'Game Two'},
          {'id': 'game1', 'name': 'Game One'}
        ])).called(1);
      });

      test('should handle empty existing games list', () async {
        // Arrange
        final game = {'id': 'game1', 'name': 'Game One'};
        when(mockLocalDatasource.getPinnedGames())
            .thenAnswer((_) async => []);
        when(mockLocalDatasource.setPinnedGames(any))
            .thenAnswer((_) async => Future.value());

        // Act
        await repository.addPinnedGame(game);

        // Assert
        verify(mockLocalDatasource.setPinnedGames([game])).called(1);
      });
    });

    group('removePinnedGame', () {
      test('should remove game from pinned games list', () async {
        // Arrange
        final existingGames = [
          {'id': 'game1', 'name': 'Game One'},
          {'id': 'game2', 'name': 'Game Two'}
        ];

        when(mockLocalDatasource.getPinnedGames())
            .thenAnswer((_) async => existingGames);
        when(mockLocalDatasource.setPinnedGames(any))
            .thenAnswer((_) async => Future.value());

        // Act
        await repository.removePinnedGame('Game One');

        // Assert
        verify(mockLocalDatasource.getPinnedGames()).called(1);
        verify(mockLocalDatasource.setPinnedGames([
          {'id': 'game2', 'name': 'Game Two'}
        ])).called(1);
      });

      test('should handle game not found in list', () async {
        // Arrange
        final existingGames = [{'id': 'game1', 'name': 'Game One'}];
        when(mockLocalDatasource.getPinnedGames())
            .thenAnswer((_) async => existingGames);
        when(mockLocalDatasource.setPinnedGames(any))
            .thenAnswer((_) async => Future.value());

        // Act
        await repository.removePinnedGame('Nonexistent Game');

        // Assert
        verify(mockLocalDatasource.setPinnedGames(existingGames)).called(1);
      });
    });
  });
}