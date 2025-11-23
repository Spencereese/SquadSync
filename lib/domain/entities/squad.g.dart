// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'squad.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SquadImpl _$$SquadImplFromJson(Map<String, dynamic> json) => _$SquadImpl(
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
    );

Map<String, dynamic> _$$SquadImplToJson(_$SquadImpl instance) =>
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
    };
