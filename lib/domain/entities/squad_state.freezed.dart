// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'squad_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SquadState _$SquadStateFromJson(Map<String, dynamic> json) {
  return _SquadState.fromJson(json);
}

/// @nodoc
mixin _$SquadState {
  bool get isInitialized => throw _privateConstructorUsedError;
  bool get isInitialDataLoaded => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String? get profileImage => throw _privateConstructorUsedError;
  Map<String, String?>? get memberProfileImages =>
      throw _privateConstructorUsedError; // Game-specific data
  Map<String, List<String?>> get gameSquadSpots =>
      throw _privateConstructorUsedError;
  Map<String, List<Map<String, dynamic>?>> get gameSpotTimers =>
      throw _privateConstructorUsedError;
  Map<String, Map<String, String>> get gameStatuses =>
      throw _privateConstructorUsedError;
  Map<String, String> get globalStatuses =>
      throw _privateConstructorUsedError; // Squad data
  List<String> get squadMemberUids => throw _privateConstructorUsedError;
  Map<String, String> get memberDisplayNames =>
      throw _privateConstructorUsedError;
  List<String> get userSquadIds => throw _privateConstructorUsedError;
  String? get selectedSquadId => throw _privateConstructorUsedError;
  Map<String, Squad> get userSquads => throw _privateConstructorUsedError;
  Map<String, dynamic>? get currentSquadData =>
      throw _privateConstructorUsedError; // UI state
  Map<String, bool> get typing => throw _privateConstructorUsedError;
  bool get tiltEnabled => throw _privateConstructorUsedError;
  bool get hasNewSquadSpot => throw _privateConstructorUsedError;
  bool get hasUnreadMessages => throw _privateConstructorUsedError; // Game data
  List<Map<String, dynamic>> get gameHistory =>
      throw _privateConstructorUsedError;
  Map<String, String?> get preferredModes => throw _privateConstructorUsedError;
  Map<String, Map<String, bool>> get userBlocks =>
      throw _privateConstructorUsedError;
  Map<String, Map<String, int>> get dailyBanVotes =>
      throw _privateConstructorUsedError;
  Map<String, List<Map<String, dynamic>>> get bans =>
      throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get availableGames =>
      throw _privateConstructorUsedError;
  Map<String, List<Map<String, dynamic>>> get gameLobbies =>
      throw _privateConstructorUsedError;
  Set<String> get preferredPeacockGames => throw _privateConstructorUsedError;
  Set<String> get mutedGames => throw _privateConstructorUsedError;
  Set<String> get hiddenGames => throw _privateConstructorUsedError;
  Map<String, Map<String, dynamic>?> get peacockTimers =>
      throw _privateConstructorUsedError;
  List<String> get peacockQueue => throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get scheduledTimes =>
      throw _privateConstructorUsedError;
  bool get hasNewAvailability =>
      throw _privateConstructorUsedError; // Current game
  Map<String, dynamic>? get currentGame =>
      throw _privateConstructorUsedError; // Timer states
  Map<String, Duration> get spotTimerStates =>
      throw _privateConstructorUsedError;
  Map<String, Duration> get peacockTimerStates =>
      throw _privateConstructorUsedError; // Analytics and tracking
  DateTime get lastSyncTimestamp => throw _privateConstructorUsedError;
  Map<String, dynamic> get analyticsMetrics =>
      throw _privateConstructorUsedError;

  /// Serializes this SquadState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SquadState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SquadStateCopyWith<SquadState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SquadStateCopyWith<$Res> {
  factory $SquadStateCopyWith(
          SquadState value, $Res Function(SquadState) then) =
      _$SquadStateCopyWithImpl<$Res, SquadState>;
  @useResult
  $Res call(
      {bool isInitialized,
      bool isInitialDataLoaded,
      String displayName,
      String? profileImage,
      Map<String, String?>? memberProfileImages,
      Map<String, List<String?>> gameSquadSpots,
      Map<String, List<Map<String, dynamic>?>> gameSpotTimers,
      Map<String, Map<String, String>> gameStatuses,
      Map<String, String> globalStatuses,
      List<String> squadMemberUids,
      Map<String, String> memberDisplayNames,
      List<String> userSquadIds,
      String? selectedSquadId,
      Map<String, Squad> userSquads,
      Map<String, dynamic>? currentSquadData,
      Map<String, bool> typing,
      bool tiltEnabled,
      bool hasNewSquadSpot,
      bool hasUnreadMessages,
      List<Map<String, dynamic>> gameHistory,
      Map<String, String?> preferredModes,
      Map<String, Map<String, bool>> userBlocks,
      Map<String, Map<String, int>> dailyBanVotes,
      Map<String, List<Map<String, dynamic>>> bans,
      List<Map<String, dynamic>> availableGames,
      Map<String, List<Map<String, dynamic>>> gameLobbies,
      Set<String> preferredPeacockGames,
      Set<String> mutedGames,
      Set<String> hiddenGames,
      Map<String, Map<String, dynamic>?> peacockTimers,
      List<String> peacockQueue,
      List<Map<String, dynamic>> scheduledTimes,
      bool hasNewAvailability,
      Map<String, dynamic>? currentGame,
      Map<String, Duration> spotTimerStates,
      Map<String, Duration> peacockTimerStates,
      DateTime lastSyncTimestamp,
      Map<String, dynamic> analyticsMetrics});
}

