// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Game _$GameFromJson(Map<String, dynamic> json) {
  return _Game.fromJson(json);
}

/// @nodoc
mixin _$Game {
  String get name => throw _privateConstructorUsedError;
  String get slug => throw _privateConstructorUsedError;
  int? get igdbId => throw _privateConstructorUsedError;
  String? get coverUrl => throw _privateConstructorUsedError;
  String? get summary => throw _privateConstructorUsedError;
  DateTime? get firstReleaseDate => throw _privateConstructorUsedError;
  List<String> get genres => throw _privateConstructorUsedError;
  List<String> get platforms => throw _privateConstructorUsedError;
  int? get maxSpots => throw _privateConstructorUsedError;
  bool get isCached => throw _privateConstructorUsedError;
  DateTime? get cachedAt => throw _privateConstructorUsedError;

  /// Serializes this Game to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GameCopyWith<Game> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GameCopyWith<$Res> {
  factory $GameCopyWith(Game value, $Res Function(Game) then) =
      _$GameCopyWithImpl<$Res, Game>;
  @useResult
  $Res call(
      {String name,
      String slug,
      int? igdbId,
      String? coverUrl,
      String? summary,
      DateTime? firstReleaseDate,
      List<String> genres,
      List<String> platforms,
      int? maxSpots,
      bool isCached,
      DateTime? cachedAt});
}

/// @nodoc
class _$GameCopyWithImpl<$Res, $Val extends Game>
    implements $GameCopyWith<$Res> {
  _$GameCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? slug = null,
    Object? igdbId = freezed,
    Object? coverUrl = freezed,
    Object? summary = freezed,
    Object? firstReleaseDate = freezed,
    Object? genres = null,
    Object? platforms = null,
    Object? maxSpots = freezed,
    Object? isCached = null,
    Object? cachedAt = freezed,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      slug: null == slug
          ? _value.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String,
      igdbId: freezed == igdbId
          ? _value.igdbId
          : igdbId // ignore: cast_nullable_to_non_nullable
              as int?,
      coverUrl: freezed == coverUrl
          ? _value.coverUrl
          : coverUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      summary: freezed == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String?,
      firstReleaseDate: freezed == firstReleaseDate
          ? _value.firstReleaseDate
          : firstReleaseDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      genres: null == genres
          ? _value.genres
          : genres // ignore: cast_nullable_to_non_nullable
              as List<String>,
      platforms: null == platforms
          ? _value.platforms
          : platforms // ignore: cast_nullable_to_non_nullable
              as List<String>,
      maxSpots: freezed == maxSpots
          ? _value.maxSpots
          : maxSpots // ignore: cast_nullable_to_non_nullable
              as int?,
      isCached: null == isCached
          ? _value.isCached
          : isCached // ignore: cast_nullable_to_non_nullable
              as bool,
      cachedAt: freezed == cachedAt
          ? _value.cachedAt
          : cachedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GameImplCopyWith<$Res> implements $GameCopyWith<$Res> {
  factory _$$GameImplCopyWith(
          _$GameImpl value, $Res Function(_$GameImpl) then) =
      __$$GameImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name,
      String slug,
      int? igdbId,
      String? coverUrl,
      String? summary,
      DateTime? firstReleaseDate,
      List<String> genres,
      List<String> platforms,
      int? maxSpots,
      bool isCached,
      DateTime? cachedAt});
}

