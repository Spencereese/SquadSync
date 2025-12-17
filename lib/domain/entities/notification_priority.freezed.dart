// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_priority.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

NotificationCooldown _$NotificationCooldownFromJson(Map<String, dynamic> json) {
  return _NotificationCooldown.fromJson(json);
}

/// @nodoc
mixin _$NotificationCooldown {
  String get userId => throw _privateConstructorUsedError;
  String get lobbyId => throw _privateConstructorUsedError;
  DateTime get lastSentAt => throw _privateConstructorUsedError;
  NotificationType get type => throw _privateConstructorUsedError;

  /// Serializes this NotificationCooldown to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NotificationCooldown
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NotificationCooldownCopyWith<NotificationCooldown> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NotificationCooldownCopyWith<$Res> {
  factory $NotificationCooldownCopyWith(NotificationCooldown value,
          $Res Function(NotificationCooldown) then) =
      _$NotificationCooldownCopyWithImpl<$Res, NotificationCooldown>;
  @useResult
  $Res call(
      {String userId,
      String lobbyId,
      DateTime lastSentAt,
      NotificationType type});
}

/// @nodoc
class _$NotificationCooldownCopyWithImpl<$Res,
        $Val extends NotificationCooldown>
    implements $NotificationCooldownCopyWith<$Res> {
  _$NotificationCooldownCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NotificationCooldown
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? lobbyId = null,
    Object? lastSentAt = null,
    Object? type = null,
  }) {
    return _then(_value.copyWith(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      lobbyId: null == lobbyId
          ? _value.lobbyId
          : lobbyId // ignore: cast_nullable_to_non_nullable
              as String,
      lastSentAt: null == lastSentAt
          ? _value.lastSentAt
          : lastSentAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as NotificationType,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NotificationCooldownImplCopyWith<$Res>
    implements $NotificationCooldownCopyWith<$Res> {
  factory _$$NotificationCooldownImplCopyWith(_$NotificationCooldownImpl value,
          $Res Function(_$NotificationCooldownImpl) then) =
      __$$NotificationCooldownImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String userId,
      String lobbyId,
      DateTime lastSentAt,
      NotificationType type});
}

/// @nodoc
class __$$NotificationCooldownImplCopyWithImpl<$Res>
    extends _$NotificationCooldownCopyWithImpl<$Res, _$NotificationCooldownImpl>
    implements _$$NotificationCooldownImplCopyWith<$Res> {
  __$$NotificationCooldownImplCopyWithImpl(_$NotificationCooldownImpl _value,
      $Res Function(_$NotificationCooldownImpl) _then)
      : super(_value, _then);

  /// Create a copy of NotificationCooldown
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? lobbyId = null,
    Object? lastSentAt = null,
    Object? type = null,
  }) {
    return _then(_$NotificationCooldownImpl(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      lobbyId: null == lobbyId
          ? _value.lobbyId
          : lobbyId // ignore: cast_nullable_to_non_nullable
              as String,
      lastSentAt: null == lastSentAt
          ? _value.lastSentAt
          : lastSentAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as NotificationType,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NotificationCooldownImpl implements _NotificationCooldown {
  const _$NotificationCooldownImpl(
      {required this.userId,
      required this.lobbyId,
      required this.lastSentAt,
      required this.type});

  factory _$NotificationCooldownImpl.fromJson(Map<String, dynamic> json) =>
      _$$NotificationCooldownImplFromJson(json);

  @override
  final String userId;
  @override
  final String lobbyId;
  @override
  final DateTime lastSentAt;
  @override
  final NotificationType type;

  @override
  String toString() {
    return 'NotificationCooldown(userId: $userId, lobbyId: $lobbyId, lastSentAt: $lastSentAt, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotificationCooldownImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.lobbyId, lobbyId) || other.lobbyId == lobbyId) &&
            (identical(other.lastSentAt, lastSentAt) ||
                other.lastSentAt == lastSentAt) &&
            (identical(other.type, type) || other.type == type));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, userId, lobbyId, lastSentAt, type);

  /// Create a copy of NotificationCooldown
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NotificationCooldownImplCopyWith<_$NotificationCooldownImpl>
      get copyWith =>
          __$$NotificationCooldownImplCopyWithImpl<_$NotificationCooldownImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NotificationCooldownImplToJson(
      this,
    );
  }
}

abstract class _NotificationCooldown implements NotificationCooldown {
  const factory _NotificationCooldown(
      {required final String userId,
      required final String lobbyId,
      required final DateTime lastSentAt,
      required final NotificationType type}) = _$NotificationCooldownImpl;

  factory _NotificationCooldown.fromJson(Map<String, dynamic> json) =
      _$NotificationCooldownImpl.fromJson;

  @override
  String get userId;
  @override
  String get lobbyId;
  @override
  DateTime get lastSentAt;
  @override
  NotificationType get type;

  /// Create a copy of NotificationCooldown
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NotificationCooldownImplCopyWith<_$NotificationCooldownImpl>
      get copyWith => throw _privateConstructorUsedError;
}

MatchAffinity _$MatchAffinityFromJson(Map<String, dynamic> json) {
  return _MatchAffinity.fromJson(json);
}

/// @nodoc
mixin _$MatchAffinity {
  String get userId => throw _privateConstructorUsedError;
  String get gameId => throw _privateConstructorUsedError;
  int get sharedSessionCount => throw _privateConstructorUsedError;
  DateTime get lastPlayedTogether => throw _privateConstructorUsedError;
  double get affinityScore => throw _privateConstructorUsedError;

  /// Serializes this MatchAffinity to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MatchAffinity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MatchAffinityCopyWith<MatchAffinity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MatchAffinityCopyWith<$Res> {
  factory $MatchAffinityCopyWith(
          MatchAffinity value, $Res Function(MatchAffinity) then) =
      _$MatchAffinityCopyWithImpl<$Res, MatchAffinity>;
  @useResult
  $Res call(
      {String userId,
      String gameId,
      int sharedSessionCount,
      DateTime lastPlayedTogether,
      double affinityScore});
}

/// @nodoc
class _$MatchAffinityCopyWithImpl<$Res, $Val extends MatchAffinity>
    implements $MatchAffinityCopyWith<$Res> {
  _$MatchAffinityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MatchAffinity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? gameId = null,
    Object? sharedSessionCount = null,
    Object? lastPlayedTogether = null,
    Object? affinityScore = null,
  }) {
    return _then(_value.copyWith(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      gameId: null == gameId
          ? _value.gameId
          : gameId // ignore: cast_nullable_to_non_nullable
              as String,
      sharedSessionCount: null == sharedSessionCount
          ? _value.sharedSessionCount
          : sharedSessionCount // ignore: cast_nullable_to_non_nullable
              as int,
      lastPlayedTogether: null == lastPlayedTogether
          ? _value.lastPlayedTogether
          : lastPlayedTogether // ignore: cast_nullable_to_non_nullable
              as DateTime,
      affinityScore: null == affinityScore
          ? _value.affinityScore
          : affinityScore // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MatchAffinityImplCopyWith<$Res>
    implements $MatchAffinityCopyWith<$Res> {
  factory _$$MatchAffinityImplCopyWith(
          _$MatchAffinityImpl value, $Res Function(_$MatchAffinityImpl) then) =
      __$$MatchAffinityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String userId,
      String gameId,
      int sharedSessionCount,
      DateTime lastPlayedTogether,
      double affinityScore});
}

/// @nodoc
class __$$MatchAffinityImplCopyWithImpl<$Res>
    extends _$MatchAffinityCopyWithImpl<$Res, _$MatchAffinityImpl>
    implements _$$MatchAffinityImplCopyWith<$Res> {
  __$$MatchAffinityImplCopyWithImpl(
      _$MatchAffinityImpl _value, $Res Function(_$MatchAffinityImpl) _then)
      : super(_value, _then);

  /// Create a copy of MatchAffinity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? gameId = null,
    Object? sharedSessionCount = null,
    Object? lastPlayedTogether = null,
    Object? affinityScore = null,
  }) {
    return _then(_$MatchAffinityImpl(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      gameId: null == gameId
          ? _value.gameId
          : gameId // ignore: cast_nullable_to_non_nullable
              as String,
      sharedSessionCount: null == sharedSessionCount
          ? _value.sharedSessionCount
          : sharedSessionCount // ignore: cast_nullable_to_non_nullable
              as int,
      lastPlayedTogether: null == lastPlayedTogether
          ? _value.lastPlayedTogether
          : lastPlayedTogether // ignore: cast_nullable_to_non_nullable
              as DateTime,
      affinityScore: null == affinityScore
          ? _value.affinityScore
          : affinityScore // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MatchAffinityImpl implements _MatchAffinity {
  const _$MatchAffinityImpl(
      {required this.userId,
      required this.gameId,
      required this.sharedSessionCount,
      required this.lastPlayedTogether,
      required this.affinityScore});

  factory _$MatchAffinityImpl.fromJson(Map<String, dynamic> json) =>
      _$$MatchAffinityImplFromJson(json);

  @override
  final String userId;
  @override
  final String gameId;
  @override
  final int sharedSessionCount;
  @override
  final DateTime lastPlayedTogether;
  @override
  final double affinityScore;

  @override
  String toString() {
    return 'MatchAffinity(userId: $userId, gameId: $gameId, sharedSessionCount: $sharedSessionCount, lastPlayedTogether: $lastPlayedTogether, affinityScore: $affinityScore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MatchAffinityImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.gameId, gameId) || other.gameId == gameId) &&
            (identical(other.sharedSessionCount, sharedSessionCount) ||
                other.sharedSessionCount == sharedSessionCount) &&
            (identical(other.lastPlayedTogether, lastPlayedTogether) ||
                other.lastPlayedTogether == lastPlayedTogether) &&
            (identical(other.affinityScore, affinityScore) ||
                other.affinityScore == affinityScore));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, userId, gameId,
      sharedSessionCount, lastPlayedTogether, affinityScore);

  /// Create a copy of MatchAffinity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MatchAffinityImplCopyWith<_$MatchAffinityImpl> get copyWith =>
      __$$MatchAffinityImplCopyWithImpl<_$MatchAffinityImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MatchAffinityImplToJson(
      this,
    );
  }
}

