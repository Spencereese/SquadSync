// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'squad.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PeacockTimerImpl _$$PeacockTimerImplFromJson(Map<String, dynamic> json) =>
    _$PeacockTimerImpl(
      endTime: const TimestampConverter()
          .fromJson(json['endTime'] as Map<String, dynamic>),
      isActive: json['isActive'] as bool,
    );

Map<String, dynamic> _$$PeacockTimerImplToJson(_$PeacockTimerImpl instance) =>
    <String, dynamic>{
      'endTime': const TimestampConverter().toJson(instance.endTime),
      'isActive': instance.isActive,
    };

_$SquadImpl _$$SquadImplFromJson(Map<String, dynamic> json) => _$SquadImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      primaryGameId: json['primaryGameId'] as String?,
      primaryGameName: json['primaryGameName'] as String?,
      maxSpots: (json['maxSpots'] as num?)?.toInt(),
      creatorUid: json['creatorUid'] as String,
      createdAt: const TimestampConverter()
          .fromJson(json['createdAt'] as Map<String, dynamic>),
      isPublic: json['isPublic'] as bool,
      inviteCode: json['inviteCode'] as String?,
      memberUids: (json['memberUids'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      lastActivity: const TimestampConverter()
          .fromJson(json['lastActivity'] as Map<String, dynamic>),
      spotClaims: Map<String, String?>.from(json['spotClaims'] as Map),
      peacockTimers: (json['peacockTimers'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, PeacockTimer.fromJson(e as Map<String, dynamic>)),
      ),
      userStatuses: Map<String, String>.from(json['userStatuses'] as Map),
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      lookingForMore: json['lookingForMore'] as bool,
      description: json['description'] as String,
      bumpTimestamp: _$JsonConverterFromJson<Map<String, dynamic>, Timestamp>(
          json['bumpTimestamp'], const TimestampConverter().fromJson),
    );

Map<String, dynamic> _$$SquadImplToJson(_$SquadImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'primaryGameId': instance.primaryGameId,
      'primaryGameName': instance.primaryGameName,
      'maxSpots': instance.maxSpots,
      'creatorUid': instance.creatorUid,
      'createdAt': const TimestampConverter().toJson(instance.createdAt),
      'isPublic': instance.isPublic,
      'inviteCode': instance.inviteCode,
      'memberUids': instance.memberUids,
      'lastActivity': const TimestampConverter().toJson(instance.lastActivity),
      'spotClaims': instance.spotClaims,
      'peacockTimers': instance.peacockTimers,
      'userStatuses': instance.userStatuses,
      'tags': instance.tags,
      'lookingForMore': instance.lookingForMore,
      'description': instance.description,
      'bumpTimestamp': _$JsonConverterToJson<Map<String, dynamic>, Timestamp>(
          instance.bumpTimestamp, const TimestampConverter().toJson),
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) =>
    json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) =>
    value == null ? null : toJson(value);
