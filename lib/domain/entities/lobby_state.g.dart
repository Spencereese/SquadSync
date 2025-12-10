// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lobby_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LobbyStateImpl _$$LobbyStateImplFromJson(Map<String, dynamic> json) =>
    _$LobbyStateImpl(
      isInitialized: json['isInitialized'] as bool,
      isInitialDataLoaded: json['isInitialDataLoaded'] as bool,
      displayName: json['displayName'] as String,
      profileImage: json['profileImage'] as String?,
      memberProfileImages:
          (json['memberProfileImages'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String?),
      ),
      gameLobbySpots: (json['gameLobbySpots'] as Map<String, dynamic>).map(
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
      lobbyMemberUids: (json['lobbyMemberUids'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      memberDisplayNames:
          Map<String, String>.from(json['memberDisplayNames'] as Map),
      userLobbyIds: (json['userLobbyIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      selectedLobbyId: json['selectedLobbyId'] as String?,
      userLobbies: (json['userLobbies'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Lobby.fromJson(e as Map<String, dynamic>)),
      ),
      currentLobbyData: json['currentLobbyData'] as Map<String, dynamic>?,
      typing: Map<String, bool>.from(json['typing'] as Map),
      tiltEnabled: json['tiltEnabled'] as bool,
      hasNewLobbySpot: json['hasNewLobbySpot'] as bool,
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

Map<String, dynamic> _$$LobbyStateImplToJson(_$LobbyStateImpl instance) =>
    <String, dynamic>{
      'isInitialized': instance.isInitialized,
      'isInitialDataLoaded': instance.isInitialDataLoaded,
      'displayName': instance.displayName,
      'profileImage': instance.profileImage,
      'memberProfileImages': instance.memberProfileImages,
      'gameLobbySpots': instance.gameLobbySpots,
      'gameSpotTimers': instance.gameSpotTimers,
      'gameStatuses': instance.gameStatuses,
      'globalStatuses': instance.globalStatuses,
      'lobbyMemberUids': instance.lobbyMemberUids,
      'memberDisplayNames': instance.memberDisplayNames,
      'userLobbyIds': instance.userLobbyIds,
      'selectedLobbyId': instance.selectedLobbyId,
      'userLobbies': instance.userLobbies,
      'currentLobbyData': instance.currentLobbyData,
      'typing': instance.typing,
      'tiltEnabled': instance.tiltEnabled,
      'hasNewLobbySpot': instance.hasNewLobbySpot,
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
