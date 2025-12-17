// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_priority.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NotificationCooldownImpl _$$NotificationCooldownImplFromJson(
        Map<String, dynamic> json) =>
    _$NotificationCooldownImpl(
      userId: json['userId'] as String,
      lobbyId: json['lobbyId'] as String,
      lastSentAt: DateTime.parse(json['lastSentAt'] as String),
      type: $enumDecode(_$NotificationTypeEnumMap, json['type']),
    );

Map<String, dynamic> _$$NotificationCooldownImplToJson(
        _$NotificationCooldownImpl instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'lobbyId': instance.lobbyId,
      'lastSentAt': instance.lastSentAt.toIso8601String(),
      'type': _$NotificationTypeEnumMap[instance.type]!,
    };

const _$NotificationTypeEnumMap = {
  NotificationType.directInvite: 'directInvite',
  NotificationType.momentum: 'momentum',
  NotificationType.lobbyUpdate: 'lobbyUpdate',
  NotificationType.chat: 'chat',
  NotificationType.spotAvailable: 'spotAvailable',
  NotificationType.timerExpiring: 'timerExpiring',
};

_$MatchAffinityImpl _$$MatchAffinityImplFromJson(Map<String, dynamic> json) =>
    _$MatchAffinityImpl(
      userId: json['userId'] as String,
      gameId: json['gameId'] as String,
      sharedSessionCount: (json['sharedSessionCount'] as num).toInt(),
      lastPlayedTogether: DateTime.parse(json['lastPlayedTogether'] as String),
      affinityScore: (json['affinityScore'] as num).toDouble(),
    );

Map<String, dynamic> _$$MatchAffinityImplToJson(_$MatchAffinityImpl instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'gameId': instance.gameId,
      'sharedSessionCount': instance.sharedSessionCount,
      'lastPlayedTogether': instance.lastPlayedTogether.toIso8601String(),
      'affinityScore': instance.affinityScore,
    };

_$BadgeStateImpl _$$BadgeStateImplFromJson(Map<String, dynamic> json) =>
    _$BadgeStateImpl(
      chatUnreadCount: (json['chatUnreadCount'] as num?)?.toInt() ?? 0,
      lobbyUpdatesCount: (json['lobbyUpdatesCount'] as num?)?.toInt() ?? 0,
      invitesCount: (json['invitesCount'] as num?)?.toInt() ?? 0,
      hasMomentum: json['hasMomentum'] as bool? ?? false,
    );

Map<String, dynamic> _$$BadgeStateImplToJson(_$BadgeStateImpl instance) =>
    <String, dynamic>{
      'chatUnreadCount': instance.chatUnreadCount,
      'lobbyUpdatesCount': instance.lobbyUpdatesCount,
      'invitesCount': instance.invitesCount,
      'hasMomentum': instance.hasMomentum,
    };

_$DirectInvitePayloadImpl _$$DirectInvitePayloadImplFromJson(
        Map<String, dynamic> json) =>
    _$DirectInvitePayloadImpl(
      inviterId: json['inviterId'] as String,
      inviterName: json['inviterName'] as String,
      lobbyId: json['lobbyId'] as String,
      gameName: json['gameName'] as String,
      gameImageUrl: json['gameImageUrl'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DirectInvitePayloadImplToJson(
        _$DirectInvitePayloadImpl instance) =>
    <String, dynamic>{
      'inviterId': instance.inviterId,
      'inviterName': instance.inviterName,
      'lobbyId': instance.lobbyId,
      'gameName': instance.gameName,
      'gameImageUrl': instance.gameImageUrl,
      'runtimeType': instance.$type,
    };

_$MomentumPayloadImpl _$$MomentumPayloadImplFromJson(
        Map<String, dynamic> json) =>
    _$MomentumPayloadImpl(
      lobbyId: json['lobbyId'] as String,
      gameName: json['gameName'] as String,
      currentPlayers: (json['currentPlayers'] as num).toInt(),
      maxPlayers: (json['maxPlayers'] as num).toInt(),
      joinerName: json['joinerName'] as String,
      participantNames: (json['participantNames'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      gameImageUrl: json['gameImageUrl'] as String?,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$MomentumPayloadImplToJson(
        _$MomentumPayloadImpl instance) =>
    <String, dynamic>{
      'lobbyId': instance.lobbyId,
      'gameName': instance.gameName,
      'currentPlayers': instance.currentPlayers,
      'maxPlayers': instance.maxPlayers,
      'joinerName': instance.joinerName,
      'participantNames': instance.participantNames,
      'gameImageUrl': instance.gameImageUrl,
      'runtimeType': instance.$type,
    };

_$SpotAvailablePayloadImpl _$$SpotAvailablePayloadImplFromJson(
        Map<String, dynamic> json) =>
    _$SpotAvailablePayloadImpl(
      lobbyId: json['lobbyId'] as String,
      gameName: json['gameName'] as String,
      spotsOpen: (json['spotsOpen'] as num).toInt(),
      friendsInLobby: (json['friendsInLobby'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$SpotAvailablePayloadImplToJson(
        _$SpotAvailablePayloadImpl instance) =>
    <String, dynamic>{
      'lobbyId': instance.lobbyId,
      'gameName': instance.gameName,
      'spotsOpen': instance.spotsOpen,
      'friendsInLobby': instance.friendsInLobby,
      'runtimeType': instance.$type,
    };

_$TimerExpiringPayloadImpl _$$TimerExpiringPayloadImplFromJson(
        Map<String, dynamic> json) =>
    _$TimerExpiringPayloadImpl(
      lobbyId: json['lobbyId'] as String,
      gameName: json['gameName'] as String,
      secondsRemaining: (json['secondsRemaining'] as num).toInt(),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$TimerExpiringPayloadImplToJson(
        _$TimerExpiringPayloadImpl instance) =>
    <String, dynamic>{
      'lobbyId': instance.lobbyId,
      'gameName': instance.gameName,
      'secondsRemaining': instance.secondsRemaining,
      'runtimeType': instance.$type,
    };
