// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'squad_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$squadSpotsHash() => r'112b4750e053bd1a8f22cb5cc365c92722f77d85';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Squad-specific providers for optimized state access
/// These providers use .select() for tree-shaking and performance
/// Provider for squad spots by game name
/// Tree-shakes: Only rebuilds when gameSquadSpots[gameName] changes
///
/// Copied from [squadSpots].
@ProviderFor(squadSpots)
const squadSpotsProvider = SquadSpotsFamily();

/// Squad-specific providers for optimized state access
/// These providers use .select() for tree-shaking and performance
/// Provider for squad spots by game name
/// Tree-shakes: Only rebuilds when gameSquadSpots[gameName] changes
///
/// Copied from [squadSpots].
class SquadSpotsFamily extends Family<List<String?>> {
  /// Squad-specific providers for optimized state access
  /// These providers use .select() for tree-shaking and performance
  /// Provider for squad spots by game name
  /// Tree-shakes: Only rebuilds when gameSquadSpots[gameName] changes
  ///
  /// Copied from [squadSpots].
  const SquadSpotsFamily();

  /// Squad-specific providers for optimized state access
  /// These providers use .select() for tree-shaking and performance
  /// Provider for squad spots by game name
  /// Tree-shakes: Only rebuilds when gameSquadSpots[gameName] changes
  ///
  /// Copied from [squadSpots].
  SquadSpotsProvider call(
    String gameName,
  ) {
    return SquadSpotsProvider(
      gameName,
    );
  }

  @override
  SquadSpotsProvider getProviderOverride(
    covariant SquadSpotsProvider provider,
  ) {
    return call(
      provider.gameName,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'squadSpotsProvider';
}

/// Squad-specific providers for optimized state access
/// These providers use .select() for tree-shaking and performance
/// Provider for squad spots by game name
/// Tree-shakes: Only rebuilds when gameSquadSpots[gameName] changes
///
/// Copied from [squadSpots].
class SquadSpotsProvider extends AutoDisposeProvider<List<String?>> {
  /// Squad-specific providers for optimized state access
  /// These providers use .select() for tree-shaking and performance
  /// Provider for squad spots by game name
  /// Tree-shakes: Only rebuilds when gameSquadSpots[gameName] changes
  ///
  /// Copied from [squadSpots].
  SquadSpotsProvider(
    String gameName,
  ) : this._internal(
          (ref) => squadSpots(
            ref as SquadSpotsRef,
            gameName,
          ),
          from: squadSpotsProvider,
          name: r'squadSpotsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$squadSpotsHash,
          dependencies: SquadSpotsFamily._dependencies,
          allTransitiveDependencies:
              SquadSpotsFamily._allTransitiveDependencies,
          gameName: gameName,
        );

  SquadSpotsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.gameName,
  }) : super.internal();

  final String gameName;