/// @nodoc
class __$$GameImplCopyWithImpl<$Res>
    extends _$GameCopyWithImpl<$Res, _$GameImpl>
    implements _$$GameImplCopyWith<$Res> {
  __$$GameImplCopyWithImpl(_$GameImpl _value, $Res Function(_$GameImpl) _then)
      : super(_value, _then);

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? slug = null,
    Object? igdbId = freezed,
    Object? coverUrl = freezed,
    Object? summary = freezed,
    Object? firstReleaseDate = freezed,
    Object? genres = null,
    Object? platforms = null,
    Object? maxSpots = freezed,
    Object? isCached = null,
    Object? cachedAt = freezed,
  }) {
    return _then(_$GameImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      slug: null == slug
          ? _value.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String,
      igdbId: freezed == igdbId
          ? _value.igdbId
          : igdbId // ignore: cast_nullable_to_non_nullable
              as int?,
      coverUrl: freezed == coverUrl
          ? _value.coverUrl
          : coverUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      summary: freezed == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String?,
      firstReleaseDate: freezed == firstReleaseDate
          ? _value.firstReleaseDate
          : firstReleaseDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      genres: null == genres
          ? _value._genres
          : genres // ignore: cast_nullable_to_non_nullable
              as List<String>,
      platforms: null == platforms
          ? _value._platforms
          : platforms // ignore: cast_nullable_to_non_nullable
              as List<String>,
      maxSpots: freezed == maxSpots
          ? _value.maxSpots
          : maxSpots // ignore: cast_nullable_to_non_nullable
              as int?,
      isCached: null == isCached
          ? _value.isCached
          : isCached // ignore: cast_nullable_to_non_nullable
              as bool,
      cachedAt: freezed == cachedAt
          ? _value.cachedAt
          : cachedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GameImpl implements _Game {
  const _$GameImpl(
      {required this.name,
      required this.slug,
      required this.igdbId,
      required this.coverUrl,
      required this.summary,
      required this.firstReleaseDate,
      required final List<String> genres,
      required final List<String> platforms,
      required this.maxSpots,
      required this.isCached,
      required this.cachedAt})
      : _genres = genres,
        _platforms = platforms;

  factory _$GameImpl.fromJson(Map<String, dynamic> json) =>
      _$$GameImplFromJson(json);

  @override
  final String name;
  @override
  final String slug;
  @override
  final int? igdbId;
  @override
  final String? coverUrl;
  @override
  final String? summary;
  @override
  final DateTime? firstReleaseDate;
  final List<String> _genres;
  @override
  List<String> get genres {
    if (_genres is EqualUnmodifiableListView) return _genres;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_genres);
  }

  final List<String> _platforms;
  @override
  List<String> get platforms {
    if (_platforms is EqualUnmodifiableListView) return _platforms;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_platforms);
  }

  @override
  final int? maxSpots;
  @override
  final bool isCached;
  @override
  final DateTime? cachedAt;

  @override
  String toString() {
    return 'Game(name: $name, slug: $slug, igdbId: $igdbId, coverUrl: $coverUrl, summary: $summary, firstReleaseDate: $firstReleaseDate, genres: $genres, platforms: $platforms, maxSpots: $maxSpots, isCached: $isCached, cachedAt: $cachedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GameImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.igdbId, igdbId) || other.igdbId == igdbId) &&
            (identical(other.coverUrl, coverUrl) ||
                other.coverUrl == coverUrl) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.firstReleaseDate, firstReleaseDate) ||
                other.firstReleaseDate == firstReleaseDate) &&
            const DeepCollectionEquality().equals(other._genres, _genres) &&
            const DeepCollectionEquality()
                .equals(other._platforms, _platforms) &&
            (identical(other.maxSpots, maxSpots) ||
                other.maxSpots == maxSpots) &&
            (identical(other.isCached, isCached) ||
                other.isCached == isCached) &&
            (identical(other.cachedAt, cachedAt) ||
                other.cachedAt == cachedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      name,
      slug,
      igdbId,
      coverUrl,
      summary,
      firstReleaseDate,
      const DeepCollectionEquality().hash(_genres),
      const DeepCollectionEquality().hash(_platforms),
      maxSpots,
      isCached,
      cachedAt);

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GameImplCopyWith<_$GameImpl> get copyWith =>
      __$$GameImplCopyWithImpl<_$GameImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GameImplToJson(
      this,
    );
  }
}

abstract class _Game implements Game {
  const factory _Game(
      {required final String name,
      required final String slug,
      required final int? igdbId,
      required final String? coverUrl,
      required final String? summary,
      required final DateTime? firstReleaseDate,
      required final List<String> genres,
      required final List<String> platforms,
      required final int? maxSpots,
      required final bool isCached,
      required final DateTime? cachedAt}) = _$GameImpl;

  factory _Game.fromJson(Map<String, dynamic> json) = _$GameImpl.fromJson;

  @override
  String get name;
  @override
  String get slug;
  @override
  int? get igdbId;
  @override
  String? get coverUrl;
  @override
  String? get summary;
  @override
  DateTime? get firstReleaseDate;
  @override
  List<String> get genres;
  @override
  List<String> get platforms;
  @override
  int? get maxSpots;
  @override
  bool get isCached;
  @override
  DateTime? get cachedAt;

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GameImplCopyWith<_$GameImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
