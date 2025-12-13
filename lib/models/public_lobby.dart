import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_lobby.freezed.dart';
part 'public_lobby.g.dart';

@freezed
class PeacockTimer with _$PeacockTimer {
  const factory PeacockTimer({
    required DateTime endTime,
    required bool isActive,
  }) = _PeacockTimer;

  factory PeacockTimer.fromJson(Map<String, dynamic> json) =>
      _$PeacockTimerFromJson(json);
}

/// PublicLobby - Model for public lobby discovery and browsing
/// Used for lobby listing, discovery features, and invite code management
/// Distinct from domain/entities/Lobby which is for active gameplay state
@freezed
class PublicLobby with _$PublicLobby {
  const factory PublicLobby({
    required String id,
    required String name,
    String? primaryGameId,
    String? primaryGameName,
    int? maxSpots,
    required String creatorUid,
    required DateTime createdAt,
    required bool isPublic,
    String? inviteCode,
    required List<String> memberUids,
    required DateTime lastActivity,
    required Map<String, String?> spotClaims,
    required Map<String, PeacockTimer> peacockTimers,
    required Map<String, String> userStatuses,
    required List<String> tags,
    required bool lookingForMore,
    required String description,
    DateTime? bumpTimestamp,
  }) = _PublicLobby;

  factory PublicLobby.fromJson(Map<String, dynamic> json) =>
      _$PublicLobbyFromJson(json);
}
