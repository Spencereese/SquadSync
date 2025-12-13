// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_group.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ChatGroup _$ChatGroupFromJson(Map<String, dynamic> json) {
  return _ChatGroup.fromJson(json);
}

/// @nodoc
mixin _$ChatGroup {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  List<String> get memberUids => throw _privateConstructorUsedError;
  bool get isPublic => throw _privateConstructorUsedError;
  int get memberCount => throw _privateConstructorUsedError;
  String get createdBy => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;
  String? get inviteCode => throw _privateConstructorUsedError;
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;
  List<String>? get admins => throw _privateConstructorUsedError;
  List<String>? get moderators => throw _privateConstructorUsedError;
  bool? get isActive => throw _privateConstructorUsedError;
  DateTime? get lastActivity => throw _privateConstructorUsedError;
  Map<String, dynamic>? get settings => throw _privateConstructorUsedError;

  /// Serializes this ChatGroup to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChatGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatGroupCopyWith<ChatGroup> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatGroupCopyWith<$Res> {
  factory $ChatGroupCopyWith(ChatGroup value, $Res Function(ChatGroup) then) =
      _$ChatGroupCopyWithImpl<$Res, ChatGroup>;
  @useResult
  $Res call(
      {String id,
      String name,
      List<String> memberUids,
      bool isPublic,
      int memberCount,
      String createdBy,
      DateTime createdAt,
      String? description,
      String? avatarUrl,
      String? inviteCode,
      Map<String, dynamic>? metadata,
      List<String>? admins,
      List<String>? moderators,
      bool? isActive,
      DateTime? lastActivity,
      Map<String, dynamic>? settings});
}

/// @nodoc
class _$ChatGroupCopyWithImpl<$Res, $Val extends ChatGroup>
    implements $ChatGroupCopyWith<$Res> {
  _$ChatGroupCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? memberUids = null,
    Object? isPublic = null,
    Object? memberCount = null,
    Object? createdBy = null,
    Object? createdAt = null,
    Object? description = freezed,
    Object? avatarUrl = freezed,
    Object? inviteCode = freezed,
    Object? metadata = freezed,
    Object? admins = freezed,
    Object? moderators = freezed,
    Object? isActive = freezed,
    Object? lastActivity = freezed,
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
      isPublic: null == isPublic
          ? _value.isPublic
          : isPublic // ignore: cast_nullable_to_non_nullable
              as bool,
      memberCount: null == memberCount
          ? _value.memberCount
          : memberCount // ignore: cast_nullable_to_non_nullable
              as int,
      createdBy: null == createdBy
          ? _value.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      inviteCode: freezed == inviteCode
          ? _value.inviteCode
          : inviteCode // ignore: cast_nullable_to_non_nullable
              as String?,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      admins: freezed == admins
          ? _value.admins
          : admins // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      moderators: freezed == moderators
          ? _value.moderators
          : moderators // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      isActive: freezed == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool?,
      lastActivity: freezed == lastActivity
          ? _value.lastActivity
          : lastActivity // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      settings: freezed == settings
          ? _value.settings
          : settings // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatGroupImplCopyWith<$Res>
    implements $ChatGroupCopyWith<$Res> {
  factory _$$ChatGroupImplCopyWith(
          _$ChatGroupImpl value, $Res Function(_$ChatGroupImpl) then) =
      __$$ChatGroupImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      List<String> memberUids,
      bool isPublic,
      int memberCount,
      String createdBy,
      DateTime createdAt,
      String? description,
      String? avatarUrl,
      String? inviteCode,
      Map<String, dynamic>? metadata,
      List<String>? admins,
      List<String>? moderators,
      bool? isActive,
      DateTime? lastActivity,
      Map<String, dynamic>? settings});
}