abstract class _MatchAffinity implements MatchAffinity {
  const factory _MatchAffinity(
      {required final String userId,
      required final String gameId,
      required final int sharedSessionCount,
      required final DateTime lastPlayedTogether,
      required final double affinityScore}) = _$MatchAffinityImpl;

  factory _MatchAffinity.fromJson(Map<String, dynamic> json) =
      _$MatchAffinityImpl.fromJson;

  @override
  String get userId;
  @override
  String get gameId;
  @override
  int get sharedSessionCount;
  @override
  DateTime get lastPlayedTogether;
  @override
  double get affinityScore;

  /// Create a copy of MatchAffinity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MatchAffinityImplCopyWith<_$MatchAffinityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BadgeState _$BadgeStateFromJson(Map<String, dynamic> json) {
  return _BadgeState.fromJson(json);
}

/// @nodoc
mixin _$BadgeState {
  int get chatUnreadCount => throw _privateConstructorUsedError;
  int get lobbyUpdatesCount => throw _privateConstructorUsedError;
  int get invitesCount => throw _privateConstructorUsedError;
  bool get hasMomentum => throw _privateConstructorUsedError;

  /// Serializes this BadgeState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BadgeState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BadgeStateCopyWith<BadgeState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BadgeStateCopyWith<$Res> {
  factory $BadgeStateCopyWith(
          BadgeState value, $Res Function(BadgeState) then) =
      _$BadgeStateCopyWithImpl<$Res, BadgeState>;
  @useResult
  $Res call(
      {int chatUnreadCount,
      int lobbyUpdatesCount,
      int invitesCount,
      bool hasMomentum});
}

