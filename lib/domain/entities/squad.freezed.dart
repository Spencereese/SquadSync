// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'squad.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Squad _$SquadFromJson(Map<String, dynamic> json) {
  return _Squad.fromJson(json);
}

/// @nodoc
mixin _$Squad {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  List<String> get memberUids => throw _privateConstructorUsedError;
  String get gameName => throw _privateConstructorUsedError;
  int get maxSpots => throw _privateConstructorUsedError;
  String get createdBy => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  List<String?> get spots => throw _privateConstructorUsedError;
  List<Map<String, dynamic>?> get spotTimers =>
      throw _privateConstructorUsedError;
  List<String> get viewers => throw _privateConstructorUsedError;
  Map<String, String> get statuses => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  Map<String, dynamic>? get settings => throw _privateConstructorUsedError;

  /// Serializes this Squad to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Squad
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SquadCopyWith<Squad> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SquadCopyWith<$Res> {
  factory $SquadCopyWith(Squad value, $Res Function(Squad) then) =
      _$SquadCopyWithImpl<$Res, Squad>;
  @useResult
  $Res call(
      {String id,
      String name,
      List<String> memberUids,
      String gameName,
      int maxSpots,
      String createdBy,
      DateTime createdAt,
      List<String?> spots,
      List<Map<String, dynamic>?> spotTimers,
      List<String> viewers,
      Map<String, String> statuses,
      bool isActive,
      String? description,
      Map<String, dynamic>? settings});
}

/// @nodoc
class _$SquadCopyWithImpl<$Res, $Val extends Squad>
    implements $SquadCopyWith<$Res> {
  _$SquadCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Squad
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? memberUids = null,
    Object? gameName = null,
    Object? maxSpots = null,
    Object? createdBy = null,
    Object? createdAt = null,
    Object? spots = null,
    Object? spotTimers = null,
    Object? viewers = null,
    Object? statuses = null,
    Object? isActive = null,
    Object? description = freezed,
    Object? settings = freezed,
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
      memberUids: null == memberUids
          ? _value.memberUids
          : memberUids // ignore: cast_nullable_to_non_nullable
              as List<String>,
      gameName: null == gameName
          ? _value.gameName
          : gameName // ignore: cast_nullable_to_non_nullable
              as String,
      maxSpots: null == maxSpots
          ? _value.maxSpots
          : maxSpots // ignore: cast_nullable_to_non_nullable
              as int,
      createdBy: null == createdBy
          ? _value.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      spots: null == spots
          ? _value.spots
          : spots // ignore: cast_nullable_to_non_nullable
              as List<String?>,
      spotTimers: null == spotTimers
          ? _value.spotTimers
          : spotTimers // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>?>,
      viewers: null == viewers
          ? _value.viewers
          : viewers // ignore: cast_nullable_to_non_nullable
              as List<String>,
      statuses: null == statuses
          ? _value.statuses
          : statuses // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      settings: freezed == settings
          ? _value.settings
          : settings // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SquadImplCopyWith<$Res> implements $SquadCopyWith<$Res> {
  factory _$$SquadImplCopyWith(
          _$SquadImpl value, $Res Function(_$SquadImpl) then) =
      __$$SquadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      List<String> memberUids,
      String gameName,
      int maxSpots,
      String createdBy,
      DateTime createdAt,
      List<String?> spots,
      List<Map<String, dynamic>?> spotTimers,
      List<String> viewers,
      Map<String, String> statuses,
      bool isActive,
      String? description,
      Map<String, dynamic>? settings});
}

