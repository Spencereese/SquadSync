// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AppUser _$AppUserFromJson(Map<String, dynamic> json) {
  return _AppUser.fromJson(json);
}

/// @nodoc
mixin _$AppUser {
  String get uid => throw _privateConstructorUsedError;
  String? get displayName => throw _privateConstructorUsedError;
  String? get profileImage => throw _privateConstructorUsedError;
  Map<String, String?> get preferredModes => throw _privateConstructorUsedError;
  Map<String, Map<String, bool>> get userBlocks =>
      throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get pinnedGames =>
      throw _privateConstructorUsedError;
  Map<String, bool> get notificationSettings =>
      throw _privateConstructorUsedError;
  Map<String, bool> get hasRatedGame => throw _privateConstructorUsedError;
  Map<String, Map<String, int>> get dailyRatings =>
      throw _privateConstructorUsedError;
  Map<String, Map<String, int>> get allTimeRatings =>
      throw _privateConstructorUsedError;
  Map<String, int> get currentStreaks => throw _privateConstructorUsedError;
  Map<String, Map<String, int>> get complaints =>
      throw _privateConstructorUsedError;
  Map<String, List<Map<String, dynamic>>> get bans =>
      throw _privateConstructorUsedError;
  Map<String, Map<String, bool>> get dailyBanVotes =>
      throw _privateConstructorUsedError;
  List<String> get blockedUsers => throw _privateConstructorUsedError;
  List<String> get friends => throw _privateConstructorUsedError;
  List<String> get alerts => throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get userGroups =>
      throw _privateConstructorUsedError;
  List<String> get alertCircles => throw _privateConstructorUsedError;
  List<Map<String, dynamic>> get publicGroups =>
      throw _privateConstructorUsedError;
  List<String> get pinnedMessages => throw _privateConstructorUsedError;

  /// Serializes this AppUser to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppUserCopyWith<AppUser> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppUserCopyWith<$Res> {
  factory $AppUserCopyWith(AppUser value, $Res Function(AppUser) then) =
      _$AppUserCopyWithImpl<$Res, AppUser>;
  @useResult
  $Res call(
      {String uid,
      String? displayName,
      String? profileImage,
      Map<String, String?> preferredModes,
      Map<String, Map<String, bool>> userBlocks,
      List<Map<String, dynamic>> pinnedGames,
      Map<String, bool> notificationSettings,
      Map<String, bool> hasRatedGame,
      Map<String, Map<String, int>> dailyRatings,
      Map<String, Map<String, int>> allTimeRatings,
      Map<String, int> currentStreaks,
      Map<String, Map<String, int>> complaints,
      Map<String, List<Map<String, dynamic>>> bans,
      Map<String, Map<String, bool>> dailyBanVotes,
      List<String> blockedUsers,
      List<String> friends,
      List<String> alerts,
      List<Map<String, dynamic>> userGroups,
      List<String> alertCircles,
      List<Map<String, dynamic>> publicGroups,
      List<String> pinnedMessages});
}

