// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GameImpl _$$GameImplFromJson(Map<String, dynamic> json) => _$GameImpl(
      name: json['name'] as String,
      slug: json['slug'] as String,
      igdbId: (json['igdbId'] as num?)?.toInt(),
      coverUrl: json['coverUrl'] as String?,
      summary: json['summary'] as String?,
      firstReleaseDate: json['firstReleaseDate'] == null
          ? null
          : DateTime.parse(json['firstReleaseDate'] as String),
      genres:
          (json['genres'] as List<dynamic>).map((e) => e as String).toList(),
      platforms:
          (json['platforms'] as List<dynamic>).map((e) => e as String).toList(),
      maxSpots: (json['maxSpots'] as num?)?.toInt(),
      isCached: json['isCached'] as bool,
      cachedAt: json['cachedAt'] == null
          ? null
          : DateTime.parse(json['cachedAt'] as String),
    );

Map<String, dynamic> _$$GameImplToJson(_$GameImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'slug': instance.slug,
      'igdbId': instance.igdbId,
      'coverUrl': instance.coverUrl,
      'summary': instance.summary,
      'firstReleaseDate': instance.firstReleaseDate?.toIso8601String(),
      'genres': instance.genres,
      'platforms': instance.platforms,
      'maxSpots': instance.maxSpots,
      'isCached': instance.isCached,
      'cachedAt': instance.cachedAt?.toIso8601String(),
    };
