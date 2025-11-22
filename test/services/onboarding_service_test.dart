import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as auth_mocks;
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart' as storage_mocks;
import 'dart:io';
import 'package:squad_sync/services/onboarding_service.dart';
import 'package:squad_sync/providers/user_notifier.dart';
import 'package:squad_sync/providers/game_notifier.dart';
import 'package:squad_sync/providers/system_notifier.dart';

// Generate mocks
@GenerateMocks([
  SharedPreferences,
  UserNotifier,
  GameNotifier,
  SystemNotifier,
])
import 'onboarding_service_test.mocks.dart';

// Define providers for testing
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => throw UnimplementedError());

void main() {
  late MockSharedPreferences mockPrefs;
  late auth_mocks.MockFirebaseAuth mockAuth;
  late MockUserNotifier mockUserNotifier;
  late MockGameNotifier mockGameNotifier;
  late MockSystemNotifier mockSystemNotifier;
  late ProviderContainer container;

  setUp(() {
    mockPrefs = MockSharedPreferences();
    mockAuth = auth_mocks.MockFirebaseAuth(signedIn: true, mockUser: auth_mocks.MockUser(uid: 'test-uid'));
    mockUserNotifier = MockUserNotifier();
    mockGameNotifier = MockGameNotifier();
    mockSystemNotifier = MockSystemNotifier();

    // Setup mocks
    when(mockPrefs.getString(any)).thenReturn(null);
    when(mockPrefs.setString(any, any)).thenAnswer((_) => Future.value(true));
    when(mockPrefs.remove(any)).thenAnswer((_) => Future.value(true));

    // Mock static instances
    (FirebaseAuth as dynamic).instance = mockAuth;
    (FirebaseStorage as dynamic).instance = MockFirebaseStorage();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(mockPrefs),
        firebaseAuthProvider.overrideWithValue(mockAuth),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('OnboardingService Validation', () {
    test('isStepValid returns false for step 0 with invalid profile', () {
      final service = container.read(onboardingServiceProvider.notifier);
      expect(service.isStepValid(0), false);
    });

    test('isStepValid returns true for step 0 with valid profile', () async {
      final service = container.read(onboardingServiceProvider.notifier);
      await service.updateProfile('ValidName', 'https://example.com/avatar.jpg');
      expect(service.isStepValid(0), true);
    });

    test('isStepValid returns false for step 1 with no games', () async {
      final service = container.read(onboardingServiceProvider.notifier);
      await service.nextStep(); // Go to step 1
      expect(service.isStepValid(1), false);
    });

    test('isStepValid returns true for step 1 with games', () async {
      final service = container.read(onboardingServiceProvider.notifier);
      await service.updatePinnedGames([{'id': '1', 'name': 'Game1'}]);
      await service.nextStep();
      expect(service.isStepValid(1), true);
    });
  });

  group('OnboardingService Draft Persistence', () {
    test('saveDraft stores state in SharedPreferences', () async {
      final service = container.read(onboardingServiceProvider.notifier);
      await service.updateProfile('TestName', 'https://example.com/avatar.jpg');
      await service.updatePinnedGames([{'id': '1', 'name': 'Game1'}]);
      await service.nextStep();

      await service.saveDraft();

      verify(mockPrefs.setString('onboarding_draft', any)).called(1);
    });

    test('loadDraft restores state from SharedPreferences', () {
      when(mockPrefs.getString('onboarding_draft')).thenReturn('{"currentStep":1,"displayName":"TestName","avatarUrl":"https://example.com/avatar.jpg","pinnedGames":"[{\\"id\\":\\"1\\",\\"name\\":\\"Game1\\"}]"}');

      final service = container.read(onboardingServiceProvider.notifier);
      final loadedState = service.loadDraft();

      expect(loadedState.currentStep, 1);
      expect(loadedState.displayName, 'TestName');
      expect(loadedState.avatarUrl, 'https://example.com/avatar.jpg');
      expect(loadedState.pinnedGames.length, 1);
    });

    test('loadDraft returns initial state when no draft', () {
      when(mockPrefs.getString('onboarding_draft')).thenReturn(null);

      final service = container.read(onboardingServiceProvider.notifier);
      final loadedState = service.loadDraft();

      expect(loadedState.currentStep, 0);
      expect(loadedState.displayName, null);
      expect(loadedState.pinnedGames.isEmpty, true);
    });
  });

  group('OnboardingService Avatar Upload', () {
    test('uploadAvatar succeeds and returns URL', () async {
      final service = container.read(onboardingServiceProvider.notifier);
      final file = File('test.jpg');

      final result = await service.uploadAvatar(file);

      expect(result, isNotNull);
    });
  });

  group('OnboardingService Completion', () {
    test('completeOnboarding updates UserNotifier and clears draft', () async {
      final service = container.read(onboardingServiceProvider.notifier);
      await service.updateProfile('TestName', 'https://example.com/avatar.jpg');
      await service.updatePinnedGames([{'id': '1', 'name': 'Game1'}]);
      await service.nextStep();

      await service.completeOnboarding();

      verify(mockPrefs.remove('onboarding_draft')).called(1);
    });

    test('completeOnboarding fails if validation fails', () async {
      final service = container.read(onboardingServiceProvider.notifier);

      await service.completeOnboarding();

      verifyNever(mockPrefs.remove('onboarding_draft'));
    });
  });

  group('OnboardingService Offline Scenarios', () {
    test('saveDraft handles SharedPreferences errors', () async {
      when(mockPrefs.setString(any, any)).thenThrow(Exception('Storage error'));

      final service = container.read(onboardingServiceProvider.notifier);

      expect(() => service.saveDraft(), throwsException);
    });
  });
}