/// @nodoc
class _$AppUserCopyWithImpl<$Res, $Val extends AppUser>
    implements $AppUserCopyWith<$Res> {
  _$AppUserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? displayName = freezed,
    Object? profileImage = freezed,
    Object? preferredModes = null,
    Object? userBlocks = null,
    Object? pinnedGames = null,
    Object? notificationSettings = null,
    Object? hasRatedGame = null,
    Object? dailyRatings = null,
    Object? allTimeRatings = null,
    Object? currentStreaks = null,
    Object? complaints = null,
    Object? bans = null,
    Object? dailyBanVotes = null,
    Object? blockedUsers = null,
    Object? friends = null,
    Object? alerts = null,
    Object? userGroups = null,
    Object? alertCircles = null,
    Object? publicGroups = null,
    Object? pinnedMessages = null,
  }) {
    return _then(_value.copyWith(
      uid: null == uid
          ? _value.uid
          : uid // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: freezed == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      profileImage: freezed == profileImage
          ? _value.profileImage
          : profileImage // ignore: cast_nullable_to_non_nullable
              as String?,
      preferredModes: null == preferredModes
          ? _value.preferredModes
          : preferredModes // ignore: cast_nullable_to_non_nullable
              as Map<String, String?>,
      userBlocks: null == userBlocks
          ? _value.userBlocks
          : userBlocks // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, bool>>,
      pinnedGames: null == pinnedGames
          ? _value.pinnedGames
          : pinnedGames // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      notificationSettings: null == notificationSettings
          ? _value.notificationSettings
          : notificationSettings // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      hasRatedGame: null == hasRatedGame
          ? _value.hasRatedGame
          : hasRatedGame // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      dailyRatings: null == dailyRatings
          ? _value.dailyRatings
          : dailyRatings // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, int>>,
      allTimeRatings: null == allTimeRatings
          ? _value.allTimeRatings
          : allTimeRatings // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, int>>,
      currentStreaks: null == currentStreaks
          ? _value.currentStreaks
          : currentStreaks // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      complaints: null == complaints
          ? _value.complaints
          : complaints // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, int>>,
      bans: null == bans
          ? _value.bans
          : bans // ignore: cast_nullable_to_non_nullable
              as Map<String, List<Map<String, dynamic>>>,
      dailyBanVotes: null == dailyBanVotes
          ? _value.dailyBanVotes
          : dailyBanVotes // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, bool>>,
      blockedUsers: null == blockedUsers
          ? _value.blockedUsers
          : blockedUsers // ignore: cast_nullable_to_non_nullable
              as List<String>,
      friends: null == friends
          ? _value.friends
          : friends // ignore: cast_nullable_to_non_nullable
              as List<String>,
      alerts: null == alerts
          ? _value.alerts
          : alerts // ignore: cast_nullable_to_non_nullable
              as List<String>,
      userGroups: null == userGroups
          ? _value.userGroups
          : userGroups // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      alertCircles: null == alertCircles
          ? _value.alertCircles
          : alertCircles // ignore: cast_nullable_to_non_nullable
              as List<String>,
      publicGroups: null == publicGroups
          ? _value.publicGroups
          : publicGroups // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      pinnedMessages: null == pinnedMessages
          ? _value.pinnedMessages
          : pinnedMessages // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AppUserImplCopyWith<$Res> implements $AppUserCopyWith<$Res> {
  factory _$$AppUserImplCopyWith(
          _$AppUserImpl value, $Res Function(_$AppUserImpl) then) =
      __$$AppUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String uid,
      String? displayName,
      String? profileImage,
      Map<String, String?> preferredModes,
      Map<String, Map<String, bool>> userBlocks,
      List<Map<String, dynamic>> pinnedGames,
      Map<String, bool> notificationSettings,
      Map<String, bool> hasRatedGame,
      Map<String, Map<String, int>> dailyRatings,
      Map<String, Map<String, int>> allTimeRatings,
      Map<String, int> currentStreaks,
      Map<String, Map<String, int>> complaints,
      Map<String, List<Map<String, dynamic>>> bans,
      Map<String, Map<String, bool>> dailyBanVotes,
      List<String> blockedUsers,
      List<String> friends,
      List<String> alerts,
      List<Map<String, dynamic>> userGroups,
      List<String> alertCircles,
      List<Map<String, dynamic>> publicGroups,
      List<String> pinnedMessages});
}

