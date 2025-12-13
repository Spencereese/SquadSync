// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_lobby.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PeacockTimerImpl _$$PeacockTimerImplFromJson(Map<String, dynamic> json) =>
    _$PeacockTimerImpl(
      endTime: DateTime.parse(json['endTime'] as String),
      isActive: json['isActive'] as bool,
    );

Map<String, dynamic> _$$PeacockTimerImplToJson(_$PeacockTimerImpl instance) =>
    <String, dynamic>{
      'endTime': instance.endTime.toIso8601String(),
      'isActive': instance.isActive,
    };

_$PublicLobbyImpl _$$PublicLobbyImplFromJson(Map<String, dynamic> json) =>
    _$PublicLobbyImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      primaryGameId: json['primaryGameId'] as String?,
      primaryGameName: json['primaryGameName'] as String?,
      maxSpots: (json['maxSpots'] as num?)?.toInt(),
      creatorUid: json['creatorUid'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isPublic: json['isPublic'] as bool,
      inviteCode: json['inviteCode'] as String?,
      memberUids: (json['memberUids'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      lastActivity: DateTime.parse(json['lastActivity'] as String),
      spotClaims: Map<String, String?>.from(json['spotClaims'] as Map),
      peacockTimers: (json['peacockTimers'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, PeacockTimer.fromJson(e as Map<String, dynamic>)),
      ),
      userStatuses: Map<String, String>.from(json['userStatuses'] as Map),
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      lookingForMore: json['lookingForMore'] as bool,
      description: json['description'] as String,
      bumpTimestamp: json['bumpTimestamp'] == null
          ? null
          : DateTime.parse(json['bumpTimestamp'] as String),
    );

Map<String, dynamic> _$$PublicLobbyImplToJson(_$PublicLobbyImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'primaryGameId': instance.primaryGameId,
      'primaryGameName': instance.primaryGameName,
      'maxSpots': instance.maxSpots,
      'creatorUid': instance.creatorUid,
      'createdAt': instance.createdAt.toIso8601String(),
      'isPublic': instance.isPublic,
      'inviteCode': instance.inviteCode,
      'memberUids': instance.memberUids,
      'lastActivity': instance.lastActivity.toIso8601String(),
      'spotClaims': instance.spotClaims,
      'peacockTimers': instance.peacockTimers,
      'userStatuses': instance.userStatuses,
      'tags': instance.tags,
      'lookingForMore': instance.lookingForMore,
      'description': instance.description,
      'bumpTimestamp': instance.bumpTimestamp?.toIso8601String(),
    };