/// @nodoc
class _$SquadStateCopyWithImpl<$Res, $Val extends SquadState>
    implements $SquadStateCopyWith<$Res> {
  _$SquadStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SquadState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isInitialized = null,
    Object? isInitialDataLoaded = null,
    Object? displayName = null,
    Object? profileImage = freezed,
    Object? memberProfileImages = freezed,
    Object? gameSquadSpots = null,
    Object? gameSpotTimers = null,
    Object? gameStatuses = null,
    Object? globalStatuses = null,
    Object? squadMemberUids = null,
    Object? memberDisplayNames = null,
    Object? userSquadIds = null,
    Object? selectedSquadId = freezed,
    Object? userSquads = null,
    Object? currentSquadData = freezed,
    Object? typing = null,
    Object? tiltEnabled = null,
    Object? hasNewSquadSpot = null,
    Object? hasUnreadMessages = null,
    Object? gameHistory = null,
    Object? preferredModes = null,
    Object? userBlocks = null,
    Object? dailyBanVotes = null,
    Object? bans = null,
    Object? availableGames = null,
    Object? gameLobbies = null,
    Object? preferredPeacockGames = null,
    Object? mutedGames = null,
    Object? hiddenGames = null,
    Object? peacockTimers = null,
    Object? peacockQueue = null,
    Object? scheduledTimes = null,
    Object? hasNewAvailability = null,
    Object? currentGame = freezed,
    Object? spotTimerStates = null,
    Object? peacockTimerStates = null,
    Object? lastSyncTimestamp = null,
    Object? analyticsMetrics = null,
  }) {
    return _then(_value.copyWith(
      isInitialized: null == isInitialized
          ? _value.isInitialized
          : isInitialized // ignore: cast_nullable_to_non_nullable
              as bool,
      isInitialDataLoaded: null == isInitialDataLoaded
          ? _value.isInitialDataLoaded
          : isInitialDataLoaded // ignore: cast_nullable_to_non_nullable
              as bool,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      profileImage: freezed == profileImage
          ? _value.profileImage
          : profileImage // ignore: cast_nullable_to_non_nullable
              as String?,
      memberProfileImages: freezed == memberProfileImages
          ? _value.memberProfileImages
          : memberProfileImages // ignore: cast_nullable_to_non_nullable
              as Map<String, String?>?,
      gameSquadSpots: null == gameSquadSpots
          ? _value.gameSquadSpots
          : gameSquadSpots // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String?>>,
      gameSpotTimers: null == gameSpotTimers
          ? _value.gameSpotTimers
          : gameSpotTimers // ignore: cast_nullable_to_non_nullable
              as Map<String, List<Map<String, dynamic>?>>,
      gameStatuses: null == gameStatuses
          ? _value.gameStatuses
          : gameStatuses // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, String>>,
      globalStatuses: null == globalStatuses
          ? _value.globalStatuses
          : globalStatuses // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      squadMemberUids: null == squadMemberUids
          ? _value.squadMemberUids
          : squadMemberUids // ignore: cast_nullable_to_non_nullable
              as List<String>,
      memberDisplayNames: null == memberDisplayNames
          ? _value.memberDisplayNames
          : memberDisplayNames // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      userSquadIds: null == userSquadIds
          ? _value.userSquadIds
          : userSquadIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      selectedSquadId: freezed == selectedSquadId
          ? _value.selectedSquadId
          : selectedSquadId // ignore: cast_nullable_to_non_nullable
              as String?,
      userSquads: null == userSquads
          ? _value.userSquads
          : userSquads // ignore: cast_nullable_to_non_nullable
              as Map<String, Squad>,
      currentSquadData: freezed == currentSquadData
          ? _value.currentSquadData
          : currentSquadData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      typing: null == typing
          ? _value.typing
          : typing // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      tiltEnabled: null == tiltEnabled
          ? _value.tiltEnabled
          : tiltEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      hasNewSquadSpot: null == hasNewSquadSpot
          ? _value.hasNewSquadSpot
          : hasNewSquadSpot // ignore: cast_nullable_to_non_nullable
              as bool,
      hasUnreadMessages: null == hasUnreadMessages
          ? _value.hasUnreadMessages
          : hasUnreadMessages // ignore: cast_nullable_to_non_nullable
              as bool,
      gameHistory: null == gameHistory
          ? _value.gameHistory
          : gameHistory // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      preferredModes: null == preferredModes
          ? _value.preferredModes
          : preferredModes // ignore: cast_nullable_to_non_nullable
              as Map<String, String?>,
      userBlocks: null == userBlocks
          ? _value.userBlocks
          : userBlocks // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, bool>>,
      dailyBanVotes: null == dailyBanVotes
          ? _value.dailyBanVotes
          : dailyBanVotes // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, int>>,
      bans: null == bans
          ? _value.bans
          : bans // ignore: cast_nullable_to_non_nullable
              as Map<String, List<Map<String, dynamic>>>,
      availableGames: null == availableGames
          ? _value.availableGames
          : availableGames // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      gameLobbies: null == gameLobbies
          ? _value.gameLobbies
          : gameLobbies // ignore: cast_nullable_to_non_nullable
              as Map<String, List<Map<String, dynamic>>>,
      preferredPeacockGames: null == preferredPeacockGames
          ? _value.preferredPeacockGames
          : preferredPeacockGames // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      mutedGames: null == mutedGames
          ? _value.mutedGames
          : mutedGames // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      hiddenGames: null == hiddenGames
          ? _value.hiddenGames
          : hiddenGames // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      peacockTimers: null == peacockTimers
          ? _value.peacockTimers
          : peacockTimers // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, dynamic>?>,
      peacockQueue: null == peacockQueue
          ? _value.peacockQueue
          : peacockQueue // ignore: cast_nullable_to_non_nullable
              as List<String>,
      scheduledTimes: null == scheduledTimes
          ? _value.scheduledTimes
          : scheduledTimes // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      hasNewAvailability: null == hasNewAvailability
          ? _value.hasNewAvailability
          : hasNewAvailability // ignore: cast_nullable_to_non_nullable
              as bool,
      currentGame: freezed == currentGame
          ? _value.currentGame
          : currentGame // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      spotTimerStates: null == spotTimerStates
          ? _value.spotTimerStates
          : spotTimerStates // ignore: cast_nullable_to_non_nullable
              as Map<String, Duration>,
      peacockTimerStates: null == peacockTimerStates
          ? _value.peacockTimerStates
          : peacockTimerStates // ignore: cast_nullable_to_non_nullable
              as Map<String, Duration>,
      lastSyncTimestamp: null == lastSyncTimestamp
          ? _value.lastSyncTimestamp
          : lastSyncTimestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      analyticsMetrics: null == analyticsMetrics
          ? _value.analyticsMetrics
          : analyticsMetrics // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SquadStateImplCopyWith<$Res>
    implements $SquadStateCopyWith<$Res> {
  factory _$$SquadStateImplCopyWith(
          _$SquadStateImpl value, $Res Function(_$SquadStateImpl) then) =
      __$$SquadStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool isInitialized,
      bool isInitialDataLoaded,
      String displayName,
      String? profileImage,
      Map<String, String?>? memberProfileImages,
      Map<String, List<String?>> gameSquadSpots,
      Map<String, List<Map<String, dynamic>?>> gameSpotTimers,
      Map<String, Map<String, String>> gameStatuses,
      Map<String, String> globalStatuses,
      List<String> squadMemberUids,
      Map<String, String> memberDisplayNames,
      List<String> userSquadIds,
      String? selectedSquadId,
      Map<String, Squad> userSquads,
      Map<String, dynamic>? currentSquadData,
      Map<String, bool> typing,
      bool tiltEnabled,
      bool hasNewSquadSpot,
      bool hasUnreadMessages,
      List<Map<String, dynamic>> gameHistory,
      Map<String, String?> preferredModes,
      Map<String, Map<String, bool>> userBlocks,
      Map<String, Map<String, int>> dailyBanVotes,
      Map<String, List<Map<String, dynamic>>> bans,
      List<Map<String, dynamic>> availableGames,
      Map<String, List<Map<String, dynamic>>> gameLobbies,
      Set<String> preferredPeacockGames,
      Set<String> mutedGames,
      Set<String> hiddenGames,
      Map<String, Map<String, dynamic>?> peacockTimers,
      List<String> peacockQueue,
      List<Map<String, dynamic>> scheduledTimes,
      bool hasNewAvailability,
      Map<String, dynamic>? currentGame,
      Map<String, Duration> spotTimerStates,
      Map<String, Duration> peacockTimerStates,
      DateTime lastSyncTimestamp,
      Map<String, dynamic> analyticsMetrics});
}

/// @nodoc
class __$$SquadStateImplCopyWithImpl<$Res>
    extends _$SquadStateCopyWithImpl<$Res, _$SquadStateImpl>
    implements _$$SquadStateImplCopyWith<$Res> {
  __$$SquadStateImplCopyWithImpl(
      _$SquadStateImpl _value, $Res Function(_$SquadStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of SquadState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isInitialized = null,
    Object? isInitialDataLoaded = null,
    Object? displayName = null,
    Object? profileImage = freezed,
    Object? memberProfileImages = freezed,
    Object? gameSquadSpots = null,
    Object? gameSpotTimers = null,
    Object? gameStatuses = null,
    Object? globalStatuses = null,
    Object? squadMemberUids = null,
    Object? memberDisplayNames = null,
    Object? userSquadIds = null,
    Object? selectedSquadId = freezed,
    Object? userSquads = null,
    Object? currentSquadData = freezed,
    Object? typing = null,
    Object? tiltEnabled = null,
    Object? hasNewSquadSpot = null,
    Object? hasUnreadMessages = null,
    Object? gameHistory = null,
    Object? preferredModes = null,
    Object? userBlocks = null,
    Object? dailyBanVotes = null,
    Object? bans = null,
    Object? availableGames = null,
    Object? gameLobbies = null,
    Object? preferredPeacockGames = null,
    Object? mutedGames = null,
    Object? hiddenGames = null,
    Object? peacockTimers = null,
    Object? peacockQueue = null,
    Object? scheduledTimes = null,
    Object? hasNewAvailability = null,
    Object? currentGame = freezed,
    Object? spotTimerStates = null,
    Object? peacockTimerStates = null,
    Object? lastSyncTimestamp = null,
    Object? analyticsMetrics = null,
  }) {
    return _then(_$SquadStateImpl(
      isInitialized: null == isInitialized
          ? _value.isInitialized
          : isInitialized // ignore: cast_nullable_to_non_nullable
              as bool,
      isInitialDataLoaded: null == isInitialDataLoaded
          ? _value.isInitialDataLoaded
          : isInitialDataLoaded // ignore: cast_nullable_to_non_nullable
              as bool,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      profileImage: freezed == profileImage
          ? _value.profileImage
          : profileImage // ignore: cast_nullable_to_non_nullable
              as String?,
      memberProfileImages: freezed == memberProfileImages
          ? _value._memberProfileImages
          : memberProfileImages // ignore: cast_nullable_to_non_nullable
              as Map<String, String?>?,
      gameSquadSpots: null == gameSquadSpots
          ? _value._gameSquadSpots
          : gameSquadSpots // ignore: cast_nullable_to_non_nullable
              as Map<String, List<String?>>,
      gameSpotTimers: null == gameSpotTimers
          ? _value._gameSpotTimers
          : gameSpotTimers // ignore: cast_nullable_to_non_nullable
              as Map<String, List<Map<String, dynamic>?>>,
      gameStatuses: null == gameStatuses
          ? _value._gameStatuses
          : gameStatuses // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, String>>,
      globalStatuses: null == globalStatuses
          ? _value._globalStatuses
          : globalStatuses // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      squadMemberUids: null == squadMemberUids
          ? _value._squadMemberUids
          : squadMemberUids // ignore: cast_nullable_to_non_nullable
              as List<String>,
      memberDisplayNames: null == memberDisplayNames
          ? _value._memberDisplayNames
          : memberDisplayNames // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      userSquadIds: null == userSquadIds
          ? _value._userSquadIds
          : userSquadIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      selectedSquadId: freezed == selectedSquadId
          ? _value.selectedSquadId
          : selectedSquadId // ignore: cast_nullable_to_non_nullable
              as String?,
      userSquads: null == userSquads
          ? _value._userSquads
          : userSquads // ignore: cast_nullable_to_non_nullable
              as Map<String, Squad>,
      currentSquadData: freezed == currentSquadData
          ? _value._currentSquadData
          : currentSquadData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      typing: null == typing
          ? _value._typing
          : typing // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      tiltEnabled: null == tiltEnabled
          ? _value.tiltEnabled
          : tiltEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      hasNewSquadSpot: null == hasNewSquadSpot
          ? _value.hasNewSquadSpot
          : hasNewSquadSpot // ignore: cast_nullable_to_non_nullable
              as bool,
      hasUnreadMessages: null == hasUnreadMessages
          ? _value.hasUnreadMessages
          : hasUnreadMessages // ignore: cast_nullable_to_non_nullable
              as bool,
      gameHistory: null == gameHistory
          ? _value._gameHistory
          : gameHistory // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      preferredModes: null == preferredModes
          ? _value._preferredModes
          : preferredModes // ignore: cast_nullable_to_non_nullable
              as Map<String, String?>,
      userBlocks: null == userBlocks
          ? _value._userBlocks
          : userBlocks // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, bool>>,
      dailyBanVotes: null == dailyBanVotes
          ? _value._dailyBanVotes
          : dailyBanVotes // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, int>>,
      bans: null == bans
          ? _value._bans
          : bans // ignore: cast_nullable_to_non_nullable
              as Map<String, List<Map<String, dynamic>>>,
      availableGames: null == availableGames
          ? _value._availableGames
          : availableGames // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      gameLobbies: null == gameLobbies
          ? _value._gameLobbies
          : gameLobbies // ignore: cast_nullable_to_non_nullable
              as Map<String, List<Map<String, dynamic>>>,
      preferredPeacockGames: null == preferredPeacockGames
          ? _value._preferredPeacockGames
          : preferredPeacockGames // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      mutedGames: null == mutedGames
          ? _value._mutedGames
          : mutedGames // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      hiddenGames: null == hiddenGames
          ? _value._hiddenGames
          : hiddenGames // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      peacockTimers: null == peacockTimers
          ? _value._peacockTimers
          : peacockTimers // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, dynamic>?>,
      peacockQueue: null == peacockQueue
          ? _value._peacockQueue
          : peacockQueue // ignore: cast_nullable_to_non_nullable
              as List<String>,
      scheduledTimes: null == scheduledTimes
          ? _value._scheduledTimes
          : scheduledTimes // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      hasNewAvailability: null == hasNewAvailability
          ? _value.hasNewAvailability
          : hasNewAvailability // ignore: cast_nullable_to_non_nullable
              as bool,
      currentGame: freezed == currentGame
          ? _value._currentGame
          : currentGame // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      spotTimerStates: null == spotTimerStates
          ? _value._spotTimerStates
          : spotTimerStates // ignore: cast_nullable_to_non_nullable
              as Map<String, Duration>,
      peacockTimerStates: null == peacockTimerStates
          ? _value._peacockTimerStates
          : peacockTimerStates // ignore: cast_nullable_to_non_nullable
              as Map<String, Duration>,
      lastSyncTimestamp: null == lastSyncTimestamp
          ? _value.lastSyncTimestamp
          : lastSyncTimestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      analyticsMetrics: null == analyticsMetrics
          ? _value._analyticsMetrics
          : analyticsMetrics // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SquadStateImpl implements _SquadState {
  const _$SquadStateImpl(
      {required this.isInitialized,
      required this.isInitialDataLoaded,
      required this.displayName,
      this.profileImage,
      final Map<String, String?>? memberProfileImages,
      required final Map<String, List<String?>> gameSquadSpots,
      required final Map<String, List<Map<String, dynamic>?>> gameSpotTimers,
      required final Map<String, Map<String, String>> gameStatuses,
      required final Map<String, String> globalStatuses,
      required final List<String> squadMemberUids,
      required final Map<String, String> memberDisplayNames,
      required final List<String> userSquadIds,
      this.selectedSquadId,
      required final Map<String, Squad> userSquads,
      final Map<String, dynamic>? currentSquadData,
      required final Map<String, bool> typing,
      required this.tiltEnabled,
      required this.hasNewSquadSpot,
      required this.hasUnreadMessages,
      required final List<Map<String, dynamic>> gameHistory,
      required final Map<String, String?> preferredModes,
      required final Map<String, Map<String, bool>> userBlocks,
      required final Map<String, Map<String, int>> dailyBanVotes,
      required final Map<String, List<Map<String, dynamic>>> bans,
      required final List<Map<String, dynamic>> availableGames,
      required final Map<String, List<Map<String, dynamic>>> gameLobbies,
      required final Set<String> preferredPeacockGames,
      required final Set<String> mutedGames,
      required final Set<String> hiddenGames,
      required final Map<String, Map<String, dynamic>?> peacockTimers,
      required final List<String> peacockQueue,
      required final List<Map<String, dynamic>> scheduledTimes,
      required this.hasNewAvailability,
      final Map<String, dynamic>? currentGame,
      required final Map<String, Duration> spotTimerStates,
      required final Map<String, Duration> peacockTimerStates,
      required this.lastSyncTimestamp,
      required final Map<String, dynamic> analyticsMetrics})
      : _memberProfileImages = memberProfileImages,
        _gameSquadSpots = gameSquadSpots,
        _gameSpotTimers = gameSpotTimers,
        _gameStatuses = gameStatuses,
        _globalStatuses = globalStatuses,
        _squadMemberUids = squadMemberUids,
        _memberDisplayNames = memberDisplayNames,
        _userSquadIds = userSquadIds,
        _userSquads = userSquads,
        _currentSquadData = currentSquadData,
        _typing = typing,
        _gameHistory = gameHistory,
        _preferredModes = preferredModes,
        _userBlocks = userBlocks,
        _dailyBanVotes = dailyBanVotes,
        _bans = bans,
        _availableGames = availableGames,
        _gameLobbies = gameLobbies,
        _preferredPeacockGames = preferredPeacockGames,
        _mutedGames = mutedGames,
        _hiddenGames = hiddenGames,
        _peacockTimers = peacockTimers,
        _peacockQueue = peacockQueue,
        _scheduledTimes = scheduledTimes,
        _currentGame = currentGame,
        _spotTimerStates = spotTimerStates,
        _peacockTimerStates = peacockTimerStates,
        _analyticsMetrics = analyticsMetrics;

  factory _$SquadStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$SquadStateImplFromJson(json);

  @override
  final bool isInitialized;
  @override
  final bool isInitialDataLoaded;
  @override
  final String displayName;
  @override
  final String? profileImage;
  final Map<String, String?>? _memberProfileImages;
  @override
  Map<String, String?>? get memberProfileImages {
    final value = _memberProfileImages;
    if (value == null) return null;
    if (_memberProfileImages is EqualUnmodifiableMapView)
      return _memberProfileImages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

// Game-specific data
  final Map<String, List<String?>> _gameSquadSpots;
// Game-specific data
  @override
  Map<String, List<String?>> get gameSquadSpots {
    if (_gameSquadSpots is EqualUnmodifiableMapView) return _gameSquadSpots;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_gameSquadSpots);
  }

  final Map<String, List<Map<String, dynamic>?>> _gameSpotTimers;
  @override
  Map<String, List<Map<String, dynamic>?>> get gameSpotTimers {
    if (_gameSpotTimers is EqualUnmodifiableMapView) return _gameSpotTimers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_gameSpotTimers);
  }

  final Map<String, Map<String, String>> _gameStatuses;
  @override
  Map<String, Map<String, String>> get gameStatuses {
    if (_gameStatuses is EqualUnmodifiableMapView) return _gameStatuses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_gameStatuses);
  }

  final Map<String, String> _globalStatuses;
  @override
  Map<String, String> get globalStatuses {
    if (_globalStatuses is EqualUnmodifiableMapView) return _globalStatuses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_globalStatuses);
  }

// Squad data
  final List<String> _squadMemberUids;
// Squad data
  @override
  List<String> get squadMemberUids {
    if (_squadMemberUids is EqualUnmodifiableListView) return _squadMemberUids;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_squadMemberUids);
  }

  final Map<String, String> _memberDisplayNames;
  @override
  Map<String, String> get memberDisplayNames {
    if (_memberDisplayNames is EqualUnmodifiableMapView)
      return _memberDisplayNames;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_memberDisplayNames);
  }

  final List<String> _userSquadIds;
  @override
  List<String> get userSquadIds {
    if (_userSquadIds is EqualUnmodifiableListView) return _userSquadIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_userSquadIds);
  }

  @override
  final String? selectedSquadId;
  final Map<String, Squad> _userSquads;
  @override
  Map<String, Squad> get userSquads {
    if (_userSquads is EqualUnmodifiableMapView) return _userSquads;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_userSquads);
  }

  final Map<String, dynamic>? _currentSquadData;
  @override
  Map<String, dynamic>? get currentSquadData {
    final value = _currentSquadData;
    if (value == null) return null;
    if (_currentSquadData is EqualUnmodifiableMapView) return _currentSquadData;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

// UI state
  final Map<String, bool> _typing;
// UI state
  @override
  Map<String, bool> get typing {
    if (_typing is EqualUnmodifiableMapView) return _typing;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_typing);
  }

  @override
  final bool tiltEnabled;
  @override
  final bool hasNewSquadSpot;
  @override
  final bool hasUnreadMessages;