/// @nodoc
class _$BadgeStateCopyWithImpl<$Res, $Val extends BadgeState>
    implements $BadgeStateCopyWith<$Res> {
  _$BadgeStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BadgeState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chatUnreadCount = null,
    Object? lobbyUpdatesCount = null,
    Object? invitesCount = null,
    Object? hasMomentum = null,
  }) {
    return _then(_value.copyWith(
      chatUnreadCount: null == chatUnreadCount
          ? _value.chatUnreadCount
          : chatUnreadCount // ignore: cast_nullable_to_non_nullable
              as int,
      lobbyUpdatesCount: null == lobbyUpdatesCount
          ? _value.lobbyUpdatesCount
          : lobbyUpdatesCount // ignore: cast_nullable_to_non_nullable
              as int,
      invitesCount: null == invitesCount
          ? _value.invitesCount
          : invitesCount // ignore: cast_nullable_to_non_nullable
              as int,
      hasMomentum: null == hasMomentum
          ? _value.hasMomentum
          : hasMomentum // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BadgeStateImplCopyWith<$Res>
    implements $BadgeStateCopyWith<$Res> {
  factory _$$BadgeStateImplCopyWith(
          _$BadgeStateImpl value, $Res Function(_$BadgeStateImpl) then) =
      __$$BadgeStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int chatUnreadCount,
      int lobbyUpdatesCount,
      int invitesCount,
      bool hasMomentum});
}

/// @nodoc
class __$$BadgeStateImplCopyWithImpl<$Res>
    extends _$BadgeStateCopyWithImpl<$Res, _$BadgeStateImpl>
    implements _$$BadgeStateImplCopyWith<$Res> {
  __$$BadgeStateImplCopyWithImpl(
      _$BadgeStateImpl _value, $Res Function(_$BadgeStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of BadgeState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chatUnreadCount = null,
    Object? lobbyUpdatesCount = null,
    Object? invitesCount = null,
    Object? hasMomentum = null,
  }) {
    return _then(_$BadgeStateImpl(
      chatUnreadCount: null == chatUnreadCount
          ? _value.chatUnreadCount
          : chatUnreadCount // ignore: cast_nullable_to_non_nullable
              as int,
      lobbyUpdatesCount: null == lobbyUpdatesCount
          ? _value.lobbyUpdatesCount
          : lobbyUpdatesCount // ignore: cast_nullable_to_non_nullable
              as int,
      invitesCount: null == invitesCount
          ? _value.invitesCount
          : invitesCount // ignore: cast_nullable_to_non_nullable
              as int,
      hasMomentum: null == hasMomentum
          ? _value.hasMomentum
          : hasMomentum // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BadgeStateImpl implements _BadgeState {
  const _$BadgeStateImpl(
      {this.chatUnreadCount = 0,
      this.lobbyUpdatesCount = 0,
      this.invitesCount = 0,
      this.hasMomentum = false});

  factory _$BadgeStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$BadgeStateImplFromJson(json);

  @override
  @JsonKey()
  final int chatUnreadCount;
  @override
  @JsonKey()
  final int lobbyUpdatesCount;
  @override
  @JsonKey()
  final int invitesCount;
  @override
  @JsonKey()
  final bool hasMomentum;

  @override
  String toString() {
    return 'BadgeState(chatUnreadCount: $chatUnreadCount, lobbyUpdatesCount: $lobbyUpdatesCount, invitesCount: $invitesCount, hasMomentum: $hasMomentum)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BadgeStateImpl &&
            (identical(other.chatUnreadCount, chatUnreadCount) ||
                other.chatUnreadCount == chatUnreadCount) &&
            (identical(other.lobbyUpdatesCount, lobbyUpdatesCount) ||
                other.lobbyUpdatesCount == lobbyUpdatesCount) &&
            (identical(other.invitesCount, invitesCount) ||
                other.invitesCount == invitesCount) &&
            (identical(other.hasMomentum, hasMomentum) ||
                other.hasMomentum == hasMomentum));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, chatUnreadCount,
      lobbyUpdatesCount, invitesCount, hasMomentum);

  /// Create a copy of BadgeState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BadgeStateImplCopyWith<_$BadgeStateImpl> get copyWith =>
      __$$BadgeStateImplCopyWithImpl<_$BadgeStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BadgeStateImplToJson(
      this,
    );
  }
}

abstract class _BadgeState implements BadgeState {
  const factory _BadgeState(
      {final int chatUnreadCount,
      final int lobbyUpdatesCount,
      final int invitesCount,
      final bool hasMomentum}) = _$BadgeStateImpl;

  factory _BadgeState.fromJson(Map<String, dynamic> json) =
      _$BadgeStateImpl.fromJson;

  @override
  int get chatUnreadCount;
  @override
  int get lobbyUpdatesCount;
  @override
  int get invitesCount;
  @override
  bool get hasMomentum;

  /// Create a copy of BadgeState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BadgeStateImplCopyWith<_$BadgeStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

NotificationPayload _$NotificationPayloadFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'directInvite':
      return _DirectInvitePayload.fromJson(json);
    case 'momentum':
      return _MomentumPayload.fromJson(json);
    case 'spotAvailable':
      return _SpotAvailablePayload.fromJson(json);
    case 'timerExpiring':
      return _TimerExpiringPayload.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'NotificationPayload',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$NotificationPayload {
  String get lobbyId => throw _privateConstructorUsedError;
  String get gameName => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String inviterId, String inviterName,
            String lobbyId, String gameName, String? gameImageUrl)
        directInvite,
    required TResult Function(
            String lobbyId,
            String gameName,
            int currentPlayers,
            int maxPlayers,
            String joinerName,
            List<String> participantNames,
            String? gameImageUrl)
        momentum,
    required TResult Function(String lobbyId, String gameName, int spotsOpen,
            List<String> friendsInLobby)
        spotAvailable,
    required TResult Function(
            String lobbyId, String gameName, int secondsRemaining)
        timerExpiring,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String inviterId, String inviterName, String lobbyId,
            String gameName, String? gameImageUrl)?
        directInvite,
    TResult? Function(
            String lobbyId,
            String gameName,
            int currentPlayers,
            int maxPlayers,
            String joinerName,
            List<String> participantNames,
            String? gameImageUrl)?
        momentum,
    TResult? Function(String lobbyId, String gameName, int spotsOpen,
            List<String> friendsInLobby)?
        spotAvailable,
    TResult? Function(String lobbyId, String gameName, int secondsRemaining)?
        timerExpiring,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String inviterId, String inviterName, String lobbyId,
            String gameName, String? gameImageUrl)?
        directInvite,
    TResult Function(
            String lobbyId,
            String gameName,
            int currentPlayers,
            int maxPlayers,
            String joinerName,
            List<String> participantNames,
            String? gameImageUrl)?
        momentum,
    TResult Function(String lobbyId, String gameName, int spotsOpen,
            List<String> friendsInLobby)?
        spotAvailable,
    TResult Function(String lobbyId, String gameName, int secondsRemaining)?
        timerExpiring,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_DirectInvitePayload value) directInvite,
    required TResult Function(_MomentumPayload value) momentum,
    required TResult Function(_SpotAvailablePayload value) spotAvailable,
    required TResult Function(_TimerExpiringPayload value) timerExpiring,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_DirectInvitePayload value)? directInvite,
    TResult? Function(_MomentumPayload value)? momentum,
    TResult? Function(_SpotAvailablePayload value)? spotAvailable,
    TResult? Function(_TimerExpiringPayload value)? timerExpiring,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_DirectInvitePayload value)? directInvite,
    TResult Function(_MomentumPayload value)? momentum,
    TResult Function(_SpotAvailablePayload value)? spotAvailable,
    TResult Function(_TimerExpiringPayload value)? timerExpiring,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this NotificationPayload to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NotificationPayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NotificationPayloadCopyWith<NotificationPayload> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NotificationPayloadCopyWith<$Res> {
  factory $NotificationPayloadCopyWith(
          NotificationPayload value, $Res Function(NotificationPayload) then) =
      _$NotificationPayloadCopyWithImpl<$Res, NotificationPayload>;
  @useResult
  $Res call({String lobbyId, String gameName});
}

