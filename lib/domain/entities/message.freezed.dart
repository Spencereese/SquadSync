// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$Message {
  String get id => throw _privateConstructorUsedError;
  String get senderId => throw _privateConstructorUsedError;
  String get text => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get timestamp => throw _privateConstructorUsedError;
  @MessageTypeConverter()
  MessageType get messageType => throw _privateConstructorUsedError;
  String? get mediaUrl => throw _privateConstructorUsedError;
  String? get mediaType => throw _privateConstructorUsedError;
  @ReactionConverter()
  Map<String, int>? get reactions => throw _privateConstructorUsedError;
  String? get replyTo => throw _privateConstructorUsedError;
  Poll? get poll => throw _privateConstructorUsedError;
  String? get voiceNoteUrl => throw _privateConstructorUsedError;
  int? get voiceNoteDuration => throw _privateConstructorUsedError;
  String? get aiResponse => throw _privateConstructorUsedError;
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;
  bool? get isEdited => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get editedAt => throw _privateConstructorUsedError;
  bool? get isDeleted => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get deletedAt => throw _privateConstructorUsedError;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MessageCopyWith<Message> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MessageCopyWith<$Res> {
  factory $MessageCopyWith(Message value, $Res Function(Message) then) =
      _$MessageCopyWithImpl<$Res, Message>;
  @useResult
  $Res call(
      {String id,
      String senderId,
      String text,
      @TimestampConverter() DateTime timestamp,
      @MessageTypeConverter() MessageType messageType,
      String? mediaUrl,
      String? mediaType,
      @ReactionConverter() Map<String, int>? reactions,
      String? replyTo,
      Poll? poll,
      String? voiceNoteUrl,
      int? voiceNoteDuration,
      String? aiResponse,
      Map<String, dynamic>? metadata,
      bool? isEdited,
      @TimestampConverter() DateTime? editedAt,
      bool? isDeleted,
      @TimestampConverter() DateTime? deletedAt});
}

/// @nodoc
class _$MessageCopyWithImpl<$Res, $Val extends Message>
    implements $MessageCopyWith<$Res> {
  _$MessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? senderId = null,
    Object? text = null,
    Object? timestamp = null,
    Object? messageType = null,
    Object? mediaUrl = freezed,
    Object? mediaType = freezed,
    Object? reactions = freezed,
    Object? replyTo = freezed,
    Object? poll = freezed,
    Object? voiceNoteUrl = freezed,
    Object? voiceNoteDuration = freezed,
    Object? aiResponse = freezed,
    Object? metadata = freezed,
    Object? isEdited = freezed,
    Object? editedAt = freezed,
    Object? isDeleted = freezed,
    Object? deletedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      senderId: null == senderId
          ? _value.senderId
          : senderId // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      messageType: null == messageType
          ? _value.messageType
          : messageType // ignore: cast_nullable_to_non_nullable
              as MessageType,
      mediaUrl: freezed == mediaUrl
          ? _value.mediaUrl
          : mediaUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      mediaType: freezed == mediaType
          ? _value.mediaType
          : mediaType // ignore: cast_nullable_to_non_nullable
              as String?,
      reactions: freezed == reactions
          ? _value.reactions
          : reactions // ignore: cast_nullable_to_non_nullable
              as Map<String, int>?,
      replyTo: freezed == replyTo
          ? _value.replyTo
          : replyTo // ignore: cast_nullable_to_non_nullable
              as String?,
      poll: freezed == poll
          ? _value.poll
          : poll // ignore: cast_nullable_to_non_nullable
              as Poll?,
      voiceNoteUrl: freezed == voiceNoteUrl
          ? _value.voiceNoteUrl
          : voiceNoteUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      voiceNoteDuration: freezed == voiceNoteDuration
          ? _value.voiceNoteDuration
          : voiceNoteDuration // ignore: cast_nullable_to_non_nullable
              as int?,
      aiResponse: freezed == aiResponse
          ? _value.aiResponse
          : aiResponse // ignore: cast_nullable_to_non_nullable
              as String?,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      isEdited: freezed == isEdited
          ? _value.isEdited
          : isEdited // ignore: cast_nullable_to_non_nullable
              as bool?,
      editedAt: freezed == editedAt
          ? _value.editedAt
          : editedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isDeleted: freezed == isDeleted
          ? _value.isDeleted
          : isDeleted // ignore: cast_nullable_to_non_nullable
              as bool?,
      deletedAt: freezed == deletedAt
          ? _value.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MessageImplCopyWith<$Res> implements $MessageCopyWith<$Res> {
  factory _$$MessageImplCopyWith(
          _$MessageImpl value, $Res Function(_$MessageImpl) then) =
      __$$MessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String senderId,
      String text,
      @TimestampConverter() DateTime timestamp,
      @MessageTypeConverter() MessageType messageType,
      String? mediaUrl,
      String? mediaType,
      @ReactionConverter() Map<String, int>? reactions,
      String? replyTo,
      Poll? poll,
      String? voiceNoteUrl,
      int? voiceNoteDuration,
      String? aiResponse,
      Map<String, dynamic>? metadata,
      bool? isEdited,
      @TimestampConverter() DateTime? editedAt,
      bool? isDeleted,
      @TimestampConverter() DateTime? deletedAt});
}