/// @nodoc
class __$$AppUserImplCopyWithImpl<$Res>
    extends _$AppUserCopyWithImpl<$Res, _$AppUserImpl>
    implements _$$AppUserImplCopyWith<$Res> {
  __$$AppUserImplCopyWithImpl(
      _$AppUserImpl _value, $Res Function(_$AppUserImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? displayName = freezed,
    Object? profileImage = freezed,
    Object? preferredModes = null,
    Object? userBlocks = null,
    Object? pinnedGames = null,
    Object? notificationSettings = null,
    Object? hasRatedGame = null,
    Object? dailyRatings = null,
    Object? allTimeRatings = null,
    Object? currentStreaks = null,
    Object? complaints = null,
    Object? bans = null,
    Object? dailyBanVotes = null,
    Object? blockedUsers = null,
    Object? friends = null,
    Object? alerts = null,
    Object? userGroups = null,
    Object? alertCircles = null,
    Object? publicGroups = null,
    Object? pinnedMessages = null,
  }) {
    return _then(_$AppUserImpl(
      uid: null == uid
          ? _value.uid
          : uid // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: freezed == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String?,
      profileImage: freezed == profileImage
          ? _value.profileImage
          : profileImage // ignore: cast_nullable_to_non_nullable
              as String?,
      preferredModes: null == preferredModes
          ? _value._preferredModes
          : preferredModes // ignore: cast_nullable_to_non_nullable
              as Map<String, String?>,
      userBlocks: null == userBlocks
          ? _value._userBlocks
          : userBlocks // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, bool>>,
      pinnedGames: null == pinnedGames
          ? _value._pinnedGames
          : pinnedGames // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      notificationSettings: null == notificationSettings
          ? _value._notificationSettings
          : notificationSettings // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      hasRatedGame: null == hasRatedGame
          ? _value._hasRatedGame
          : hasRatedGame // ignore: cast_nullable_to_non_nullable
              as Map<String, bool>,
      dailyRatings: null == dailyRatings
          ? _value._dailyRatings
          : dailyRatings // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, int>>,
      allTimeRatings: null == allTimeRatings
          ? _value._allTimeRatings
          : allTimeRatings // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, int>>,
      currentStreaks: null == currentStreaks
          ? _value._currentStreaks
          : currentStreaks // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      complaints: null == complaints
          ? _value._complaints
          : complaints // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, int>>,
      bans: null == bans
          ? _value._bans
          : bans // ignore: cast_nullable_to_non_nullable
              as Map<String, List<Map<String, dynamic>>>,
      dailyBanVotes: null == dailyBanVotes
          ? _value._dailyBanVotes
          : dailyBanVotes // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, bool>>,
      blockedUsers: null == blockedUsers
          ? _value._blockedUsers
          : blockedUsers // ignore: cast_nullable_to_non_nullable
              as List<String>,
      friends: null == friends
          ? _value._friends
          : friends // ignore: cast_nullable_to_non_nullable
              as List<String>,
      alerts: null == alerts
          ? _value._alerts
          : alerts // ignore: cast_nullable_to_non_nullable
              as List<String>,
      userGroups: null == userGroups
          ? _value._userGroups
          : userGroups // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      alertCircles: null == alertCircles
          ? _value._alertCircles
          : alertCircles // ignore: cast_nullable_to_non_nullable
              as List<String>,
      publicGroups: null == publicGroups
          ? _value._publicGroups
          : publicGroups // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>,
      pinnedMessages: null == pinnedMessages
          ? _value._pinnedMessages
          : pinnedMessages // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AppUserImpl implements _AppUser {
  const _$AppUserImpl(
      {required this.uid,
      required this.displayName,
      required this.profileImage,
      required final Map<String, String?> preferredModes,
      required final Map<String, Map<String, bool>> userBlocks,
      required final List<Map<String, dynamic>> pinnedGames,
      required final Map<String, bool> notificationSettings,
      required final Map<String, bool> hasRatedGame,
      required final Map<String, Map<String, int>> dailyRatings,
      required final Map<String, Map<String, int>> allTimeRatings,
      required final Map<String, int> currentStreaks,
      required final Map<String, Map<String, int>> complaints,
      required final Map<String, List<Map<String, dynamic>>> bans,
      required final Map<String, Map<String, bool>> dailyBanVotes,
      required final List<String> blockedUsers,
      required final List<String> friends,
      required final List<String> alerts,
      required final List<Map<String, dynamic>> userGroups,
      required final List<String> alertCircles,
      required final List<Map<String, dynamic>> publicGroups,
      required final List<String> pinnedMessages})
      : _preferredModes = preferredModes,
        _userBlocks = userBlocks,
        _pinnedGames = pinnedGames,
        _notificationSettings = notificationSettings,
        _hasRatedGame = hasRatedGame,
        _dailyRatings = dailyRatings,
        _allTimeRatings = allTimeRatings,
        _currentStreaks = currentStreaks,
        _complaints = complaints,
        _bans = bans,
        _dailyBanVotes = dailyBanVotes,
        _blockedUsers = blockedUsers,
        _friends = friends,
        _alerts = alerts,
        _userGroups = userGroups,
        _alertCircles = alertCircles,
        _publicGroups = publicGroups,
        _pinnedMessages = pinnedMessages;

  factory _$AppUserImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppUserImplFromJson(json);

  @override
  final String uid;
  @override
  final String? displayName;
  @override
  final String? profileImage;
  final Map<String, String?> _preferredModes;
  @override
  Map<String, String?> get preferredModes {
    if (_preferredModes is EqualUnmodifiableMapView) return _preferredModes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_preferredModes);
  }

  final Map<String, Map<String, bool>> _userBlocks;
  @override
  Map<String, Map<String, bool>> get userBlocks {
    if (_userBlocks is EqualUnmodifiableMapView) return _userBlocks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_userBlocks);
  }

  final List<Map<String, dynamic>> _pinnedGames;
  @override
  List<Map<String, dynamic>> get pinnedGames {
    if (_pinnedGames is EqualUnmodifiableListView) return _pinnedGames;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pinnedGames);
  }

  final Map<String, bool> _notificationSettings;
  @override
  Map<String, bool> get notificationSettings {
    if (_notificationSettings is EqualUnmodifiableMapView)
      return _notificationSettings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_notificationSettings);
  }

  final Map<String, bool> _hasRatedGame;
  @override
  Map<String, bool> get hasRatedGame {
    if (_hasRatedGame is EqualUnmodifiableMapView) return _hasRatedGame;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_hasRatedGame);
  }

  final Map<String, Map<String, int>> _dailyRatings;
  @override
  Map<String, Map<String, int>> get dailyRatings {
    if (_dailyRatings is EqualUnmodifiableMapView) return _dailyRatings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_dailyRatings);
  }

  final Map<String, Map<String, int>> _allTimeRatings;
  @override
  Map<String, Map<String, int>> get allTimeRatings {
    if (_allTimeRatings is EqualUnmodifiableMapView) return _allTimeRatings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_allTimeRatings);
  }

  final Map<String, int> _currentStreaks;
  @override
  Map<String, int> get currentStreaks {
    if (_currentStreaks is EqualUnmodifiableMapView) return _currentStreaks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_currentStreaks);
  }

  final Map<String, Map<String, int>> _complaints;
  @override
  Map<String, Map<String, int>> get complaints {
    if (_complaints is EqualUnmodifiableMapView) return _complaints;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_complaints);
  }

  final Map<String, List<Map<String, dynamic>>> _bans;
  @override
  Map<String, List<Map<String, dynamic>>> get bans {
    if (_bans is EqualUnmodifiableMapView) return _bans;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_bans);
  }

  final Map<String, Map<String, bool>> _dailyBanVotes;
  @override
  Map<String, Map<String, bool>> get dailyBanVotes {
    if (_dailyBanVotes is EqualUnmodifiableMapView) return _dailyBanVotes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_dailyBanVotes);
  }

  final List<String> _blockedUsers;
  @override
  List<String> get blockedUsers {
    if (_blockedUsers is EqualUnmodifiableListView) return _blockedUsers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_blockedUsers);
  }

  final List<String> _friends;
  @override
  List<String> get friends {
    if (_friends is EqualUnmodifiableListView) return _friends;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_friends);
  }

  final List<String> _alerts;
  @override
  List<String> get alerts {
    if (_alerts is EqualUnmodifiableListView) return _alerts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_alerts);
  }

  final List<Map<String, dynamic>> _userGroups;
  @override
  List<Map<String, dynamic>> get userGroups {
    if (_userGroups is EqualUnmodifiableListView) return _userGroups;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_userGroups);
  }

  final List<String> _alertCircles;
  @override
  List<String> get alertCircles {
    if (_alertCircles is EqualUnmodifiableListView) return _alertCircles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_alertCircles);
  }

  final List<Map<String, dynamic>> _publicGroups;
  @override
  List<Map<String, dynamic>> get publicGroups {
    if (_publicGroups is EqualUnmodifiableListView) return _publicGroups;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_publicGroups);
  }

  final List<String> _pinnedMessages;
  @override
  List<String> get pinnedMessages {
    if (_pinnedMessages is EqualUnmodifiableListView) return _pinnedMessages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pinnedMessages);
  }

  @override
  String toString() {
    return 'AppUser(uid: $uid, displayName: $displayName, profileImage: $profileImage, preferredModes: $preferredModes, userBlocks: $userBlocks, pinnedGames: $pinnedGames, notificationSettings: $notificationSettings, hasRatedGame: $hasRatedGame, dailyRatings: $dailyRatings, allTimeRatings: $allTimeRatings, currentStreaks: $currentStreaks, complaints: $complaints, bans: $bans, dailyBanVotes: $dailyBanVotes, blockedUsers: $blockedUsers, friends: $friends, alerts: $alerts, userGroups: $userGroups, alertCircles: $alertCircles, publicGroups: $publicGroups, pinnedMessages: $pinnedMessages)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppUserImpl &&
            (identical(other.uid, uid) || other.uid == uid) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.profileImage, profileImage) ||
                other.profileImage == profileImage) &&
            const DeepCollectionEquality()
                .equals(other._preferredModes, _preferredModes) &&
            const DeepCollectionEquality()
                .equals(other._userBlocks, _userBlocks) &&
            const DeepCollectionEquality()
                .equals(other._pinnedGames, _pinnedGames) &&
            const DeepCollectionEquality()
                .equals(other._notificationSettings, _notificationSettings) &&
            const DeepCollectionEquality()
                .equals(other._hasRatedGame, _hasRatedGame) &&
            const DeepCollectionEquality()
                .equals(other._dailyRatings, _dailyRatings) &&
            const DeepCollectionEquality()
                .equals(other._allTimeRatings, _allTimeRatings) &&
            const DeepCollectionEquality()
                .equals(other._currentStreaks, _currentStreaks) &&
            const DeepCollectionEquality()
                .equals(other._complaints, _complaints) &&
            const DeepCollectionEquality().equals(other._bans, _bans) &&
            const DeepCollectionEquality()
                .equals(other._dailyBanVotes, _dailyBanVotes) &&
            const DeepCollectionEquality()
                .equals(other._blockedUsers, _blockedUsers) &&
            const DeepCollectionEquality().equals(other._friends, _friends) &&
            const DeepCollectionEquality().equals(other._alerts, _alerts) &&
            const DeepCollectionEquality()
                .equals(other._userGroups, _userGroups) &&
            const DeepCollectionEquality()
                .equals(other._alertCircles, _alertCircles) &&
            const DeepCollectionEquality()
                .equals(other._publicGroups, _publicGroups) &&
            const DeepCollectionEquality()
                .equals(other._pinnedMessages, _pinnedMessages));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        uid,
        displayName,
        profileImage,
        const DeepCollectionEquality().hash(_preferredModes),
        const DeepCollectionEquality().hash(_userBlocks),
        const DeepCollectionEquality().hash(_pinnedGames),
        const DeepCollectionEquality().hash(_notificationSettings),
        const DeepCollectionEquality().hash(_hasRatedGame),
        const DeepCollectionEquality().hash(_dailyRatings),
        const DeepCollectionEquality().hash(_allTimeRatings),
        const DeepCollectionEquality().hash(_currentStreaks),
        const DeepCollectionEquality().hash(_complaints),
        const DeepCollectionEquality().hash(_bans),
        const DeepCollectionEquality().hash(_dailyBanVotes),
        const DeepCollectionEquality().hash(_blockedUsers),
        const DeepCollectionEquality().hash(_friends),
        const DeepCollectionEquality().hash(_alerts),
        const DeepCollectionEquality().hash(_userGroups),
        const DeepCollectionEquality().hash(_alertCircles),
        const DeepCollectionEquality().hash(_publicGroups),
        const DeepCollectionEquality().hash(_pinnedMessages)
      ]);

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppUserImplCopyWith<_$AppUserImpl> get copyWith =>
      __$$AppUserImplCopyWithImpl<_$AppUserImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AppUserImplToJson(
      this,
    );
  }
}