/// @nodoc
class _$NotificationPayloadCopyWithImpl<$Res, $Val extends NotificationPayload>
    implements $NotificationPayloadCopyWith<$Res> {
  _$NotificationPayloadCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NotificationPayload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? lobbyId = null,
    Object? gameName = null,
  }) {
    return _then(_value.copyWith(
      lobbyId: null == lobbyId
          ? _value.lobbyId
          : lobbyId // ignore: cast_nullable_to_non_nullable
              as String,
      gameName: null == gameName
          ? _value.gameName
          : gameName // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DirectInvitePayloadImplCopyWith<$Res>
    implements $NotificationPayloadCopyWith<$Res> {
  factory _$$DirectInvitePayloadImplCopyWith(_$DirectInvitePayloadImpl value,
          $Res Function(_$DirectInvitePayloadImpl) then) =
      __$$DirectInvitePayloadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String inviterId,
      String inviterName,
      String lobbyId,
      String gameName,
      String? gameImageUrl});
}

/// @nodoc
class __$$DirectInvitePayloadImplCopyWithImpl<$Res>
    extends _$NotificationPayloadCopyWithImpl<$Res, _$DirectInvitePayloadImpl>
    implements _$$DirectInvitePayloadImplCopyWith<$Res> {
  __$$DirectInvitePayloadImplCopyWithImpl(_$DirectInvitePayloadImpl _value,
      $Res Function(_$DirectInvitePayloadImpl) _then)
      : super(_value, _then);

  /// Create a copy of NotificationPayload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? inviterId = null,
    Object? inviterName = null,
    Object? lobbyId = null,
    Object? gameName = null,
    Object? gameImageUrl = freezed,
  }) {
    return _then(_$DirectInvitePayloadImpl(
      inviterId: null == inviterId
          ? _value.inviterId
          : inviterId // ignore: cast_nullable_to_non_nullable
              as String,
      inviterName: null == inviterName
          ? _value.inviterName
          : inviterName // ignore: cast_nullable_to_non_nullable
              as String,
      lobbyId: null == lobbyId
          ? _value.lobbyId
          : lobbyId // ignore: cast_nullable_to_non_nullable
              as String,
      gameName: null == gameName
          ? _value.gameName
          : gameName // ignore: cast_nullable_to_non_nullable
              as String,
      gameImageUrl: freezed == gameImageUrl
          ? _value.gameImageUrl
          : gameImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DirectInvitePayloadImpl implements _DirectInvitePayload {
  const _$DirectInvitePayloadImpl(
      {required this.inviterId,
      required this.inviterName,
      required this.lobbyId,
      required this.gameName,
      this.gameImageUrl,
      final String? $type})
      : $type = $type ?? 'directInvite';

  factory _$DirectInvitePayloadImpl.fromJson(Map<String, dynamic> json) =>
      _$$DirectInvitePayloadImplFromJson(json);

  @override
  final String inviterId;
  @override
  final String inviterName;
  @override
  final String lobbyId;
  @override
  final String gameName;
  @override
  final String? gameImageUrl;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'NotificationPayload.directInvite(inviterId: $inviterId, inviterName: $inviterName, lobbyId: $lobbyId, gameName: $gameName, gameImageUrl: $gameImageUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DirectInvitePayloadImpl &&
            (identical(other.inviterId, inviterId) ||
                other.inviterId == inviterId) &&
            (identical(other.inviterName, inviterName) ||
                other.inviterName == inviterName) &&
            (identical(other.lobbyId, lobbyId) || other.lobbyId == lobbyId) &&
            (identical(other.gameName, gameName) ||
                other.gameName == gameName) &&
            (identical(other.gameImageUrl, gameImageUrl) ||
                other.gameImageUrl == gameImageUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, inviterId, inviterName, lobbyId, gameName, gameImageUrl);

  /// Create a copy of NotificationPayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DirectInvitePayloadImplCopyWith<_$DirectInvitePayloadImpl> get copyWith =>
      __$$DirectInvitePayloadImplCopyWithImpl<_$DirectInvitePayloadImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String inviterId, String inviterName,
            String lobbyId, String gameName, String? gameImageUrl)
        directInvite,
    required TResult Function(
            String lobbyId,
            String gameName,
            int currentPlayers,
            int maxPlayers,
            String joinerName,
            List<String> participantNames,
            String? gameImageUrl)
        momentum,
    required TResult Function(String lobbyId, String gameName, int spotsOpen,
            List<String> friendsInLobby)
        spotAvailable,
    required TResult Function(
            String lobbyId, String gameName, int secondsRemaining)
        timerExpiring,
  }) {
    return directInvite(
        inviterId, inviterName, lobbyId, gameName, gameImageUrl);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String inviterId, String inviterName, String lobbyId,
            String gameName, String? gameImageUrl)?
        directInvite,
    TResult? Function(
            String lobbyId,
            String gameName,
            int currentPlayers,
            int maxPlayers,
            String joinerName,
            List<String> participantNames,
            String? gameImageUrl)?
        momentum,
    TResult? Function(String lobbyId, String gameName, int spotsOpen,
            List<String> friendsInLobby)?
        spotAvailable,
    TResult? Function(String lobbyId, String gameName, int secondsRemaining)?
        timerExpiring,
  }) {
    return directInvite?.call(
        inviterId, inviterName, lobbyId, gameName, gameImageUrl);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String inviterId, String inviterName, String lobbyId,
            String gameName, String? gameImageUrl)?
        directInvite,
    TResult Function(
            String lobbyId,
            String gameName,
            int currentPlayers,
            int maxPlayers,
            String joinerName,
            List<String> participantNames,
            String? gameImageUrl)?
        momentum,
    TResult Function(String lobbyId, String gameName, int spotsOpen,
            List<String> friendsInLobby)?
        spotAvailable,
    TResult Function(String lobbyId, String gameName, int secondsRemaining)?
        timerExpiring,
    required TResult orElse(),
  }) {
    if (directInvite != null) {
      return directInvite(
          inviterId, inviterName, lobbyId, gameName, gameImageUrl);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_DirectInvitePayload value) directInvite,
    required TResult Function(_MomentumPayload value) momentum,
    required TResult Function(_SpotAvailablePayload value) spotAvailable,
    required TResult Function(_TimerExpiringPayload value) timerExpiring,
  }) {
    return directInvite(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_DirectInvitePayload value)? directInvite,
    TResult? Function(_MomentumPayload value)? momentum,
    TResult? Function(_SpotAvailablePayload value)? spotAvailable,
    TResult? Function(_TimerExpiringPayload value)? timerExpiring,
  }) {
    return directInvite?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_DirectInvitePayload value)? directInvite,
    TResult Function(_MomentumPayload value)? momentum,
    TResult Function(_SpotAvailablePayload value)? spotAvailable,
    TResult Function(_TimerExpiringPayload value)? timerExpiring,
    required TResult orElse(),
  }) {
    if (directInvite != null) {
      return directInvite(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$DirectInvitePayloadImplToJson(
      this,
    );
  }
}

abstract class _DirectInvitePayload implements NotificationPayload {
  const factory _DirectInvitePayload(
      {required final String inviterId,
      required final String inviterName,
      required final String lobbyId,
      required final String gameName,
      final String? gameImageUrl}) = _$DirectInvitePayloadImpl;

  factory _DirectInvitePayload.fromJson(Map<String, dynamic> json) =
      _$DirectInvitePayloadImpl.fromJson;

  String get inviterId;
  String get inviterName;
  @override
  String get lobbyId;
  @override
  String get gameName;
  String? get gameImageUrl;

  /// Create a copy of NotificationPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DirectInvitePayloadImplCopyWith<_$DirectInvitePayloadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MomentumPayloadImplCopyWith<$Res>
    implements $NotificationPayloadCopyWith<$Res> {
  factory _$$MomentumPayloadImplCopyWith(_$MomentumPayloadImpl value,
          $Res Function(_$MomentumPayloadImpl) then) =
      __$$MomentumPayloadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String lobbyId,
      String gameName,
      int currentPlayers,
      int maxPlayers,
      String joinerName,
      List<String> participantNames,
      String? gameImageUrl});
}