/// @nodoc
class __$$MessageImplCopyWithImpl<$Res>
    extends _$MessageCopyWithImpl<$Res, _$MessageImpl>
    implements _$$MessageImplCopyWith<$Res> {
  __$$MessageImplCopyWithImpl(
      _$MessageImpl _value, $Res Function(_$MessageImpl) _then)
      : super(_value, _then);

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? senderId = null,
    Object? text = null,
    Object? timestamp = null,
    Object? messageType = null,
    Object? mediaUrl = freezed,
    Object? mediaType = freezed,
    Object? reactions = freezed,
    Object? replyTo = freezed,
    Object? poll = freezed,
    Object? voiceNoteUrl = freezed,
    Object? voiceNoteDuration = freezed,
    Object? aiResponse = freezed,
    Object? metadata = freezed,
    Object? isEdited = freezed,
    Object? editedAt = freezed,
    Object? isDeleted = freezed,
    Object? deletedAt = freezed,
  }) {
    return _then(_$MessageImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      senderId: null == senderId
          ? _value.senderId
          : senderId // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      messageType: null == messageType
          ? _value.messageType
          : messageType // ignore: cast_nullable_to_non_nullable
              as MessageType,
      mediaUrl: freezed == mediaUrl
          ? _value.mediaUrl
          : mediaUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      mediaType: freezed == mediaType
          ? _value.mediaType
          : mediaType // ignore: cast_nullable_to_non_nullable
              as String?,
      reactions: freezed == reactions
          ? _value._reactions
          : reactions // ignore: cast_nullable_to_non_nullable
              as Map<String, int>?,
      replyTo: freezed == replyTo
          ? _value.replyTo
          : replyTo // ignore: cast_nullable_to_non_nullable
              as String?,
      poll: freezed == poll
          ? _value.poll
          : poll // ignore: cast_nullable_to_non_nullable
              as Poll?,
      voiceNoteUrl: freezed == voiceNoteUrl
          ? _value.voiceNoteUrl
          : voiceNoteUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      voiceNoteDuration: freezed == voiceNoteDuration
          ? _value.voiceNoteDuration
          : voiceNoteDuration // ignore: cast_nullable_to_non_nullable
              as int?,
      aiResponse: freezed == aiResponse
          ? _value.aiResponse
          : aiResponse // ignore: cast_nullable_to_non_nullable
              as String?,
      metadata: freezed == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      isEdited: freezed == isEdited
          ? _value.isEdited
          : isEdited // ignore: cast_nullable_to_non_nullable
              as bool?,
      editedAt: freezed == editedAt
          ? _value.editedAt
          : editedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isDeleted: freezed == isDeleted
          ? _value.isDeleted
          : isDeleted // ignore: cast_nullable_to_non_nullable
              as bool?,
      deletedAt: freezed == deletedAt
          ? _value.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc

class _$MessageImpl implements _Message {
  const _$MessageImpl(
      {required this.id,
      required this.senderId,
      required this.text,
      @TimestampConverter() required this.timestamp,
      @MessageTypeConverter() required this.messageType,
      this.mediaUrl,
      this.mediaType,
      @ReactionConverter() final Map<String, int>? reactions,
      this.replyTo,
      this.poll,
      this.voiceNoteUrl,
      this.voiceNoteDuration,
      this.aiResponse,
      final Map<String, dynamic>? metadata,
      this.isEdited,
      @TimestampConverter() this.editedAt,
      this.isDeleted,
      @TimestampConverter() this.deletedAt})
      : _reactions = reactions,
        _metadata = metadata;

  @override
  final String id;
  @override
  final String senderId;
  @override
  final String text;
  @override
  @TimestampConverter()
  final DateTime timestamp;
  @override
  @MessageTypeConverter()
  final MessageType messageType;
  @override
  final String? mediaUrl;
  @override
  final String? mediaType;
  final Map<String, int>? _reactions;
  @override
  @ReactionConverter()
  Map<String, int>? get reactions {
    final value = _reactions;
    if (value == null) return null;
    if (_reactions is EqualUnmodifiableMapView) return _reactions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final String? replyTo;
  @override
  final Poll? poll;
  @override
  final String? voiceNoteUrl;
  @override
  final int? voiceNoteDuration;
  @override
  final String? aiResponse;
  final Map<String, dynamic>? _metadata;
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final bool? isEdited;
  @override
  @TimestampConverter()
  final DateTime? editedAt;
  @override
  final bool? isDeleted;
  @override
  @TimestampConverter()
  final DateTime? deletedAt;

  @override
  String toString() {
    return 'Message(id: $id, senderId: $senderId, text: $text, timestamp: $timestamp, messageType: $messageType, mediaUrl: $mediaUrl, mediaType: $mediaType, reactions: $reactions, replyTo: $replyTo, poll: $poll, voiceNoteUrl: $voiceNoteUrl, voiceNoteDuration: $voiceNoteDuration, aiResponse: $aiResponse, metadata: $metadata, isEdited: $isEdited, editedAt: $editedAt, isDeleted: $isDeleted, deletedAt: $deletedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.senderId, senderId) ||
                other.senderId == senderId) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.messageType, messageType) ||
                other.messageType == messageType) &&
            (identical(other.mediaUrl, mediaUrl) ||
                other.mediaUrl == mediaUrl) &&
            (identical(other.mediaType, mediaType) ||
                other.mediaType == mediaType) &&
            const DeepCollectionEquality()
                .equals(other._reactions, _reactions) &&
            (identical(other.replyTo, replyTo) || other.replyTo == replyTo) &&
            (identical(other.poll, poll) || other.poll == poll) &&
            (identical(other.voiceNoteUrl, voiceNoteUrl) ||
                other.voiceNoteUrl == voiceNoteUrl) &&
            (identical(other.voiceNoteDuration, voiceNoteDuration) ||
                other.voiceNoteDuration == voiceNoteDuration) &&
            (identical(other.aiResponse, aiResponse) ||
                other.aiResponse == aiResponse) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata) &&
            (identical(other.isEdited, isEdited) ||
                other.isEdited == isEdited) &&
            (identical(other.editedAt, editedAt) ||
                other.editedAt == editedAt) &&
            (identical(other.isDeleted, isDeleted) ||
                other.isDeleted == isDeleted) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      senderId,
      text,
      timestamp,
      messageType,
      mediaUrl,
      mediaType,
      const DeepCollectionEquality().hash(_reactions),
      replyTo,
      poll,
      voiceNoteUrl,
      voiceNoteDuration,
      aiResponse,
      const DeepCollectionEquality().hash(_metadata),
      isEdited,
      editedAt,
      isDeleted,
      deletedAt);

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageImplCopyWith<_$MessageImpl> get copyWith =>
      __$$MessageImplCopyWithImpl<_$MessageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'text': text,
      'timestamp': const TimestampConverter().toJson(timestamp),
      'messageType': const MessageTypeConverter().toJson(messageType),
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'reactions': const ReactionConverter().toJson(reactions),
      'replyTo': replyTo,
      'poll': poll?.toJson(),
      'voiceNoteUrl': voiceNoteUrl,
      'voiceNoteDuration': voiceNoteDuration,
      'aiResponse': aiResponse,
      'metadata': metadata,
      'isEdited': isEdited,
      'editedAt': editedAt != null
          ? const TimestampConverter().toJson(editedAt!)
          : null,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null
          ? const TimestampConverter().toJson(deletedAt!)
          : null,
    };
  }
}