// Game data
  final List<Map<String, dynamic>> _gameHistory;
// Game data
  @override
  List<Map<String, dynamic>> get gameHistory {
    if (_gameHistory is EqualUnmodifiableListView) return _gameHistory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_gameHistory);
  }

  final Map<String, String?> _preferredModes;
  @override
  Map<String, String?> get preferredModes {
    if (_preferredModes is EqualUnmodifiableMapView) return _preferredModes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_preferredModes);
  }

  final Map<String, Map<String, bool>> _userBlocks;
  @override
  Map<String, Map<String, bool>> get userBlocks {
    if (_userBlocks is EqualUnmodifiableMapView) return _userBlocks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_userBlocks);
  }

  final Map<String, Map<String, int>> _dailyBanVotes;
  @override
  Map<String, Map<String, int>> get dailyBanVotes {
    if (_dailyBanVotes is EqualUnmodifiableMapView) return _dailyBanVotes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_dailyBanVotes);
  }

  final Map<String, List<Map<String, dynamic>>> _bans;
  @override
  Map<String, List<Map<String, dynamic>>> get bans {
    if (_bans is EqualUnmodifiableMapView) return _bans;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_bans);
  }

  final List<Map<String, dynamic>> _availableGames;
  @override
  List<Map<String, dynamic>> get availableGames {
    if (_availableGames is EqualUnmodifiableListView) return _availableGames;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_availableGames);
  }

  final Map<String, List<Map<String, dynamic>>> _gameLobbies;
  @override
  Map<String, List<Map<String, dynamic>>> get gameLobbies {
    if (_gameLobbies is EqualUnmodifiableMapView) return _gameLobbies;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_gameLobbies);
  }

  final Set<String> _preferredPeacockGames;
  @override
  Set<String> get preferredPeacockGames {
    if (_preferredPeacockGames is EqualUnmodifiableSetView)
      return _preferredPeacockGames;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_preferredPeacockGames);
  }

  final Set<String> _mutedGames;
  @override
  Set<String> get mutedGames {
    if (_mutedGames is EqualUnmodifiableSetView) return _mutedGames;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_mutedGames);
  }

  final Set<String> _hiddenGames;
  @override
  Set<String> get hiddenGames {
    if (_hiddenGames is EqualUnmodifiableSetView) return _hiddenGames;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_hiddenGames);
  }

  final Map<String, Map<String, dynamic>?> _peacockTimers;
  @override
  Map<String, Map<String, dynamic>?> get peacockTimers {
    if (_peacockTimers is EqualUnmodifiableMapView) return _peacockTimers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_peacockTimers);
  }

  final List<String> _peacockQueue;
  @override
  List<String> get peacockQueue {
    if (_peacockQueue is EqualUnmodifiableListView) return _peacockQueue;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_peacockQueue);
  }

  final List<Map<String, dynamic>> _scheduledTimes;
  @override
  List<Map<String, dynamic>> get scheduledTimes {
    if (_scheduledTimes is EqualUnmodifiableListView) return _scheduledTimes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_scheduledTimes);
  }

  @override
  final bool hasNewAvailability;