/// @nodoc
class __$$MomentumPayloadImplCopyWithImpl<$Res>
    extends _$NotificationPayloadCopyWithImpl<$Res, _$MomentumPayloadImpl>
    implements _$$MomentumPayloadImplCopyWith<$Res> {
  __$$MomentumPayloadImplCopyWithImpl(
      _$MomentumPayloadImpl _value, $Res Function(_$MomentumPayloadImpl) _then)
      : super(_value, _then);

  /// Create a copy of NotificationPayload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? lobbyId = null,
    Object? gameName = null,
    Object? currentPlayers = null,
    Object? maxPlayers = null,
    Object? joinerName = null,
    Object? participantNames = null,
    Object? gameImageUrl = freezed,
  }) {
    return _then(_$MomentumPayloadImpl(
      lobbyId: null == lobbyId
          ? _value.lobbyId
          : lobbyId // ignore: cast_nullable_to_non_nullable
              as String,
      gameName: null == gameName
          ? _value.gameName
          : gameName // ignore: cast_nullable_to_non_nullable
              as String,
      currentPlayers: null == currentPlayers
          ? _value.currentPlayers
          : currentPlayers // ignore: cast_nullable_to_non_nullable
              as int,
      maxPlayers: null == maxPlayers
          ? _value.maxPlayers
          : maxPlayers // ignore: cast_nullable_to_non_nullable
              as int,
      joinerName: null == joinerName
          ? _value.joinerName
          : joinerName // ignore: cast_nullable_to_non_nullable
              as String,
      participantNames: null == participantNames
          ? _value._participantNames
          : participantNames // ignore: cast_nullable_to_non_nullable
              as List<String>,
      gameImageUrl: freezed == gameImageUrl
          ? _value.gameImageUrl
          : gameImageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MomentumPayloadImpl implements _MomentumPayload {
  const _$MomentumPayloadImpl(
      {required this.lobbyId,
      required this.gameName,
      required this.currentPlayers,
      required this.maxPlayers,
      required this.joinerName,
      required final List<String> participantNames,
      this.gameImageUrl,
      final String? $type})
      : _participantNames = participantNames,
        $type = $type ?? 'momentum';

  factory _$MomentumPayloadImpl.fromJson(Map<String, dynamic> json) =>
      _$$MomentumPayloadImplFromJson(json);

  @override
  final String lobbyId;
  @override
  final String gameName;
  @override
  final int currentPlayers;
  @override
  final int maxPlayers;
  @override
  final String joinerName;
  final List<String> _participantNames;
  @override
  List<String> get participantNames {
    if (_participantNames is EqualUnmodifiableListView)
      return _participantNames;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_participantNames);
  }

  @override
  final String? gameImageUrl;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'NotificationPayload.momentum(lobbyId: $lobbyId, gameName: $gameName, currentPlayers: $currentPlayers, maxPlayers: $maxPlayers, joinerName: $joinerName, participantNames: $participantNames, gameImageUrl: $gameImageUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MomentumPayloadImpl &&
            (identical(other.lobbyId, lobbyId) || other.lobbyId == lobbyId) &&
            (identical(other.gameName, gameName) ||
                other.gameName == gameName) &&
            (identical(other.currentPlayers, currentPlayers) ||
                other.currentPlayers == currentPlayers) &&
            (identical(other.maxPlayers, maxPlayers) ||
                other.maxPlayers == maxPlayers) &&
            (identical(other.joinerName, joinerName) ||
                other.joinerName == joinerName) &&
            const DeepCollectionEquality()
                .equals(other._participantNames, _participantNames) &&
            (identical(other.gameImageUrl, gameImageUrl) ||
                other.gameImageUrl == gameImageUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      lobbyId,
      gameName,
      currentPlayers,
      maxPlayers,
      joinerName,
      const DeepCollectionEquality().hash(_participantNames),
      gameImageUrl);

  /// Create a copy of NotificationPayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MomentumPayloadImplCopyWith<_$MomentumPayloadImpl> get copyWith =>
      __$$MomentumPayloadImplCopyWithImpl<_$MomentumPayloadImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String inviterId, String inviterName,
            String lobbyId, String gameName, String? gameImageUrl)
        directInvite,
    required TResult Function(
            String lobbyId,
            String gameName,
            int currentPlayers,
            int maxPlayers,
            String joinerName,
            List<String> participantNames,
            String? gameImageUrl)
        momentum,
    required TResult Function(String lobbyId, String gameName, int spotsOpen,
            List<String> friendsInLobby)
        spotAvailable,
    required TResult Function(
            String lobbyId, String gameName, int secondsRemaining)
        timerExpiring,
  }) {
    return momentum(lobbyId, gameName, currentPlayers, maxPlayers, joinerName,
        participantNames, gameImageUrl);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String inviterId, String inviterName, String lobbyId,
            String gameName, String? gameImageUrl)?
        directInvite,
    TResult? Function(
            String lobbyId,
            String gameName,
            int currentPlayers,
            int maxPlayers,
            String joinerName,
            List<String> participantNames,
            String? gameImageUrl)?
        momentum,
    TResult? Function(String lobbyId, String gameName, int spotsOpen,
            List<String> friendsInLobby)?
        spotAvailable,
    TResult? Function(String lobbyId, String gameName, int secondsRemaining)?
        timerExpiring,
  }) {
    return momentum?.call(lobbyId, gameName, currentPlayers, maxPlayers,
        joinerName, participantNames, gameImageUrl);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String inviterId, String inviterName, String lobbyId,
            String gameName, String? gameImageUrl)?
        directInvite,
    TResult Function(
            String lobbyId,
            String gameName,
            int currentPlayers,
            int maxPlayers,
            String joinerName,
            List<String> participantNames,
            String? gameImageUrl)?
        momentum,
    TResult Function(String lobbyId, String gameName, int spotsOpen,
            List<String> friendsInLobby)?
        spotAvailable,
    TResult Function(String lobbyId, String gameName, int secondsRemaining)?
        timerExpiring,
    required TResult orElse(),
  }) {
    if (momentum != null) {
      return momentum(lobbyId, gameName, currentPlayers, maxPlayers, joinerName,
          participantNames, gameImageUrl);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_DirectInvitePayload value) directInvite,
    required TResult Function(_MomentumPayload value) momentum,
    required TResult Function(_SpotAvailablePayload value) spotAvailable,
    required TResult Function(_TimerExpiringPayload value) timerExpiring,
  }) {
    return momentum(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_DirectInvitePayload value)? directInvite,
    TResult? Function(_MomentumPayload value)? momentum,
    TResult? Function(_SpotAvailablePayload value)? spotAvailable,
    TResult? Function(_TimerExpiringPayload value)? timerExpiring,
  }) {
    return momentum?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_DirectInvitePayload value)? directInvite,
    TResult Function(_MomentumPayload value)? momentum,
    TResult Function(_SpotAvailablePayload value)? spotAvailable,
    TResult Function(_TimerExpiringPayload value)? timerExpiring,
    required TResult orElse(),
  }) {
    if (momentum != null) {
      return momentum(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$MomentumPayloadImplToJson(
      this,
    );
  }
}

abstract class _MomentumPayload implements NotificationPayload {
  const factory _MomentumPayload(
      {required final String lobbyId,
      required final String gameName,
      required final int currentPlayers,
      required final int maxPlayers,
      required final String joinerName,
      required final List<String> participantNames,
      final String? gameImageUrl}) = _$MomentumPayloadImpl;

  factory _MomentumPayload.fromJson(Map<String, dynamic> json) =
      _$MomentumPayloadImpl.fromJson;

  @override
  String get lobbyId;
  @override
  String get gameName;
  int get currentPlayers;
  int get maxPlayers;
  String get joinerName;
  List<String> get participantNames;
  String? get gameImageUrl;

  /// Create a copy of NotificationPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MomentumPayloadImplCopyWith<_$MomentumPayloadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SpotAvailablePayloadImplCopyWith<$Res>
    implements $NotificationPayloadCopyWith<$Res> {
  factory _$$SpotAvailablePayloadImplCopyWith(_$SpotAvailablePayloadImpl value,
          $Res Function(_$SpotAvailablePayloadImpl) then) =
      __$$SpotAvailablePayloadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String lobbyId,
      String gameName,
      int spotsOpen,
      List<String> friendsInLobby});
}