abstract class _Message implements Message {
  const factory _Message(
      {required final String id,
      required final String senderId,
      required final String text,
      @TimestampConverter() required final DateTime timestamp,
      @MessageTypeConverter() required final MessageType messageType,
      final String? mediaUrl,
      final String? mediaType,
      @ReactionConverter() final Map<String, int>? reactions,
      final String? replyTo,
      final Poll? poll,
      final String? voiceNoteUrl,
      final int? voiceNoteDuration,
      final String? aiResponse,
      final Map<String, dynamic>? metadata,
      final bool? isEdited,
      @TimestampConverter() final DateTime? editedAt,
      final bool? isDeleted,
      @TimestampConverter() final DateTime? deletedAt}) = _$MessageImpl;

  @override
  String get id;
  @override
  String get senderId;
  @override
  String get text;
  @override
  @TimestampConverter()
  DateTime get timestamp;
  @override
  @MessageTypeConverter()
  MessageType get messageType;
  @override
  String? get mediaUrl;
  @override
  String? get mediaType;
  @override
  @ReactionConverter()
  Map<String, int>? get reactions;
  @override
  String? get replyTo;
  @override
  Poll? get poll;
  @override
  String? get voiceNoteUrl;
  @override
  int? get voiceNoteDuration;
  @override
  String? get aiResponse;
  @override
  Map<String, dynamic>? get metadata;
  @override
  bool? get isEdited;
  @override
  @TimestampConverter()
  DateTime? get editedAt;
  @override
  bool? get isDeleted;
  @override
  @TimestampConverter()
  DateTime? get deletedAt;

  /// Create a copy of Message
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageImplCopyWith<_$MessageImpl> get copyWith =>
      throw _privateConstructorUsedError;

  /// Serializes this Message to a JSON map.
  Map<String, dynamic> toJson();
}
