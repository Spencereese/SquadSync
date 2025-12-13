import 'package:riverpod/riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../../services/auth_service_supabase.dart';
import '../../services/supabase_service.dart';
import '../../services/grok_service.dart';

part 'onboarding_notifier.freezed.dart';

@freezed // Disable DiagnosticableTreeMixin - has bugs in Freezed 3.0
class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    @Default(0) int currentPage,
    @Default(4) int totalPages,
    @Default(false) bool isLoading,
    @Default(false) bool hasSkipped,
    String? callsign,
    String? avatarPath,
    @Default([]) List<String> selectedGames,
    @Default([]) List<String> aiRecommendedGames,
    @Default(false) bool isLoadingRecommendations,
    @Default({}) Map<String, bool> preferences,
    @Default('A') String abTestVariant, // A or B for A/B testing
    String? error,
  }) = _OnboardingState;
}

class OnboardingNotifier extends AutoDisposeNotifier<OnboardingState> {
  final _analytics = FirebaseAnalytics.instance;
  final _grokService = GrokService();

  @override
  OnboardingState build() {
    _initializeABTest();
    return const OnboardingState();
  }

  /// Initialize A/B test variant on first load
  void _initializeABTest() async {
    // 50/50 split for A/B testing
    final variant = DateTime.now().millisecond % 2 == 0 ? 'A' : 'B';
    state = state.copyWith(abTestVariant: variant);

    await _analytics.logEvent(
      name: 'onboarding_started',
      parameters: {
        'ab_variant': variant,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void setPage(int page) {
    state = state.copyWith(currentPage: page);

    _analytics.logEvent(
      name: 'onboarding_page_view',
      parameters: {
        'page': page,
        'ab_variant': state.abTestVariant,
      },
    );
  }

  void nextPage() {
    if (state.currentPage < state.totalPages - 1) {
      state = state.copyWith(currentPage: state.currentPage + 1);

      _analytics.logEvent(
        name: 'onboarding_next',
        parameters: {
          'from_page': state.currentPage - 1,
          'to_page': state.currentPage,
        },
      );
    }
  }

  void previousPage() {
    if (state.currentPage > 0) {
      state = state.copyWith(currentPage: state.currentPage - 1);

      _analytics.logEvent(
        name: 'onboarding_back',
        parameters: {
          'from_page': state.currentPage + 1,
          'to_page': state.currentPage,
        },
      );
    }
  }

  /// Skip to final page
  void skipToEnd() {
    final fromPage = state.currentPage;
    state = state.copyWith(
      currentPage: state.totalPages - 1,
      hasSkipped: true,
    );

    _analytics.logEvent(
      name: 'onboarding_skipped',
      parameters: {
        'from_page': fromPage,
        'ab_variant': state.abTestVariant,
      },
    );
  }

  /// Get progress percentage (0.0 to 1.0)
  double get progressPercentage => (state.currentPage + 1) / state.totalPages;

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

    _analytics.logEvent(
      name: 'onboarding_games_selected',
      parameters: {
        'game_count': games.length,
        'ab_variant': state.abTestVariant,
      },
    );
  }

  /// Get AI-powered game recommendations using Grok
  Future<void> fetchGameRecommendations(String userContext) async {
    state = state.copyWith(isLoadingRecommendations: true);

    try {
      // Build context for Grok
      final prompt = """
Based on this user profile, recommend 5 games they might enjoy:
$userContext

Respond with a JSON array of game names only, like: ["Game 1", "Game 2", ...]
""";

      final response = await _grokService.getGrokResponse(
        prompt,
        context: 'Game recommendations for onboarding',
      );

      // Parse JSON response
      final recommendations = _parseGameRecommendations(response);

      state = state.copyWith(
        aiRecommendedGames: recommendations,
        isLoadingRecommendations: false,
      );

      _analytics.logEvent(
        name: 'onboarding_ai_recommendations',
        parameters: {
          'recommendations_count': recommendations.length,
          'ab_variant': state.abTestVariant,
        },
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingRecommendations: false,
        error: 'Failed to fetch recommendations: $e',
      );

      _analytics.logEvent(
        name: 'onboarding_ai_error',
        parameters: {'error': e.toString()},
      );
    }
  }

  List<String> _parseGameRecommendations(String response) {
    try {
      // Try to extract JSON array from response
      final jsonMatch = RegExp(r'\[.*?\]', dotAll: true).firstMatch(response);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        final List<dynamic> parsed = List<String>.from(jsonStr
            .replaceAll('[', '')
            .replaceAll(']', '')
            .split(',')
            .map((s) => s.trim().replaceAll('"', ''))
            .where((s) => s.isNotEmpty));
        return parsed.take(5).map((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  void togglePreference(String key, bool value) {
    final prefs = Map<String, bool>.from(state.preferences);
    prefs[key] = value;
    state = state.copyWith(preferences: prefs);

    _analytics.logEvent(
      name: 'onboarding_preference_changed',
      parameters: {
        'preference': key,
        'value': value,
        'ab_variant': state.abTestVariant,
      },
    );
  }

  /// Validate preferences before completing onboarding
  bool validatePreferences() {
    final prefs = state.preferences;

    // Voice Ready validation: if enabled, ensure microphone permission intent
    final voiceReady = prefs['voice_ready'] ?? false;
    final micAlwaysOn = prefs['mic_always_on'] ?? false;

    // Logical validation: can't have mic always on without voice ready
    if (micAlwaysOn && !voiceReady) {
      state = state.copyWith(
        error: 'Microphone always-on requires Voice Ready to be enabled',
      );
      return false;
    }

    return true;
  }

  Future<void> completeOnboarding() async {
    // Validate preferences first
    if (!validatePreferences()) {
      _analytics.logEvent(
        name: 'onboarding_validation_failed',
        parameters: {'error': state.error ?? 'Validation failed'},
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final authService = AuthServiceSupabase();
      final user = authService.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      final supabase = SupabaseService.client;
      final userId = user.id;

      // Save to Supabase users table with all onboarding data
      await supabase.from('users').upsert({
        'uid': userId,
        'display_name': state.callsign ?? 'Operator',
        'photo_url': state.avatarPath,
        'pinned_games': state.selectedGames,
        'preferences': state.preferences,
        'onboarding_complete': true,
        'onboarding_skipped': state.hasSkipped,
        'ab_variant': state.abTestVariant,
        'ai_recommendations_used': state.aiRecommendedGames.isNotEmpty,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Also update Supabase Auth metadata for quick access
      await authService.updateProfile(
        displayName: state.callsign ?? 'Operator',
        additionalData: {
          'avatar_path': state.avatarPath,
          'pinned_games': state.selectedGames,
          'preferences': state.preferences,
          'onboarding_complete': true,
        },
      );

      // Log completion analytics
      await _analytics.logEvent(
        name: 'onboarding_completed',
        parameters: {
          'skipped': state.hasSkipped,
          'ab_variant': state.abTestVariant,
          'games_selected': state.selectedGames.length,
          'ai_recs_used': state.aiRecommendedGames.isNotEmpty,
          'voice_ready': state.preferences['voice_ready'] ?? false,
          'competitive': state.preferences['competitive'] ?? true,
        },
      );

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );

      _analytics.logEvent(
        name: 'onboarding_error',
        parameters: {'error': e.toString()},
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

final onboardingProvider = NotifierProvider.autoDispose<OnboardingNotifier, OnboardingState>(OnboardingNotifier.new);
