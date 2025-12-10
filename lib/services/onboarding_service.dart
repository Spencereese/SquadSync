import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'auth_service_supabase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';

part 'onboarding_service.freezed.dart';
part 'onboarding_service.g.dart';

@freezed
class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    required int currentStep,
    required String? displayName,
    required String? avatarUrl,
    required List<Map<String, dynamic>> pinnedGames,
    required bool isInitialized,
  }) = _OnboardingState;

  factory OnboardingState.initial() => const OnboardingState(
        currentStep: 0,
        displayName: null,
        avatarUrl: null,
        pinnedGames: [],
        isInitialized: false,
      );
}

@riverpod
class OnboardingService extends _$OnboardingService {
  late SharedPreferences _prefs;

  @override
  Future<OnboardingState> build() async {
    _prefs = await SharedPreferences.getInstance();
    return loadDraft();
  }

  bool isStepValid(int step) {
    if (step == 0) {
      // Profile step: displayName > 3 chars, avatar uploaded
      return (state.value?.displayName?.length ?? 0) > 3 &&
          state.value?.avatarUrl != null;
    } else if (step == 1) {
      // Games step: at least 1 pinned game
      return (state.value?.pinnedGames.isNotEmpty ?? false);
    }
    return false;
  }

  Future<void> updateProfile(String displayName, String avatarUrl) async {
    state = AsyncValue.data(
        state.value!.copyWith(displayName: displayName, avatarUrl: avatarUrl));
    await saveDraft();
  }

  Future<void> updatePinnedGames(List<Map<String, dynamic>> pinnedGames) async {
    state = AsyncValue.data(state.value!.copyWith(pinnedGames: pinnedGames));
    await saveDraft();
  }

  Future<void> nextStep() async {
    if (isStepValid(state.value!.currentStep)) {
      state = AsyncValue.data(
          state.value!.copyWith(currentStep: state.value!.currentStep + 1));
      await saveDraft();
    }
  }

  Future<void> previousStep() async {
    final currentStep = state.value!.currentStep;
    if (currentStep > 0) {
      state =
          AsyncValue.data(state.value!.copyWith(currentStep: currentStep - 1));
      await saveDraft();
    }
  }

  Future<void> completeOnboarding() async {
    if (isStepValid(0) && isStepValid(1)) {
      // Save user profile data to Supabase Auth
      final authService = AuthServiceSupabase();
      final user = authService.currentUser;
      if (user != null && state.value != null) {
        final displayName = state.value!.displayName!;
        final avatarUrl = state.value!.avatarUrl!;

        // Update Supabase Auth profile
        await authService.updateProfile(
          displayName: displayName,
          additionalData: {
            'photo_url': avatarUrl,
            'pinned_games': state.value!.pinnedGames,
          },
        );

        // Update local storage
        await _prefs.setString('displayName', displayName);
        await _prefs.setString('profileImage', avatarUrl);
      }

      // Clear draft
      await _prefs.remove('onboarding_draft');
    }
  }

  Future<String?> uploadAvatar(File imageFile) async {
    try {
      // TODO: Implement Supabase Storage upload
      // For now, return null - avatar upload needs Supabase Storage integration
      return null;
    } catch (e) {
      // Handle error
      return null;
    }
  }

  Future<void> saveDraft() async {
    final currentState = state.value!;
    final data = {
      'currentStep': currentState.currentStep,
      'displayName': currentState.displayName,
      'avatarUrl': currentState.avatarUrl,
      'pinnedGames': json.encode(currentState.pinnedGames),
    };
    await _prefs.setString('onboarding_draft', json.encode(data));
  }

  OnboardingState loadDraft() {
    // Check if _prefs is initialized
    try {
      final draft = _prefs.getString('onboarding_draft');
      if (draft != null) {
        final data = json.decode(draft) as Map<String, dynamic>;
        return OnboardingState(
          currentStep: data['currentStep'] ?? 0,
          displayName: data['displayName'],
          avatarUrl: data['avatarUrl'],
          pinnedGames: data['pinnedGames'] != null
              ? List<Map<String, dynamic>>.from(
                  json.decode(data['pinnedGames']))
              : [],
          isInitialized: true,
        );
      }
    } catch (e) {
      // _prefs not initialized yet, return initial state
      return OnboardingState.initial().copyWith(isInitialized: true);
    }
    return OnboardingState.initial().copyWith(isInitialized: true);
  }
}