/// @nodoc
class __$$SpotAvailablePayloadImplCopyWithImpl<$Res>
    extends _$NotificationPayloadCopyWithImpl<$Res, _$SpotAvailablePayloadImpl>
    implements _$$SpotAvailablePayloadImplCopyWith<$Res> {
  __$$SpotAvailablePayloadImplCopyWithImpl(_$SpotAvailablePayloadImpl _value,
      $Res Function(_$SpotAvailablePayloadImpl) _then)
      : super(_value, _then);

  /// Create a copy of NotificationPayload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? lobbyId = null,
    Object? gameName = null,
    Object? spotsOpen = null,
    Object? friendsInLobby = null,
  }) {
    return _then(_$SpotAvailablePayloadImpl(
      lobbyId: null == lobbyId
          ? _value.lobbyId
          : lobbyId // ignore: cast_nullable_to_non_nullable
              as String,
      gameName: null == gameName
          ? _value.gameName
          : gameName // ignore: cast_nullable_to_non_nullable
              as String,
      spotsOpen: null == spotsOpen
          ? _value.spotsOpen
          : spotsOpen // ignore: cast_nullable_to_non_nullable
              as int,
      friendsInLobby: null == friendsInLobby
          ? _value._friendsInLobby
          : friendsInLobby // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SpotAvailablePayloadImpl implements _SpotAvailablePayload {
  const _$SpotAvailablePayloadImpl(
      {required this.lobbyId,
      required this.gameName,
      required this.spotsOpen,
      required final List<String> friendsInLobby,
      final String? $type})
      : _friendsInLobby = friendsInLobby,
        $type = $type ?? 'spotAvailable';

  factory _$SpotAvailablePayloadImpl.fromJson(Map<String, dynamic> json) =>
      _$$SpotAvailablePayloadImplFromJson(json);

  @override
  final String lobbyId;
  @override
  final String gameName;
  @override
  final int spotsOpen;
  final List<String> _friendsInLobby;
  @override
  List<String> get friendsInLobby {
    if (_friendsInLobby is EqualUnmodifiableListView) return _friendsInLobby;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_friendsInLobby);
  }

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'NotificationPayload.spotAvailable(lobbyId: $lobbyId, gameName: $gameName, spotsOpen: $spotsOpen, friendsInLobby: $friendsInLobby)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SpotAvailablePayloadImpl &&
            (identical(other.lobbyId, lobbyId) || other.lobbyId == lobbyId) &&
            (identical(other.gameName, gameName) ||
                other.gameName == gameName) &&
            (identical(other.spotsOpen, spotsOpen) ||
                other.spotsOpen == spotsOpen) &&
            const DeepCollectionEquality()
                .equals(other._friendsInLobby, _friendsInLobby));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, lobbyId, gameName, spotsOpen,
      const DeepCollectionEquality().hash(_friendsInLobby));

  /// Create a copy of NotificationPayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SpotAvailablePayloadImplCopyWith<_$SpotAvailablePayloadImpl>
      get copyWith =>
          __$$SpotAvailablePayloadImplCopyWithImpl<_$SpotAvailablePayloadImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String inviterId, String inviterName,
            String lobbyId, String gameName, String? gameImageUrl)
        directInvite,
    required TResult Function(
            String lobbyId,
            String gameName,
            int currentPlayers,
            int maxPlayers,
            String joinerName,
            List<String> participantNames,
            String? gameImageUrl)
        momentum,
    required TResult Function(String lobbyId, String gameName, int spotsOpen,
            List<String> friendsInLobby)
        spotAvailable,
    required TResult Function(
            String lobbyId, String gameName, int secondsRemaining)
        timerExpiring,
  }) {
    return spotAvailable(lobbyId, gameName, spotsOpen, friendsInLobby);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String inviterId, String inviterName, String lobbyId,
            String gameName, String? gameImageUrl)?
        directInvite,
    TResult? Function(
            String lobbyId,
            String gameName,
            int currentPlayers,
            int maxPlayers,
            String joinerName,
            List<String> participantNames,
            String? gameImageUrl)?
        momentum,
    TResult? Function(String lobbyId, String gameName, int spotsOpen,
            List<String> friendsInLobby)?
        spotAvailable,
    TResult? Function(String lobbyId, String gameName, int secondsRemaining)?
        timerExpiring,
  }) {
    return spotAvailable?.call(lobbyId, gameName, spotsOpen, friendsInLobby);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String inviterId, String inviterName, String lobbyId,
            String gameName, String? gameImageUrl)?
        directInvite,
    TResult Function(
            String lobbyId,
            String gameName,
            int currentPlayers,
            int maxPlayers,
            String joinerName,
            List<String> participantNames,
            String? gameImageUrl)?
        momentum,
    TResult Function(String lobbyId, String gameName, int spotsOpen,
            List<String> friendsInLobby)?
        spotAvailable,
    TResult Function(String lobbyId, String gameName, int secondsRemaining)?
        timerExpiring,
    required TResult orElse(),
  }) {
    if (spotAvailable != null) {
      return spotAvailable(lobbyId, gameName, spotsOpen, friendsInLobby);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_DirectInvitePayload value) directInvite,
    required TResult Function(_MomentumPayload value) momentum,
    required TResult Function(_SpotAvailablePayload value) spotAvailable,
    required TResult Function(_TimerExpiringPayload value) timerExpiring,
  }) {
    return spotAvailable(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_DirectInvitePayload value)? directInvite,
    TResult? Function(_MomentumPayload value)? momentum,
    TResult? Function(_SpotAvailablePayload value)? spotAvailable,
    TResult? Function(_TimerExpiringPayload value)? timerExpiring,
  }) {
    return spotAvailable?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_DirectInvitePayload value)? directInvite,
    TResult Function(_MomentumPayload value)? momentum,
    TResult Function(_SpotAvailablePayload value)? spotAvailable,
    TResult Function(_TimerExpiringPayload value)? timerExpiring,
    required TResult orElse(),
  }) {
    if (spotAvailable != null) {
      return spotAvailable(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SpotAvailablePayloadImplToJson(
      this,
    );
  }
}

abstract class _SpotAvailablePayload implements NotificationPayload {
  const factory _SpotAvailablePayload(
      {required final String lobbyId,
      required final String gameName,
      required final int spotsOpen,
      required final List<String> friendsInLobby}) = _$SpotAvailablePayloadImpl;

  factory _SpotAvailablePayload.fromJson(Map<String, dynamic> json) =
      _$SpotAvailablePayloadImpl.fromJson;

  @override
  String get lobbyId;
  @override
  String get gameName;
  int get spotsOpen;
  List<String> get friendsInLobby;

  /// Create a copy of NotificationPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SpotAvailablePayloadImplCopyWith<_$SpotAvailablePayloadImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$TimerExpiringPayloadImplCopyWith<$Res>
    implements $NotificationPayloadCopyWith<$Res> {
  factory _$$TimerExpiringPayloadImplCopyWith(_$TimerExpiringPayloadImpl value,
          $Res Function(_$TimerExpiringPayloadImpl) then) =
      __$$TimerExpiringPayloadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String lobbyId, String gameName, int secondsRemaining});
}