// Current game
  final Map<String, dynamic>? _currentGame;
// Current game
  @override
  Map<String, dynamic>? get currentGame {
    final value = _currentGame;
    if (value == null) return null;
    if (_currentGame is EqualUnmodifiableMapView) return _currentGame;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

// Timer states
  final Map<String, Duration> _spotTimerStates;
// Timer states
  @override
  Map<String, Duration> get spotTimerStates {
    if (_spotTimerStates is EqualUnmodifiableMapView) return _spotTimerStates;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_spotTimerStates);
  }

  final Map<String, Duration> _peacockTimerStates;
  @override
  Map<String, Duration> get peacockTimerStates {
    if (_peacockTimerStates is EqualUnmodifiableMapView)
      return _peacockTimerStates;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_peacockTimerStates);
  }

// Analytics and tracking
  @override
  final DateTime lastSyncTimestamp;
  final Map<String, dynamic> _analyticsMetrics;
  @override
  Map<String, dynamic> get analyticsMetrics {
    if (_analyticsMetrics is EqualUnmodifiableMapView) return _analyticsMetrics;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_analyticsMetrics);
  }

  @override
  String toString() {
    return 'SquadState(isInitialized: $isInitialized, isInitialDataLoaded: $isInitialDataLoaded, displayName: $displayName, profileImage: $profileImage, memberProfileImages: $memberProfileImages, gameSquadSpots: $gameSquadSpots, gameSpotTimers: $gameSpotTimers, gameStatuses: $gameStatuses, globalStatuses: $globalStatuses, squadMemberUids: $squadMemberUids, memberDisplayNames: $memberDisplayNames, userSquadIds: $userSquadIds, selectedSquadId: $selectedSquadId, userSquads: $userSquads, currentSquadData: $currentSquadData, typing: $typing, tiltEnabled: $tiltEnabled, hasNewSquadSpot: $hasNewSquadSpot, hasUnreadMessages: $hasUnreadMessages, gameHistory: $gameHistory, preferredModes: $preferredModes, userBlocks: $userBlocks, dailyBanVotes: $dailyBanVotes, bans: $bans, availableGames: $availableGames, gameLobbies: $gameLobbies, preferredPeacockGames: $preferredPeacockGames, mutedGames: $mutedGames, hiddenGames: $hiddenGames, peacockTimers: $peacockTimers, peacockQueue: $peacockQueue, scheduledTimes: $scheduledTimes, hasNewAvailability: $hasNewAvailability, currentGame: $currentGame, spotTimerStates: $spotTimerStates, peacockTimerStates: $peacockTimerStates, lastSyncTimestamp: $lastSyncTimestamp, analyticsMetrics: $analyticsMetrics)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SquadStateImpl &&
            (identical(other.isInitialized, isInitialized) ||
                other.isInitialized == isInitialized) &&
            (identical(other.isInitialDataLoaded, isInitialDataLoaded) ||
                other.isInitialDataLoaded == isInitialDataLoaded) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.profileImage, profileImage) ||
                other.profileImage == profileImage) &&
            const DeepCollectionEquality()
                .equals(other._memberProfileImages, _memberProfileImages) &&
            const DeepCollectionEquality()
                .equals(other._gameSquadSpots, _gameSquadSpots) &&
            const DeepCollectionEquality()
                .equals(other._gameSpotTimers, _gameSpotTimers) &&
            const DeepCollectionEquality()
                .equals(other._gameStatuses, _gameStatuses) &&
            const DeepCollectionEquality()
                .equals(other._globalStatuses, _globalStatuses) &&
            const DeepCollectionEquality()
                .equals(other._squadMemberUids, _squadMemberUids) &&
            const DeepCollectionEquality()
                .equals(other._memberDisplayNames, _memberDisplayNames) &&
            const DeepCollectionEquality()
                .equals(other._userSquadIds, _userSquadIds) &&
            (identical(other.selectedSquadId, selectedSquadId) ||
                other.selectedSquadId == selectedSquadId) &&
            const DeepCollectionEquality()
                .equals(other._userSquads, _userSquads) &&
            const DeepCollectionEquality()
                .equals(other._currentSquadData, _currentSquadData) &&
            const DeepCollectionEquality().equals(other._typing, _typing) &&
            (identical(other.tiltEnabled, tiltEnabled) ||
                other.tiltEnabled == tiltEnabled) &&
            (identical(other.hasNewSquadSpot, hasNewSquadSpot) ||
                other.hasNewSquadSpot == hasNewSquadSpot) &&
            (identical(other.hasUnreadMessages, hasUnreadMessages) ||
                other.hasUnreadMessages == hasUnreadMessages) &&
            const DeepCollectionEquality()
                .equals(other._gameHistory, _gameHistory) &&
            const DeepCollectionEquality()
                .equals(other._preferredModes, _preferredModes) &&
            const DeepCollectionEquality()
                .equals(other._userBlocks, _userBlocks) &&
            const DeepCollectionEquality()
                .equals(other._dailyBanVotes, _dailyBanVotes) &&
            const DeepCollectionEquality().equals(other._bans, _bans) &&
            const DeepCollectionEquality()
                .equals(other._availableGames, _availableGames) &&
            const DeepCollectionEquality()
                .equals(other._gameLobbies, _gameLobbies) &&
            const DeepCollectionEquality()
                .equals(other._preferredPeacockGames, _preferredPeacockGames) &&
            const DeepCollectionEquality()
                .equals(other._mutedGames, _mutedGames) &&
            const DeepCollectionEquality()
                .equals(other._hiddenGames, _hiddenGames) &&
            const DeepCollectionEquality()
                .equals(other._peacockTimers, _peacockTimers) &&
            const DeepCollectionEquality()
                .equals(other._peacockQueue, _peacockQueue) &&
            const DeepCollectionEquality()
                .equals(other._scheduledTimes, _scheduledTimes) &&
            (identical(other.hasNewAvailability, hasNewAvailability) ||
                other.hasNewAvailability == hasNewAvailability) &&
            const DeepCollectionEquality()
                .equals(other._currentGame, _currentGame) &&
            const DeepCollectionEquality()
                .equals(other._spotTimerStates, _spotTimerStates) &&
            const DeepCollectionEquality()
                .equals(other._peacockTimerStates, _peacockTimerStates) &&
            (identical(other.lastSyncTimestamp, lastSyncTimestamp) ||
                other.lastSyncTimestamp == lastSyncTimestamp) &&
            const DeepCollectionEquality()
                .equals(other._analyticsMetrics, _analyticsMetrics));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        isInitialized,
        isInitialDataLoaded,
        displayName,
        profileImage,
        const DeepCollectionEquality().hash(_memberProfileImages),
        const DeepCollectionEquality().hash(_gameSquadSpots),
        const DeepCollectionEquality().hash(_gameSpotTimers),
        const DeepCollectionEquality().hash(_gameStatuses),
        const DeepCollectionEquality().hash(_globalStatuses),
        const DeepCollectionEquality().hash(_squadMemberUids),
        const DeepCollectionEquality().hash(_memberDisplayNames),
        const DeepCollectionEquality().hash(_userSquadIds),
        selectedSquadId,
        const DeepCollectionEquality().hash(_userSquads),
        const DeepCollectionEquality().hash(_currentSquadData),
        const DeepCollectionEquality().hash(_typing),
        tiltEnabled,
        hasNewSquadSpot,
        hasUnreadMessages,
        const DeepCollectionEquality().hash(_gameHistory),
        const DeepCollectionEquality().hash(_preferredModes),
        const DeepCollectionEquality().hash(_userBlocks),
        const DeepCollectionEquality().hash(_dailyBanVotes),
        const DeepCollectionEquality().hash(_bans),
        const DeepCollectionEquality().hash(_availableGames),
        const DeepCollectionEquality().hash(_gameLobbies),
        const DeepCollectionEquality().hash(_preferredPeacockGames),
        const DeepCollectionEquality().hash(_mutedGames),
        const DeepCollectionEquality().hash(_hiddenGames),
        const DeepCollectionEquality().hash(_peacockTimers),
        const DeepCollectionEquality().hash(_peacockQueue),
        const DeepCollectionEquality().hash(_scheduledTimes),
        hasNewAvailability,
        const DeepCollectionEquality().hash(_currentGame),
        const DeepCollectionEquality().hash(_spotTimerStates),
        const DeepCollectionEquality().hash(_peacockTimerStates),
        lastSyncTimestamp,
        const DeepCollectionEquality().hash(_analyticsMetrics)
      ]);

  /// Create a copy of SquadState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SquadStateImplCopyWith<_$SquadStateImpl> get copyWith =>
      __$$SquadStateImplCopyWithImpl<_$SquadStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SquadStateImplToJson(
      this,
    );
  }
}

