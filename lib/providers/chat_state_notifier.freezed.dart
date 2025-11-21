// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_state_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ChatStateData {
  bool get isRecording => throw _privateConstructorUsedError;
  bool get isUploading => throw _privateConstructorUsedError;
  List<String> get typingUsers => throw _privateConstructorUsedError;
  List<Message> get messages => throw _privateConstructorUsedError;
  int get unreadCount => throw _privateConstructorUsedError;
  Map<String, bool> get sendingStatus => throw _privateConstructorUsedError;
  String get quickReactionEmoji => throw _privateConstructorUsedError;
  List<String> get quickReactionEmojis => throw _privateConstructorUsedError;
  Map<String, dynamic>? get replyToMessage =>
      throw _privateConstructorUsedError;
  bool get isDMView => throw _privateConstructorUsedError;
  int get dmUnreadCount => throw _privateConstructorUsedError;
  String? get errorMessage => throw _privateConstructorUsedError;
  bool get isInitialized => throw _privateConstructorUsedError;
  DocumentSnapshot<Object?>? get lastDocument =>
      throw _privateConstructorUsedError;

  /// Create a copy of ChatStateData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatStateDataCopyWith<ChatStateData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatStateDataCopyWith<$Res> {
  factory $ChatStateDataCopyWith(
          ChatStateData value, $Res Function(ChatStateData) then) =
      _$ChatStateDataCopyWithImpl<$Res, ChatStateData>;
  @useResult
  $Res call(
      {bool isRecording,
      bool isUploading,
      List<String> typingUsers,
      List<Message> messages,
      int unreadCount,
      Map<String, bool> sendingStatus,
      String quickReactionEmoji,
      List<String> quickReactionEmojis,
      Map<String, dynamic>? replyToMessage,
      bool isDMView,
      int dmUnreadCount,
      String? errorMessage,
      bool isInitialized,
      DocumentSnapshot<Object?>? lastDocument});
}

