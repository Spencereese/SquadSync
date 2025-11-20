import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../squad_state_notifier.dart';
import 'providers.dart';

part 'squad_providers.g.dart';

/// Squad-specific providers for optimized state access
/// These providers use .select() for tree-shaking and performance

/// Provider for squad spots by game name
/// Tree-shakes: Only rebuilds when gameSquadSpots[gameName] changes
@riverpod
List<String?> squadSpots(SquadSpotsRef ref, String gameName) {
  return ref.watch(squadStateNotifierProvider.select(
    (state) => state.gameSquadSpots[gameName] ?? [],
  ));
}

/// Provider for spot timers by game name
/// Tree-shakes: Only rebuilds when gameSpotTimers[gameName] changes
@riverpod
List<Map<String, dynamic>?> spotTimers(SpotTimersRef ref, String gameName) {
  return ref.watch(squadStateNotifierProvider.select(
    (state) => state.gameSpotTimers[gameName] ?? [],
  ));
}

/// Provider for game statuses by game name
/// Tree-shakes: Only rebuilds when gameStatuses[gameName] changes
@riverpod
Map<String, String> gameStatuses(GameStatusesRef ref, String gameName) {
  return ref.watch(squadStateNotifierProvider.select(
    (state) => state.gameStatuses[gameName] ?? {},
  ));
}

/// Provider for global statuses
/// Tree-shakes: Only rebuilds when globalStatuses changes
@riverpod
Map<String, String> globalStatuses(GlobalStatusesRef ref) {
  return ref.watch(squadStateNotifierProvider.select(
    (state) => state.globalStatuses,
  ));
}

/// Provider for current game
/// Tree-shakes: Only rebuilds when currentGame changes
@riverpod
Map<String, dynamic>? currentGame(CurrentGameRef ref) {
  return ref.watch(squadStateNotifierProvider.select(
    (state) => state.currentGame,
  ));
}

/// Provider for selected squad ID
/// Tree-shakes: Only rebuilds when selectedSquadId changes
@riverpod
String? selectedSquadId(SelectedSquadIdRef ref) {
  return ref.watch(squadStateNotifierProvider.select(
    (state) => state.selectedSquadId,
  ));
}

/// Provider for display name
/// Tree-shakes: Only rebuilds when displayName changes
@riverpod
String? displayName(DisplayNameRef ref) {
  return ref.watch(squadStateNotifierProvider.select(
    (state) => state.displayName,
  ));
}

/// Provider for profile image
/// Tree-shakes: Only rebuilds when profileImage changes
@riverpod
String? profileImage(ProfileImageRef ref) {
  return ref.watch(squadStateNotifierProvider.select(
    (state) => state.profileImage,
  ));
}

/// Provider for tilt enabled status
/// Tree-shakes: Only rebuilds when tiltEnabled changes
@riverpod
bool tiltEnabled(TiltEnabledRef ref) {
  return ref.watch(squadStateNotifierProvider.select(
    (state) => state.tiltEnabled,
  ));
}

/// Provider for initialization status
/// Tree-shakes: Only rebuilds when isInitialized changes
@riverpod
bool isInitialized(IsInitializedRef ref) {
  return ref.watch(squadStateNotifierProvider.select(
    (state) => state.isInitialized,
  ));
}

/// Provider for unread messages status
/// Tree-shakes: Only rebuilds when hasUnreadMessages changes
@riverpod
bool hasUnreadMessages(HasUnreadMessagesRef ref) {
  return ref.watch(squadStateNotifierProvider.select(
    (state) => state.hasUnreadMessages,
  ));
}

/// Provider for new squad spot status
/// Tree-shakes: Only rebuilds when hasNewSquadSpot changes
@riverpod
bool hasNewSquadSpot(HasNewSquadSpotRef ref) {
  return ref.watch(squadStateNotifierProvider.select(
    (state) => state.hasNewSquadSpot,
  ));
}