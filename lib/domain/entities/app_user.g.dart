// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppUserImpl _$$AppUserImplFromJson(Map<String, dynamic> json) =>
    _$AppUserImpl(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String?,
      profileImage: json['profileImage'] as String?,
      preferredModes: Map<String, String?>.from(json['preferredModes'] as Map),
      userBlocks: (json['userBlocks'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Map<String, bool>.from(e as Map)),
      ),
      pinnedGames: (json['pinnedGames'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      notificationSettings:
          Map<String, bool>.from(json['notificationSettings'] as Map),
      hasRatedGame: Map<String, bool>.from(json['hasRatedGame'] as Map),
      dailyRatings: (json['dailyRatings'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Map<String, int>.from(e as Map)),
      ),
      allTimeRatings: (json['allTimeRatings'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Map<String, int>.from(e as Map)),
      ),
      currentStreaks: Map<String, int>.from(json['currentStreaks'] as Map),
      complaints: (json['complaints'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Map<String, int>.from(e as Map)),
      ),
      bans: (json['bans'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(
            k,
            (e as List<dynamic>)
                .map((e) => e as Map<String, dynamic>)
                .toList()),
      ),
      dailyBanVotes: (json['dailyBanVotes'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Map<String, bool>.from(e as Map)),
      ),
      blockedUsers: (json['blockedUsers'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      friends:
          (json['friends'] as List<dynamic>).map((e) => e as String).toList(),
      alerts:
          (json['alerts'] as List<dynamic>).map((e) => e as String).toList(),
      userGroups: (json['userGroups'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      alertCircles: (json['alertCircles'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      publicGroups: (json['publicGroups'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      pinnedMessages: (json['pinnedMessages'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$$AppUserImplToJson(_$AppUserImpl instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'displayName': instance.displayName,
      'profileImage': instance.profileImage,
      'preferredModes': instance.preferredModes,
      'userBlocks': instance.userBlocks,
      'pinnedGames': instance.pinnedGames,
      'notificationSettings': instance.notificationSettings,
      'hasRatedGame': instance.hasRatedGame,
      'dailyRatings': instance.dailyRatings,
      'allTimeRatings': instance.allTimeRatings,
      'currentStreaks': instance.currentStreaks,
      'complaints': instance.complaints,
      'bans': instance.bans,
      'dailyBanVotes': instance.dailyBanVotes,
      'blockedUsers': instance.blockedUsers,
      'friends': instance.friends,
      'alerts': instance.alerts,
      'userGroups': instance.userGroups,
      'alertCircles': instance.alertCircles,
      'publicGroups': instance.publicGroups,
      'pinnedMessages': instance.pinnedMessages,
    };
