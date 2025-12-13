// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'public_lobby.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PeacockTimer _$PeacockTimerFromJson(Map<String, dynamic> json) {
  return _PeacockTimer.fromJson(json);
}

/// @nodoc
mixin _$PeacockTimer {
  DateTime get endTime => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;

  /// Serializes this PeacockTimer to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PeacockTimer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PeacockTimerCopyWith<PeacockTimer> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PeacockTimerCopyWith<$Res> {
  factory $PeacockTimerCopyWith(
          PeacockTimer value, $Res Function(PeacockTimer) then) =
      _$PeacockTimerCopyWithImpl<$Res, PeacockTimer>;
  @useResult
  $Res call({DateTime endTime, bool isActive});
}

/// @nodoc
class _$PeacockTimerCopyWithImpl<$Res, $Val extends PeacockTimer>
    implements $PeacockTimerCopyWith<$Res> {
  _$PeacockTimerCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PeacockTimer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? endTime = null,
    Object? isActive = null,
  }) {
    return _then(_value.copyWith(
      endTime: null == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PeacockTimerImplCopyWith<$Res>
    implements $PeacockTimerCopyWith<$Res> {
  factory _$$PeacockTimerImplCopyWith(
          _$PeacockTimerImpl value, $Res Function(_$PeacockTimerImpl) then) =
      __$$PeacockTimerImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({DateTime endTime, bool isActive});
}

/// @nodoc
class __$$PeacockTimerImplCopyWithImpl<$Res>
    extends _$PeacockTimerCopyWithImpl<$Res, _$PeacockTimerImpl>
    implements _$$PeacockTimerImplCopyWith<$Res> {
  __$$PeacockTimerImplCopyWithImpl(
      _$PeacockTimerImpl _value, $Res Function(_$PeacockTimerImpl) _then)
      : super(_value, _then);

  /// Create a copy of PeacockTimer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? endTime = null,
    Object? isActive = null,
  }) {
    return _then(_$PeacockTimerImpl(
      endTime: null == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PeacockTimerImpl implements _PeacockTimer {
  const _$PeacockTimerImpl({required this.endTime, required this.isActive});

  factory _$PeacockTimerImpl.fromJson(Map<String, dynamic> json) =>
      _$$PeacockTimerImplFromJson(json);

  @override
  final DateTime endTime;
  @override
  final bool isActive;

  @override
  String toString() {
    return 'PeacockTimer(endTime: $endTime, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PeacockTimerImpl &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, endTime, isActive);

  /// Create a copy of PeacockTimer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PeacockTimerImplCopyWith<_$PeacockTimerImpl> get copyWith =>
      __$$PeacockTimerImplCopyWithImpl<_$PeacockTimerImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PeacockTimerImplToJson(
      this,
    );
  }
}

abstract class _PeacockTimer implements PeacockTimer {
  const factory _PeacockTimer(
      {required final DateTime endTime,
      required final bool isActive}) = _$PeacockTimerImpl;

  factory _PeacockTimer.fromJson(Map<String, dynamic> json) =
      _$PeacockTimerImpl.fromJson;

  @override
  DateTime get endTime;
  @override
  bool get isActive;

  /// Create a copy of PeacockTimer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PeacockTimerImplCopyWith<_$PeacockTimerImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PublicLobby _$PublicLobbyFromJson(Map<String, dynamic> json) {
  return _PublicLobby.fromJson(json);
}

/// @nodoc
mixin _$PublicLobby {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get primaryGameId => throw _privateConstructorUsedError;
  String? get primaryGameName => throw _privateConstructorUsedError;
  int? get maxSpots => throw _privateConstructorUsedError;
  String get creatorUid => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  bool get isPublic => throw _privateConstructorUsedError;
  String? get inviteCode => throw _privateConstructorUsedError;
  List<String> get memberUids => throw _privateConstructorUsedError;
  DateTime get lastActivity => throw _privateConstructorUsedError;
  Map<String, String?> get spotClaims => throw _privateConstructorUsedError;
  Map<String, PeacockTimer> get peacockTimers =>
      throw _privateConstructorUsedError;
  Map<String, String> get userStatuses => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;
  bool get lookingForMore => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  DateTime? get bumpTimestamp => throw _privateConstructorUsedError;

  /// Serializes this PublicLobby to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PublicLobby
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PublicLobbyCopyWith<PublicLobby> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PublicLobbyCopyWith<$Res> {
  factory $PublicLobbyCopyWith(
          PublicLobby value, $Res Function(PublicLobby) then) =
      _$PublicLobbyCopyWithImpl<$Res, PublicLobby>;
  @useResult
  $Res call(
      {String id,
      String name,
      String? primaryGameId,
      String? primaryGameName,
      int? maxSpots,
      String creatorUid,
      DateTime createdAt,
      bool isPublic,
      String? inviteCode,
      List<String> memberUids,
      DateTime lastActivity,
      Map<String, String?> spotClaims,
      Map<String, PeacockTimer> peacockTimers,
      Map<String, String> userStatuses,
      List<String> tags,
      bool lookingForMore,
      String description,
      DateTime? bumpTimestamp});
}

/// @nodoc
class _$PublicLobbyCopyWithImpl<$Res, $Val extends PublicLobby>
    implements $PublicLobbyCopyWith<$Res> {
  _$PublicLobbyCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PublicLobby
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? primaryGameId = freezed,
    Object? primaryGameName = freezed,
    Object? maxSpots = freezed,
    Object? creatorUid = null,
    Object? createdAt = null,
    Object? isPublic = null,
    Object? inviteCode = freezed,
    Object? memberUids = null,
    Object? lastActivity = null,
    Object? spotClaims = null,
    Object? peacockTimers = null,
    Object? userStatuses = null,
    Object? tags = null,
    Object? lookingForMore = null,
    Object? description = null,
    Object? bumpTimestamp = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      primaryGameId: freezed == primaryGameId
          ? _value.primaryGameId
          : primaryGameId // ignore: cast_nullable_to_non_nullable
              as String?,
      primaryGameName: freezed == primaryGameName
          ? _value.primaryGameName
          : primaryGameName // ignore: cast_nullable_to_non_nullable
              as String?,
      maxSpots: freezed == maxSpots
          ? _value.maxSpots
          : maxSpots // ignore: cast_nullable_to_non_nullable
              as int?,
      creatorUid: null == creatorUid
          ? _value.creatorUid
          : creatorUid // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isPublic: null == isPublic
          ? _value.isPublic
          : isPublic // ignore: cast_nullable_to_non_nullable
              as bool,
      inviteCode: freezed == inviteCode
          ? _value.inviteCode
          : inviteCode // ignore: cast_nullable_to_non_nullable
              as String?,
      memberUids: null == memberUids
          ? _value.memberUids
          : memberUids // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lastActivity: null == lastActivity
          ? _value.lastActivity
          : lastActivity // ignore: cast_nullable_to_non_nullable
              as DateTime,
      spotClaims: null == spotClaims
          ? _value.spotClaims
          : spotClaims // ignore: cast_nullable_to_non_nullable
              as Map<String, String?>,
      peacockTimers: null == peacockTimers
          ? _value.peacockTimers
          : peacockTimers // ignore: cast_nullable_to_non_nullable
              as Map<String, PeacockTimer>,
      userStatuses: null == userStatuses
          ? _value.userStatuses
          : userStatuses // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      tags: null == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lookingForMore: null == lookingForMore
          ? _value.lookingForMore
          : lookingForMore // ignore: cast_nullable_to_non_nullable
              as bool,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      bumpTimestamp: freezed == bumpTimestamp
          ? _value.bumpTimestamp
          : bumpTimestamp // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PublicLobbyImplCopyWith<$Res>
    implements $PublicLobbyCopyWith<$Res> {
  factory _$$PublicLobbyImplCopyWith(
          _$PublicLobbyImpl value, $Res Function(_$PublicLobbyImpl) then) =
      __$$PublicLobbyImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String? primaryGameId,
      String? primaryGameName,
      int? maxSpots,
      String creatorUid,
      DateTime createdAt,
      bool isPublic,
      String? inviteCode,
      List<String> memberUids,
      DateTime lastActivity,
      Map<String, String?> spotClaims,
      Map<String, PeacockTimer> peacockTimers,
      Map<String, String> userStatuses,
      List<String> tags,
      bool lookingForMore,
      String description,
      DateTime? bumpTimestamp});
}

/// @nodoc
class __$$PublicLobbyImplCopyWithImpl<$Res>
    extends _$PublicLobbyCopyWithImpl<$Res, _$PublicLobbyImpl>
    implements _$$PublicLobbyImplCopyWith<$Res> {
  __$$PublicLobbyImplCopyWithImpl(
      _$PublicLobbyImpl _value, $Res Function(_$PublicLobbyImpl) _then)
      : super(_value, _then);

  /// Create a copy of PublicLobby
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? primaryGameId = freezed,
    Object? primaryGameName = freezed,
    Object? maxSpots = freezed,
    Object? creatorUid = null,
    Object? createdAt = null,
    Object? isPublic = null,
    Object? inviteCode = freezed,
    Object? memberUids = null,
    Object? lastActivity = null,
    Object? spotClaims = null,
    Object? peacockTimers = null,
    Object? userStatuses = null,
    Object? tags = null,
    Object? lookingForMore = null,
    Object? description = null,
    Object? bumpTimestamp = freezed,
  }) {
    return _then(_$PublicLobbyImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      primaryGameId: freezed == primaryGameId
          ? _value.primaryGameId
          : primaryGameId // ignore: cast_nullable_to_non_nullable
              as String?,
      primaryGameName: freezed == primaryGameName
          ? _value.primaryGameName
          : primaryGameName // ignore: cast_nullable_to_non_nullable
              as String?,
      maxSpots: freezed == maxSpots
          ? _value.maxSpots
          : maxSpots // ignore: cast_nullable_to_non_nullable
              as int?,
      creatorUid: null == creatorUid
          ? _value.creatorUid
          : creatorUid // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isPublic: null == isPublic
          ? _value.isPublic
          : isPublic // ignore: cast_nullable_to_non_nullable
              as bool,
      inviteCode: freezed == inviteCode
          ? _value.inviteCode
          : inviteCode // ignore: cast_nullable_to_non_nullable
              as String?,
      memberUids: null == memberUids
          ? _value._memberUids
          : memberUids // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lastActivity: null == lastActivity
          ? _value.lastActivity
          : lastActivity // ignore: cast_nullable_to_non_nullable
              as DateTime,
      spotClaims: null == spotClaims
          ? _value._spotClaims
          : spotClaims // ignore: cast_nullable_to_non_nullable
              as Map<String, String?>,
      peacockTimers: null == peacockTimers
          ? _value._peacockTimers
          : peacockTimers // ignore: cast_nullable_to_non_nullable
              as Map<String, PeacockTimer>,
      userStatuses: null == userStatuses
          ? _value._userStatuses
          : userStatuses // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      tags: null == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lookingForMore: null == lookingForMore
          ? _value.lookingForMore
          : lookingForMore // ignore: cast_nullable_to_non_nullable
              as bool,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      bumpTimestamp: freezed == bumpTimestamp
          ? _value.bumpTimestamp
          : bumpTimestamp // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PublicLobbyImpl implements _PublicLobby {
  const _$PublicLobbyImpl(
      {required this.id,
      required this.name,
      this.primaryGameId,
      this.primaryGameName,
      this.maxSpots,
      required this.creatorUid,
      required this.createdAt,
      required this.isPublic,
      this.inviteCode,
      required final List<String> memberUids,
      required this.lastActivity,
      required final Map<String, String?> spotClaims,
      required final Map<String, PeacockTimer> peacockTimers,
      required final Map<String, String> userStatuses,
      required final List<String> tags,
      required this.lookingForMore,
      required this.description,
      this.bumpTimestamp})
      : _memberUids = memberUids,
        _spotClaims = spotClaims,
        _peacockTimers = peacockTimers,
        _userStatuses = userStatuses,
        _tags = tags;

  factory _$PublicLobbyImpl.fromJson(Map<String, dynamic> json) =>
      _$$PublicLobbyImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? primaryGameId;
  @override
  final String? primaryGameName;
  @override
  final int? maxSpots;
  @override
  final String creatorUid;
  @override
  final DateTime createdAt;
  @override
  final bool isPublic;
  @override
  final String? inviteCode;
  final List<String> _memberUids;
  @override
  List<String> get memberUids {
    if (_memberUids is EqualUnmodifiableListView) return _memberUids;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_memberUids);
  }

  @override
  final DateTime lastActivity;
  final Map<String, String?> _spotClaims;
  @override
  Map<String, String?> get spotClaims {
    if (_spotClaims is EqualUnmodifiableMapView) return _spotClaims;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_spotClaims);
  }

  final Map<String, PeacockTimer> _peacockTimers;
  @override
  Map<String, PeacockTimer> get peacockTimers {
    if (_peacockTimers is EqualUnmodifiableMapView) return _peacockTimers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_peacockTimers);
  }

  final Map<String, String> _userStatuses;
  @override
  Map<String, String> get userStatuses {
    if (_userStatuses is EqualUnmodifiableMapView) return _userStatuses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_userStatuses);
  }

  final List<String> _tags;
  @override
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  final bool lookingForMore;
  @override
  final String description;
  @override
  final DateTime? bumpTimestamp;

  @override
  String toString() {
    return 'PublicLobby(id: $id, name: $name, primaryGameId: $primaryGameId, primaryGameName: $primaryGameName, maxSpots: $maxSpots, creatorUid: $creatorUid, createdAt: $createdAt, isPublic: $isPublic, inviteCode: $inviteCode, memberUids: $memberUids, lastActivity: $lastActivity, spotClaims: $spotClaims, peacockTimers: $peacockTimers, userStatuses: $userStatuses, tags: $tags, lookingForMore: $lookingForMore, description: $description, bumpTimestamp: $bumpTimestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PublicLobbyImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.primaryGameId, primaryGameId) ||
                other.primaryGameId == primaryGameId) &&
            (identical(other.primaryGameName, primaryGameName) ||
                other.primaryGameName == primaryGameName) &&
            (identical(other.maxSpots, maxSpots) ||
                other.maxSpots == maxSpots) &&
            (identical(other.creatorUid, creatorUid) ||
                other.creatorUid == creatorUid) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.isPublic, isPublic) ||
                other.isPublic == isPublic) &&
            (identical(other.inviteCode, inviteCode) ||
                other.inviteCode == inviteCode) &&
            const DeepCollectionEquality()
                .equals(other._memberUids, _memberUids) &&
            (identical(other.lastActivity, lastActivity) ||
                other.lastActivity == lastActivity) &&
            const DeepCollectionEquality()
                .equals(other._spotClaims, _spotClaims) &&
            const DeepCollectionEquality()
                .equals(other._peacockTimers, _peacockTimers) &&
            const DeepCollectionEquality()
                .equals(other._userStatuses, _userStatuses) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.lookingForMore, lookingForMore) ||
                other.lookingForMore == lookingForMore) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.bumpTimestamp, bumpTimestamp) ||
                other.bumpTimestamp == bumpTimestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      primaryGameId,
      primaryGameName,
      maxSpots,
      creatorUid,
      createdAt,
      isPublic,
      inviteCode,
      const DeepCollectionEquality().hash(_memberUids),
      lastActivity,
      const DeepCollectionEquality().hash(_spotClaims),
      const DeepCollectionEquality().hash(_peacockTimers),
      const DeepCollectionEquality().hash(_userStatuses),
      const DeepCollectionEquality().hash(_tags),
      lookingForMore,
      description,
      bumpTimestamp);

  /// Create a copy of PublicLobby
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PublicLobbyImplCopyWith<_$PublicLobbyImpl> get copyWith =>
      __$$PublicLobbyImplCopyWithImpl<_$PublicLobbyImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PublicLobbyImplToJson(
      this,
    );
  }
}

