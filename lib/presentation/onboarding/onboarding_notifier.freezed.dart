// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'onboarding_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$OnboardingState {
  int get currentPage => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String? get callsign => throw _privateConstructorUsedError;
  String? get avatarPath => throw _privateConstructorUsedError;
  List<String> get selectedGames => throw _privateConstructorUsedError;
  Map<String, bool> get preferences => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OnboardingStateCopyWith<OnboardingState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OnboardingStateCopyWith<$Res> {
  factory $OnboardingStateCopyWith(
          OnboardingState value, $Res Function(OnboardingState) then) =
      _$OnboardingStateCopyWithImpl<$Res, OnboardingState>;
  @useResult
  $Res call(
      {int currentPage,
      bool isLoading,
      String? callsign,
      String? avatarPath,
      List<String> selectedGames,
      Map<String, bool> preferences,
      String? error});
}

/// @nodoc
class _$OnboardingStateCopyWithImpl<$Res, $Val extends OnboardingState>
    implements $OnboardingStateCopyWith<$Res> {
  _$OnboardingStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentPage = null,
    Object? isLoading = null,
    Object? callsign = freezed,
    Object? avatarPath = freezed,
    Object? selectedGames = null,
    Object? preferences = null,
    Object? error = freezed,
  }) {
    return _then(_value.copyWith(
      currentPage: null == currentPage
          ? _value.currentPage
          : currentPage // ignore: cast_nullable_to_non_nullable
              as int,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      callsign: freezed == callsign
          ? _value.callsign
          : callsign // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarPath: freezed == avatarPath
          ? _value.avatarPath
          : avatarPath // ignore: cast_nullable_to_non_nullable
              as String?,
      selectedGames: null == selectedGames
          ? _value.selectedGames
          : selectedGames // ignore: cast_nullable_to_non_nullable
              as List<String>,
      preferences: null == preferences
          ? _value.preferences
          : preferences // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$OnboardingStateImplCopyWith<$Res>
    implements $OnboardingStateCopyWith<$Res> {
  factory _$$OnboardingStateImplCopyWith(_$OnboardingStateImpl value,
          $Res Function(_$OnboardingStateImpl) then) =
      __$$OnboardingStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int currentPage,
      bool isLoading,
      String? callsign,
      String? avatarPath,
      List<String> selectedGames,
      Map<String, bool> preferences,
      String? error});
}

/// @nodoc
class __$$OnboardingStateImplCopyWithImpl<$Res>
    extends _$OnboardingStateCopyWithImpl<$Res, _$OnboardingStateImpl>
    implements _$$OnboardingStateImplCopyWith<$Res> {
  __$$OnboardingStateImplCopyWithImpl(
      _$OnboardingStateImpl _value, $Res Function(_$OnboardingStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentPage = null,
    Object? isLoading = null,
    Object? callsign = freezed,
    Object? avatarPath = freezed,
    Object? selectedGames = null,
    Object? preferences = null,
    Object? error = freezed,
  }) {
    return _then(_$OnboardingStateImpl(
      currentPage: null == currentPage
          ? _value.currentPage
          : currentPage // ignore: cast_nullable_to_non_nullable
              as int,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      callsign: freezed == callsign
          ? _value.callsign
          : callsign // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarPath: freezed == avatarPath
          ? _value.avatarPath
          : avatarPath // ignore: cast_nullable_to_non_nullable
              as String?,
      selectedGames: null == selectedGames
          ? _value._selectedGames
          : selectedGames // ignore: cast_nullable_to_non_nullable
              as List<String>,
      preferences: null == preferences
          ? _value._preferences
          : preferences // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$OnboardingStateImpl implements _OnboardingState {
  const _$OnboardingStateImpl(
      {this.currentPage = 0,
      this.isLoading = false,
      this.callsign,
      this.avatarPath,
      final List<String> selectedGames = const [],
      final Map<String, bool> preferences = const {},
      this.error})
      : _selectedGames = selectedGames,
        _preferences = preferences;

  @override
  @JsonKey()
  final int currentPage;
  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? callsign;
  @override
  final String? avatarPath;
  final List<String> _selectedGames;
  @override
  @JsonKey()
  List<String> get selectedGames {
    if (_selectedGames is EqualUnmodifiableListView) return _selectedGames;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_selectedGames);
  }

  final Map<String, bool> _preferences;
  @override
  @JsonKey()
  Map<String, bool> get preferences {
    if (_preferences is EqualUnmodifiableMapView) return _preferences;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_preferences);
  }

  @override
  final String? error;

  @override
  String toString() {
    return 'OnboardingState(currentPage: $currentPage, isLoading: $isLoading, callsign: $callsign, avatarPath: $avatarPath, selectedGames: $selectedGames, preferences: $preferences, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OnboardingStateImpl &&
            (identical(other.currentPage, currentPage) ||
                other.currentPage == currentPage) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.callsign, callsign) ||
                other.callsign == callsign) &&
            (identical(other.avatarPath, avatarPath) ||
                other.avatarPath == avatarPath) &&
            const DeepCollectionEquality()
                .equals(other._selectedGames, _selectedGames) &&
            const DeepCollectionEquality()
                .equals(other._preferences, _preferences) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      currentPage,
      isLoading,
      callsign,
      avatarPath,
      const DeepCollectionEquality().hash(_selectedGames),
      const DeepCollectionEquality().hash(_preferences),
      error);

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OnboardingStateImplCopyWith<_$OnboardingStateImpl> get copyWith =>
      __$$OnboardingStateImplCopyWithImpl<_$OnboardingStateImpl>(
          this, _$identity);
}

abstract class _OnboardingState implements OnboardingState {
  const factory _OnboardingState(
      {final int currentPage,
      final bool isLoading,
      final String? callsign,
      final String? avatarPath,
      final List<String> selectedGames,
      final Map<String, bool> preferences,
      final String? error}) = _$OnboardingStateImpl;

  @override
  int get currentPage;
  @override
  bool get isLoading;
  @override
  String? get callsign;
  @override
  String? get avatarPath;
  @override
  List<String> get selectedGames;
  @override
  Map<String, bool> get preferences;
  @override
  String? get error;

  /// Create a copy of OnboardingState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OnboardingStateImplCopyWith<_$OnboardingStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
