import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/data/datasources/user_remote_datasource.dart';
import '../../helpers/mocks.mocks.dart';

void main() {
  late UserRemoteDataSourceImpl datasource;
  late MockFirebaseFirestore mockFirestore;
  late MockDocumentReference<Map<String, dynamic>> mockDocRef;
  late MockDocumentSnapshot<Map<String, dynamic>> mockDocSnapshot;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockDocRef = MockDocumentReference();
    mockDocSnapshot = MockDocumentSnapshot();
    datasource = UserRemoteDataSourceImpl(mockFirestore);
  });

  group('UserRemoteDataSourceImpl', () {
    const testUid = 'test-uid';

    group('getUserProfile', () {
      test('should return user profile data when document exists', () async {
        // Arrange
        final profileData = {'displayName': 'Test User', 'profileImage': 'url'};
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockQuery = MockQuery<Map<String, dynamic>>();
        final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();

        when(mockFirestore.collection('users')).thenReturn(mockCollection);
        when(mockCollection.doc(testUid)).thenReturn(mockDocRef);
        when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
        when(mockDocSnapshot.exists).thenReturn(true);
        when(mockDocSnapshot.data()).thenReturn(profileData);

        // Act
        final result = await datasource.getUserProfile(testUid);

        // Assert
        expect(result, profileData);
        verify(mockFirestore.collection('users')).called(1);
        verify(mockCollection.doc(testUid)).called(1);
      });

      test('should return null when document does not exist', () async {
        // Arrange
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();

        when(mockFirestore.collection('users')).thenReturn(mockCollection);
        when(mockCollection.doc(testUid)).thenReturn(mockDocRef);
        when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
        when(mockDocSnapshot.exists).thenReturn(false);

        // Act
        final result = await datasource.getUserProfile(testUid);

        // Assert
        expect(result, null);
      });
    });

    group('updateUserProfile', () {
      test('should update user profile in Firestore', () async {
        // Arrange
        final updateData = {'displayName': 'Updated Name'};
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();

        when(mockFirestore.collection('users')).thenReturn(mockCollection);
        when(mockCollection.doc(testUid)).thenReturn(mockDocRef);
        when(mockDocRef.update(updateData)).thenAnswer((_) async => Future.value());

        // Act
        await datasource.updateUserProfile(testUid, updateData);

        // Assert
        verify(mockDocRef.update(updateData)).called(1);
      });
    });

    group('getUserRatings', () {
      test('should return user ratings data', () async {
        // Arrange
        final ratingsData = {'dailyRatings': {'game1': {'rating': 5}}};
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();

        when(mockFirestore.collection('user_ratings')).thenReturn(mockCollection);
        when(mockCollection.doc(testUid)).thenReturn(mockDocRef);
        when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
        when(mockDocSnapshot.exists).thenReturn(true);
        when(mockDocSnapshot.data()).thenReturn(ratingsData);

        // Act
        final result = await datasource.getUserRatings(testUid);

        // Assert
        expect(result, ratingsData);
      });
    });

    group('getUserComplaints', () {
      test('should return user complaints data', () async {
        // Arrange
        final complaintsData = {'complaints': {'game1': {'user1': 2}}};
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();

        when(mockFirestore.collection('complaints')).thenReturn(mockCollection);
        when(mockCollection.doc(testUid)).thenReturn(mockDocRef);
        when(mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
        when(mockDocSnapshot.exists).thenReturn(true);
        when(mockDocSnapshot.data()).thenReturn(complaintsData);

        // Act
        final result = await datasource.getUserComplaints(testUid);

        // Assert
        expect(result, complaintsData);
      });
    });

    group('addBan', () {
      test('should add ban data to Firestore', () async {
        // Arrange
        final banData = {'reason': 'spam', 'duration': 24};
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();

        when(mockFirestore.collection('bans')).thenReturn(mockCollection);
        when(mockCollection.doc(testUid)).thenReturn(mockDocRef);
        when(mockDocRef.set(any, any)).thenAnswer((_) async => Future.value());

        // Act
        await datasource.addBan(testUid, banData);

        // Assert
        verify(mockDocRef.set(any, any)).called(1);
        verify(mockFirestore.collection('bans')).called(1);
        verify(mockCollection.doc(testUid)).called(1);
      });
    });
  });
}