abstract class _PublicLobby implements PublicLobby {
  const factory _PublicLobby(
      {required final String id,
      required final String name,
      final String? primaryGameId,
      final String? primaryGameName,
      final int? maxSpots,
      required final String creatorUid,
      required final DateTime createdAt,
      required final bool isPublic,
      final String? inviteCode,
      required final List<String> memberUids,
      required final DateTime lastActivity,
      required final Map<String, String?> spotClaims,
      required final Map<String, PeacockTimer> peacockTimers,
      required final Map<String, String> userStatuses,
      required final List<String> tags,
      required final bool lookingForMore,
      required final String description,
      final DateTime? bumpTimestamp}) = _$PublicLobbyImpl;

  factory _PublicLobby.fromJson(Map<String, dynamic> json) =
      _$PublicLobbyImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get primaryGameId;
  @override
  String? get primaryGameName;
  @override
  int? get maxSpots;
  @override
  String get creatorUid;
  @override
  DateTime get createdAt;
  @override
  bool get isPublic;
  @override
  String? get inviteCode;
  @override
  List<String> get memberUids;
  @override
  DateTime get lastActivity;
  @override
  Map<String, String?> get spotClaims;
  @override
  Map<String, PeacockTimer> get peacockTimers;
  @override
  Map<String, String> get userStatuses;
  @override
  List<String> get tags;
  @override
  bool get lookingForMore;
  @override
  String get description;
  @override
  DateTime? get bumpTimestamp;

  /// Create a copy of PublicLobby
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PublicLobbyImplCopyWith<_$PublicLobbyImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