/// @nodoc
class _$ChatStateDataCopyWithImpl<$Res, $Val extends ChatStateData>
    implements $ChatStateDataCopyWith<$Res> {
  _$ChatStateDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatStateData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isRecording = null,
    Object? isUploading = null,
    Object? typingUsers = null,
    Object? messages = null,
    Object? unreadCount = null,
    Object? sendingStatus = null,
    Object? quickReactionEmoji = null,
    Object? quickReactionEmojis = null,
    Object? replyToMessage = freezed,
    Object? isDMView = null,
    Object? dmUnreadCount = null,
    Object? errorMessage = freezed,
    Object? isInitialized = null,
    Object? lastDocument = freezed,
  }) {
    return _then(_value.copyWith(
      isRecording: null == isRecording
          ? _value.isRecording
          : isRecording // ignore: cast_nullable_to_non_nullable
              as bool,
      isUploading: null == isUploading
          ? _value.isUploading
          : isUploading // ignore: cast_nullable_to_non_nullable
              as bool,
      typingUsers: null == typingUsers
          ? _value.typingUsers
          : typingUsers // ignore: cast_nullable_to_non_nullable
              as List<String>,
      messages: null == messages
          ? _value.messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<Message>,
      unreadCount: null == unreadCount
          ? _value.unreadCount
          : unreadCount // ignore: cast_nullable_to_non_nullable
              as int,
      sendingStatus: null == sendingStatus
          ? _value.sendingStatus
          : sendingStatus // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      quickReactionEmoji: null == quickReactionEmoji
          ? _value.quickReactionEmoji
          : quickReactionEmoji // ignore: cast_nullable_to_non_nullable
              as String,
      quickReactionEmojis: null == quickReactionEmojis
          ? _value.quickReactionEmojis
          : quickReactionEmojis // ignore: cast_nullable_to_non_nullable
              as List<String>,
      replyToMessage: freezed == replyToMessage
          ? _value.replyToMessage
          : replyToMessage // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      isDMView: null == isDMView
          ? _value.isDMView
          : isDMView // ignore: cast_nullable_to_non_nullable
              as bool,
      dmUnreadCount: null == dmUnreadCount
          ? _value.dmUnreadCount
          : dmUnreadCount // ignore: cast_nullable_to_non_nullable
              as int,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      isInitialized: null == isInitialized
          ? _value.isInitialized
          : isInitialized // ignore: cast_nullable_to_non_nullable
              as bool,
      lastDocument: freezed == lastDocument
          ? _value.lastDocument
          : lastDocument // ignore: cast_nullable_to_non_nullable
              as DocumentSnapshot<Object?>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatStateDataImplCopyWith<$Res>
    implements $ChatStateDataCopyWith<$Res> {
  factory _$$ChatStateDataImplCopyWith(
          _$ChatStateDataImpl value, $Res Function(_$ChatStateDataImpl) then) =
      __$$ChatStateDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool isRecording,
      bool isUploading,
      List<String> typingUsers,
      List<Message> messages,
      int unreadCount,
      Map<String, bool> sendingStatus,
      String quickReactionEmoji,
      List<String> quickReactionEmojis,
      Map<String, dynamic>? replyToMessage,
      bool isDMView,
      int dmUnreadCount,
      String? errorMessage,
      bool isInitialized,
      DocumentSnapshot<Object?>? lastDocument});
}

/// @nodoc
class __$$ChatStateDataImplCopyWithImpl<$Res>
    extends _$ChatStateDataCopyWithImpl<$Res, _$ChatStateDataImpl>
    implements _$$ChatStateDataImplCopyWith<$Res> {
  __$$ChatStateDataImplCopyWithImpl(
      _$ChatStateDataImpl _value, $Res Function(_$ChatStateDataImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatStateData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isRecording = null,
    Object? isUploading = null,
    Object? typingUsers = null,
    Object? messages = null,
    Object? unreadCount = null,
    Object? sendingStatus = null,
    Object? quickReactionEmoji = null,
    Object? quickReactionEmojis = null,
    Object? replyToMessage = freezed,
    Object? isDMView = null,
    Object? dmUnreadCount = null,
    Object? errorMessage = freezed,
    Object? isInitialized = null,
    Object? lastDocument = freezed,
  }) {
    return _then(_$ChatStateDataImpl(
      isRecording: null == isRecording
          ? _value.isRecording
          : isRecording // ignore: cast_nullable_to_non_nullable
              as bool,
      isUploading: null == isUploading
          ? _value.isUploading
          : isUploading // ignore: cast_nullable_to_non_nullable
              as bool,
      typingUsers: null == typingUsers
          ? _value._typingUsers
          : typingUsers // ignore: cast_nullable_to_non_nullable
              as List<String>,
      messages: null == messages
          ? _value._messages
          : messages // ignore: cast_nullable_to_non_nullable
              as List<Message>,
      unreadCount: null == unreadCount
          ? _value.unreadCount
          : unreadCount // ignore: cast_nullable_to_non_nullable
              as int,
      sendingStatus: null == sendingStatus
          ? _value._sendingStatus
          : sendingStatus // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      quickReactionEmoji: null == quickReactionEmoji
          ? _value.quickReactionEmoji
          : quickReactionEmoji // ignore: cast_nullable_to_non_nullable
              as String,
      quickReactionEmojis: null == quickReactionEmojis
          ? _value._quickReactionEmojis
          : quickReactionEmojis // ignore: cast_nullable_to_non_nullable
              as List<String>,
      replyToMessage: freezed == replyToMessage
          ? _value._replyToMessage
          : replyToMessage // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      isDMView: null == isDMView
          ? _value.isDMView
          : isDMView // ignore: cast_nullable_to_non_nullable
              as bool,
      dmUnreadCount: null == dmUnreadCount
          ? _value.dmUnreadCount
          : dmUnreadCount // ignore: cast_nullable_to_non_nullable
              as int,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      isInitialized: null == isInitialized
          ? _value.isInitialized
          : isInitialized // ignore: cast_nullable_to_non_nullable
              as bool,
      lastDocument: freezed == lastDocument
          ? _value.lastDocument
          : lastDocument // ignore: cast_nullable_to_non_nullable
              as DocumentSnapshot<Object?>?,
    ));
  }
}

/// @nodoc

class _$ChatStateDataImpl implements _ChatStateData {
  const _$ChatStateDataImpl(
      {required this.isRecording,
      required this.isUploading,
      required final List<String> typingUsers,
      required final List<Message> messages,
      required this.unreadCount,
      required final Map<String, bool> sendingStatus,
      required this.quickReactionEmoji,
      required final List<String> quickReactionEmojis,
      required final Map<String, dynamic>? replyToMessage,
      required this.isDMView,
      required this.dmUnreadCount,
      this.errorMessage,
      required this.isInitialized,
      this.lastDocument})
      : _typingUsers = typingUsers,
        _messages = messages,
        _sendingStatus = sendingStatus,
        _quickReactionEmojis = quickReactionEmojis,
        _replyToMessage = replyToMessage;

  @override
  final bool isRecording;
  @override
  final bool isUploading;
  final List<String> _typingUsers;
  @override
  List<String> get typingUsers {
    if (_typingUsers is EqualUnmodifiableListView) return _typingUsers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_typingUsers);
  }

  final List<Message> _messages;
  @override
  List<Message> get messages {
    if (_messages is EqualUnmodifiableListView) return _messages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_messages);
  }

  @override
  final int unreadCount;
  final Map<String, bool> _sendingStatus;
  @override
  Map<String, bool> get sendingStatus {
    if (_sendingStatus is EqualUnmodifiableMapView) return _sendingStatus;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_sendingStatus);
  }

  @override
  final String quickReactionEmoji;
  final List<String> _quickReactionEmojis;
  @override
  List<String> get quickReactionEmojis {
    if (_quickReactionEmojis is EqualUnmodifiableListView)
      return _quickReactionEmojis;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_quickReactionEmojis);
  }

  final Map<String, dynamic>? _replyToMessage;
  @override
  Map<String, dynamic>? get replyToMessage {
    final value = _replyToMessage;
    if (value == null) return null;
    if (_replyToMessage is EqualUnmodifiableMapView) return _replyToMessage;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final bool isDMView;
  @override
  final int dmUnreadCount;
  @override
  final String? errorMessage;
  @override
  final bool isInitialized;
  @override
  final DocumentSnapshot<Object?>? lastDocument;

  @override
  String toString() {
    return 'ChatStateData(isRecording: $isRecording, isUploading: $isUploading, typingUsers: $typingUsers, messages: $messages, unreadCount: $unreadCount, sendingStatus: $sendingStatus, quickReactionEmoji: $quickReactionEmoji, quickReactionEmojis: $quickReactionEmojis, replyToMessage: $replyToMessage, isDMView: $isDMView, dmUnreadCount: $dmUnreadCount, errorMessage: $errorMessage, isInitialized: $isInitialized, lastDocument: $lastDocument)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatStateDataImpl &&
            (identical(other.isRecording, isRecording) ||
                other.isRecording == isRecording) &&
            (identical(other.isUploading, isUploading) ||
                other.isUploading == isUploading) &&
            const DeepCollectionEquality()
                .equals(other._typingUsers, _typingUsers) &&
            const DeepCollectionEquality().equals(other._messages, _messages) &&
            (identical(other.unreadCount, unreadCount) ||
                other.unreadCount == unreadCount) &&
            const DeepCollectionEquality()
                .equals(other._sendingStatus, _sendingStatus) &&
            (identical(other.quickReactionEmoji, quickReactionEmoji) ||
                other.quickReactionEmoji == quickReactionEmoji) &&
            const DeepCollectionEquality()
                .equals(other._quickReactionEmojis, _quickReactionEmojis) &&
            const DeepCollectionEquality()
                .equals(other._replyToMessage, _replyToMessage) &&
            (identical(other.isDMView, isDMView) ||
                other.isDMView == isDMView) &&
            (identical(other.dmUnreadCount, dmUnreadCount) ||
                other.dmUnreadCount == dmUnreadCount) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.isInitialized, isInitialized) ||
                other.isInitialized == isInitialized) &&
            (identical(other.lastDocument, lastDocument) ||
                other.lastDocument == lastDocument));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      isRecording,
      isUploading,
      const DeepCollectionEquality().hash(_typingUsers),
      const DeepCollectionEquality().hash(_messages),
      unreadCount,
      const DeepCollectionEquality().hash(_sendingStatus),
      quickReactionEmoji,
      const DeepCollectionEquality().hash(_quickReactionEmojis),
      const DeepCollectionEquality().hash(_replyToMessage),
      isDMView,
      dmUnreadCount,
      errorMessage,
      isInitialized,
      lastDocument);

  /// Create a copy of ChatStateData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatStateDataImplCopyWith<_$ChatStateDataImpl> get copyWith =>
      __$$ChatStateDataImplCopyWithImpl<_$ChatStateDataImpl>(this, _$identity);
}