/// @nodoc
class __$$SquadImplCopyWithImpl<$Res>
    extends _$SquadCopyWithImpl<$Res, _$SquadImpl>
    implements _$$SquadImplCopyWith<$Res> {
  __$$SquadImplCopyWithImpl(
      _$SquadImpl _value, $Res Function(_$SquadImpl) _then)
      : super(_value, _then);

  /// Create a copy of Squad
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? memberUids = null,
    Object? gameName = null,
    Object? maxSpots = null,
    Object? createdBy = null,
    Object? createdAt = null,
    Object? spots = null,
    Object? spotTimers = null,
    Object? viewers = null,
    Object? statuses = null,
    Object? isActive = null,
    Object? description = freezed,
    Object? settings = freezed,
  }) {
    return _then(_$SquadImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      memberUids: null == memberUids
          ? _value._memberUids
          : memberUids // ignore: cast_nullable_to_non_nullable
              as List<String>,
      gameName: null == gameName
          ? _value.gameName
          : gameName // ignore: cast_nullable_to_non_nullable
              as String,
      maxSpots: null == maxSpots
          ? _value.maxSpots
          : maxSpots // ignore: cast_nullable_to_non_nullable
              as int,
      createdBy: null == createdBy
          ? _value.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      spots: null == spots
          ? _value._spots
          : spots // ignore: cast_nullable_to_non_nullable
              as List<String?>,
      spotTimers: null == spotTimers
          ? _value._spotTimers
          : spotTimers // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>?>,
      viewers: null == viewers
          ? _value._viewers
          : viewers // ignore: cast_nullable_to_non_nullable
              as List<String>,
      statuses: null == statuses
          ? _value._statuses
          : statuses // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      settings: freezed == settings
          ? _value._settings
          : settings // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SquadImpl implements _Squad {
  const _$SquadImpl(
      {required this.id,
      required this.name,
      required final List<String> memberUids,
      required this.gameName,
      required this.maxSpots,
      required this.createdBy,
      required this.createdAt,
      required final List<String?> spots,
      required final List<Map<String, dynamic>?> spotTimers,
      required final List<String> viewers,
      required final Map<String, String> statuses,
      required this.isActive,
      this.description,
      final Map<String, dynamic>? settings})
      : _memberUids = memberUids,
        _spots = spots,
        _spotTimers = spotTimers,
        _viewers = viewers,
        _statuses = statuses,
        _settings = settings;

  factory _$SquadImpl.fromJson(Map<String, dynamic> json) =>
      _$$SquadImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  final List<String> _memberUids;
  @override
  List<String> get memberUids {
    if (_memberUids is EqualUnmodifiableListView) return _memberUids;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_memberUids);
  }

  @override
  final String gameName;
  @override
  final int maxSpots;
  @override
  final String createdBy;
  @override
  final DateTime createdAt;
  final List<String?> _spots;
  @override
  List<String?> get spots {
    if (_spots is EqualUnmodifiableListView) return _spots;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_spots);
  }

  final List<Map<String, dynamic>?> _spotTimers;
  @override
  List<Map<String, dynamic>?> get spotTimers {
    if (_spotTimers is EqualUnmodifiableListView) return _spotTimers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_spotTimers);
  }

  final List<String> _viewers;
  @override
  List<String> get viewers {
    if (_viewers is EqualUnmodifiableListView) return _viewers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_viewers);
  }

  final Map<String, String> _statuses;
  @override
  Map<String, String> get statuses {
    if (_statuses is EqualUnmodifiableMapView) return _statuses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_statuses);
  }

  @override
  final bool isActive;
  @override
  final String? description;
  final Map<String, dynamic>? _settings;
  @override
  Map<String, dynamic>? get settings {
    final value = _settings;
    if (value == null) return null;
    if (_settings is EqualUnmodifiableMapView) return _settings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'Squad(id: $id, name: $name, memberUids: $memberUids, gameName: $gameName, maxSpots: $maxSpots, createdBy: $createdBy, createdAt: $createdAt, spots: $spots, spotTimers: $spotTimers, viewers: $viewers, statuses: $statuses, isActive: $isActive, description: $description, settings: $settings)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SquadImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality()
                .equals(other._memberUids, _memberUids) &&
            (identical(other.gameName, gameName) ||
                other.gameName == gameName) &&
            (identical(other.maxSpots, maxSpots) ||
                other.maxSpots == maxSpots) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            const DeepCollectionEquality().equals(other._spots, _spots) &&
            const DeepCollectionEquality()
                .equals(other._spotTimers, _spotTimers) &&
            const DeepCollectionEquality().equals(other._viewers, _viewers) &&
            const DeepCollectionEquality().equals(other._statuses, _statuses) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other._settings, _settings));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      const DeepCollectionEquality().hash(_memberUids),
      gameName,
      maxSpots,
      createdBy,
      createdAt,
      const DeepCollectionEquality().hash(_spots),
      const DeepCollectionEquality().hash(_spotTimers),
      const DeepCollectionEquality().hash(_viewers),
      const DeepCollectionEquality().hash(_statuses),
      isActive,
      description,
      const DeepCollectionEquality().hash(_settings));

  /// Create a copy of Squad
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SquadImplCopyWith<_$SquadImpl> get copyWith =>
      __$$SquadImplCopyWithImpl<_$SquadImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SquadImplToJson(
      this,
    );
  }
}

abstract class _Squad implements Squad {
  const factory _Squad(
      {required final String id,
      required final String name,
      required final List<String> memberUids,
      required final String gameName,
      required final int maxSpots,
      required final String createdBy,
      required final DateTime createdAt,
      required final List<String?> spots,
      required final List<Map<String, dynamic>?> spotTimers,
      required final List<String> viewers,
      required final Map<String, String> statuses,
      required final bool isActive,
      final String? description,
      final Map<String, dynamic>? settings}) = _$SquadImpl;

  factory _Squad.fromJson(Map<String, dynamic> json) = _$SquadImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  List<String> get memberUids;
  @override
  String get gameName;
  @override
  int get maxSpots;
  @override
  String get createdBy;
  @override
  DateTime get createdAt;
  @override
  List<String?> get spots;
  @override
  List<Map<String, dynamic>?> get spotTimers;
  @override
  List<String> get viewers;
  @override
  Map<String, String> get statuses;
  @override
  bool get isActive;
  @override
  String? get description;
  @override
  Map<String, dynamic>? get settings;

  /// Create a copy of Squad
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SquadImplCopyWith<_$SquadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
