// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lobby.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LobbyImpl _$$LobbyImplFromJson(Map<String, dynamic> json) => _$LobbyImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      memberUids: (json['memberUids'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      gameName: json['gameName'] as String,
      maxSpots: (json['maxSpots'] as num).toInt(),
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      spots: (json['spots'] as List<dynamic>).map((e) => e as String?).toList(),
      spotTimers: (json['spotTimers'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>?)
          .toList(),
      viewers:
          (json['viewers'] as List<dynamic>).map((e) => e as String).toList(),
      statuses: Map<String, String>.from(json['statuses'] as Map),
      isActive: json['isActive'] as bool,
      description: json['description'] as String?,
      settings: json['settings'] as Map<String, dynamic>?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      visibility: json['visibility'] as String? ?? 'group_private',
      constitutionRules:
          json['constitutionRules'] as Map<String, dynamic>? ?? const {},
      embeddedMessageId: json['embeddedMessageId'] as String?,
      chatGroupId: json['chatGroupId'] as String?,
    );

Map<String, dynamic> _$$LobbyImplToJson(_$LobbyImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'memberUids': instance.memberUids,
      'gameName': instance.gameName,
      'maxSpots': instance.maxSpots,
      'createdBy': instance.createdBy,
      'createdAt': instance.createdAt.toIso8601String(),
      'spots': instance.spots,
      'spotTimers': instance.spotTimers,
      'viewers': instance.viewers,
      'statuses': instance.statuses,
      'isActive': instance.isActive,
      'description': instance.description,
      'settings': instance.settings,
      'tags': instance.tags,
      'visibility': instance.visibility,
      'constitutionRules': instance.constitutionRules,
      'embeddedMessageId': instance.embeddedMessageId,
      'chatGroupId': instance.chatGroupId,
    };
