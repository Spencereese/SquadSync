import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/data/datasources/user_local_datasource.dart';
import '../../helpers/mocks.mocks.dart';

void main() {
  late UserLocalDataSourceImpl datasource;
  late MockSharedPreferences mockPrefs;

  setUp(() {
    mockPrefs = MockSharedPreferences();
    datasource = UserLocalDataSourceImpl(mockPrefs);
  });

  group('UserLocalDataSourceImpl', () {
    group('getProfileImage', () {
      test('should return profile image from SharedPreferences', () async {
        // Arrange
        const imageUrl = 'https://example.com/image.jpg';
        when(mockPrefs.getString('profileImage')).thenReturn(imageUrl);

        // Act
        final result = await datasource.getProfileImage();

        // Assert
        expect(result, imageUrl);
        verify(mockPrefs.getString('profileImage')).called(1);
      });

      test('should return null when no profile image stored', () async {
        // Arrange
        when(mockPrefs.getString('profileImage')).thenReturn(null);

        // Act
        final result = await datasource.getProfileImage();

        // Assert
        expect(result, null);
      });
    });

    group('setProfileImage', () {
      test('should store profile image in SharedPreferences', () async {
        // Arrange
        const imageUrl = 'https://example.com/image.jpg';
        when(mockPrefs.setString('profileImage', imageUrl))
            .thenAnswer((_) async => true);

        // Act
        await datasource.setProfileImage(imageUrl);

        // Assert
        verify(mockPrefs.setString('profileImage', imageUrl)).called(1);
      });
    });

    group('getDisplayName', () {
      test('should return display name from SharedPreferences', () async {
        // Arrange
        const displayName = 'Test User';
        when(mockPrefs.getString('displayName')).thenReturn(displayName);

        // Act
        final result = await datasource.getDisplayName();

        // Assert
        expect(result, displayName);
      });

      test('should return null when no display name stored', () async {
        // Arrange
        when(mockPrefs.getString('displayName')).thenReturn(null);

        // Act
        final result = await datasource.getDisplayName();

        // Assert
        expect(result, null);
      });
    });

    group('setDisplayName', () {
      test('should store display name in SharedPreferences', () async {
        // Arrange
        const displayName = 'Test User';
        when(mockPrefs.setString('displayName', displayName))
            .thenAnswer((_) async => true);

        // Act
        await datasource.setDisplayName(displayName);

        // Assert
        verify(mockPrefs.setString('displayName', displayName)).called(1);
      });
    });

    group('getPinnedGames', () {
      test('should return pinned games from SharedPreferences', () async {
        // Arrange
        const gamesJson = '[{"id": "game1", "name": "Game One"}]';
        final expectedGames = [{'id': 'game1', 'name': 'Game One'}];
        when(mockPrefs.getString('pinnedGames')).thenReturn(gamesJson);

        // Act
        final result = await datasource.getPinnedGames();

        // Assert
        expect(result, expectedGames);
      });

      test('should return empty list when no pinned games stored', () async {
        // Arrange
        when(mockPrefs.getString('pinnedGames')).thenReturn(null);

        // Act
        final result = await datasource.getPinnedGames();

        // Assert
        expect(result, []);
      });
    });

    group('setPinnedGames', () {
      test('should store pinned games in SharedPreferences', () async {
        // Arrange
        final games = [{'id': 'game1', 'name': 'Game One'}];
        const expectedJson = '[{"id":"game1","name":"Game One"}]';
        when(mockPrefs.setString('pinnedGames', expectedJson))
            .thenAnswer((_) async => true);

        // Act
        await datasource.setPinnedGames(games);

        // Assert
        verify(mockPrefs.setString('pinnedGames', expectedJson)).called(1);
      });
    });
  });
}