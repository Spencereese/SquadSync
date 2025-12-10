// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_metadata.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ChatMetadata _$ChatMetadataFromJson(Map<String, dynamic> json) {
  return _ChatMetadata.fromJson(json);
}

/// @nodoc
mixin _$ChatMetadata {
  String get chatId => throw _privateConstructorUsedError;
  int get lastMessageTimestamp => throw _privateConstructorUsedError;
  Map<String, int> get unreadCounts =>
      throw _privateConstructorUsedError; // userId -> count
  List<String> get typingUsers => throw _privateConstructorUsedError;
  Map<String, String> get lastReadMessageId =>
      throw _privateConstructorUsedError; // userId -> messageId
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this ChatMetadata to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChatMetadata
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatMetadataCopyWith<ChatMetadata> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatMetadataCopyWith<$Res> {
  factory $ChatMetadataCopyWith(
          ChatMetadata value, $Res Function(ChatMetadata) then) =
      _$ChatMetadataCopyWithImpl<$Res, ChatMetadata>;
  @useResult
  $Res call(
      {String chatId,
      int lastMessageTimestamp,
      Map<String, int> unreadCounts,
      List<String> typingUsers,
      Map<String, String> lastReadMessageId,
      DateTime? updatedAt});
}

/// @nodoc
class _$ChatMetadataCopyWithImpl<$Res, $Val extends ChatMetadata>
    implements $ChatMetadataCopyWith<$Res> {
  _$ChatMetadataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatMetadata
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chatId = null,
    Object? lastMessageTimestamp = null,
    Object? unreadCounts = null,
    Object? typingUsers = null,
    Object? lastReadMessageId = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      chatId: null == chatId
          ? _value.chatId
          : chatId // ignore: cast_nullable_to_non_nullable
              as String,
      lastMessageTimestamp: null == lastMessageTimestamp
          ? _value.lastMessageTimestamp
          : lastMessageTimestamp // ignore: cast_nullable_to_non_nullable
              as int,
      unreadCounts: null == unreadCounts
          ? _value.unreadCounts
          : unreadCounts // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      typingUsers: null == typingUsers
          ? _value.typingUsers
          : typingUsers // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lastReadMessageId: null == lastReadMessageId
          ? _value.lastReadMessageId
          : lastReadMessageId // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatMetadataImplCopyWith<$Res>
    implements $ChatMetadataCopyWith<$Res> {
  factory _$$ChatMetadataImplCopyWith(
          _$ChatMetadataImpl value, $Res Function(_$ChatMetadataImpl) then) =
      __$$ChatMetadataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String chatId,
      int lastMessageTimestamp,
      Map<String, int> unreadCounts,
      List<String> typingUsers,
      Map<String, String> lastReadMessageId,
      DateTime? updatedAt});
}

/// @nodoc
class __$$ChatMetadataImplCopyWithImpl<$Res>
    extends _$ChatMetadataCopyWithImpl<$Res, _$ChatMetadataImpl>
    implements _$$ChatMetadataImplCopyWith<$Res> {
  __$$ChatMetadataImplCopyWithImpl(
      _$ChatMetadataImpl _value, $Res Function(_$ChatMetadataImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatMetadata
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chatId = null,
    Object? lastMessageTimestamp = null,
    Object? unreadCounts = null,
    Object? typingUsers = null,
    Object? lastReadMessageId = null,
    Object? updatedAt = freezed,
  }) {
    return _then(_$ChatMetadataImpl(
      chatId: null == chatId
          ? _value.chatId
          : chatId // ignore: cast_nullable_to_non_nullable
              as String,
      lastMessageTimestamp: null == lastMessageTimestamp
          ? _value.lastMessageTimestamp
          : lastMessageTimestamp // ignore: cast_nullable_to_non_nullable
              as int,
      unreadCounts: null == unreadCounts
          ? _value._unreadCounts
          : unreadCounts // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      typingUsers: null == typingUsers
          ? _value._typingUsers
          : typingUsers // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lastReadMessageId: null == lastReadMessageId
          ? _value._lastReadMessageId
          : lastReadMessageId // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatMetadataImpl implements _ChatMetadata {
  const _$ChatMetadataImpl(
      {required this.chatId,
      this.lastMessageTimestamp = 0,
      final Map<String, int> unreadCounts = const {},
      final List<String> typingUsers = const [],
      final Map<String, String> lastReadMessageId = const {},
      this.updatedAt})
      : _unreadCounts = unreadCounts,
        _typingUsers = typingUsers,
        _lastReadMessageId = lastReadMessageId;

  factory _$ChatMetadataImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatMetadataImplFromJson(json);

  @override
  final String chatId;
  @override
  @JsonKey()
  final int lastMessageTimestamp;
  final Map<String, int> _unreadCounts;
  @override
  @JsonKey()
  Map<String, int> get unreadCounts {
    if (_unreadCounts is EqualUnmodifiableMapView) return _unreadCounts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_unreadCounts);
  }

// userId -> count
  final List<String> _typingUsers;
// userId -> count
  @override
  @JsonKey()
  List<String> get typingUsers {
    if (_typingUsers is EqualUnmodifiableListView) return _typingUsers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_typingUsers);
  }

  final Map<String, String> _lastReadMessageId;
  @override
  @JsonKey()
  Map<String, String> get lastReadMessageId {
    if (_lastReadMessageId is EqualUnmodifiableMapView)
      return _lastReadMessageId;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_lastReadMessageId);
  }

// userId -> messageId
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'ChatMetadata(chatId: $chatId, lastMessageTimestamp: $lastMessageTimestamp, unreadCounts: $unreadCounts, typingUsers: $typingUsers, lastReadMessageId: $lastReadMessageId, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatMetadataImpl &&
            (identical(other.chatId, chatId) || other.chatId == chatId) &&
            (identical(other.lastMessageTimestamp, lastMessageTimestamp) ||
                other.lastMessageTimestamp == lastMessageTimestamp) &&
            const DeepCollectionEquality()
                .equals(other._unreadCounts, _unreadCounts) &&
            const DeepCollectionEquality()
                .equals(other._typingUsers, _typingUsers) &&
            const DeepCollectionEquality()
                .equals(other._lastReadMessageId, _lastReadMessageId) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      chatId,
      lastMessageTimestamp,
      const DeepCollectionEquality().hash(_unreadCounts),
      const DeepCollectionEquality().hash(_typingUsers),
      const DeepCollectionEquality().hash(_lastReadMessageId),
      updatedAt);

  /// Create a copy of ChatMetadata
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatMetadataImplCopyWith<_$ChatMetadataImpl> get copyWith =>
      __$$ChatMetadataImplCopyWithImpl<_$ChatMetadataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatMetadataImplToJson(
      this,
    );
  }
}

abstract class _ChatMetadata implements ChatMetadata {
  const factory _ChatMetadata(
      {required final String chatId,
      final int lastMessageTimestamp,
      final Map<String, int> unreadCounts,
      final List<String> typingUsers,
      final Map<String, String> lastReadMessageId,
      final DateTime? updatedAt}) = _$ChatMetadataImpl;

  factory _ChatMetadata.fromJson(Map<String, dynamic> json) =
      _$ChatMetadataImpl.fromJson;

  @override
  String get chatId;
  @override
  int get lastMessageTimestamp;
  @override
  Map<String, int> get unreadCounts; // userId -> count
  @override
  List<String> get typingUsers;
  @override
  Map<String, String> get lastReadMessageId; // userId -> messageId
  @override
  DateTime? get updatedAt;

  /// Create a copy of ChatMetadata
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatMetadataImplCopyWith<_$ChatMetadataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