/// @nodoc
class __$$ChatGroupImplCopyWithImpl<$Res>
    extends _$ChatGroupCopyWithImpl<$Res, _$ChatGroupImpl>
    implements _$$ChatGroupImplCopyWith<$Res> {
  __$$ChatGroupImplCopyWithImpl(
      _$ChatGroupImpl _value, $Res Function(_$ChatGroupImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? memberUids = null,
    Object? isPublic = null,
    Object? memberCount = null,
    Object? createdBy = null,
    Object? createdAt = null,
    Object? description = freezed,
    Object? avatarUrl = freezed,
    Object? inviteCode = freezed,
    Object? metadata = freezed,
    Object? admins = freezed,
    Object? moderators = freezed,
    Object? isActive = freezed,
    Object? lastActivity = freezed,
    Object? settings = freezed,
  }) {
    return _then(_$ChatGroupImpl(
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
      isPublic: null == isPublic
          ? _value.isPublic
          : isPublic // ignore: cast_nullable_to_non_nullable
              as bool,
      memberCount: null == memberCount
          ? _value.memberCount
          : memberCount // ignore: cast_nullable_to_non_nullable
              as int,
      createdBy: null == createdBy
          ? _value.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarUrl: freezed == avatarUrl
          ? _value.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      inviteCode: freezed == inviteCode
          ? _value.inviteCode
          : inviteCode // ignore: cast_nullable_to_non_nullable
              as String?,
      metadata: freezed == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      admins: freezed == admins
          ? _value._admins
          : admins // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      moderators: freezed == moderators
          ? _value._moderators
          : moderators // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      isActive: freezed == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool?,
      lastActivity: freezed == lastActivity
          ? _value.lastActivity
          : lastActivity // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      settings: freezed == settings
          ? _value._settings
          : settings // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatGroupImpl implements _ChatGroup {
  const _$ChatGroupImpl(
      {required this.id,
      required this.name,
      required final List<String> memberUids,
      required this.isPublic,
      required this.memberCount,
      required this.createdBy,
      required this.createdAt,
      this.description,
      this.avatarUrl,
      this.inviteCode,
      final Map<String, dynamic>? metadata,
      final List<String>? admins,
      final List<String>? moderators,
      this.isActive,
      this.lastActivity,
      final Map<String, dynamic>? settings})
      : _memberUids = memberUids,
        _metadata = metadata,
        _admins = admins,
        _moderators = moderators,
        _settings = settings;

  factory _$ChatGroupImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatGroupImplFromJson(json);

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
  final bool isPublic;
  @override
  final int memberCount;
  @override
  final String createdBy;
  @override
  final DateTime createdAt;
  @override
  final String? description;
  @override
  final String? avatarUrl;
  @override
  final String? inviteCode;
  final Map<String, dynamic>? _metadata;
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  final List<String>? _admins;
  @override
  List<String>? get admins {
    final value = _admins;
    if (value == null) return null;
    if (_admins is EqualUnmodifiableListView) return _admins;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<String>? _moderators;
  @override
  List<String>? get moderators {
    final value = _moderators;
    if (value == null) return null;
    if (_moderators is EqualUnmodifiableListView) return _moderators;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final bool? isActive;
  @override
  final DateTime? lastActivity;
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
    return 'ChatGroup(id: $id, name: $name, memberUids: $memberUids, isPublic: $isPublic, memberCount: $memberCount, createdBy: $createdBy, createdAt: $createdAt, description: $description, avatarUrl: $avatarUrl, inviteCode: $inviteCode, metadata: $metadata, admins: $admins, moderators: $moderators, isActive: $isActive, lastActivity: $lastActivity, settings: $settings)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatGroupImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality()
                .equals(other._memberUids, _memberUids) &&
            (identical(other.isPublic, isPublic) ||
                other.isPublic == isPublic) &&
            (identical(other.memberCount, memberCount) ||
                other.memberCount == memberCount) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.inviteCode, inviteCode) ||
                other.inviteCode == inviteCode) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata) &&
            const DeepCollectionEquality().equals(other._admins, _admins) &&
            const DeepCollectionEquality()
                .equals(other._moderators, _moderators) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.lastActivity, lastActivity) ||
                other.lastActivity == lastActivity) &&
            const DeepCollectionEquality().equals(other._settings, _settings));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      const DeepCollectionEquality().hash(_memberUids),
      isPublic,
      memberCount,
      createdBy,
      createdAt,
      description,
      avatarUrl,
      inviteCode,
      const DeepCollectionEquality().hash(_metadata),
      const DeepCollectionEquality().hash(_admins),
      const DeepCollectionEquality().hash(_moderators),
      isActive,
      lastActivity,
      const DeepCollectionEquality().hash(_settings));

  /// Create a copy of ChatGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatGroupImplCopyWith<_$ChatGroupImpl> get copyWith =>
      __$$ChatGroupImplCopyWithImpl<_$ChatGroupImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatGroupImplToJson(
      this,
    );
  }
}

abstract class _ChatGroup implements ChatGroup {
  const factory _ChatGroup(
      {required final String id,
      required final String name,
      required final List<String> memberUids,
      required final bool isPublic,
      required final int memberCount,
      required final String createdBy,
      required final DateTime createdAt,
      final String? description,
      final String? avatarUrl,
      final String? inviteCode,
      final Map<String, dynamic>? metadata,
      final List<String>? admins,
      final List<String>? moderators,
      final bool? isActive,
      final DateTime? lastActivity,
      final Map<String, dynamic>? settings}) = _$ChatGroupImpl;

  factory _ChatGroup.fromJson(Map<String, dynamic> json) =
      _$ChatGroupImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  List<String> get memberUids;
  @override
  bool get isPublic;
  @override
  int get memberCount;
  @override
  String get createdBy;
  @override
  DateTime get createdAt;
  @override
  String? get description;
  @override
  String? get avatarUrl;
  @override
  String? get inviteCode;
  @override
  Map<String, dynamic>? get metadata;
  @override
  List<String>? get admins;
  @override
  List<String>? get moderators;
  @override
  bool? get isActive;
  @override
  DateTime? get lastActivity;
  @override
  Map<String, dynamic>? get settings;

  /// Create a copy of ChatGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatGroupImplCopyWith<_$ChatGroupImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
