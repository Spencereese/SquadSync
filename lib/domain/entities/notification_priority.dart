import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_priority.freezed.dart';
part 'notification_priority.g.dart';

/// Priority levels for notifications
enum NotificationPriority {
  high, // Push notifications (invites, momentum)
  medium, // In-app alerts with sound
  low, // Badge only (chat, lobby updates)
}

/// Cooldown tracking for notification throttling
@freezed
class NotificationCooldown with _$NotificationCooldown {
  const factory NotificationCooldown({
    required String userId,
    required String lobbyId,
    required DateTime lastSentAt,
    required NotificationType type,
  }) = _NotificationCooldown;

  factory NotificationCooldown.fromJson(Map<String, dynamic> json) =>
      _$NotificationCooldownFromJson(json);
}

/// Types of notifications for cooldown tracking
enum NotificationType {
  directInvite,
  momentum,
  lobbyUpdate,
  chat,
  spotAvailable,
  timerExpiring,
}

/// Match affinity for smart notification prioritization
@freezed
class MatchAffinity with _$MatchAffinity {
  const factory MatchAffinity({
    required String userId,
    required String gameId,
    required int sharedSessionCount,
    required DateTime lastPlayedTogether,
    required double affinityScore,
  }) = _MatchAffinity;

  factory MatchAffinity.fromJson(Map<String, dynamic> json) =>
      _$MatchAffinityFromJson(json);
}

/// In-app badge state
@freezed
class BadgeState with _$BadgeState {
  const factory BadgeState({
    @Default(0) int chatUnreadCount,
    @Default(0) int lobbyUpdatesCount,
    @Default(0) int invitesCount,
    @Default(false) bool hasMomentum,
  }) = _BadgeState;

  factory BadgeState.fromJson(Map<String, dynamic> json) =>
      _$BadgeStateFromJson(json);
}

/// Notification payload for different alert types
@freezed
class NotificationPayload with _$NotificationPayload {
  const factory NotificationPayload.directInvite({
    required String inviterId,
    required String inviterName,
    required String lobbyId,
    required String gameName,
    String? gameImageUrl,
  }) = _DirectInvitePayload;

  const factory NotificationPayload.momentum({
    required String lobbyId,
    required String gameName,
    required int currentPlayers,
    required int maxPlayers,
    required String joinerName,
    required List<String> participantNames,
    String? gameImageUrl,
  }) = _MomentumPayload;

  const factory NotificationPayload.spotAvailable({
    required String lobbyId,
    required String gameName,
    required int spotsOpen,
    required List<String> friendsInLobby,
  }) = _SpotAvailablePayload;

  const factory NotificationPayload.timerExpiring({
    required String lobbyId,
    required String gameName,
    required int secondsRemaining,
  }) = _TimerExpiringPayload;

  factory NotificationPayload.fromJson(Map<String, dynamic> json) =>
      _$NotificationPayloadFromJson(json);
}