abstract class _AppUser implements AppUser {
  const factory _AppUser(
      {required final String uid,
      required final String? displayName,
      required final String? profileImage,
      required final Map<String, String?> preferredModes,
      required final Map<String, Map<String, bool>> userBlocks,
      required final List<Map<String, dynamic>> pinnedGames,
      required final Map<String, bool> notificationSettings,
      required final Map<String, bool> hasRatedGame,
      required final Map<String, Map<String, int>> dailyRatings,
      required final Map<String, Map<String, int>> allTimeRatings,
      required final Map<String, int> currentStreaks,
      required final Map<String, Map<String, int>> complaints,
      required final Map<String, List<Map<String, dynamic>>> bans,
      required final Map<String, Map<String, bool>> dailyBanVotes,
      required final List<String> blockedUsers,
      required final List<String> friends,
      required final List<String> alerts,
      required final List<Map<String, dynamic>> userGroups,
      required final List<String> alertCircles,
      required final List<Map<String, dynamic>> publicGroups,
      required final List<String> pinnedMessages}) = _$AppUserImpl;

  factory _AppUser.fromJson(Map<String, dynamic> json) = _$AppUserImpl.fromJson;

  @override
  String get uid;
  @override
  String? get displayName;
  @override
  String? get profileImage;
  @override
  Map<String, String?> get preferredModes;
  @override
  Map<String, Map<String, bool>> get userBlocks;
  @override
  List<Map<String, dynamic>> get pinnedGames;
  @override
  Map<String, bool> get notificationSettings;
  @override
  Map<String, bool> get hasRatedGame;
  @override
  Map<String, Map<String, int>> get dailyRatings;
  @override
  Map<String, Map<String, int>> get allTimeRatings;
  @override
  Map<String, int> get currentStreaks;
  @override
  Map<String, Map<String, int>> get complaints;
  @override
  Map<String, List<Map<String, dynamic>>> get bans;
  @override
  Map<String, Map<String, bool>> get dailyBanVotes;
  @override
  List<String> get blockedUsers;
  @override
  List<String> get friends;
  @override
  List<String> get alerts;
  @override
  List<Map<String, dynamic>> get userGroups;
  @override
  List<String> get alertCircles;
  @override
  List<Map<String, dynamic>> get publicGroups;
  @override
  List<String> get pinnedMessages;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppUserImplCopyWith<_$AppUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
