// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$GameState {
  List<Game> get availableGames => throw _privateConstructorUsedError;
  List<Game> get gameHistory => throw _privateConstructorUsedError;
  Map<String, List<Map<String, dynamic>>> get gameLobbies =>
      throw _privateConstructorUsedError;
  Game? get currentGame => throw _privateConstructorUsedError;
  Map<String, dynamic>? get onboardingFlow =>
      throw _privateConstructorUsedError;
  bool get isInitialized => throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get twitchClips =>
      throw _privateConstructorUsedError;
  String? get errorMessage => throw _privateConstructorUsedError;

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GameStateCopyWith<GameState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GameStateCopyWith<$Res> {
  factory $GameStateCopyWith(GameState value, $Res Function(GameState) then) =
      _$GameStateCopyWithImpl<$Res, GameState>;
  @useResult
  $Res call(
      {List<Game> availableGames,
      List<Game> gameHistory,
      Map<String, List<Map<String, dynamic>>> gameLobbies,
      Game? currentGame,
      Map<String, dynamic>? onboardingFlow,
      bool isInitialized,
      List<Map<String, dynamic>> twitchClips,
      String? errorMessage});

  $GameCopyWith<$Res>? get currentGame;
}

/// @nodoc
class _$GameStateCopyWithImpl<$Res, $Val extends GameState>
    implements $GameStateCopyWith<$Res> {
  _$GameStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? availableGames = null,
    Object? gameHistory = null,
    Object? gameLobbies = null,
    Object? currentGame = freezed,
    Object? onboardingFlow = freezed,
    Object? isInitialized = null,
    Object? twitchClips = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_value.copyWith(
      availableGames: null == availableGames
          ? _value.availableGames
          : availableGames // ignore: cast_nullable_to_non_nullable
              as List<Game>,
      gameHistory: null == gameHistory
          ? _value.gameHistory
          : gameHistory // ignore: cast_nullable_to_non_nullable
              as List<Game>,
      gameLobbies: null == gameLobbies
          ? _value.gameLobbies
          : gameLobbies // ignore: cast_nullable_to_non_nullable
              as Map<String, List<Map<String, dynamic>>>,
      currentGame: freezed == currentGame
          ? _value.currentGame
          : currentGame // ignore: cast_nullable_to_non_nullable
              as Game?,
      onboardingFlow: freezed == onboardingFlow
          ? _value.onboardingFlow
          : onboardingFlow // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      isInitialized: null == isInitialized
          ? _value.isInitialized
          : isInitialized // ignore: cast_nullable_to_non_nullable
              as bool,
      twitchClips: null == twitchClips
          ? _value.twitchClips
          : twitchClips // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GameCopyWith<$Res>? get currentGame {
    if (_value.currentGame == null) {
      return null;
    }

    return $GameCopyWith<$Res>(_value.currentGame!, (value) {
      return _then(_value.copyWith(currentGame: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$GameStateImplCopyWith<$Res>
    implements $GameStateCopyWith<$Res> {
  factory _$$GameStateImplCopyWith(
          _$GameStateImpl value, $Res Function(_$GameStateImpl) then) =
      __$$GameStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<Game> availableGames,
      List<Game> gameHistory,
      Map<String, List<Map<String, dynamic>>> gameLobbies,
      Game? currentGame,
      Map<String, dynamic>? onboardingFlow,
      bool isInitialized,
      List<Map<String, dynamic>> twitchClips,
      String? errorMessage});

  @override
  $GameCopyWith<$Res>? get currentGame;
}

/// @nodoc
class __$$GameStateImplCopyWithImpl<$Res>
    extends _$GameStateCopyWithImpl<$Res, _$GameStateImpl>
    implements _$$GameStateImplCopyWith<$Res> {
  __$$GameStateImplCopyWithImpl(
      _$GameStateImpl _value, $Res Function(_$GameStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? availableGames = null,
    Object? gameHistory = null,
    Object? gameLobbies = null,
    Object? currentGame = freezed,
    Object? onboardingFlow = freezed,
    Object? isInitialized = null,
    Object? twitchClips = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_$GameStateImpl(
      availableGames: null == availableGames
          ? _value._availableGames
          : availableGames // ignore: cast_nullable_to_non_nullable
              as List<Game>,
      gameHistory: null == gameHistory
          ? _value._gameHistory
          : gameHistory // ignore: cast_nullable_to_non_nullable
              as List<Game>,
      gameLobbies: null == gameLobbies
          ? _value._gameLobbies
          : gameLobbies // ignore: cast_nullable_to_non_nullable
              as Map<String, List<Map<String, dynamic>>>,
      currentGame: freezed == currentGame
          ? _value.currentGame
          : currentGame // ignore: cast_nullable_to_non_nullable
              as Game?,
      onboardingFlow: freezed == onboardingFlow
          ? _value._onboardingFlow
          : onboardingFlow // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      isInitialized: null == isInitialized
          ? _value.isInitialized
          : isInitialized // ignore: cast_nullable_to_non_nullable
              as bool,
      twitchClips: null == twitchClips
          ? _value._twitchClips
          : twitchClips // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$GameStateImpl implements _GameState {
  const _$GameStateImpl(
      {required final List<Game> availableGames,
      required final List<Game> gameHistory,
      required final Map<String, List<Map<String, dynamic>>> gameLobbies,
      required this.currentGame,
      required final Map<String, dynamic>? onboardingFlow,
      required this.isInitialized,
      required final List<Map<String, dynamic>> twitchClips,
      this.errorMessage})
      : _availableGames = availableGames,
        _gameHistory = gameHistory,
        _gameLobbies = gameLobbies,
        _onboardingFlow = onboardingFlow,
        _twitchClips = twitchClips;

  final List<Game> _availableGames;
  @override
  List<Game> get availableGames {
    if (_availableGames is EqualUnmodifiableListView) return _availableGames;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_availableGames);
  }

  final List<Game> _gameHistory;
  @override
  List<Game> get gameHistory {
    if (_gameHistory is EqualUnmodifiableListView) return _gameHistory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_gameHistory);
  }

  final Map<String, List<Map<String, dynamic>>> _gameLobbies;
  @override
  Map<String, List<Map<String, dynamic>>> get gameLobbies {
    if (_gameLobbies is EqualUnmodifiableMapView) return _gameLobbies;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_gameLobbies);
  }

  @override
  final Game? currentGame;
  final Map<String, dynamic>? _onboardingFlow;
  @override
  Map<String, dynamic>? get onboardingFlow {
    final value = _onboardingFlow;
    if (value == null) return null;
    if (_onboardingFlow is EqualUnmodifiableMapView) return _onboardingFlow;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final bool isInitialized;
  final List<Map<String, dynamic>> _twitchClips;
  @override
  List<Map<String, dynamic>> get twitchClips {
    if (_twitchClips is EqualUnmodifiableListView) return _twitchClips;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_twitchClips);
  }

  @override
  final String? errorMessage;

  @override
  String toString() {
    return 'GameState(availableGames: $availableGames, gameHistory: $gameHistory, gameLobbies: $gameLobbies, currentGame: $currentGame, onboardingFlow: $onboardingFlow, isInitialized: $isInitialized, twitchClips: $twitchClips, errorMessage: $errorMessage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GameStateImpl &&
            const DeepCollectionEquality()
                .equals(other._availableGames, _availableGames) &&
            const DeepCollectionEquality()
                .equals(other._gameHistory, _gameHistory) &&
            const DeepCollectionEquality()
                .equals(other._gameLobbies, _gameLobbies) &&
            (identical(other.currentGame, currentGame) ||
                other.currentGame == currentGame) &&
            const DeepCollectionEquality()
                .equals(other._onboardingFlow, _onboardingFlow) &&
            (identical(other.isInitialized, isInitialized) ||
                other.isInitialized == isInitialized) &&
            const DeepCollectionEquality()
                .equals(other._twitchClips, _twitchClips) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_availableGames),
      const DeepCollectionEquality().hash(_gameHistory),
      const DeepCollectionEquality().hash(_gameLobbies),
      currentGame,
      const DeepCollectionEquality().hash(_onboardingFlow),
      isInitialized,
      const DeepCollectionEquality().hash(_twitchClips),
      errorMessage);

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GameStateImplCopyWith<_$GameStateImpl> get copyWith =>
      __$$GameStateImplCopyWithImpl<_$GameStateImpl>(this, _$identity);
}

abstract class _GameState implements GameState {
  const factory _GameState(
      {required final List<Game> availableGames,
      required final List<Game> gameHistory,
      required final Map<String, List<Map<String, dynamic>>> gameLobbies,
      required final Game? currentGame,
      required final Map<String, dynamic>? onboardingFlow,
      required final bool isInitialized,
      required final List<Map<String, dynamic>> twitchClips,
      final String? errorMessage}) = _$GameStateImpl;

  @override
  List<Game> get availableGames;
  @override
  List<Game> get gameHistory;
  @override
  Map<String, List<Map<String, dynamic>>> get gameLobbies;
  @override
  Game? get currentGame;
  @override
  Map<String, dynamic>? get onboardingFlow;
  @override
  bool get isInitialized;
  @override
  List<Map<String, dynamic>> get twitchClips;
  @override
  String? get errorMessage;

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GameStateImplCopyWith<_$GameStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