abstract class _ChatStateData implements ChatStateData {
  const factory _ChatStateData(
      {required final bool isRecording,
      required final bool isUploading,
      required final List<String> typingUsers,
      required final List<Message> messages,
      required final int unreadCount,
      required final Map<String, bool> sendingStatus,
      required final String quickReactionEmoji,
      required final List<String> quickReactionEmojis,
      required final Map<String, dynamic>? replyToMessage,
      required final bool isDMView,
      required final int dmUnreadCount,
      final String? errorMessage,
      required final bool isInitialized,
      final DocumentSnapshot<Object?>? lastDocument}) = _$ChatStateDataImpl;

  @override
  bool get isRecording;
  @override
  bool get isUploading;
  @override
  List<String> get typingUsers;
  @override
  List<Message> get messages;
  @override
  int get unreadCount;
  @override
  Map<String, bool> get sendingStatus;
  @override
  String get quickReactionEmoji;
  @override
  List<String> get quickReactionEmojis;
  @override
  Map<String, dynamic>? get replyToMessage;
  @override
  bool get isDMView;
  @override
  int get dmUnreadCount;
  @override
  String? get errorMessage;
  @override
  bool get isInitialized;
  @override
  DocumentSnapshot<Object?>? get lastDocument;

  /// Create a copy of ChatStateData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatStateDataImplCopyWith<_$ChatStateDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
