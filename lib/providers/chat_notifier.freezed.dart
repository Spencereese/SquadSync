// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ChatState {
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
  bool get isInitialized => throw _privateConstructorUsedError;
  DocumentSnapshot<Object?>? get lastDocument =>
      throw _privateConstructorUsedError;
  String? get errorMessage =>
      throw _privateConstructorUsedError; // Sync-related fields
  bool get isOnline => throw _privateConstructorUsedError;
  bool get isSyncing => throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get syncConflicts =>
      throw _privateConstructorUsedError;
  int get lastSyncTimestamp => throw _privateConstructorUsedError;
  String? get syncError => throw _privateConstructorUsedError;

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatStateCopyWith<ChatState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatStateCopyWith<$Res> {
  factory $ChatStateCopyWith(ChatState value, $Res Function(ChatState) then) =
      _$ChatStateCopyWithImpl<$Res, ChatState>;
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
      bool isInitialized,
      DocumentSnapshot<Object?>? lastDocument,
      String? errorMessage,
      bool isOnline,
      bool isSyncing,
      List<Map<String, dynamic>> syncConflicts,
      int lastSyncTimestamp,
      String? syncError});
}

/// @nodoc
class _$ChatStateCopyWithImpl<$Res, $Val extends ChatState>
    implements $ChatStateCopyWith<$Res> {
  _$ChatStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatState
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
    Object? isInitialized = null,
    Object? lastDocument = freezed,
    Object? errorMessage = freezed,
    Object? isOnline = null,
    Object? isSyncing = null,
    Object? syncConflicts = null,
    Object? lastSyncTimestamp = null,
    Object? syncError = freezed,
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
      isInitialized: null == isInitialized
          ? _value.isInitialized
          : isInitialized // ignore: cast_nullable_to_non_nullable
              as bool,
      lastDocument: freezed == lastDocument
          ? _value.lastDocument
          : lastDocument // ignore: cast_nullable_to_non_nullable
              as DocumentSnapshot<Object?>?,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      isOnline: null == isOnline
          ? _value.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool,
      isSyncing: null == isSyncing
          ? _value.isSyncing
          : isSyncing // ignore: cast_nullable_to_non_nullable
              as bool,
      syncConflicts: null == syncConflicts
          ? _value.syncConflicts
          : syncConflicts // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      lastSyncTimestamp: null == lastSyncTimestamp
          ? _value.lastSyncTimestamp
          : lastSyncTimestamp // ignore: cast_nullable_to_non_nullable
              as int,
      syncError: freezed == syncError
          ? _value.syncError
          : syncError // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatStateImplCopyWith<$Res>
    implements $ChatStateCopyWith<$Res> {
  factory _$$ChatStateImplCopyWith(
          _$ChatStateImpl value, $Res Function(_$ChatStateImpl) then) =
      __$$ChatStateImplCopyWithImpl<$Res>;
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
      bool isInitialized,
      DocumentSnapshot<Object?>? lastDocument,
      String? errorMessage,
      bool isOnline,
      bool isSyncing,
      List<Map<String, dynamic>> syncConflicts,
      int lastSyncTimestamp,
      String? syncError});
}

