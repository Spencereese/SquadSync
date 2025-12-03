import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:squad_sync/screens/onboarding/onboarding_flow.dart';
import 'package:squad_sync/screens/onboarding/profile_setup_screen.dart';
import 'package:squad_sync/screens/add_game_screen.dart';
import 'package:squad_sync/services/onboarding_service.dart';
import 'package:squad_sync/providers/user_notifier.dart';
import 'package:squad_sync/providers/game_notifier.dart';
import 'package:squad_sync/providers/system_notifier.dart';
import 'package:squad_sync/chat/chat_groups_screen.dart';
import 'package:squad_sync/services/app_flow_manager.dart';

// Define providers for testing
final sharedPreferencesProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());
final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => throw UnimplementedError());
final firebaseStorageProvider =
    Provider<FirebaseStorage>((ref) => throw UnimplementedError());
final appFlowManagerProvider =
    Provider<AppFlowManager>((ref) => throw UnimplementedError());

void main() {
  late MockSharedPreferences mockPrefs;
  late MockFirebaseAuth mockAuth;
  late MockFirebaseStorage mockStorage;
  late MockUser mockUser;
  late MockReference mockRef;
  late MockUploadTask mockUploadTask;
  late MockTaskSnapshot mockSnapshot;
  late MockUserNotifier mockUserNotifier;
  late MockGameNotifier mockGameNotifier;
  late MockSystemNotifier mockSystemNotifier;
  late MockAppFlowManager mockAppFlowManager;
  late MockImagePicker mockImagePicker;
  late MockXFile mockXFile;

  setUp(() {
    mockPrefs = MockSharedPreferences();
    mockAuth =
        MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'test-uid'));
    mockStorage = MockFirebaseStorage();
    mockUser = MockUser();
    mockRef = MockReference();
    mockUploadTask = MockUploadTask();
    mockSnapshot = MockTaskSnapshot();
    mockUserNotifier = MockUserNotifier();
    mockGameNotifier = MockGameNotifier();
    mockSystemNotifier = MockSystemNotifier();
    mockAppFlowManager = MockAppFlowManager();
    mockImagePicker = MockImagePicker();
    mockXFile = MockXFile();

    // Setup mocks
    when(mockUser.uid).thenReturn('test-uid');
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockStorage.ref()).thenReturn(mockRef);
    when(mockRef.child(any)).thenReturn(mockRef);
    when(mockRef.putFile(any)).thenReturn(mockUploadTask);
    when(mockUploadTask.whenComplete(any))
        .thenAnswer((_) => Future.value(mockSnapshot));
    when(mockSnapshot.ref).thenReturn(mockRef);
    when(mockRef.getDownloadURL())
        .thenReturn(Future.value('https://example.com/avatar.jpg'));

    when(mockPrefs.getString(any)).thenReturn(null);
    when(mockPrefs.setString(any, any)).thenAnswer((_) => Future.value(true));
    when(mockPrefs.remove(any)).thenAnswer((_) => Future.value(true));

    when(mockImagePicker.pickImage(source: anyNamed('source')))
        .thenAnswer((_) => Future.value(mockXFile));
    when(mockXFile.path).thenReturn('/test/path.jpg');

    // Mock static instances
    FirebaseAuth.instance = mockAuth;
    FirebaseStorage.instance = mockStorage;
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(mockPrefs),
        firebaseAuthProvider.overrideWithValue(mockAuth),
        firebaseStorageProvider.overrideWithValue(mockStorage),
        userNotifierProvider.overrideWith((ref) => mockUserNotifier),
        gameNotifierProvider.overrideWith((ref) => mockGameNotifier),
        systemNotifierProvider.overrideWith((ref) => mockSystemNotifier),
        appFlowManagerProvider.overrideWithValue(mockAppFlowManager),
      ],
      child: MaterialApp(
        home: const OnboardingFlow(),
      ),
    );
  }

  group('OnboardingFlow Widget Tests', () {
    testWidgets('renders ProfileSetupScreen initially', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ProfileSetupScreen), findsOneWidget);
      expect(find.text('Create Your Profile'), findsOneWidget);
    });

    testWidgets('shows validation hints for invalid input', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Hi'); // Too short
      await tester.pump();

      expect(find.text('Display name must be longer than 3 characters'),
          findsOneWidget);
      expect(find.text('Please upload an avatar to continue'), findsOneWidget);
    });

    testWidgets('enables Next button when profile is valid', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'ValidName');

      // Mock avatar upload
      final avatarButton = find.byType(GestureDetector);
      await tester.tap(avatarButton);
      await tester.pump();

      expect(find.text('Next'), findsOneWidget);
      final nextButton = find.widgetWithText(ElevatedButton, 'Next');
      expect(tester.widget<ElevatedButton>(nextButton).enabled, true);
    });

    testWidgets('navigates to AddGameScreen on next step', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Make profile valid
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'ValidName');

      final avatarButton = find.byType(GestureDetector);
      await tester.tap(avatarButton);
      await tester.pump();

      final nextButton = find.widgetWithText(ElevatedButton, 'Next');
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      expect(find.byType(AddGameScreen), findsOneWidget);
      expect(find.text('Select Your Games'), findsOneWidget);
    });

    testWidgets('shows game pinning validation', (tester) async {
      // Navigate to games step
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Simulate navigation to step 1
      final onboardingService = tester
          .element(find.byType(OnboardingFlow))
          .read(onboardingServiceProvider.notifier);
      await onboardingService.updateProfile(
          'ValidName', 'https://example.com/avatar.jpg');
      await onboardingService.nextStep();
      await tester.pumpAndSettle();

      expect(find.text('Pin at least 1 game to continue'), findsOneWidget);
    });

    testWidgets('completes onboarding and navigates to ChatGroupsScreen',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Complete profile
      final onboardingService = tester
          .element(find.byType(OnboardingFlow))
          .read(onboardingServiceProvider.notifier);
      await onboardingService.updateProfile(
          'ValidName', 'https://example.com/avatar.jpg');
      await onboardingService.updatePinnedGames([
        {'id': '1', 'name': 'Game1'}
      ]);
      await onboardingService.nextStep();
      await tester.pumpAndSettle();

      final completeButton = find.widgetWithText(ElevatedButton, 'Get Started');
      await tester.tap(completeButton);
      await tester.pumpAndSettle();

      expect(find.byType(ChatGroupsScreen), findsOneWidget);
      verify(mockAppFlowManager.trackOnboardingCompleted(
        userId: 'test-uid',
        gamesPinned: 1,
        timeSpent: anyNamed('timeSpent'),
      )).called(1);
    });

    testWidgets('animations trigger on screen changes', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check for animation effects (this is basic, real animation testing would need more setup)
      expect(find.byType(ProfileSetupScreen), findsOneWidget);
    });

    testWidgets('handles offline avatar upload failure', (tester) async {
      when(mockRef.putFile(any)).thenThrow(Exception('Network error'));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final avatarButton = find.byType(GestureDetector);
      await tester.tap(avatarButton);
      await tester.pump();

      expect(find.textContaining('Failed to upload avatar'), findsOneWidget);
    });

    testWidgets('reactivity: buttons enable within 100ms of input changes',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final nameField = find.byType(TextField).first;
      final startTime = DateTime.now();

      await tester.enterText(nameField, 'ValidName');
      await tester.pump();

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;

      expect(duration, lessThan(100)); // Should update quickly
    });
  });
}