abstract class _SquadState implements SquadState {
  const factory _SquadState(
      {required final bool isInitialized,
      required final bool isInitialDataLoaded,
      required final String displayName,
      final String? profileImage,
      final Map<String, String?>? memberProfileImages,
      required final Map<String, List<String?>> gameSquadSpots,
      required final Map<String, List<Map<String, dynamic>?>> gameSpotTimers,
      required final Map<String, Map<String, String>> gameStatuses,
      required final Map<String, String> globalStatuses,
      required final List<String> squadMemberUids,
      required final Map<String, String> memberDisplayNames,
      required final List<String> userSquadIds,
      final String? selectedSquadId,
      required final Map<String, Squad> userSquads,
      final Map<String, dynamic>? currentSquadData,
      required final Map<String, bool> typing,
      required final bool tiltEnabled,
      required final bool hasNewSquadSpot,
      required final bool hasUnreadMessages,
      required final List<Map<String, dynamic>> gameHistory,
      required final Map<String, String?> preferredModes,
      required final Map<String, Map<String, bool>> userBlocks,
      required final Map<String, Map<String, int>> dailyBanVotes,
      required final Map<String, List<Map<String, dynamic>>> bans,
      required final List<Map<String, dynamic>> availableGames,
      required final Map<String, List<Map<String, dynamic>>> gameLobbies,
      required final Set<String> preferredPeacockGames,
      required final Set<String> mutedGames,
      required final Set<String> hiddenGames,
      required final Map<String, Map<String, dynamic>?> peacockTimers,
      required final List<String> peacockQueue,
      required final List<Map<String, dynamic>> scheduledTimes,
      required final bool hasNewAvailability,
      final Map<String, dynamic>? currentGame,
      required final Map<String, Duration> spotTimerStates,
      required final Map<String, Duration> peacockTimerStates,
      required final DateTime lastSyncTimestamp,
      required final Map<String, dynamic> analyticsMetrics}) = _$SquadStateImpl;

