// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatGroupImpl _$$ChatGroupImplFromJson(Map<String, dynamic> json) =>
    _$ChatGroupImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      memberUids: (json['memberUids'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      isPublic: json['isPublic'] as bool,
      memberCount: (json['memberCount'] as num).toInt(),
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      description: json['description'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      admins:
          (json['admins'] as List<dynamic>?)?.map((e) => e as String).toList(),
      moderators: (json['moderators'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      isActive: json['isActive'] as bool?,
      lastActivity: json['lastActivity'] == null
          ? null
          : DateTime.parse(json['lastActivity'] as String),
      settings: json['settings'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$ChatGroupImplToJson(_$ChatGroupImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'memberUids': instance.memberUids,
      'isPublic': instance.isPublic,
      'memberCount': instance.memberCount,
      'createdBy': instance.createdBy,
      'createdAt': instance.createdAt.toIso8601String(),
      'description': instance.description,
      'avatarUrl': instance.avatarUrl,
      'metadata': instance.metadata,
      'admins': instance.admins,
      'moderators': instance.moderators,
      'isActive': instance.isActive,
      'lastActivity': instance.lastActivity?.toIso8601String(),
      'settings': instance.settings,
    };
