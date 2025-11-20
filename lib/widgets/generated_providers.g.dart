// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'generated_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userGreetingHash() => r'a9ef50e617eaef7b7506d77778504d7d27b0ea20';

/// Generated provider with dependencies
///
/// Copied from [userGreeting].
@ProviderFor(userGreeting)
final userGreetingProvider = AutoDisposeProvider<String>.internal(
  userGreeting,
  name: r'userGreetingProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$userGreetingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserGreetingRef = AutoDisposeProviderRef<String>;
String _$userPinnedGamesHash() => r'c6d82580f8c45d165496f567e0195f64b140fd66';

/// Generated provider for async operations
///
/// Copied from [userPinnedGames].
@ProviderFor(userPinnedGames)
final userPinnedGamesProvider =
    AutoDisposeFutureProvider<List<String>>.internal(
  userPinnedGames,
  name: r'userPinnedGamesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userPinnedGamesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserPinnedGamesRef = AutoDisposeFutureProviderRef<List<String>>;
String _$gameStatusHash() => r'36067bac20b3c675b4e02822257dd534e6425049';

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

/// Generated provider with family (parameterized)
///
/// Copied from [gameStatus].
@ProviderFor(gameStatus)
const gameStatusProvider = GameStatusFamily();

/// Generated provider with family (parameterized)
///
/// Copied from [gameStatus].
class GameStatusFamily extends Family<String> {
  /// Generated provider with family (parameterized)
  ///
  /// Copied from [gameStatus].
  const GameStatusFamily();

  /// Generated provider with family (parameterized)
  ///
  /// Copied from [gameStatus].
  GameStatusProvider call(
    String gameName,
  ) {
    return GameStatusProvider(
      gameName,
    );
  }

  @override
  GameStatusProvider getProviderOverride(
    covariant GameStatusProvider provider,
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
  String? get name => r'gameStatusProvider';
}

/// Generated provider with family (parameterized)
///
/// Copied from [gameStatus].
class GameStatusProvider extends AutoDisposeProvider<String> {
  /// Generated provider with family (parameterized)
  ///
  /// Copied from [gameStatus].
  GameStatusProvider(
    String gameName,
  ) : this._internal(
          (ref) => gameStatus(
            ref as GameStatusRef,
            gameName,
          ),
          from: gameStatusProvider,
          name: r'gameStatusProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$gameStatusHash,
          dependencies: GameStatusFamily._dependencies,
          allTransitiveDependencies:
              GameStatusFamily._allTransitiveDependencies,
          gameName: gameName,
        );

  GameStatusProvider._internal(
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
    String Function(GameStatusRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GameStatusProvider._internal(
        (ref) => create(ref as GameStatusRef),
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
  AutoDisposeProviderElement<String> createElement() {
    return _GameStatusProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GameStatusProvider && other.gameName == gameName;
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
mixin GameStatusRef on AutoDisposeProviderRef<String> {
  /// The parameter `gameName` of this provider.
  String get gameName;
}

class _GameStatusProviderElement extends AutoDisposeProviderElement<String>
    with GameStatusRef {
  _GameStatusProviderElement(super.provider);

  @override
  String get gameName => (origin as GameStatusProvider).gameName;
}

String _$userDisplayNameHash() => r'83750e67592fd088cd37c1b15754e85c7ba4422b';

/// Example of migrating existing providers to generated ones
/// This shows the pattern for converting manual providers to generated providers
///
/// Copied from [userDisplayName].
@ProviderFor(userDisplayName)
final userDisplayNameProvider = AutoDisposeProvider<String>.internal(
  userDisplayName,
  name: r'userDisplayNameProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userDisplayNameHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserDisplayNameRef = AutoDisposeProviderRef<String>;
String _$userStatsHash() => r'3b936c178880b047922c3c6838739ffcdee76660';

/// Example of a generated provider with complex logic
///
/// Copied from [userStats].
@ProviderFor(userStats)
final userStatsProvider = AutoDisposeProvider<Map<String, dynamic>>.internal(
  userStats,
  name: r'userStatsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$userStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserStatsRef = AutoDisposeProviderRef<Map<String, dynamic>>;
String _$squadSpotsForGameHash() => r'c085a25a447102fd6e16c16bf7ac1ef09ccc208e';

/// Squad-specific generated providers with tree-shaking benefits
/// Tree-shaking: Only rebuilds when specific state slices change
///
/// Copied from [squadSpotsForGame].
@ProviderFor(squadSpotsForGame)
const squadSpotsForGameProvider = SquadSpotsForGameFamily();

/// Squad-specific generated providers with tree-shaking benefits
/// Tree-shaking: Only rebuilds when specific state slices change
///
/// Copied from [squadSpotsForGame].
class SquadSpotsForGameFamily extends Family<List<String?>> {
  /// Squad-specific generated providers with tree-shaking benefits
  /// Tree-shaking: Only rebuilds when specific state slices change
  ///
  /// Copied from [squadSpotsForGame].
  const SquadSpotsForGameFamily();

  /// Squad-specific generated providers with tree-shaking benefits
  /// Tree-shaking: Only rebuilds when specific state slices change
  ///
  /// Copied from [squadSpotsForGame].
  SquadSpotsForGameProvider call(
    String gameName,
  ) {
    return SquadSpotsForGameProvider(
      gameName,
    );
  }

  @override
  SquadSpotsForGameProvider getProviderOverride(
    covariant SquadSpotsForGameProvider provider,
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
  String? get name => r'squadSpotsForGameProvider';
}

/// Squad-specific generated providers with tree-shaking benefits
/// Tree-shaking: Only rebuilds when specific state slices change
///
/// Copied from [squadSpotsForGame].
class SquadSpotsForGameProvider extends AutoDisposeProvider<List<String?>> {
  /// Squad-specific generated providers with tree-shaking benefits
  /// Tree-shaking: Only rebuilds when specific state slices change
  ///
  /// Copied from [squadSpotsForGame].
  SquadSpotsForGameProvider(
    String gameName,
  ) : this._internal(
          (ref) => squadSpotsForGame(
            ref as SquadSpotsForGameRef,
            gameName,
          ),
          from: squadSpotsForGameProvider,
          name: r'squadSpotsForGameProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$squadSpotsForGameHash,
          dependencies: SquadSpotsForGameFamily._dependencies,
          allTransitiveDependencies:
              SquadSpotsForGameFamily._allTransitiveDependencies,
          gameName: gameName,
        );

  SquadSpotsForGameProvider._internal(
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
    List<String?> Function(SquadSpotsForGameRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SquadSpotsForGameProvider._internal(
        (ref) => create(ref as SquadSpotsForGameRef),
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
    return _SquadSpotsForGameProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SquadSpotsForGameProvider && other.gameName == gameName;
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
mixin SquadSpotsForGameRef on AutoDisposeProviderRef<List<String?>> {
  /// The parameter `gameName` of this provider.
  String get gameName;
}

class _SquadSpotsForGameProviderElement
    extends AutoDisposeProviderElement<List<String?>>
    with SquadSpotsForGameRef {
  _SquadSpotsForGameProviderElement(super.provider);

  @override
  String get gameName => (origin as SquadSpotsForGameProvider).gameName;
}

String _$spotTimersForGameHash() => r'92dcd0cf37eeed51e355ce3ed25ed9bfe37831b8';

/// See also [spotTimersForGame].
@ProviderFor(spotTimersForGame)
const spotTimersForGameProvider = SpotTimersForGameFamily();

/// See also [spotTimersForGame].
class SpotTimersForGameFamily extends Family<List<Map<String, dynamic>?>> {
  /// See also [spotTimersForGame].
  const SpotTimersForGameFamily();

  /// See also [spotTimersForGame].
  SpotTimersForGameProvider call(
    String gameName,
  ) {
    return SpotTimersForGameProvider(
      gameName,
    );
  }

  @override
  SpotTimersForGameProvider getProviderOverride(
    covariant SpotTimersForGameProvider provider,
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
  String? get name => r'spotTimersForGameProvider';
}

/// See also [spotTimersForGame].
class SpotTimersForGameProvider
    extends AutoDisposeProvider<List<Map<String, dynamic>?>> {
  /// See also [spotTimersForGame].
  SpotTimersForGameProvider(
    String gameName,
  ) : this._internal(
          (ref) => spotTimersForGame(
            ref as SpotTimersForGameRef,
            gameName,
          ),
          from: spotTimersForGameProvider,
          name: r'spotTimersForGameProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$spotTimersForGameHash,
          dependencies: SpotTimersForGameFamily._dependencies,
          allTransitiveDependencies:
              SpotTimersForGameFamily._allTransitiveDependencies,
          gameName: gameName,
        );

  SpotTimersForGameProvider._internal(
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
    List<Map<String, dynamic>?> Function(SpotTimersForGameRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SpotTimersForGameProvider._internal(
        (ref) => create(ref as SpotTimersForGameRef),
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
    return _SpotTimersForGameProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SpotTimersForGameProvider && other.gameName == gameName;
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
mixin SpotTimersForGameRef
    on AutoDisposeProviderRef<List<Map<String, dynamic>?>> {
  /// The parameter `gameName` of this provider.
  String get gameName;
}

class _SpotTimersForGameProviderElement
    extends AutoDisposeProviderElement<List<Map<String, dynamic>?>>
    with SpotTimersForGameRef {
  _SpotTimersForGameProviderElement(super.provider);

  @override
  String get gameName => (origin as SpotTimersForGameProvider).gameName;
}

String _$statusesForGameHash() => r'bc15670fecdd141162a1821762a6aa84439dd17f';

/// See also [statusesForGame].
@ProviderFor(statusesForGame)
const statusesForGameProvider = StatusesForGameFamily();

/// See also [statusesForGame].
class StatusesForGameFamily extends Family<Map<String, String>> {
  /// See also [statusesForGame].
  const StatusesForGameFamily();

  /// See also [statusesForGame].
  StatusesForGameProvider call(
    String gameName,
  ) {
    return StatusesForGameProvider(
      gameName,
    );
  }

  @override
  StatusesForGameProvider getProviderOverride(
    covariant StatusesForGameProvider provider,
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
  String? get name => r'statusesForGameProvider';
}

/// See also [statusesForGame].
class StatusesForGameProvider extends AutoDisposeProvider<Map<String, String>> {
  /// See also [statusesForGame].
  StatusesForGameProvider(
    String gameName,
  ) : this._internal(
          (ref) => statusesForGame(
            ref as StatusesForGameRef,
            gameName,
          ),
          from: statusesForGameProvider,
          name: r'statusesForGameProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$statusesForGameHash,
          dependencies: StatusesForGameFamily._dependencies,
          allTransitiveDependencies:
              StatusesForGameFamily._allTransitiveDependencies,
          gameName: gameName,
        );

  StatusesForGameProvider._internal(
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
    Map<String, String> Function(StatusesForGameRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: StatusesForGameProvider._internal(
        (ref) => create(ref as StatusesForGameRef),
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
    return _StatusesForGameProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StatusesForGameProvider && other.gameName == gameName;
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
mixin StatusesForGameRef on AutoDisposeProviderRef<Map<String, String>> {
  /// The parameter `gameName` of this provider.
  String get gameName;
}

class _StatusesForGameProviderElement
    extends AutoDisposeProviderElement<Map<String, String>>
    with StatusesForGameRef {
  _StatusesForGameProviderElement(super.provider);

  @override
  String get gameName => (origin as StatusesForGameProvider).gameName;
}

String _$isUserInSquadHash() => r'e21be4f28a9b64a98886f6248d104f5c5568f24b';

/// See also [isUserInSquad].
@ProviderFor(isUserInSquad)
final isUserInSquadProvider = AutoDisposeProvider<bool>.internal(
  isUserInSquad,
  name: r'isUserInSquadProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$isUserInSquadHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsUserInSquadRef = AutoDisposeProviderRef<bool>;
String _$activeSquadMembersCountHash() =>
    r'800c696dcc9d0d29bff77e008a7523885b9ebecf';

/// See also [activeSquadMembersCount].
@ProviderFor(activeSquadMembersCount)
final activeSquadMembersCountProvider = AutoDisposeProvider<int>.internal(
  activeSquadMembersCount,
  name: r'activeSquadMembersCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeSquadMembersCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ActiveSquadMembersCountRef = AutoDisposeProviderRef<int>;
String _$squadHealthStatusHash() => r'0d35cba7aadcb3bc020ea51298120f3bc3194fd5';

/// Provider for computed squad health status
///
/// Copied from [squadHealthStatus].
@ProviderFor(squadHealthStatus)
final squadHealthStatusProvider = AutoDisposeProvider<String>.internal(
  squadHealthStatus,
  name: r'squadHealthStatusProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$squadHealthStatusHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SquadHealthStatusRef = AutoDisposeProviderRef<String>;
String _$counterHash() => r'4243b34530f53accfd9014a9f0e316fe304ada3e';

/// Example of Riverpod code generation for better performance
/// This file demonstrates how to use @riverpod annotations for automatic code generation
/// Generated provider - more efficient with code generation
///
/// Copied from [Counter].
@ProviderFor(Counter)
final counterProvider = AutoDisposeNotifierProvider<Counter, int>.internal(
  Counter.new,
  name: r'counterProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$counterHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Counter = AutoDisposeNotifier<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