  factory _SquadState.fromJson(Map<String, dynamic> json) =
      _$SquadStateImpl.fromJson;

  @override
  bool get isInitialized;
  @override
  bool get isInitialDataLoaded;
  @override
  String get displayName;
  @override
  String? get profileImage;
  @override
  Map<String, String?>? get memberProfileImages; // Game-specific data
  @override
  Map<String, List<String?>> get gameSquadSpots;
  @override
  Map<String, List<Map<String, dynamic>?>> get gameSpotTimers;
  @override
  Map<String, Map<String, String>> get gameStatuses;
  @override
  Map<String, String> get globalStatuses; // Squad data
  @override
  List<String> get squadMemberUids;
  @override
  Map<String, String> get memberDisplayNames;
  @override
  List<String> get userSquadIds;
  @override
  String? get selectedSquadId;
  @override
  Map<String, Squad> get userSquads;
  @override
  Map<String, dynamic>? get currentSquadData; // UI state
  @override
  Map<String, bool> get typing;
  @override
  bool get tiltEnabled;
  @override
  bool get hasNewSquadSpot;
  @override
  bool get hasUnreadMessages; // Game data
  @override
  List<Map<String, dynamic>> get gameHistory;
  @override
  Map<String, String?> get preferredModes;
  @override
  Map<String, Map<String, bool>> get userBlocks;
  @override
  Map<String, Map<String, int>> get dailyBanVotes;
  @override
  Map<String, List<Map<String, dynamic>>> get bans;
  @override
  List<Map<String, dynamic>> get availableGames;
  @override
  Map<String, List<Map<String, dynamic>>> get gameLobbies;
  @override
  Set<String> get preferredPeacockGames;
  @override
  Set<String> get mutedGames;
  @override
  Set<String> get hiddenGames;
  @override
  Map<String, Map<String, dynamic>?> get peacockTimers;
  @override
  List<String> get peacockQueue;
  @override
  List<Map<String, dynamic>> get scheduledTimes;
  @override
  bool get hasNewAvailability; // Current game
  @override
  Map<String, dynamic>? get currentGame; // Timer states
  @override
  Map<String, Duration> get spotTimerStates;
  @override
  Map<String, Duration> get peacockTimerStates; // Analytics and tracking
  @override
  DateTime get lastSyncTimestamp;
  @override
  Map<String, dynamic> get analyticsMetrics;

  /// Create a copy of SquadState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SquadStateImplCopyWith<_$SquadStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
