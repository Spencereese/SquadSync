// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'squad_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SquadStateImpl _$$SquadStateImplFromJson(Map<String, dynamic> json) =>
    _$SquadStateImpl(
      isInitialized: json['isInitialized'] as bool,
      isInitialDataLoaded: json['isInitialDataLoaded'] as bool,
      displayName: json['displayName'] as String,
      profileImage: json['profileImage'] as String?,
      memberProfileImages:
          (json['memberProfileImages'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String?),
      ),
      gameSquadSpots: (json['gameSquadSpots'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String?).toList()),
      ),
      gameSpotTimers: (json['gameSpotTimers'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(
            k,
            (e as List<dynamic>)
                .map((e) => e as Map<String, dynamic>?)
                .toList()),
      ),
      gameStatuses: (json['gameStatuses'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Map<String, String>.from(e as Map)),
      ),
      globalStatuses: Map<String, String>.from(json['globalStatuses'] as Map),
      squadMemberUids: (json['squadMemberUids'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      memberDisplayNames:
          Map<String, String>.from(json['memberDisplayNames'] as Map),
      userSquadIds: (json['userSquadIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      selectedSquadId: json['selectedSquadId'] as String?,
      userSquads: (json['userSquads'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Squad.fromJson(e as Map<String, dynamic>)),
      ),
      currentSquadData: json['currentSquadData'] as Map<String, dynamic>?,
      typing: Map<String, bool>.from(json['typing'] as Map),
      tiltEnabled: json['tiltEnabled'] as bool,
      hasNewSquadSpot: json['hasNewSquadSpot'] as bool,
      hasUnreadMessages: json['hasUnreadMessages'] as bool,
      gameHistory: (json['gameHistory'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      preferredModes: Map<String, String?>.from(json['preferredModes'] as Map),
      userBlocks: (json['userBlocks'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Map<String, bool>.from(e as Map)),
      ),
      dailyBanVotes: (json['dailyBanVotes'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Map<String, int>.from(e as Map)),
      ),
      bans: (json['bans'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(
            k,
            (e as List<dynamic>)
                .map((e) => e as Map<String, dynamic>)
                .toList()),
      ),
      availableGames: (json['availableGames'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      gameLobbies: (json['gameLobbies'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(
            k,
            (e as List<dynamic>)
                .map((e) => e as Map<String, dynamic>)
                .toList()),
      ),
      preferredPeacockGames: (json['preferredPeacockGames'] as List<dynamic>)
          .map((e) => e as String)
          .toSet(),
      mutedGames:
          (json['mutedGames'] as List<dynamic>).map((e) => e as String).toSet(),
      hiddenGames: (json['hiddenGames'] as List<dynamic>)
          .map((e) => e as String)
          .toSet(),
      peacockTimers: (json['peacockTimers'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, e as Map<String, dynamic>?),
      ),
      peacockQueue: (json['peacockQueue'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      scheduledTimes: (json['scheduledTimes'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      hasNewAvailability: json['hasNewAvailability'] as bool,
      currentGame: json['currentGame'] as Map<String, dynamic>?,
      spotTimerStates: (json['spotTimerStates'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Duration(microseconds: (e as num).toInt())),
      ),
      peacockTimerStates:
          (json['peacockTimerStates'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Duration(microseconds: (e as num).toInt())),
      ),
      dailyRatings: (json['dailyRatings'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Map<String, int>.from(e as Map)),
      ),
      allTimeRatings: (json['allTimeRatings'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Map<String, int>.from(e as Map)),
      ),
      analyticsMetrics: json['analyticsMetrics'] as Map<String, dynamic>,
      lastSyncTimestamp: DateTime.parse(json['lastSyncTimestamp'] as String),
    );

Map<String, dynamic> _$$SquadStateImplToJson(_$SquadStateImpl instance) =>
    <String, dynamic>{
      'isInitialized': instance.isInitialized,
      'isInitialDataLoaded': instance.isInitialDataLoaded,
      'displayName': instance.displayName,
      'profileImage': instance.profileImage,
      'memberProfileImages': instance.memberProfileImages,
      'gameSquadSpots': instance.gameSquadSpots,
      'gameSpotTimers': instance.gameSpotTimers,
      'gameStatuses': instance.gameStatuses,
      'globalStatuses': instance.globalStatuses,
      'squadMemberUids': instance.squadMemberUids,
      'memberDisplayNames': instance.memberDisplayNames,
      'userSquadIds': instance.userSquadIds,
      'selectedSquadId': instance.selectedSquadId,
      'userSquads': instance.userSquads,
      'currentSquadData': instance.currentSquadData,
      'typing': instance.typing,
      'tiltEnabled': instance.tiltEnabled,
      'hasNewSquadSpot': instance.hasNewSquadSpot,
      'hasUnreadMessages': instance.hasUnreadMessages,
      'gameHistory': instance.gameHistory,
      'preferredModes': instance.preferredModes,
      'userBlocks': instance.userBlocks,
      'dailyBanVotes': instance.dailyBanVotes,
      'bans': instance.bans,
      'availableGames': instance.availableGames,
      'gameLobbies': instance.gameLobbies,
      'preferredPeacockGames': instance.preferredPeacockGames.toList(),
      'mutedGames': instance.mutedGames.toList(),
      'hiddenGames': instance.hiddenGames.toList(),
      'peacockTimers': instance.peacockTimers,
      'peacockQueue': instance.peacockQueue,
      'scheduledTimes': instance.scheduledTimes,
      'hasNewAvailability': instance.hasNewAvailability,
      'currentGame': instance.currentGame,
      'spotTimerStates':
          instance.spotTimerStates.map((k, e) => MapEntry(k, e.inMicroseconds)),
      'peacockTimerStates': instance.peacockTimerStates
          .map((k, e) => MapEntry(k, e.inMicroseconds)),
      'dailyRatings': instance.dailyRatings,
      'allTimeRatings': instance.allTimeRatings,
      'analyticsMetrics': instance.analyticsMetrics,
      'lastSyncTimestamp': instance.lastSyncTimestamp.toIso8601String(),
    };