  @override
  Override overrideWith(
    List<String?> Function(SquadSpotsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SquadSpotsProvider._internal(
        (ref) => create(ref as SquadSpotsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        gameName: gameName,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<List<String?>> createElement() {
    return _SquadSpotsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SquadSpotsProvider && other.gameName == gameName;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, gameName.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SquadSpotsRef on AutoDisposeProviderRef<List<String?>> {
  /// The parameter `gameName` of this provider.
  String get gameName;
}

class _SquadSpotsProviderElement
    extends AutoDisposeProviderElement<List<String?>> with SquadSpotsRef {
  _SquadSpotsProviderElement(super.provider);

  @override
  String get gameName => (origin as SquadSpotsProvider).gameName;
}

String _$spotTimersHash() => r'e073567f202f9fe4750f07dedbdfd2be15f8ca5b';

/// Provider for spot timers by game name
/// Tree-shakes: Only rebuilds when gameSpotTimers[gameName] changes
///
/// Copied from [spotTimers].
@ProviderFor(spotTimers)
const spotTimersProvider = SpotTimersFamily();

/// Provider for spot timers by game name
/// Tree-shakes: Only rebuilds when gameSpotTimers[gameName] changes
///
/// Copied from [spotTimers].
class SpotTimersFamily extends Family<List<Map<String, dynamic>?>> {
  /// Provider for spot timers by game name
  /// Tree-shakes: Only rebuilds when gameSpotTimers[gameName] changes
  ///
  /// Copied from [spotTimers].
  const SpotTimersFamily();

  /// Provider for spot timers by game name
  /// Tree-shakes: Only rebuilds when gameSpotTimers[gameName] changes
  ///
  /// Copied from [spotTimers].
  SpotTimersProvider call(
    String gameName,
  ) {
    return SpotTimersProvider(
      gameName,
    );
  }

  @override
  SpotTimersProvider getProviderOverride(
    covariant SpotTimersProvider provider,
  ) {
    return call(
      provider.gameName,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'spotTimersProvider';
}

/// Provider for spot timers by game name
/// Tree-shakes: Only rebuilds when gameSpotTimers[gameName] changes
///
/// Copied from [spotTimers].
class SpotTimersProvider
    extends AutoDisposeProvider<List<Map<String, dynamic>?>> {
  /// Provider for spot timers by game name
  /// Tree-shakes: Only rebuilds when gameSpotTimers[gameName] changes
  ///
  /// Copied from [spotTimers].
  SpotTimersProvider(
    String gameName,
  ) : this._internal(
          (ref) => spotTimers(
            ref as SpotTimersRef,
            gameName,
          ),
          from: spotTimersProvider,
          name: r'spotTimersProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$spotTimersHash,
          dependencies: SpotTimersFamily._dependencies,
          allTransitiveDependencies:
              SpotTimersFamily._allTransitiveDependencies,
          gameName: gameName,
        );

  SpotTimersProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.gameName,
  }) : super.internal();

  final String gameName;

  @override
  Override overrideWith(
    List<Map<String, dynamic>?> Function(SpotTimersRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SpotTimersProvider._internal(
        (ref) => create(ref as SpotTimersRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        gameName: gameName,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<List<Map<String, dynamic>?>> createElement() {
    return _SpotTimersProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SpotTimersProvider && other.gameName == gameName;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, gameName.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SpotTimersRef on AutoDisposeProviderRef<List<Map<String, dynamic>?>> {
  /// The parameter `gameName` of this provider.
  String get gameName;
}

class _SpotTimersProviderElement
    extends AutoDisposeProviderElement<List<Map<String, dynamic>?>>
    with SpotTimersRef {
  _SpotTimersProviderElement(super.provider);

  @override
  String get gameName => (origin as SpotTimersProvider).gameName;
}

String _$gameStatusesHash() => r'546b54c43c4030a8a48d03d7714c7761125b08e6';

/// Provider for game statuses by game name
/// Tree-shakes: Only rebuilds when gameStatuses[gameName] changes
///
/// Copied from [gameStatuses].
@ProviderFor(gameStatuses)
const gameStatusesProvider = GameStatusesFamily();

/// Provider for game statuses by game name
/// Tree-shakes: Only rebuilds when gameStatuses[gameName] changes
///
/// Copied from [gameStatuses].
class GameStatusesFamily extends Family<Map<String, String>> {
  /// Provider for game statuses by game name
  /// Tree-shakes: Only rebuilds when gameStatuses[gameName] changes
  ///
  /// Copied from [gameStatuses].
  const GameStatusesFamily();

  /// Provider for game statuses by game name
  /// Tree-shakes: Only rebuilds when gameStatuses[gameName] changes
  ///
  /// Copied from [gameStatuses].
  GameStatusesProvider call(
    String gameName,
  ) {
    return GameStatusesProvider(
      gameName,
    );
  }

  @override
  GameStatusesProvider getProviderOverride(
    covariant GameStatusesProvider provider,
  ) {
    return call(
      provider.gameName,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'gameStatusesProvider';
}

/// Provider for game statuses by game name
/// Tree-shakes: Only rebuilds when gameStatuses[gameName] changes
///
/// Copied from [gameStatuses].
class GameStatusesProvider extends AutoDisposeProvider<Map<String, String>> {
  /// Provider for game statuses by game name
  /// Tree-shakes: Only rebuilds when gameStatuses[gameName] changes
  ///
  /// Copied from [gameStatuses].
  GameStatusesProvider(
    String gameName,
  ) : this._internal(
          (ref) => gameStatuses(
            ref as GameStatusesRef,
            gameName,
          ),
          from: gameStatusesProvider,
          name: r'gameStatusesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$gameStatusesHash,
          dependencies: GameStatusesFamily._dependencies,
          allTransitiveDependencies:
              GameStatusesFamily._allTransitiveDependencies,
          gameName: gameName,
        );

  GameStatusesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.gameName,
  }) : super.internal();

  final String gameName;

  @override
  Override overrideWith(
    Map<String, String> Function(GameStatusesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GameStatusesProvider._internal(
        (ref) => create(ref as GameStatusesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        gameName: gameName,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<Map<String, String>> createElement() {
    return _GameStatusesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GameStatusesProvider && other.gameName == gameName;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, gameName.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GameStatusesRef on AutoDisposeProviderRef<Map<String, String>> {
  /// The parameter `gameName` of this provider.
  String get gameName;
}

class _GameStatusesProviderElement
    extends AutoDisposeProviderElement<Map<String, String>>
    with GameStatusesRef {
  _GameStatusesProviderElement(super.provider);

  @override
  String get gameName => (origin as GameStatusesProvider).gameName;
}

String _$globalStatusesHash() => r'0b22967810419469231fd365bf25caf00aab8427';

/// Provider for global statuses
/// Tree-shakes: Only rebuilds when globalStatuses changes
///
/// Copied from [globalStatuses].
@ProviderFor(globalStatuses)
final globalStatusesProvider =
    AutoDisposeProvider<Map<String, String>>.internal(
  globalStatuses,
  name: r'globalStatusesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$globalStatusesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GlobalStatusesRef = AutoDisposeProviderRef<Map<String, String>>;
String _$currentGameHash() => r'7dae6fb9a6d547f646890cfb0e2a6796d6c28cf8';

/// Provider for current game
/// Tree-shakes: Only rebuilds when currentGame changes
///
/// Copied from [currentGame].
@ProviderFor(currentGame)
final currentGameProvider = AutoDisposeProvider<Map<String, dynamic>?>.internal(
  currentGame,
  name: r'currentGameProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$currentGameHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentGameRef = AutoDisposeProviderRef<Map<String, dynamic>?>;
String _$selectedSquadIdHash() => r'8b3cc9f9e7cb9a5c2cdefceb757f23d123614a32';

/// Provider for selected squad ID
/// Tree-shakes: Only rebuilds when selectedSquadId changes
///
/// Copied from [selectedSquadId].
@ProviderFor(selectedSquadId)
final selectedSquadIdProvider = AutoDisposeProvider<String?>.internal(
  selectedSquadId,
  name: r'selectedSquadIdProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$selectedSquadIdHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SelectedSquadIdRef = AutoDisposeProviderRef<String?>;
String _$displayNameHash() => r'19aee848d92332684bb3e51fd5b79f6a5468828f';

/// Provider for display name
/// Tree-shakes: Only rebuilds when displayName changes
///
/// Copied from [displayName].
@ProviderFor(displayName)
final displayNameProvider = AutoDisposeProvider<String?>.internal(
  displayName,
  name: r'displayNameProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$displayNameHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DisplayNameRef = AutoDisposeProviderRef<String?>;
String _$profileImageHash() => r'9b24b4776564438678a5b00b8cbb69f95bde712d';

/// Provider for profile image
/// Tree-shakes: Only rebuilds when profileImage changes
///
/// Copied from [profileImage].
@ProviderFor(profileImage)
final profileImageProvider = AutoDisposeProvider<String?>.internal(
  profileImage,
  name: r'profileImageProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$profileImageHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProfileImageRef = AutoDisposeProviderRef<String?>;
String _$tiltEnabledHash() => r'84d68c6ff8b03187481aa146afddcac7bb7db313';

/// Provider for tilt enabled status
/// Tree-shakes: Only rebuilds when tiltEnabled changes
///
/// Copied from [tiltEnabled].
@ProviderFor(tiltEnabled)
final tiltEnabledProvider = AutoDisposeProvider<bool>.internal(
  tiltEnabled,
  name: r'tiltEnabledProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$tiltEnabledHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TiltEnabledRef = AutoDisposeProviderRef<bool>;
String _$isInitializedHash() => r'a949e0cd3e48f0ae505f8f3b2e09840bc1512bcd';

/// Provider for initialization status
/// Tree-shakes: Only rebuilds when isInitialized changes
///
/// Copied from [isInitialized].
@ProviderFor(isInitialized)
final isInitializedProvider = AutoDisposeProvider<bool>.internal(
  isInitialized,
  name: r'isInitializedProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$isInitializedHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsInitializedRef = AutoDisposeProviderRef<bool>;
String _$hasUnreadMessagesHash() => r'179d06b48a6d718975052acd79898309eef4b24f';

/// Provider for unread messages status
/// Tree-shakes: Only rebuilds when hasUnreadMessages changes
///
/// Copied from [hasUnreadMessages].
@ProviderFor(hasUnreadMessages)
final hasUnreadMessagesProvider = AutoDisposeProvider<bool>.internal(
  hasUnreadMessages,
  name: r'hasUnreadMessagesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$hasUnreadMessagesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HasUnreadMessagesRef = AutoDisposeProviderRef<bool>;
String _$hasNewSquadSpotHash() => r'2ab523a1260605bca66aad0c52507a0aad86e23e';

/// Provider for new squad spot status
/// Tree-shakes: Only rebuilds when hasNewSquadSpot changes
///
/// Copied from [hasNewSquadSpot].
@ProviderFor(hasNewSquadSpot)
final hasNewSquadSpotProvider = AutoDisposeProvider<bool>.internal(
  hasNewSquadSpot,
  name: r'hasNewSquadSpotProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$hasNewSquadSpotHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HasNewSquadSpotRef = AutoDisposeProviderRef<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