/// @nodoc
class __$$TimerExpiringPayloadImplCopyWithImpl<$Res>
    extends _$NotificationPayloadCopyWithImpl<$Res, _$TimerExpiringPayloadImpl>
    implements _$$TimerExpiringPayloadImplCopyWith<$Res> {
  __$$TimerExpiringPayloadImplCopyWithImpl(_$TimerExpiringPayloadImpl _value,
      $Res Function(_$TimerExpiringPayloadImpl) _then)
      : super(_value, _then);

  /// Create a copy of NotificationPayload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? lobbyId = null,
    Object? gameName = null,
    Object? secondsRemaining = null,
  }) {
    return _then(_$TimerExpiringPayloadImpl(
      lobbyId: null == lobbyId
          ? _value.lobbyId
          : lobbyId // ignore: cast_nullable_to_non_nullable
              as String,
      gameName: null == gameName
          ? _value.gameName
          : gameName // ignore: cast_nullable_to_non_nullable
              as String,
      secondsRemaining: null == secondsRemaining
          ? _value.secondsRemaining
          : secondsRemaining // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TimerExpiringPayloadImpl implements _TimerExpiringPayload {
  const _$TimerExpiringPayloadImpl(
      {required this.lobbyId,
      required this.gameName,
      required this.secondsRemaining,
      final String? $type})
      : $type = $type ?? 'timerExpiring';

  factory _$TimerExpiringPayloadImpl.fromJson(Map<String, dynamic> json) =>
      _$$TimerExpiringPayloadImplFromJson(json);

  @override
  final String lobbyId;
  @override
  final String gameName;
  @override
  final int secondsRemaining;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'NotificationPayload.timerExpiring(lobbyId: $lobbyId, gameName: $gameName, secondsRemaining: $secondsRemaining)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TimerExpiringPayloadImpl &&
            (identical(other.lobbyId, lobbyId) || other.lobbyId == lobbyId) &&
            (identical(other.gameName, gameName) ||
                other.gameName == gameName) &&
            (identical(other.secondsRemaining, secondsRemaining) ||
                other.secondsRemaining == secondsRemaining));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, lobbyId, gameName, secondsRemaining);

  /// Create a copy of NotificationPayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TimerExpiringPayloadImplCopyWith<_$TimerExpiringPayloadImpl>
      get copyWith =>
          __$$TimerExpiringPayloadImplCopyWithImpl<_$TimerExpiringPayloadImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String inviterId, String inviterName,
            String lobbyId, String gameName, String? gameImageUrl)
        directInvite,
    required TResult Function(
            String lobbyId,
            String gameName,
            int currentPlayers,
            int maxPlayers,
            String joinerName,
            List<String> participantNames,
            String? gameImageUrl)
        momentum,
    required TResult Function(String lobbyId, String gameName, int spotsOpen,
            List<String> friendsInLobby)
        spotAvailable,
    required TResult Function(
            String lobbyId, String gameName, int secondsRemaining)
        timerExpiring,
  }) {
    return timerExpiring(lobbyId, gameName, secondsRemaining);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String inviterId, String inviterName, String lobbyId,
            String gameName, String? gameImageUrl)?
        directInvite,
    TResult? Function(
            String lobbyId,
            String gameName,
            int currentPlayers,
            int maxPlayers,
            String joinerName,
            List<String> participantNames,
            String? gameImageUrl)?
        momentum,
    TResult? Function(String lobbyId, String gameName, int spotsOpen,
            List<String> friendsInLobby)?
        spotAvailable,
    TResult? Function(String lobbyId, String gameName, int secondsRemaining)?
        timerExpiring,
  }) {
    return timerExpiring?.call(lobbyId, gameName, secondsRemaining);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String inviterId, String inviterName, String lobbyId,
            String gameName, String? gameImageUrl)?
        directInvite,
    TResult Function(
            String lobbyId,
            String gameName,
            int currentPlayers,
            int maxPlayers,
            String joinerName,
            List<String> participantNames,
            String? gameImageUrl)?
        momentum,
    TResult Function(String lobbyId, String gameName, int spotsOpen,
            List<String> friendsInLobby)?
        spotAvailable,
    TResult Function(String lobbyId, String gameName, int secondsRemaining)?
        timerExpiring,
    required TResult orElse(),
  }) {
    if (timerExpiring != null) {
      return timerExpiring(lobbyId, gameName, secondsRemaining);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_DirectInvitePayload value) directInvite,
    required TResult Function(_MomentumPayload value) momentum,
    required TResult Function(_SpotAvailablePayload value) spotAvailable,
    required TResult Function(_TimerExpiringPayload value) timerExpiring,
  }) {
    return timerExpiring(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_DirectInvitePayload value)? directInvite,
    TResult? Function(_MomentumPayload value)? momentum,
    TResult? Function(_SpotAvailablePayload value)? spotAvailable,
    TResult? Function(_TimerExpiringPayload value)? timerExpiring,
  }) {
    return timerExpiring?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_DirectInvitePayload value)? directInvite,
    TResult Function(_MomentumPayload value)? momentum,
    TResult Function(_SpotAvailablePayload value)? spotAvailable,
    TResult Function(_TimerExpiringPayload value)? timerExpiring,
    required TResult orElse(),
  }) {
    if (timerExpiring != null) {
      return timerExpiring(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$TimerExpiringPayloadImplToJson(
      this,
    );
  }
}

abstract class _TimerExpiringPayload implements NotificationPayload {
  const factory _TimerExpiringPayload(
      {required final String lobbyId,
      required final String gameName,
      required final int secondsRemaining}) = _$TimerExpiringPayloadImpl;

  factory _TimerExpiringPayload.fromJson(Map<String, dynamic> json) =
      _$TimerExpiringPayloadImpl.fromJson;

  @override
  String get lobbyId;
  @override
  String get gameName;
  int get secondsRemaining;

  /// Create a copy of NotificationPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TimerExpiringPayloadImplCopyWith<_$TimerExpiringPayloadImpl>
      get copyWith => throw _privateConstructorUsedError;
}