/// @nodoc
class __$$ChatStateImplCopyWithImpl<$Res>
    extends _$ChatStateCopyWithImpl<$Res, _$ChatStateImpl>
    implements _$$ChatStateImplCopyWith<$Res> {
  __$$ChatStateImplCopyWithImpl(
      _$ChatStateImpl _value, $Res Function(_$ChatStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChatState
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
    Object? isInitialized = null,
    Object? lastDocument = freezed,
    Object? errorMessage = freezed,
    Object? isOnline = null,
    Object? isSyncing = null,
    Object? syncConflicts = null,
    Object? lastSyncTimestamp = null,
    Object? syncError = freezed,
  }) {
    return _then(_$ChatStateImpl(
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
      isInitialized: null == isInitialized
          ? _value.isInitialized
          : isInitialized // ignore: cast_nullable_to_non_nullable
              as bool,
      lastDocument: freezed == lastDocument
          ? _value.lastDocument
          : lastDocument // ignore: cast_nullable_to_non_nullable
              as DocumentSnapshot<Object?>?,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      isOnline: null == isOnline
          ? _value.isOnline
          : isOnline // ignore: cast_nullable_to_non_nullable
              as bool,
      isSyncing: null == isSyncing
          ? _value.isSyncing
          : isSyncing // ignore: cast_nullable_to_non_nullable
              as bool,
      syncConflicts: null == syncConflicts
          ? _value._syncConflicts
          : syncConflicts // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      lastSyncTimestamp: null == lastSyncTimestamp
          ? _value.lastSyncTimestamp
          : lastSyncTimestamp // ignore: cast_nullable_to_non_nullable
              as int,
      syncError: freezed == syncError
          ? _value.syncError
          : syncError // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$ChatStateImpl implements _ChatState {
  const _$ChatStateImpl(
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
      required this.isInitialized,
      this.lastDocument,
      this.errorMessage,
      required this.isOnline,
      required this.isSyncing,
      required final List<Map<String, dynamic>> syncConflicts,
      required this.lastSyncTimestamp,
      this.syncError})
      : _typingUsers = typingUsers,
        _messages = messages,
        _sendingStatus = sendingStatus,
        _quickReactionEmojis = quickReactionEmojis,
        _replyToMessage = replyToMessage,
        _syncConflicts = syncConflicts;

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
  final bool isInitialized;
  @override
  final DocumentSnapshot<Object?>? lastDocument;
  @override
  final String? errorMessage;
// Sync-related fields
  @override
  final bool isOnline;
  @override
  final bool isSyncing;
  final List<Map<String, dynamic>> _syncConflicts;
  @override
  List<Map<String, dynamic>> get syncConflicts {
    if (_syncConflicts is EqualUnmodifiableListView) return _syncConflicts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_syncConflicts);
  }

  @override
  final int lastSyncTimestamp;
  @override
  final String? syncError;

  @override
  String toString() {
    return 'ChatState(isRecording: $isRecording, isUploading: $isUploading, typingUsers: $typingUsers, messages: $messages, unreadCount: $unreadCount, sendingStatus: $sendingStatus, quickReactionEmoji: $quickReactionEmoji, quickReactionEmojis: $quickReactionEmojis, replyToMessage: $replyToMessage, isDMView: $isDMView, dmUnreadCount: $dmUnreadCount, isInitialized: $isInitialized, lastDocument: $lastDocument, errorMessage: $errorMessage, isOnline: $isOnline, isSyncing: $isSyncing, syncConflicts: $syncConflicts, lastSyncTimestamp: $lastSyncTimestamp, syncError: $syncError)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatStateImpl &&
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
            (identical(other.isInitialized, isInitialized) ||
                other.isInitialized == isInitialized) &&
            (identical(other.lastDocument, lastDocument) ||
                other.lastDocument == lastDocument) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.isOnline, isOnline) ||
                other.isOnline == isOnline) &&
            (identical(other.isSyncing, isSyncing) ||
                other.isSyncing == isSyncing) &&
            const DeepCollectionEquality()
                .equals(other._syncConflicts, _syncConflicts) &&
            (identical(other.lastSyncTimestamp, lastSyncTimestamp) ||
                other.lastSyncTimestamp == lastSyncTimestamp) &&
            (identical(other.syncError, syncError) ||
                other.syncError == syncError));
  }

  @override
  int get hashCode => Object.hashAll([
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
        isInitialized,
        lastDocument,
        errorMessage,
        isOnline,
        isSyncing,
        const DeepCollectionEquality().hash(_syncConflicts),
        lastSyncTimestamp,
        syncError
      ]);

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatStateImplCopyWith<_$ChatStateImpl> get copyWith =>
      __$$ChatStateImplCopyWithImpl<_$ChatStateImpl>(this, _$identity);
}

abstract class _ChatState implements ChatState {
  const factory _ChatState(
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
      required final bool isInitialized,
      final DocumentSnapshot<Object?>? lastDocument,
      final String? errorMessage,
      required final bool isOnline,
      required final bool isSyncing,
      required final List<Map<String, dynamic>> syncConflicts,
      required final int lastSyncTimestamp,
      final String? syncError}) = _$ChatStateImpl;

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
  bool get isInitialized;
  @override
  DocumentSnapshot<Object?>? get lastDocument;
  @override
  String? get errorMessage; // Sync-related fields
  @override
  bool get isOnline;
  @override
  bool get isSyncing;
  @override
  List<Map<String, dynamic>> get syncConflicts;
  @override
  int get lastSyncTimestamp;
  @override
  String? get syncError;

  /// Create a copy of ChatState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatStateImplCopyWith<_$ChatStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
