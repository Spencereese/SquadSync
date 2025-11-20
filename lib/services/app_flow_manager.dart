import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Analytics service for tracking app flows and user events
class AppFlowManager {
  final FirebaseAnalytics _analytics;

  AppFlowManager(this._analytics);

  /// Track onboarding completion
  Future<void> trackOnboardingCompleted({
    required String userId,
    required int gamesPinned,
    required Duration timeSpent,
  }) async {
    await _analytics.logEvent(
      name: 'onboarding_completed',
      parameters: {
        'user_id': userId,
        'games_pinned': gamesPinned,
        'time_spent_seconds': timeSpent.inSeconds,
      },
    );
  }

  /// Track squad creation
  Future<void> trackSquadCreated({
    required String userId,
    required String squadId,
    required String squadName,
    required int memberCount,
  }) async {
    await _analytics.logEvent(
      name: 'squad_created',
      parameters: {
        'user_id': userId,
        'squad_id': squadId,
        'squad_name': squadName,
        'member_count': memberCount,
      },
    );
  }

  /// Track squad join
  Future<void> trackSquadJoined({
    required String userId,
    required String squadId,
    required String squadName,
    required String joinMethod, // 'invite_code', 'direct_join', etc.
  }) async {
    await _analytics.logEvent(
      name: 'squad_joined',
      parameters: {
        'user_id': userId,
        'squad_id': squadId,
        'squad_name': squadName,
        'join_method': joinMethod,
      },
    );
  }

  /// Track group discovery search
  Future<void> trackGroupDiscoverySearch({
    required String userId,
    required String searchTerm,
    required String gameName,
    required int resultsCount,
    required Duration searchDuration,
  }) async {
    await _analytics.logEvent(
      name: 'group_discovery_search',
      parameters: {
        'user_id': userId,
        'search_term': searchTerm,
        'game_name': gameName,
        'results_count': resultsCount,
        'search_duration_ms': searchDuration.inMilliseconds,
      },
    );
  }

  /// Track group discovery conversion (search to join)
  Future<void> trackGroupDiscoveryConversion({
    required String userId,
    required String searchTerm,
    required String gameName,
    required String joinedSquadId,
    required String joinedSquadName,
    required int groupsViewedBeforeJoin,
  }) async {
    await _analytics.logEvent(
      name: 'group_discovery_conversion',
      parameters: {
        'user_id': userId,
        'search_term': searchTerm,
        'game_name': gameName,
        'joined_squad_id': joinedSquadId,
        'joined_squad_name': joinedSquadName,
        'groups_viewed_before_join': groupsViewedBeforeJoin,
      },
    );
  }

  /// Track game session started
  Future<void> trackGameSessionStarted({
    required String userId,
    required String squadId,
    required String gameName,
    required int playerCount,
  }) async {
    await _analytics.logEvent(
      name: 'game_session_started',
      parameters: {
        'user_id': userId,
        'squad_id': squadId,
        'game_name': gameName,
        'player_count': playerCount,
      },
    );
  }

  /// Track voice room usage
  Future<void> trackVoiceRoomJoined({
    required String userId,
    required String squadId,
    required String roomId,
    required int participantCount,
  }) async {
    await _analytics.logEvent(
      name: 'voice_room_joined',
      parameters: {
        'user_id': userId,
        'squad_id': squadId,
        'room_id': roomId,
        'participant_count': participantCount,
      },
    );
  }

  /// Track user engagement
  Future<void> trackUserEngagement({
    required String userId,
    required String action,
    required String screen,
    Map<String, Object>? additionalParams,
  }) async {
    final parameters = <String, Object>{
      'user_id': userId,
      'action': action,
      'screen': screen,
      ...?additionalParams,
    };

    await _analytics.logEvent(
      name: 'user_engagement',
      parameters: parameters,
    );
  }

  /// Track error events
  Future<void> trackError({
    required String userId,
    required String errorType,
    required String errorMessage,
    String? screen,
  }) async {
    await _analytics.logEvent(
      name: 'app_error',
      parameters: {
        'user_id': userId,
        'error_type': errorType,
        'error_message': errorMessage,
        'screen': screen ?? 'unknown',
      },
    );
  }

  /// Set user properties
  Future<void> setUserProperties({
    required String userId,
    String? displayName,
    int? squadCount,
    int? gamesPinned,
    bool? hasCompletedOnboarding,
  }) async {
    await _analytics.setUserId(id: userId);

    if (displayName != null) {
      await _analytics.setUserProperty(
          name: 'display_name', value: displayName);
    }
    if (squadCount != null) {
      await _analytics.setUserProperty(
          name: 'squad_count', value: squadCount.toString());
    }
    if (gamesPinned != null) {
      await _analytics.setUserProperty(
          name: 'games_pinned', value: gamesPinned.toString());
    }
    if (hasCompletedOnboarding != null) {
      await _analytics.setUserProperty(
        name: 'onboarding_completed',
        value: hasCompletedOnboarding.toString(),
      );
    }
  }

  /// Track screen views
  Future<void> trackScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }
}

// Riverpod provider for AppFlowManager
final appFlowManagerProvider = Provider<AppFlowManager>((ref) {
  final analytics = FirebaseAnalytics.instance;
  return AppFlowManager(analytics);
});
