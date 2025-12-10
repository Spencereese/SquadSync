import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../services/auth_service_supabase.dart';

part 'onboarding_notifier.freezed.dart';

@freezed
class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    @Default(0) int currentPage,
    @Default(false) bool isLoading,
    String? callsign,
    String? avatarPath,
    @Default([]) List<String> selectedGames,
    @Default({}) Map<String, bool> preferences,
    String? error,
  }) = _OnboardingState;
}

class OnboardingNotifier extends AutoDisposeNotifier<OnboardingState> {
  @override
  OnboardingState build() {
    return const OnboardingState();
  }

  void setPage(int page) {
    state = state.copyWith(currentPage: page);
  }

  void nextPage() {
    if (state.currentPage < 3) {
      state = state.copyWith(currentPage: state.currentPage + 1);
    }
  }

  void previousPage() {
    if (state.currentPage > 0) {
      state = state.copyWith(currentPage: state.currentPage - 1);
    }
  }

  void setCallsign(String callsign) {
    state = state.copyWith(callsign: callsign);
  }

  void setAvatarPath(String path) {
    state = state.copyWith(avatarPath: path);
  }

  void toggleGame(String gameId) {
    final games = List<String>.from(state.selectedGames);
    if (games.contains(gameId)) {
      games.remove(gameId);
    } else {
      if (games.length < 6) {
        games.add(gameId);
      }
    }
    state = state.copyWith(selectedGames: games);
  }

  void setGames(List<String> games) {
    state = state.copyWith(selectedGames: games.take(6).toList());
  }

  void togglePreference(String key, bool value) {
    final prefs = Map<String, bool>.from(state.preferences);
    prefs[key] = value;
    state = state.copyWith(preferences: prefs);
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final authService = AuthServiceSupabase();
      final user = authService.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      // Save user profile to Supabase Auth metadata
      await authService.updateProfile(
        displayName: state.callsign ?? 'Operator',
        additionalData: {
          'avatar_path': state.avatarPath,
          'pinned_games': state.selectedGames,
          'preferences': state.preferences,
          'onboarding_complete': true,
        },
      );

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  bool canProceedFromPage(int page) {
    switch (page) {
      case 0:
        final authService = AuthServiceSupabase();
        return authService.currentUser != null;
      case 1:
        return state.callsign != null && state.callsign!.trim().isNotEmpty;
      case 2:
        return state.selectedGames.isNotEmpty;
      case 3:
        return true;
      default:
        return false;
    }
  }
}

final onboardingProvider =
    NotifierProvider.autoDispose<OnboardingNotifier, OnboardingState>(
  OnboardingNotifier.new,
);
