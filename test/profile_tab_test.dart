import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_sync/profile_tab.dart';
import 'package:squad_sync/squad_state_notifier.dart';
import '../test/helpers/mocks.mocks.dart';

void main() {
  late MockSharedPreferences mockPrefs;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockFirebaseStorage mockStorage;
  late MockReference mockReference;
  late MockUploadTask mockUploadTask;
  late MockTaskSnapshot mockTaskSnapshot;
  late MockImagePicker mockImagePicker;
  late MockXFile mockXFile;

  setUp(() {
    mockPrefs = MockSharedPreferences();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockStorage = MockFirebaseStorage();
    mockReference = MockReference();
    mockUploadTask = MockUploadTask();
    mockTaskSnapshot = MockTaskSnapshot();
    mockImagePicker = MockImagePicker();
    mockXFile = MockXFile();

    // Setup Firebase Auth mock
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test-uid');

    // Setup Firebase Storage mock
    when(mockStorage.ref()).thenReturn(mockReference);
    when(mockReference.child(any)).thenReturn(mockReference);
    when(mockReference.putFile(any)).thenReturn(mockUploadTask);
    when(mockUploadTask.whenComplete(any)).thenReturn(mockUploadTask);
    when(mockReference.getDownloadURL()).thenAnswer((_) async => 'https://example.com/image.jpg');

    // Setup Image Picker mock
    when(mockImagePicker.pickImage(source: anyNamed('source'))).thenAnswer((_) async => mockXFile);
    when(mockXFile.path).thenReturn('/test/path/image.jpg');
  });

  group('ProfileTab Widget Tests', () {
    final testSquadState = SquadStateData(
      displayName: 'Test User',
      profileImage: 'https://example.com/old-image.jpg',
      selectedSquadId: 'test-squad',
      selectedGame: {'id': 'game1', 'name': 'Test Game'},
      squadSpots: ['user1', 'user2'],
      gameSquadSpots: {'Test Game': ['user1', 'user2']},
      gameSpotTimers: {'Test Game': {}},
      gameStatuses: {'Test Game': {}},
      memberDisplayNames: {'user1': 'User One', 'user2': 'User Two'},
      blockedUsers: [],
      pinnedGames: [{'id': 'game1', 'name': 'Test Game'}],
      achievements: {},
      isDarkTheme: true,
      notificationsEnabled: true,
      soundsEnabled: true,
      tiltEnabled: true,
      onlineStatusVisible: true,
      selectedPeacockId: null,
      peacockQueue: [],
      peacockTimers: {},
    );

    testWidgets('renders ProfileTab correctly with user data', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadStateNotifierProvider.overrideWith((ref) => testSquadState),
          ],
          child: const MaterialApp(
            home: ProfileTab(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Your Profile'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('displays profile image when available', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadStateNotifierProvider.overrideWith((ref) => testSquadState),
          ],
          child: const MaterialApp(
            home: ProfileTab(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('Tap to change profile picture'), findsOneWidget);
    });

    testWidgets('shows default icon when no profile image', (WidgetTester tester) async {
      final stateWithoutImage = testSquadState.copyWith(profileImage: null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadStateNotifierProvider.overrideWith((ref) => stateWithoutImage),
          ],
          child: const MaterialApp(
            home: ProfileTab(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('opens display name edit dialog when edit icon tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadStateNotifierProvider.overrideWith((ref) => testSquadState),
          ],
          child: const MaterialApp(
            home: ProfileTab(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(find.text('Edit Display Name'), findsOneWidget);
      expect(find.text('Enter new name'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('updates display name when save button tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadStateNotifierProvider.overrideWith((ref) => testSquadState),
          ],
          child: const MaterialApp(
            home: ProfileTab(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'New Display Name');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Display name updated!'), findsOneWidget);
    });

    testWidgets('opens settings sheet when settings icon tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadStateNotifierProvider.overrideWith((ref) => testSquadState),
          ],
          child: const MaterialApp(
            home: ProfileTab(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
    });

    testWidgets('loads settings from SharedPreferences on init', (WidgetTester tester) async {
      when(mockPrefs.getBool('isDarkTheme')).thenReturn(false);
      when(mockPrefs.getBool('notificationsEnabled')).thenReturn(false);
      when(mockPrefs.getBool('soundsEnabled')).thenReturn(false);
      when(mockPrefs.getBool('tiltEnabled')).thenReturn(false);
      when(mockPrefs.getBool('onlineStatusVisible')).thenReturn(false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadStateNotifierProvider.overrideWith((ref) => testSquadState),
          ],
          child: const MaterialApp(
            home: ProfileTab(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Settings should be loaded and synced with state
      verify(mockPrefs.getBool('isDarkTheme')).called(1);
      verify(mockPrefs.getBool('notificationsEnabled')).called(1);
      verify(mockPrefs.getBool('soundsEnabled')).called(1);
      verify(mockPrefs.getBool('tiltEnabled')).called(1);
      verify(mockPrefs.getBool('onlineStatusVisible')).called(1);
    });

    testWidgets('handles profile image update with image picker', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadStateNotifierProvider.overrideWith((ref) => testSquadState),
          ],
          child: const MaterialApp(
            home: ProfileTab(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on profile image
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      // Verify Firebase Storage interactions
      verify(mockStorage.ref()).called(1);
      verify(mockReference.child('profile_pics/test-uid.jpg')).called(1);
      verify(mockReference.putFile(any)).called(1);
      verify(mockReference.getDownloadURL()).called(1);

      // Should show success snackbar
      expect(find.text('Profile picture updated!'), findsOneWidget);
    });

    testWidgets('handles image picker cancellation gracefully', (WidgetTester tester) async {
      when(mockImagePicker.pickImage(source: anyNamed('source'))).thenAnswer((_) async => null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadStateNotifierProvider.overrideWith((ref) => testSquadState),
          ],
          child: const MaterialApp(
            home: ProfileTab(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      // Should not attempt to upload or show success message
      verifyNever(mockStorage.ref());
      expect(find.text('Profile picture updated!'), findsNothing);
    });

    testWidgets('displays friends section', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadStateNotifierProvider.overrideWith((ref) => testSquadState),
          ],
          child: const MaterialApp(
            home: ProfileTab(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Friends'), findsOneWidget);
    });

    testWidgets('displays pending requests section', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadStateNotifierProvider.overrideWith((ref) => testSquadState),
          ],
          child: const MaterialApp(
            home: ProfileTab(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pending Requests'), findsOneWidget);
    });

    testWidgets('handles empty display name input gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadStateNotifierProvider.overrideWith((ref) => testSquadState),
          ],
          child: const MaterialApp(
            home: ProfileTab(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Leave text field empty
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Should not show success message for empty name
      expect(find.text('Display name updated!'), findsNothing);
    });

    testWidgets('closes settings sheet when close button tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadStateNotifierProvider.overrideWith((ref) => testSquadState),
          ],
          child: const MaterialApp(
            home: ProfileTab(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsNothing);
    });
  });
}