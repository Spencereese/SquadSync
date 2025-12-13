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
      peacockQueue: (json['peacockQueue'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      peacockTimers: (json['peacockTimers'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, e as Map<String, dynamic>?),
      ),
      peacockTimerStates:
          (json['peacockTimerStates'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Duration(microseconds: (e as num).toInt())),
      ),
      preferredPeacockGames: (json['preferredPeacockGames'] as List<dynamic>)
          .map((e) => e as String)
          .toSet(),
      spotTimerStates: (json['spotTimerStates'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Duration(microseconds: (e as num).toInt())),
      ),
      selectedLobbyId: json['selectedLobbyId'] as String?,
      currentLobby: json['currentLobby'] == null
          ? null
          : Lobby.fromJson(json['currentLobby'] as Map<String, dynamic>),
      currentLobbyData: json['currentLobbyData'] as Map<String, dynamic>?,
      currentGame: json['currentGame'] as Map<String, dynamic>?,
      userLobbyIds: (json['userLobbyIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      userLobbies: (json['userLobbies'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Lobby.fromJson(e as Map<String, dynamic>)),
      ),
      lobbyMemberUids: (json['lobbyMemberUids'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      memberDisplayNames:
          Map<String, String>.from(json['memberDisplayNames'] as Map),
      memberProfileImages:
          (json['memberProfileImages'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String?),
      ),
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
      mutedGames:
          (json['mutedGames'] as List<dynamic>).map((e) => e as String).toSet(),
      hiddenGames: (json['hiddenGames'] as List<dynamic>)
          .map((e) => e as String)
          .toSet(),
      scheduledTimes: (json['scheduledTimes'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      hasNewAvailability: json['hasNewAvailability'] as bool,
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
      'gameLobbySpots': instance.gameLobbySpots,
      'gameSpotTimers': instance.gameSpotTimers,
      'gameStatuses': instance.gameStatuses,
      'globalStatuses': instance.globalStatuses,
      'peacockQueue': instance.peacockQueue,
      'peacockTimers': instance.peacockTimers,
      'peacockTimerStates': instance.peacockTimerStates
          .map((k, e) => MapEntry(k, e.inMicroseconds)),
      'preferredPeacockGames': instance.preferredPeacockGames.toList(),
      'spotTimerStates':
          instance.spotTimerStates.map((k, e) => MapEntry(k, e.inMicroseconds)),
      'selectedLobbyId': instance.selectedLobbyId,
      'currentLobby': instance.currentLobby,
      'currentLobbyData': instance.currentLobbyData,
      'currentGame': instance.currentGame,
      'userLobbyIds': instance.userLobbyIds,
      'userLobbies': instance.userLobbies,
      'lobbyMemberUids': instance.lobbyMemberUids,
      'memberDisplayNames': instance.memberDisplayNames,
      'memberProfileImages': instance.memberProfileImages,
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
      'mutedGames': instance.mutedGames.toList(),
      'hiddenGames': instance.hiddenGames.toList(),
      'scheduledTimes': instance.scheduledTimes,
      'hasNewAvailability': instance.hasNewAvailability,
      'dailyRatings': instance.dailyRatings,
      'allTimeRatings': instance.allTimeRatings,
      'analyticsMetrics': instance.analyticsMetrics,
      'lastSyncTimestamp': instance.lastSyncTimestamp.toIso8601String(),
    };
